# Phoenix Pix Arena Native — NPC service UI contract

## Boundaries
- One Godot `PPANativeNpcMenu` Control owns every **NPC** screen. The original five-page `ppa_character_screen.gd` owns the **character** screen. Neither is a child of the other.
- `test_world_menu.open_npc(npc)` closes character, optional WebView and legacy test panel *before* opening the NPC. `open_page("character")` closes the NPC first; Back and the red close button release both.
- The nine deployed Peace City service IDs are `forge`, `storage`, `auction`, `arena`, `clan`, `merchant`, `blackmarket`, `dungeon`, `fartzone`. Asset paths and original placement remain in `test_city_npcs.gd`.
- `test_shop_catalog.gd` holds the **verified original** merchant catalog (12 items) and reference-only black market offers. No new prices, inventories, balances, slots, skill ranks or drops are fabricated.
- All server-mutating buttons are disabled, not wired to local test `stash`, and do not call `/api/save`.

## Server integration before enabling any transaction
1. Exchange the existing Phoenix game ticket using the already established launcher session; never grant authority from visual class preview.
2. Implement a server-authorized, read-only `GET NPC snapshot` adapter. Map the NPC service and account/hero ID; subscribe to `npc_snapshot_requested(service)` and supply a validated `{ "service": "...", "data": {...} }` to `PPANativeNpcMenu.apply_authoritative_snapshot`. Reject stale responses if an NPC changed/closed or the account switched.
3. Define *typed* service operations on the backend (merchant purchase; forge enhance/craft; warehouse move; auction create/buy/cancel; clan apply/create/lead; arena queue; dungeon enter; fart-zone enter). Revalidate price, item ownership, quantity, location, combat state, currency, permissions and cooldown server-side. Always use idempotency keys for purchases/trading and return a fresh authoritative snapshot.
4. Enable exactly the matching action only when there is a tested server route; a read-only snapshot alone must **not** enable purchasing. Never use local test inventory for production transactions.
5. Verify cross-client consistency: open both Telegram PPA and Godot with the same server character and compare player save, inventory, bank, guild, item state and currency *after* confirmed server operations.

## Acceptance
- All nine NPCs open a service-specific screen without revealing the character UI, old test panel or original WebView.
- NPC window instance is reused when opening different NPCs (no stacked modal controls or duplicate listeners).
- Tabs and item inspection work without touching currency or test bag. Disabled server commands cannot change local inventory.
- Landscape and portrait tablet layouts must be inspected manually; CI headless checks structure and navigation, not final device visual quality.
- Build APK only from the separate NPC test workflow. Do not publish to the launcher release channel before user approves.

## Telegram menu parity / dual orientation (2026-10-08)
Compared against owner-provided screenshots from the live Telegram PPA (not conjectural stock). The native Godot UI now includes:
- **Clan:** overview, clans/ranking, participants, clan warehouse, exchange, bosses, bonuses, wars/citadel, journal (9 horizontally scrollable tabs).
- **Forge:** enhancement, equipment, legendary, accessories, pets, rune fusion (from the separate rune bag).
- **Storage:** personal, clan, premium, sorting; inventory and storage displayed in distinct slot regions.
- **Arena:** challenges (endless waves, AI, PvP, season), attempts, rating, arena store, match history.
- **Dungeon keeper:** three floor ranges, quest tier selector (1–20, 21–30, 31–40, daily), bosses, loot. The 21–30 quest names are *reference labels* from user screenshots; progress/reward fulfillment remain unconnected.
- **Auction:** buy/sell/my listings and Telegram-style item categories.
- **Black market:** existing categories plus buyback; static reference items are never mislabeled as live offers.
- **Fart-zone miner:** entrance, ordinary and legendary pickaxe, slag, guards.
- **Merchant:** retains 12 original catalog items, no fabricated balance or stock.

Android project `display/window/handheld/orientation=6` (SCREEN_SENSOR) and stretch aspect `expand`. A square 720×720 reference viewport supports portrait and landscape while preserving the desktop 1280×720 override. NPC category tabs use one horizontal scroll row, the character menu already sizes from viewport, and the class selector stacks its preview above the choices in portrait. Gameplay city/camera/3D viewport already read dynamic Control size. Automatic rotation still depends on Android's auto-rotate setting and actual device behavior; headless checks alone cannot prove tablet sensor behavior.

Only navigation, descriptions and *read-only* catalog controls work before server integration. Mutating controls are disabled. Do not transfer quest completion, clan permissions, balances or actual warehouse content by copying labels from screenshots.
