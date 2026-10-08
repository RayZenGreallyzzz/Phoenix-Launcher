#!/usr/bin/env python3
"""Copy deployed PPA dungeon stone art and EXACT runtime walk bits.

The approved source PNG mask is in a private repository, so never request a
GitHub secret/token. Published Telegram PPA already embeds its *final*
collision grid after Lanczos resize and red/alpha threshold in build.mjs.
Extract that public authoritative bitset and convert it losslessly to PNG
for Godot's Image.get_pixel. No independent map geometry or guesswork.
"""
import base64
import hashlib
import re
import struct
import zlib
from pathlib import Path
from urllib.request import Request, urlopen

DEST = Path(__file__).resolve().parents[1] / "assets"
HOST = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"

def fetch(uri: str, limit: int) -> bytes:
    req = Request(uri, headers={"User-Agent": "PPA-Godot-Dungeon-Port/1"})
    with urlopen(req, timeout=110) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Oversized PPA asset: " + uri)
    return data

def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (struct.pack(">I", len(payload)) + kind + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))

def collision_png(bits: bytes, w: int, h: int) -> tuple[bytes, float]:
    # 1-bit grid is packed MSB-first by PPA's JS runtime.
    # RGBA white/opaque = walkable, white/transparent = wall.
    raw = bytearray()
    walk_count = 0
    for y in range(h):
        raw.append(0)
        for x in range(w):
            n = y * w + x
            walk = (bits[n // 8] >> (7 - n % 8)) & 1
            walk_count += walk
            raw.extend((255, 255, 255, 255 if walk else 0))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(raw, 7))
        + png_chunk(b"IEND", b"")
    )
    return png, walk_count / float(w * h)

