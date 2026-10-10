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

## How to resume after chat limit

In a new chat, say:

> «Продолжи общую Telegram/Godot PPA из GitHub контрольных точек `docs/checkpoints/PPA_SHARED_WORLD_AUCTION_2026-10-10.md` в серверном PR #34 и Godot PR #33. Проверь фактические HEAD и GitHub Actions, затем доведи совместимость выплат продавцам и сохранений между двумя клиентами. Production не трогай, APK пока не выдавай, если сборка/подпись не подтверждены.»

**Do not claim code in a draft PR is already running in Telegram or on the user's device.**
