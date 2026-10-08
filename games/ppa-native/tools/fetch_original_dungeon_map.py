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
    (DEST / "dungeon_walk_mask.png").write_bytes(mask)
    (DEST / "dungeon_layout.webp").write_bytes(floor)
    print("PPA_ORIGINAL_DUNGEON_ASSETS_OK",
          "walk_grid=%sx%s" % (width, height),
          "walk_ratio=%.4f" % ratio,
          "walk_sha256=" + hashlib.sha256(bits).hexdigest(),
          "floor_sha256=" + hashlib.sha256(floor).hexdigest(),
          "source=live_PPA_no_private_repo_access", flush=True)

if __name__ == "__main__":
    main()
