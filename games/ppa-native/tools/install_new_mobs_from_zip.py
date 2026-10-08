#!/usr/bin/env python3
"""Install ONLY verified NEW PPA 1–20 dungeon monster PNGs.

The source bundle comes from user Library ("Атлас пиксельных монстров
1–20.png"). No old live DUNGEON_MOB_SPRITES fallbacks.

This script intentionally never downloads public live PPA enemy art.
Drop a verified 22-PNG ZIP and independently approved 3-color slime SHA256 pins into source_art. A missing pack leaves enemy visuals disabled.
"""
from __future__ import annotations

import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
SRC = GAME / "source_art/PPA_New_Dungeon_Mobs_1-20_TEST.zip"
DEST = GAME / "assets/dungeon_new_mobs"
NAMES = [
    "mob_01_ash_rat.png", "mob_02_cave_spider.png",
    "mob_03_charred_beetle.png", "mob_04_slime_green.png",
    "mob_05_bone_rodent.png", "mob_06_goblin_scout.png",
    "mob_07_bone_warrior.png", "mob_08_ash_wolf.png",
    "mob_09_mushroom_abomination.png", "mob_10_goblin_shaman.png",
    "mob_11_cultist.png", "mob_12_cursed_knight.png",
    "mob_13_stone_golem.png", "mob_14_lava_elemental.png",
    "mob_15_ash_guard.png", "mob_16_hell_hound.png",
    "mob_17_fire_demon.png", "mob_18_void_watcher.png",
    "mob_19_elite_golem.png", "mob_20_ash_executioner.png",
]
SLIME_FILES = [
    "mob_04_slime_green.png",
    "mob_04_slime_red.png",
    "mob_04_slime_blue.png",
]
EXTRAS = SLIME_FILES[1:]

def verify_png(data: bytes, name: str) -> None:
    if not data.startswith(b"\\x89PNG\\r\\n\\x1a\\n"):
        raise ValueError("Invalid monster PNG: " + name)
    w, h = struct.unpack(">II", data[16:24])
    if (w, h) != (112, 112):
        raise ValueError("Unexpected source sprite size for " + name)

def verify_image(data, filepath: str, filename: str, expected_sha: str,
                 pins: dict[str, str], output: list[tuple[str, bytes]]) -> None:
    actual_sha = hashlib.sha256(data).hexdigest()
    if actual_sha != expected_sha:
        raise ValueError("New monster sprite SHA mismatch: " + filename)
    if filename in SLIME_FILES and actual_sha != pins[filename]:
        raise ValueError("PPA_UNAPPROVED_SLIME_ART_REJECTED: " + filename)
    verify_png(data, filename)
    output.append((filename, data))

def main() -> None:
    if not SRC.exists():
        print("PPA_NEW_DUNGEON_ART_PENDING zip_missing=1 old_mobs=0")
        return

    if SRC.stat().st_size > 9_000_000:
        raise ValueError("Unexpectedly large PPA new monster ZIP")
    # Three independently approved slime PNGs are required. Never rename
    # the bird or reuse one colored slime for the other two.
    pins_path = GAME / "source_art/approved_mob04_variants_sha256.json"
    if not pins_path.is_file():
        raise ValueError(
            "PPA_SLIME_APPROVAL_REQUIRED: approved green/red/blue source hashes missing"
        )
    pins = json.loads(pins_path.read_text(encoding="utf-8"))
    if not isinstance(pins, dict) or set(pins) != set(SLIME_FILES):
        raise ValueError("Slime approval pin set must contain exactly three colors")
    for filename in SLIME_FILES:
        sha = pins[filename]
        if not isinstance(sha, str) or not re.fullmatch(r"[a-f0-9]{64}", sha):
            raise ValueError("Invalid independently approved SHA256: " + filename)
    for obsolete in ("mob_04_carrion_bird.png", "mob_04_scavenger_slime.png"):
        if (DEST / obsolete).exists():
            raise ValueError("PPA_OBSOLETE_CARRION_BIRD_REJECTED: stale fourth-mob art")
    with zipfile.ZipFile(SRC) as data:
        members = data.namelist()
        if any("carrion_bird" in member for member in members):
            raise ValueError("PPA_OBSOLETE_CARRION_BIRD_REJECTED: replace slot 4 with approved slime art")
        expected = {f"1-20/{name}" for name in NAMES + EXTRAS} | {"manifest.json", "preview.jpg"}
        if set(members) != expected or len(members) != len(expected):
            raise ValueError("Unsafe or unexpected new dungeon monster filenames")
        manifest = json.loads(data.read("manifest.json"))
        rows = manifest.get("enemies")
        if not isinstance(rows, list) or len(rows) != 20:
            raise ValueError("New monster source manifest has wrong length")
        output = []
        for i, name in enumerate(NAMES):
            row = rows[i]
            if int(row.get("level", 0)) != i + 1 or row.get("filename") != name:
                raise ValueError("Monster order does not match recovered atlas")
            payload = data.read(f"1-20/{name}")
            verify_image(payload, f"1-20/{name}", name, row.get("sha256"), pins, output)
        variants = manifest.get("slime_variants")
        if not isinstance(variants, list) or len(variants) != 2:
            raise ValueError("Three-color slime manifest must list red and blue variants")
        for i, name in enumerate(EXTRAS):
            row = variants[i]
            if row.get("level") != 4 or row.get("filename") != name:
                raise ValueError("Slime color/order mismatch in manifest")
            verify_image(data.read(f"1-20/{name}"), f"1-20/{name}",
                         name, row.get("sha256"), pins, output)
        DEST.mkdir(parents=True, exist_ok=True)
        for name, payload in output:
            (DEST / name).write_bytes(payload)
        print(
            "PPA_NEW_DUNGEON_ART_IMPORTED_OK",
            "sprites=22",
            "types=20_level_species,slime_green_red_blue",
            "published_old=0",
            "server_writes=0",
            flush=True,
        )

if __name__ == "__main__":
    main()
