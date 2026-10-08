# Original PPA dungeon creatures in Godot: 1–60

Verified against **the live PPA client** SHA-256 `3323076a3adb46677e8bf56036a93f6935817efd2b019a8c01d52368ce75bfce`, via isolated, read-only audit [run 37857073923](https://github.com/RayZenGreallyzzz/Phoenix-Launcher/actions/runs/37857073923).

## IMPORTANT: there are NOT 60 different monster species

The live PPA source defines `MOB_TABLE` for **20 base types**. The 21–40 monsters are instantiated from `mobByLvl(DG_SPAWN_LVL[si])` and passed through `applyDungeon21MobStats`, which sets `e.baseLvl=baseLvl`, `e.lvl=baseLvl+20` and preserves the original sprite and animation identity. The 41–60 branch calls `applyDungeon41MobStats`, which sets `e.lvl=baseLvl+40`. It **also explicitly retains original art**.

Godot maps all three levels to the same source asset:

| Base level | 21–40 level | 41–60 level | Original PPA monster |
|---:|---:|---:|---|
| 1 | 21 | 41 | Пепельная крыса |
| 2 | 22 | 42 | Пещерный паук |
| 3 | 23 | 43 | Обугленный жук |
| 4 | 24 | 44 | Слайм-падальщик (green/red/blue) |
| 5 | 25 | 45 | Костяной грызун |
| 6 | 26 | 46 | Гоблин-разведчик |
| 7 | 27 | 47 | Костяной воин |
| 8 | 28 | 48 | Пепельный волк |
| 9 | 29 | 49 | Грибная тварь |
| 10 | 30 | 50 | Гоблин-шаман |
| 11 | 31 | 51 | Культист |
| 12 | 32 | 52 | Проклятый рыцарь |
| 13 | 33 | 53 | Каменный голем |
| 14 | 34 | 54 | Лавовый элементаль |
| 15 | 35 | 55 | Пепельный страж |
| 16 | 36 | 56 | Адская гончая |
| 17 | 37 | 57 | Огненный демон |
| 18 | 38 | 58 | Пустотный наблюдатель |
| 19 | 39 | 59 | Элитный голем |
| 20 | 40 | 60 | Пепельный палач |

### Combat archetype names, not distinct visuals

At level 21–60 the live client cycles by *ordinal within the same room*: `roomOrd % 3` gives **ЖИВУЧИЙ**, **БРОНИРОВАННЫЙ**, **БЕРСЕРК**. The extra HP/DEF/ATK in PPA are authoritative there; **Godot visual-only QA does not create/change those stats**. Archetype is stored in preview-only metadata for later verification; source art remains unchanged.

All 60 mobs use the **same original 22 PNG files**, consisting of 19 native sprite-sheet animations for non-slimes (including cave spider) and three separate original slimes at 4, 24, 44. The original walk mask, 14px alignment, spawn positions, 24-entity preview cap and test-only AI behaviour are unchanged. Phoenix20 / Lord40 / Dragon60 are **separate bosses** and continue gated until their own original art is specifically imported and verified.

The selector in dungeon cycles through `МОБЫ 1–20` → `МОБЫ 21–40` → `МОБЫ 41–60`; old Godot disabled tier 2/3 sprites by mistake. This test branch fixes that behavior.

No Telegram/server writes, no sync, no loot, no shared inventory, no multiplayer. This is **not** the official production MMORPG client.
