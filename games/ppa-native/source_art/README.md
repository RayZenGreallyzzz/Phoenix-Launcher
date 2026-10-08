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

## Authoritative source: the LIVE Telegram PPA

The approved runtime is the game itself, not September's Library poster or an older 20-file ZIP.

The client HTML with SHA-256 `3323076a3adb46677e8bf56036a93f6935817efd2b019a8c01d52368ce75bfce` supplies exact public image URLs. The isolated Godot CI fetches them with `tools/export_live_runtime_monsters.py` and verifies each content-addressed PNG.

The exact **22 original runtime images** are:

- 18 approved 4×4 animation sheets from `MOB_ANIM_PACKS`: levels 1, 3, and 5–20. Each atlas is 768×640 (192×160 frames); original per-level animation timing is recorded.
- The separately updated level-2 cave spider atlas `CAVE_SPIDER_ATLAS`: 768×448 (192×112 frames).
- Three live level-4 `SLIME_SCAVENGER_SPRITES`: green, red, blue, each 165×160. Three appearances combined with mirrored direction and width multipliers (0.88, 0.96, 1.04, 1.12).

The old `DUNGEON_MOB_SPRITES` array is not the current visual source for several mobs and MUST NOT be imported by itself. Nor should `mob_04_carrion_bird.png` ever be used.

### Steps for isolated QA

```bash
python3 games/ppa-native/tools/export_live_runtime_monsters.py \
  --expect-source-sha256 3323076a3adb46677e8bf56036a93f6935817efd2b019a8c01d52368ce75bfce \
  --output games/ppa-native/assets/dungeon_new_mobs
```

This saves exactly 22 unmodified PNGs plus `manifest.json`; normal native Godot import then uses 4×4 frames and real 1–20 level assignment. If the deployed client changes, the exporter refuses to re-import silently. It never modifies server data, character saves, drops, bosses or the accepted map/mask.

**Status:** Godot integration is isolated on a draft branch until the Android CI smoke test and device visual check pass. No changes to Telegram PPA production.
