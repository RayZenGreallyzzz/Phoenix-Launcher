#!/usr/bin/env python3
"""Install ONLY verified NEW PPA 1–20 dungeon monster PNGs.

The source bundle comes from user Library ("Атлас пиксельных монстров
1–20.png"). No old live DUNGEON_MOB_SPRITES fallbacks.

This script intentionally never downloads public live PPA enemy art.
Drop the approved small ZIP into source_art to enable 20 local mob PNGs.
"""
from __future__ import annotations

import hashlib
import json
import struct
import zipfile
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
SRC = GAME / "source_art/PPA_New_Dungeon_Mobs_1-20_TEST.zip"
DEST = GAME / "assets/dungeon_new_mobs"
NAMES = [
    "mob_01_ash_rat.png", "mob_02_cave_spider.png",
    "mob_03_charred_beetle.png", "mob_04_carrion_bird.png",
    "mob_05_bone_rodent.png", "mob_06_goblin_scout.png",
    "mob_07_bone_warrior.png", "mob_08_ash_wolf.png",
    "mob_09_mushroom_abomination.png", "mob_10_goblin_shaman.png",
    "mob_11_cultist.png", "mob_12_cursed_knight.png",
    "mob_13_stone_golem.png", "mob_14_lava_elemental.png",
    "mob_15_ash_guard.png", "mob_16_hell_hound.png",
    "mob_17_fire_demon.png", "mob_18_void_watcher.png",
    "mob_19_elite_golem.png", "mob_20_ash_executioner.png",
]

def main() -> None:
    if not SRC.exists():
        print("PPA_NEW_DUNGEON_ART_PENDING zip_missing=1 old_mobs=0")
        return

    if SRC.stat().st_size > 9_000_000:
        raise ValueError("Unexpectedly large PPA new monster ZIP")
    with zipfile.ZipFile(SRC) as data:
        members = data.namelist()
        expected = {f"1-20/{name}" for name in NAMES} | {"manifest.json", "preview.jpg"}
        if set(members) != expected:
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
            if hashlib.sha256(payload).hexdigest() != row.get("sha256"):
                raise ValueError("New monster sprite SHA mismatch: " + name)
            if not payload.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError("Invalid monster PNG: " + name)
            w, h = struct.unpack(">II", payload[16:24])
            if (w, h) != (112, 112):
                raise ValueError("Unexpected source sprite size for " + name)
            output.append((name, payload))
        DEST.mkdir(parents=True, exist_ok=True)
        for name, payload in output:
            (DEST / name).write_bytes(payload)
        print(
            "PPA_NEW_DUNGEON_ART_IMPORTED_OK",
            "sprites=20",
            "types=rat,spider,beetle,...",
            "published_old=0",
            "server_writes=0",
            flush=True,
        )

if __name__ == "__main__":
    main()
