# PPA Godot unified native integration — QA checkpoint, 2026-10-10

## Isolation and provenance
- Base: `feature/ppa-native-shared-npc-bridge-20261010` (client PR #28; retains NPC, Arena AI training, shared save views, art, original map, 8 hero GLBs and events).
- Selectively integrated native account lifecycle from `feature/ppa-native-session-snapshot-20261010` (client PR #26). This is NOT a full-tree overwrite or a merge into `main`.
- Added **mandatory game-session hand-off** to `SceneTree` (`ppa_native_game_session`) that PR #26 lacked. The current native world requires this key to fetch `/api/game/state`, NPC read-only projections and optional realtime presence.
- Preserve the mature responsive portrait/landscape hero selection and 3D preview instead of replacing it with an older fixed-layout gallery.
- Clear old account, bearer session and old read-only snapshot on startup/account exit. Character class remains server-owned.
- Build a separate **`com.phoenixgames.ppa.beta`** debug APK as an Actions **artifact only**, not a GitHub release, not the `ppa-native-stable` update feed.

## Current permissions and server dependencies
- Existing Phoenix ticket exchange and `/api/game/me` work independently of native save permission.
- `GET /api/game/character` and `POST /api/game/character/register` need backend PR #30 and owner-managed flags; registration is expected to be unavailable when feature disabled.
- `GET /api/game/state` needs approved read-only flag `PPA_GODOT_STATE_READ_ENABLED=1`. HTTP 404 leaves the client in visibly unsynced **local test-only** mode.
- `GET /api/game/npc/{service}` needs backend PR #31 and independently authorized read-only feature flag(s); no server write endpoints for merchant, forge, auction or arena are implemented.
- `POST /api/game/realtime/ticket` needs PR #30 and an owner-approved feature flag. This experimental socket only displays online presence; it **does not** implement native combat or movement. It can disconnect the same character's Telegram socket.
- No Cloudflare deployment, D1 change, save migration, PPA release publication, or original Telegram changes are included.

## Regression guard and artifact
- `python3 games/ppa-native/tools/test_native_auth_boundary.py` checks fresh account-bound tickets, verified save, class ownership, server token handoff and responsive selection.
- Workflow: `.github/workflows/ppa-native-unified-beta-20261010.yml`; path-scoped integration-branch push; intended output is a signed debug Beta APK as a workflow artifact.
- APK compilation, signature/installation and tablet FPS MUST be verified from the actual run and device. A passing source test by itself does not prove end-to-end game sync.

## Required end-to-end checks before activating anything
1. Existing linked Telegram account: verify same hero name, class, level and **versioned** save.
2. Verify original sharpened item UID/level, rune counts/slots, learned skill ranks/books and Gold/PPA/Gram balances match the Telegram client without alterations.
3. Open NPC/forge/auction/clan/events; compare catalog vs server-owned values, and verify unavailable actions are labeled disabled (no fake purchases).
4. Switch Phoenix accounts on same device: no prior hero, save or bearer remains in native UI.
5. Unlinked/email-only account must never get a fabricated Telegram ID or starter inventory.
6. Test game without read-only server flag: safe local gallery and explicit unsynced status; no 404 retry storm.
7. Check direct APK opening without Launcher ticket is denied; Launcher opens fresh one-time ticket.
8. Only after security, D1 backup and Worker rollback verification: stage server PR #30/#31 separately and gate with explicit approval.

**DO NOT merge this branch into main or publish to stable just to test it.**