def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    floor = fetch(HOST + "/assets/dungeon-layout-test.webp", 45_000_000)
    if len(floor) < 10_000 or floor[:4] != b"RIFF" or floor[8:12] != b"WEBP":
        raise ValueError("Original PPA dungeon composite missing or invalid")

    source = fetch(HOST + "/?godot_dungeon_mask=20261008", 10_000_000).decode("utf-8")
    # The approved build.mjs emits:
    # const DG={gw:2048,gh:...,cellX:...,cellY:...};
    # (function(){const bin=atob('...');...})()
    geometry = re.search(r"const\s+DG\s*=\s*\{\s*gw\s*:\s*(\d+)\s*,\s*gh\s*:\s*(\d+)\s*,", source)
    if geometry is None:
        raise ValueError("Deployed PPA does not expose the approved DG walk dimensions")
    width, height = map(int, geometry.groups())
    if width != 2048 or not (400 <= height <= 4096):
        raise ValueError(f"Unexpected deployed walk dimensions {width}x{height}")
    bitfield = re.search(r"const\s+bin\s*=\s*atob\(['\"]([A-Za-z0-9+/=]{10000,})['\"]\)", source)
    if bitfield is None:
        raise ValueError("Deployed PPA does not expose the approved packed DG walk data")
    bits = base64.b64decode(bitfield.group(1), validate=True)
    if len(bits) != (width * height + 7) // 8:
        raise ValueError("Published walk bitfield length mismatch")
    mask, ratio = collision_png(bits, width, height)
    if not 0.08 <= ratio <= 0.65:
        raise ValueError(f"Unexpected original dungeon walk coverage {ratio:.3f}")
    # Derive a guaranteed-safe initial TEST position from published walk bits
    # at build time. Avoid a brute-force mask search at every scene load.
    def walk_at(x: int, y: int) -> bool:
        if x < 0 or y < 0 or x >= width or y >= height:
            return False
        i = y * width + x
        return ((bits[i // 8] >> (7 - i % 8)) & 1) == 1

    spawn = None
    radius = 10
    for x in range(max(20, int(width * 0.035)), max(24, int(width * 0.38)), 6):
        if spawn:
            break
        for off in range(0, max(6, int(height * 0.33)), 6):
            for direction in (1, -1):
                y = int(height * 0.5) + direction * off
                if all(walk_at(x + dx, y + dy) for dx,dy in
                       ((0,0),(radius,0),(-radius,0),(0,radius),(0,-radius),
                        (7,7),(-7,7),(7,-7),(-7,-7))):
                    spawn = (x,y)
                    break
            if spawn:
                break
    if not spawn:
        raise ValueError("Published mask contains no safe dungeon entrance corridor")
    # This is a normal generated Godot source constant, not a server spawn.
    # World-relative position remains correct if the final floor height differs
    # by one pixel due to texture rounding.
    generated = DEST.parent / "scripts/ppa_dungeon_spawn_generated.gd"
    generated.write_text(
        "extends RefCounted\n"
        + "const UV := Vector2(%.9f, %.9f)\n" % (
            (spawn[0] + 0.5) / float(width), (spawn[1] + 0.5) / float(height))
        + "const MASK_DIMS := Vector2i(%d, %d)\n" % (width, height)
        + 'const WALK_SHA256 := "%s"\n' % hashlib.sha256(bits).hexdigest(),
        encoding="utf-8"
    )
    # ORIGINAL Telegram PPA spawn positions, twenty level branches and
    # boss chamber are embedded as JSON constants in the public deployed
    # client. This exports the EXACT already-built positions to a temporary
    # Godot contract; no hand-authored corridors, levels, or fake mob spawns.
    import json
    def deployed_json_array(name: str):
        m = re.search(
            r"\bconst\s+" + re.escape(name) + r"\s*=\s*(\[[^\n;]*\])\s*;",
            source, re.DOTALL
        )
        if m is None:
            raise ValueError("Published dungeon spawn constant missing: " + name)
        return json.loads(m.group(1))

    spawn_rows = deployed_json_array("DG_ACTIVE_SPAWNS")
    room_rows = deployed_json_array("DG_ROOM_META")
    boss_match = re.search(
        r"\bconst\s+DG_BOSS_IMG\s*=\s*\[\s*(\d+)\s*,\s*(\d+)\s*\]\s*;",
        source
    )
    if boss_match is None:
        raise ValueError("Published dungeon boss room center missing")
    boss_x, boss_y = map(int, boss_match.groups())
    if len(room_rows) != 20 or sorted(r["level"] for r in room_rows) != list(range(1, 21)):
        raise ValueError("Published original dungeon is no longer twenty distinct level branches")
    if not (250 <= len(spawn_rows) <= 2500):
        raise ValueError("Original published dungeon spawn density unexpectedly changed")
    if not (0 <= boss_x < width and 0 <= boss_y < height and walk_at(boss_x, boss_y)):
        raise ValueError("Published boss point outside authentic walk mask")
    level_map = [int(row["level"]) for row in room_rows]
    actual_per_branch = [0] * 20
    for i, entry in enumerate(spawn_rows):
        if (not isinstance(entry, list) or len(entry) < 4
                or not all(isinstance(c, int) for c in entry[:4])):
            raise ValueError("Malformed published dungeon spawn: " + str(i))
        x, y, branch, ordinal = entry[:4]
        if (not (0 <= x < width and 0 <= y < height)
                or not (0 <= branch < 20) or ordinal < 0
                or not walk_at(x, y)):
            raise ValueError("Spawn outside original mask/branch: " + str(i))
        actual_per_branch[branch] += 1
    if any(actual_per_branch[i] != int(room_rows[i]["count"]) for i in range(20)):
        raise ValueError("Mob counts disagree with published PPA room metadata")

    entities_source = DEST.parent / "scripts/ppa_dungeon_entities_generated.gd"
    # Array-only JSON is valid inside a Godot string. Parse it once on dungeon
    # entry; static main-scene code stays tiny, test APK never mutates server.
    spawn_json = json.dumps(spawn_rows, separators=(",", ":"))
    entities_source.write_text(
        "extends RefCounted\n"
        + 'const SPAWNS_JSON := "' + spawn_json + '"\n'
        + "const ROOM_LEVELS := " + json.dumps(level_map) + "\n"
        + "const ROOM_COUNTS := " + json.dumps(actual_per_branch) + "\n"
        + "const BOSS_IMG := Vector2i(%d, %d)\n" % (boss_x, boss_y)
        + "const ORIGINAL_MASK_SIZE := Vector2i(%d, %d)\n" % (width, height)
        + 'const SPAWNS_SHA256 := "%s"\n' % hashlib.sha256(spawn_json.encode()).hexdigest(),
        encoding="utf-8"
    )
    print("PPA_ORIGINAL_DUNGEON_ENTITIES_OK",
          "spawn_count=" + str(len(spawn_rows)),
          "branches=20",
          "per_branch=" + ",".join(map(str, actual_per_branch)),
          "boss_mask=%s,%s" % (boss_x, boss_y),
          "sha256=" + hashlib.sha256(spawn_json.encode()).hexdigest(),
          "server_writes=0", flush=True)

    (DEST / "dungeon_walk_mask.png").write_bytes(mask)
    (DEST / "dungeon_layout.webp").write_bytes(floor)
    print("PPA_ORIGINAL_DUNGEON_ASSETS_OK",
          "walk_grid=%sx%s" % (width, height),
          "walk_ratio=%.4f" % ratio,
          "walk_sha256=" + hashlib.sha256(bits).hexdigest(),
          "floor_sha256=" + hashlib.sha256(floor).hexdigest(),
          "spawn_mask=%s,%s" % spawn,
          "source=live_PPA_no_private_repo_access", flush=True)

if __name__ == "__main__":
    main()
