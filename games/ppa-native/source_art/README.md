# New dungeon enemy art — original user Library

Only the **new unpublished** 1–20 enemy sprites belong here. The legacy deployed PPA `DUNGEON_MOB_SPRITES` art must never be used.

The visual-test build accepts one source archive at:

`games/ppa-native/source_art/PPA_New_Dungeon_Mobs_1-20_TEST.zip`

The archive was prepared from the user's own `Атлас пиксельных монстров 1–20.png` and includes 20 PNGs and a SHA256 manifest. The Android build verifies exact PNG names, 112×112 dimensions and each hash, and unpacks only verified sprites into `assets/dungeon_new_mobs` before the Godot import. It rejects partial/altered packs.

**No ZIP means no enemy visuals.** This is intentional, to prevent ancient art reappearing. The current level list has distinct rat, cave-spider and charred-beetle tiers; boss art and floors 21–60 are not connected yet. No server damage or rewards.
