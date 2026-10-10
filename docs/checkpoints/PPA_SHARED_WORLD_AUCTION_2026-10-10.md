# Godot / Telegram PPA checkpoint — 2026-10-10

**ONE original Phoenix Pix Arena, NOT a second economy or a separate app.** This checkpoint exists so a user can start a new ChatGPT conversation after a chat length limit without losing the build plan.

**Primary server checkpoint:** [PPA_SHARED_WORLD_AUCTION_2026-10-10.md](https://github.com/RayZenGreallyzzz/ppa-phoenixpixarena/blob/feature/ppa-shared-forge-material-view-20261010/docs/checkpoints/PPA_SHARED_WORLD_AUCTION_2026-10-10.md). Read it FIRST for backend status, flags, migration controls and do-not-deploy warnings.

## Branches / exact starting state

- Godot repository: `RayZenGreallyzzz/Phoenix-Launcher`; **open draft** [PR #33](https://github.com/RayZenGreallyzzz/Phoenix-Launcher/pull/33); branch `feature/godot-shared-forge-material-view-20261010`; pre-checkpoint HEAD `2583238c5059c85d9aa1c9991c98a54cf6b920e6`. PR base `feature/godot-shared-clan-merchant-20261010` (stacked).
- Telegram/Cloudflare server repository: `RayZenGreallyzzz/ppa-phoenixpixarena`; **open draft** [PR #34](https://github.com/RayZenGreallyzzz/ppa-phoenixpixarena/pull/34); branch `feature/ppa-shared-forge-material-view-20261010`; original pre-checkpoint HEAD `52c15c679d085fe3a57e82cc4f92837b16da1542` (a documentation commit has been added). PR base `feature/native-shared-clan-merchant-20261010`.
- Pre-checkpoint Godot HEAD had GREEN checks: `Test Godot shared clan and merchant commands`, `Test Godot shared city protocol`. Server HEAD had four GREEN checks for forge, clan, realtime and save protection.
- **Neither PR is merged. NO new APK has been verified, deployed, signed, installed or delivered. NO Cloudflare production update.** Read current CI and code status anew before claiming anything changed.

## Implemented in native draft client

- Existing Godot 4.6 original Android PPA world, authentic package `com.phoenixgames.ppa`, city/dungeon/HUD/maps/joystick from previous project; retain existing tablet performance/UX.
- Account-bound shared online player/NPC/merchant/clan info and versioned character save.
- Godot blacksmith matching original Telegram PPA: 58 recipes, legendary/epic equipment, wings/pets/necklaces/cloaks/artifacts, authenticated server craft, +1..+7 enhancement with material/stone/rune quantities and confirmation; special adaptive pet remains restricted.
- Authenticated bag item UID equip/unequip, canonical personal 200-slot store and atomic 500-slot common clan vault.
- Auction NPC uses the SAME server `auction_lots` and `auction_credits`: public listings, my listings, seller pending credits, PPA/Gram and Premium auction slots, 10% fee. Native put/buy/cancel/recover only for proven server-escrowed `nat_...` gear lots.
- **Seller credit handling is a separate unfinished rollout**. In `games/ppa-native/scripts/ppa_npc_screen.gd`, `_auction_claim_credit()` only submits signed credit ID/save version if server advertises `serverCreditClaimsEnabled`, `canClaim` and `claim`. It does NOT mint money locally. `games/ppa-native/scripts/ppa_native_auction_service.gd` carries signed `claim` command; `games/ppa-native/scripts/test_native_auction_credit_claim.gd` tests mode OFF/ON, no speculative wallet change and owner/pending safeguards. The new original server claim mode requires `PPA_AUCTION_SERVER_CREDIT_CLAIM_ENABLED=1` **AND** explicit `PPA_AUCTION_SERVER_CREDIT_CUTOFF_MS`, which must remain unset on live production until migration/device QA is approved.

## Critical release blockers

1. Read primary server checkpoint: original Telegram client grants legacy seller credits *locally* before ACK; new backend can atomically claim post-cutoff credits. Cached or outdated Telegram clients may cause double-credit/stale-save problems unless migration is staged and field-tested.
2. Verify original Telegram bridge `gateway/ppa-bridge.js`, `gateway/online-client.js`, `src/online.js`, `src/shared-auction-credit-claim.js`, client save/reload and rollback on failure. Test both clients simultaneously and idempotency.
3. Verify provenance of old Telegram-origin auction listings before exposing old lots to native buy. Current cross-client buy/cancel is limited to native-created cryptographically proven escrow lots.
4. Keep all server write flags OFF until a coordinated staging backup and release. Never reset D1 or duplicate character accounts/inventories.
5. Build original signed Android package `com.phoenixgames.ppa`, with higher versionCode and the **same signer as previously installed PPA**, only after dependency branches integrated and Godot CI plus APK workflow confirmed; do not reuse an old debug APK.
6. Then manually test Telegram and Godot shared world, same account/gear/HP/mob/NPC/shop/inventory/clan/market and FPS on tablet/phone.

## 2026-10-10 continuation: command receipt parity FIXED (test branch only)

- Server PR #34 advanced to `7ae31a06a705f44bdfd8295d66a2786b8767b560` (5/5 green CI). It now retains the post-cutoff seller-credit visibility barrier during rollback, blocks stale Telegram saves on ambiguous claim responses, and has a dedicated seller-credit CI. Production is unchanged.
- Godot PR #33 code at `e10f4813ae9a03348ab75dae4d0a7556c89f526b` passed BOTH headless CI workflows (shared city; clan/merchant/NPC).
- Discovered and fixed real response-contract mismatch in `games/ppa-native/scripts/ppa_native_command_service.gd`: successful canonical server command envelopes have `gameId`, `contract`, `ownerId`, `requestId`, `commandStatus=done` and a receipt, but intentionally omit `state/actions`. Previously Godot incorrectly required a full state snapshot before emitting `command_finished`, so a successful PPA operation appeared to fail in the NPC UI.
- Now the native client accepts only a properly matched command acknowledgement, emits success, and GETs fresh canonical state; full `state/actions` validation still applies strictly to read-only state responses.
- Offline Godot test `test_native_command_receipt.gd` plus `test_native_command_receipt_probe.gd` checks receipt-only success, fresh state request, stale requestId, terminal refusal, and wrong-account snapshot. Verified green in Godot PR #33 CI.
- Next NOT YET DONE: staging D1 / two real clients, old cached Telegram mini-app behaviour, installed APK signer and Android performance. Do not deploy Cloudflare, merge stacked PRs, enable economy write flags, or claim full shared-world PvE/PK/Arena based on headless CI.

## APK QA checkpoint — successful Godot Android export (2026-10-10)

- Godot client draft PR #33 compiled at source commit `11bfa67534961cbc96f6eb7e790e6627d23fc854`. Exact GitHub Actions run: [#38085646626](https://github.com/RayZenGreallyzzz/Phoenix-Launcher/actions/runs/38085646626), **SUCCESS** (all 51 steps).
- Authenticated Godot 4.6 build verified original Android package `com.phoenixgames.ppa`, versionCode `600282` (higher than installed 0.3.152) and EXACT SAME signing certificate fingerprint enforced by workflow. APK signing, ZIP alignment, bundled original WebView UI and AndroidManifest all passed.
- Artifact: `PPA-Godot-Original-HUD-Existing-Package-QA`, artifact ID `11682746212`; contains `PhoenixPixArena-native-debug.apk` (223,717,668 bytes; SHA-256 `f1aa6c25926750669170c7b249e8a3f649ef0b8e6cdec4e94c8ceef1e2cf4522`). GitHub retention through November 9, 2026.
- CI confirmed 100-entry authentic UID auction selector (+7 kept), signed forge UI, legacy/NPC menu read-only safety, AI arena uses the SAME original combat HUD attack button, canonical action receipts, city realtime contract, save-only views and hero asset imports.
- Fixed stale headless audits only: `audit_native_ui.gd`, `audit_native_npc_arena_events.gd`, `audit_native_arena_training.gd`. Production Telegram PPA and Cloudflare D1 were NOT changed or deployed.
- **Not yet done:** install and manually test the APK on the user's tablet and phone; verify two CLIENTS on one character with server flags and D1 staging backup; full PvE/PK/arena realtime parity remains separate. Passing build and signer checks do not establish live cross-client shared combat.
- The original base and feature PRs remain stacked/draft; do not merge into `main` or enable economy flags simply because QA APK was produced.

## 2026-10-11 native-menu loading/performance QA after tablet video

- Real Godot tablet QA confirmed NPC menus and original bag visuals, but noted repeated delay on reopening character and narrow premium cards; some NPC native API routes return `Game API route not found`.
- Root cause A: city prefetch already calls `/api/game/state`, yet each character/global/NPC entry signaled a fresh GET, and every `open_index(0)` rebuilt the entire inventory UI. Branch-only fixes now reuse an authenticated RAM snapshot for **30 seconds**, do not queue a second GET during first load, force GET on all successful economy commands and explicit manual refresh, and preserve 100 rendered item slots on unchanged-page reopen. Failures and owner/session rotation clear cache. No on-disk save or Telegram economics changed.
- Root cause B: premium catalog layout chose up to three columns from full device width, not inner window width. Now portrait uses one column; tablet landscape at most two. Original public goods, packs and subscriptions remain read-only.
- Root cause C: `src/worker.js` in backend draft uses default-off environment gates for Godot NPC, state, merchant, forge, inventory, storage and auction. A deployed worker missing new routes OR a read-flag still disabled can return `404 NOT_FOUND`; not evidence of missing original item data. The Godot native command UI now displays an explanatory Russian message instead of raw English. **Do NOT** turn on write/settlement flags without backup, production deployment review, staged integration tests, and explicit operator approval.
- Added offline CI in `test-native-clan-service.yml`: `test_native_save_menu_cache.gd` (city GET, no duplicate, manual force, owner/session isolation), `test_native_premium_card_layout.gd` (portrait/tablet). Full APK QA `audit_native_ui.gd` asserts identical inventory widget identity when reopening the same unchanged page.
- Safe resume: monitor Godot PR #33 head CI, only offer an APK from the exact successful artifact head; previous successful signed APK was `11bfa675` / QA run `38085646626`, not the new optimizations. Server PR #34 remains separate and undeployed.

## How to resume after chat limit

In a new chat, say:

> «Продолжи общую Telegram/Godot PPA из GitHub контрольных точек `docs/checkpoints/PPA_SHARED_WORLD_AUCTION_2026-10-10.md` в серверном PR #34 и Godot PR #33. Проверь фактические HEAD и GitHub Actions, затем доведи совместимость выплат продавцам и сохранений между двумя клиентами. Production не трогай, APK пока не выдавай, если сборка/подпись не подтверждены.»

**Do not claim code in a draft PR is already running in Telegram or on the user's device.**
