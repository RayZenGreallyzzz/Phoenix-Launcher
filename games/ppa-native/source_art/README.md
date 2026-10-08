# PPA — new dungeon enemy art, levels 1–20

Only unpublished PPA dungeon sprites go into this test build. Deployed legacy `DUNGEON_MOB_SPRITES` are forbidden.

## Important correction — fourth monster

The initial recovered `Атлас пиксельных монстров 1–20.png` and its original 20-PNG ZIP accidentally included `mob_04_carrion_bird.png` (**old Падальщик**).

The **approved current in-game creature is «Слайм-падальщик»**, not the old bird. The wrong fourth PNG must never be presented as approved, renamed, repacked, drawn in Godot, or shipped in an APK.

Correct fourth asset ID: `mob_04_scavenger_slime.png`.

## Import contract

Provide:
1. `PPA_New_Dungeon_Mobs_1-20_TEST.zip` containing 20 valid 112×112 PNG files with a SHA-256 manifest, with slot 4 named `mob_04_scavenger_slime.png`.
2. `approved_mob04_sha256.txt`: the lowercase 64-character SHA-256 digest of a **separately confirmed correct slime image**, pinned independently of the ZIP's own manifest.

The importer validates the exact 20-file roster, image dimensions, per-file SHA-256 and the independent slime pin. It rejects the old bird. The existing `.zip.b64` in the earlier QA branch is an obsolete reference and **must not be used** as a release-ready pack. It is retained in that earlier branch only for audit/history.

**No complete verified pack = no new mob art activation.** This is intentional, not a bug. Do not resurrect ancient sprite art or change spawn levels, map, mask, bosses, realtime logic or balance to conceal a missing image. Boss artwork and levels 21–60 are a separate approval/import step.
