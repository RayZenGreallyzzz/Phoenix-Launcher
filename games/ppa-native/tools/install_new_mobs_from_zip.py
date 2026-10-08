#!/usr/bin/env python3
"""Install ONLY verified NEW PPA 1–20 dungeon monster PNGs.

The source bundle comes from user Library ("Атлас пиксельных монстров
1–20.png"). No old live DUNGEON_MOB_SPRITES fallbacks.

This script intentionally never downloads public live PPA enemy art.
Drop the approved ZIP and the independently pinned SHA256 of the approved slime into source_art to enable 20 local mob PNGs.
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
    "mob_03_charred_beetle.png", "mob_04_scavenger_slime.png",
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
    # The recovered old atlas still contained a bird as the fourth creature.
    # Slot 4 is the approved Слайм-падальщик. Until its separate, human-
    # approved image is present, do NOT silently ship the obsolete bird.
    approved_sha_file = GAME / "source_art/approved_mob04_sha256.txt"
    if not approved_sha_file.is_file():
        raise ValueError(
            "PPA_SLIME_APPROVAL_REQUIRED: slot 4 needs approved "
            "mob_04_scavenger_slime.png and its pinned SHA256"
        )
    approved_slime_sha = approved_sha_file.read_text(encoding="utf-8").strip().lower()
    if not re.fullmatch(r"[a-f0-9]{64}", approved_slime_sha):
        raise ValueError("Invalid approved slime SHA256 pin")
    with zipfile.ZipFile(SRC) as data:
        members = data.namelist()
        if any("carrion_bird" in member for member in members):
            raise ValueError("PPA_OBSOLETE_CARRION_BIRD_REJECTED: replace slot 4 with approved slime art")
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
            actual_sha = hashlib.sha256(payload).hexdigest()
            if actual_sha != row.get("sha256"):
                raise ValueError("New monster sprite SHA mismatch: " + name)
            if i == 3 and actual_sha != approved_slime_sha:
                raise ValueError("PPA_UNAPPROVED_SLIME_ART_REJECTED: slot 4 SHA256 is not the human-approved asset")
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
