#!/usr/bin/env python3
"""Read-only inspection/export of sprites FROM the currently deployed Telegram PPA.

Reads the active same-origin HTML and the images it references. Produces an audit
report and numbered source files for review. Does NOT publish any replacement
sprites or assign art to Godot. No gameplay or server writes.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen

HOST = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
VIDEO_LEVELS = [
    "Пепельная крыса", "Пещерный паук", "Обугленный жук",
    "Слайм-падальщик", "Костяной грызун", "Гоблин-разведчик",
    "Костяной воин", "Пепельный волк", "Грибная тварь", "Гоблин-шаман",
    "Культист", "Проклятый рыцарь", "Каменный голем", "Лавовый элементаль",
    "Пепельный страж", "Адская гончая", "Огненный демон",
    "Пустотный наблюдатель", "Элитный голем", "Пепельный палач",
]


def fetch(url: str, limit: int) -> bytes:
    req = Request(url, headers={"User-Agent": "PPA-Dungeon-Live-Art-Audit/1", "Cache-Control": "no-cache"})
    with urlopen(req, timeout=100) as response:
        content = response.read(limit + 1)
    if len(content) > limit:
        raise ValueError("Unexpectedly large source at " + url)
    return content


def js_array(source: str, name: str) -> str:
    pattern = r"\b(?:const|let|var)\s+" + re.escape(name) + r"\s*=\s*\[([\s\S]*?)\]\s*;"
    m = re.search(pattern, source)
    if not m:
        raise ValueError("Could not find deployed runtime array: " + name)
    return m.group(1)


def image_properties(data: bytes) -> tuple[str, int | None, int | None]:
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        return "png", int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        # WebP dimensions aren't used as a security criterion; keep the original bytes.
        return "webp", None, None
    if data.startswith(b"\xff\xd8\xff"):
        return "jpeg", None, None
    raise ValueError("The deployed asset is not a recognized raster image")


def find_mentions(source: str, needle: str, cap: int = 8) -> list[str]:
    samples = []
    for match in re.finditer(re.escape(needle), source, re.I):
        frag = source[max(0, match.start() - 130):match.end() + 210]
        frag = re.sub(r"data:image/[^;\"']+;base64,[A-Za-z0-9+/=]+", "[EMBEDDED_IMAGE]", frag)
        samples.append(re.sub(r"\s+", " ", frag).strip()[:360])
        if len(samples) >= cap:
            break
    return samples


def run(html: bytes, output: Path, allow_downloads: bool) -> dict:
    source = html.decode("utf-8")
    output.mkdir(parents=True, exist_ok=True)
    source_sha = hashlib.sha256(html).hexdigest()
    array = js_array(source, "DUNGEON_MOB_SPRITES")
    paths = re.findall(r"(['\"])(.*?)\1\s*,?", array, re.S)
    raw_sources = [value for _, value in paths]
    if len(raw_sources) != 20:
        raise ValueError("Deployed DUNGEON_MOB_SPRITES is not 20 entries: " + str(len(raw_sources)))
    table = js_array(source, "MOB_TABLE")
    names = []
    for match in re.finditer(r"\{\s*lvl\s*:\s*(\d+)\s*,\s*n\s*:\s*(['\"])(.*?)\2", table):
        lv = int(match.group(1))
        if 1 <= lv <= 20:
            names.append((lv, match.group(3)))
    # Do not treat any static array as authoritative unless current runtime
    # demonstrably creates mob sprite references from DUNGEON_MOB_IMAGES.
    runtime_uses_sheet = bool(re.search(r"sprite\s*:\s*DUNGEON_MOB_IMAGES\s*\[", source))
    same_origin = urlparse(HOST).netloc
    entries = []
    for ix, asset in enumerate(raw_sources):
        label = VIDEO_LEVELS[ix]
        data = None
        if asset.startswith("data:image/"):
            m = re.fullmatch(r"data:image/(png|webp|jpeg);base64,([A-Za-z0-9+/=]+)", asset)
            if not m:
                raise ValueError("Invalid source image data URI at level " + str(ix + 1))
            data = base64.b64decode(m.group(2), validate=True)
        elif allow_downloads:
            url = urljoin(HOST + "/", asset)
            if urlparse(url).netloc != same_origin:
                raise ValueError("Unexpected cross-origin image: " + url)
            data = fetch(url, 15_000_000)
        row = {"level": ix + 1, "video_name": label, "source_reference": asset[:250]}
        if data is not None:
            fmt, w, h = image_properties(data)
            filename = f"level_{ix+1:02d}_runtime_slot.{fmt}"
            (output / filename).write_bytes(data)
            row.update(file=filename, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                       width=w, height=h)
        entries.append(row)
    game_names = {level: name for level, name in names}
    conflicts = [{"level": lv, "in_game_table": game_names.get(lv),
                  "video_name": VIDEO_LEVELS[lv - 1]}
                 for lv in range(1, 21) if game_names.get(lv) != VIDEO_LEVELS[lv - 1]]
    report = {
        "warning": "Audit/export only. Static sprite table may be overridden by runtime code. Do not blindly install into Godot.",
        "source": HOST, "html_sha256": source_sha, "runtime_indexed_sprite_reference": runtime_uses_sheet,
        "video_names": VIDEO_LEVELS, "table_name_conflicts": conflicts,
        "static_images": entries,
        "dynamic_sprite_code": {
            "sprite_assignments": find_mentions(source, ".sprite="),
            "dungeon_mob_images_usages": find_mentions(source, "DUNGEON_MOB_IMAGES"),
            "slime_mentions": find_mentions(source, "Слайм"),
            "slime_english_mentions": find_mentions(source, "slime"),
            "color_mentions": find_mentions(source, "цвет", cap=4),
        },
    }
    (output / "audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PPA_LIVE_MOB_ART_AUDIT_OK static_slots=20 downloaded=" + str(sum(bool(x.get('file')) for x in entries)))
    print("SOURCE_SHA256=" + source_sha)
    print("TABLE_NAME_CONFLICTS=" + str(len(conflicts)))
    for r in entries:
        print(f"LEVEL {r['level']:02d} {r['video_name']}: {r.get('file', 'not_downloaded')} "
              f"sha={r.get('sha256', 'none')[:16]}")
    print("DYNAMIC_CODE_MENTIONS: " + json.dumps({k: len(v) for k, v in report["dynamic_sprite_code"].items()}))
    print("PPA_ART_MAPPING_REQUIRES_RUNTIME_REVIEW=1")
    return report


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--html-file", help="Read local HTML instead of deploying a network request")
    p.add_argument("--output", type=Path, default=Path("audit-output/live-dungeon-art"))
    p.add_argument("--no-download", action="store_true")
    a = p.parse_args()
    html = Path(a.html_file).read_bytes() if a.html_file else fetch(
        HOST + "/?godot_live_mob_art_audit=20261009", 11_000_000)
    run(html, a.output, not a.no_download)
