# PPA unified account, save, realtime contract (2026-10-10)

## Non-negotiable architecture

- **One Phoenix account, one PPA character, one authoritative save, one realtime actor**; Telegram Mini App and native Godot are clients, not independent games.
- Telegram login, email/password and future Google OAuth are **authentication methods**, not separate character identities. A Gmail address typed into Email is **not** Google OAuth.
- PPA world, inventory, equipment/sharpening, skills, runes, currency, clan, trading, PvP and drops remain **server-owned**. Native must not simulate rewards or send full state replacements without explicit validation.
- Keep legacy production Telegram data intact. Existing saves currently use `saves.telegram_id` and a versioned JSON state. Never rename, mass-update or replace that column without a verified, reversible D1 migration.
- Shared realtime must always be the existing `/api/realtime/ws` → `REALTIME` Durable Object `ppa-global-v1` and the **same server-assigned `players.realtime_pid`** for both clients. Never introduce a Godot-only online counter or server.
- Reconnecting on either platform must replace the prior WebSocket for the same player. Both clients must understand one authoritative realtime protocol; do not declare cross-client combat ready on transport parity alone.

## Current, safe stage (this PR)

1. Phoenix Launcher issues a **fresh, one-time account-bound** ticket on each game launch. Android clears the previous game task (not just CLEAR_TOP).
2. Godot never restores a previous local game token and clears beta-era cached sessions. Switching accounts returns to Launcher.
3. Godot requests `GET /api/game/state` with the exchanged game session. Only accept `readOnly: true`, matching authenticated Telegram owner, real nonzero save version and a real state object.
4. The native *visual preview* cannot change the class when a server-verified save is present.
5. Beta inventory remains isolated and visibly marked **TEST**, never represented as the Telegram hero's items. No writes to existing D1 from this native change.

**Gates:** /api/game/state is 404 by default unless owner sets `PPA_GODOT_STATE_READ_ENABLED=1`; this PR does NOT enable it or deploy the Worker. A 404 leaves the isolated beta gallery, not a fake synced state.

## Server-side counterpart

The separate PPA Worker branch adds an optional `POST /api/game/realtime/ticket` authenticated with the game session, resolves linked Telegram ID on the server, and issues a ticket with the exact existing `realtime_pid` and original WebSocket gateway. This feature is 404 by default unless `PPA_GODOT_REALTIME_ENABLED=1`.

### Still NOT implemented; required before accepting new players

- A permanent **internal game-player ID** independent of Telegram/email with an audited table/foreign-key migration and compatibility mapping for all existing Telegram players, social data, payments and the realtime hub. No fabricated numeric Telegram IDs for email-only accounts.
- Email-only player registration and creation of the initial authoritative save from exactly the same canonical defaults/newbie rewards as the Telegram flow.
- Account linking requiring proof of **both** identities. If both accounts already own characters, refuse automatic merges; require an explicit conflict resolution and immutable backup.
- Native inventory/forge/vendor/rewards server operations (idempotent requests, server pricing, optimistic version conflicts, no client-generated items).
- Native realtime gameplay and reconciliation, with anti-duplication checks when switching between clients. Read-only snapshot and ticket issuance do not provide combat/world sync by themselves.
- Verification of Google OAuth identity tokens if adding a one-click Google button. Never equate a claimed email address with a Google identity.

## Minimum release acceptance

- Telegram → Godot → Telegram: nickname, class, level, sharpened item UID, runes, books and currencies preserve exact identity and version.
- Godot → Telegram → Godot: identical save after every confirmed authorized action.
- Email-only → same Email login on another device: exactly one character and save; optional verified Telegram link preserves ownership.
- Two simultaneous clients: one stable realtime pid, one active world actor, no duplicated loot or two save owners.
- Unauthorized/expired/foreign ticket or switched account: no save disclosure, no stale native hero, no access to other account.
- Full D1 backup and a tested rollback before any migration; test APK and Worker canary before production.
