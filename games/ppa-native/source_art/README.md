# PPA Godot dungeon 1–20 — approved names and safe art importer

The **current PPA gameplay video** is the authoritative source for the dungeon monster **name and level** mapping. Old September posters and the archived 20-PNG pack are NOT approved sprite sources.

## Exact one-to-one monster roster

| Level | Name | Asset |
|---:|---|---|
| 1 | Пепельная крыса | `mob_01_ash_rat.png` |
| 2 | Пещерный паук | `mob_02_cave_spider.png` |
| 3 | Обугленный жук | `mob_03_charred_beetle.png` |
| 4 | Слайм-падальщик | **Green + red + blue** variants |
| 5 | Костяной грызун | `mob_05_bone_rodent.png` |
| 6 | Гоблин-разведчик | `mob_06_goblin_scout.png` |
| 7 | Костяной воин | `mob_07_bone_warrior.png` |
| 8 | Пепельный волк | `mob_08_ash_wolf.png` |
| 9 | Грибная тварь | `mob_09_mushroom_abomination.png` |
| 10 | Гоблин-шаман | `mob_10_goblin_shaman.png` |
| 11 | Культист | `mob_11_cultist.png` |
| 12 | Проклятый рыцарь | `mob_12_cursed_knight.png` |
| 13 | Каменный голем | `mob_13_stone_golem.png` |
| 14 | Лавовый элементаль | `mob_14_lava_elemental.png` |
| 15 | Пепельный страж | `mob_15_ash_guard.png` |
| 16 | Адская гончая | `mob_16_hell_hound.png` |
| 17 | Огненный демон | `mob_17_fire_demon.png` |
| 18 | Пустотный наблюдатель | `mob_18_void_watcher.png` |
| 19 | Элитный голем | `mob_19_elite_golem.png` |
| 20 | Пепельный палач | `mob_20_ash_executioner.png` |

Phoenix is the **separate boss after level 20**. Boss artwork and floors 21–60 remain separately gated until approved; they must never inherit the wrong 1–20 sprites.

## Level 4: three color variants of the SAME monster

- `mob_04_slime_green.png`
- `mob_04_slime_red.png`
- `mob_04_slime_blue.png`

The same level-4 monster type cycles through the three colors by stable spawn index. It does **not** change HP, damage, drops, level, or spawn coordinates. Do not use a bird, rename a bird, or fake new colors with other species.

## Import contract (22 approved images)

The importer `tools/install_new_mobs_from_zip.py` requires:

1. `PPA_New_Dungeon_Mobs_1-20_TEST.zip.b64` containing a ZIP with **22** separate 112×112 PNGs (the 20 level representatives, including green slime at level 4, plus red and blue slime);
2. `PPA_New_Dungeon_Mobs_1-20_TEST.zip.sha256` containing the SHA-256 of that ZIP;
3. `approved_mob04_variants_sha256.json`: a JSON object keyed by the three `mob_04_slime_*.png` filenames with **independently approved** SHA-256 values.

ZIP entries: `1-20/<PNG>` for each image, `manifest.json`, and `preview.jpg`. The manifest `enemies` list contains 20 rows, each with `level`, `filename`, and `sha256`; `slime_variants` contains two extra rows for **red**, then **blue**, both at level 4. A complete correct ZIP manifest does not replace independent human approval of the actual art.

The older `PPA_New_Dungeon_Mobs_1-20_TEST.zip.b64` had `mob_04_carrion_bird.png` and is **removed from this test branch**. It remains available in Git history if needed for forensic comparison; do not ship it.

When approved art is missing, Godot safely shows the genuine map without monster/boss visuals. This is deliberate until all 22 files are verified. Test-only visuals do not touch Telegram PPA production accounts, combat server, loot, bosses, spawns, collision mask or performance constants.
