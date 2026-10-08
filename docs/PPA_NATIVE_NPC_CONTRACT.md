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

## Storage & clan UI invariants (2026-10-08)
- Capacity constants are centralized in `games/ppa-native/scripts/ppa_storage_contract.gd`: **character bag 100; personal warehouse 200; clan warehouse 500; premium warehouse 50**. Never infer capacity from `items.length`, local test stash or user access.
- Character bag visually contains 100 cells; early/locked status remains distinct from capacity and must eventually be populated from authoritative server permission data.
- The temporary offline stash limits were corrected from 64 to bag 100 / personal warehouse 200. This local store is NOT the game server; no clan or premium items are persisted in it. Keep it isolated from live Telegram PPA saved data.
- Server-owned inventory snapshots must include `storage_kind`, `capacity`, `unlocked_slots`, `items`, and for clan `role_permission` and revision. Verify capacity against server and do not manufacture missing items or privileges in the client.
- To avoid freezing mobile/tablet: only draw the cells currently visible in each continuously scrollable virtual grid. No per-slot Control/Button nodes are allocated. Scrolling must not mutate inventory data.
- All nine clan tabs are directly visible in native grid layout (portrait 3×3, landscape 5×2). `exchange` is always a clickable tab, but the actual exchange action stays server-locked. No mock transfer of clan coins/resources.
- Automated audit verifies all four capacities, last-page indices, full 9-tab clan navigation, and that moving between screens never silently changes the local test stash. Device portrait/landscape still needs visual QA.

## Continuous virtual warehouse grid (supersedes pagination)
The 0.4 test's twenty-at-a-time page buttons were rejected: 25 page turns for the 500-slot clan warehouse are unplayable on a tablet. The Native implementation now uses **continuous vertical touch scrolling** with a single lightweight `ppa_virtual_storage_grid.gd` Control per inventory/storage panel. Its scrollbar is independent for left and right panels. It draws only cells in the visible rows and allocates **zero child nodes per slot**, regardless of capacity.

All four capacities remain 100 / 200 / 500 / 50. No paging arrows, 1/25 labels, or 'next page' actions remain in the actual UI. The width of the panels and square cells adapts to portrait and landscape. The last slot is reachable by scrolling; the viewport only draws the visible slice. The drawing-only view intentionally has no fabricated items or server mutations. On future server integration, the backend must provide verified item IDs/positions and permissions before rendering interactive items.

The old `PAGE_SIZE` and paging helpers in `ppa_storage_contract.gd` are removed; that contract now describes **capacities only**. CI verifies all grid capacity constants, first-to-last scroll coverage and bounded visible draw ranges. Real Android touch inertia must still be exercised on a tablet.

## Item selection in Auction SELL / Forge ENHANCE
Both native NPCs use the reusable `ppa_inventory_picker.gd`. It displays the **entire 100-slot bag as square, touch-scrollable cells**, never a truncated fake 10/16-cell region. Empty slots are visible but cannot be selected; only actual inventory entries supplied by a validated service snapshot can represent real production possessions. For local UI tests the private preview stash is read-only and intentionally starts empty (old demo items stay removed).

- **Auction sell:** select a suitable inventory item, inspect name/rarity/quantity/upgrade, choose per-item ask price, offered quantity (clamped by available stack) and the PPA/Gram listing currency. Server fees, ownership and auction eligibility require authenticated backend checks; the final `ВЫСТАВИТЬ ЛОТ` button stays disabled.
- **Forge enhance:** choose gear from inventory **or equipped slots**, then separately choose sharpening material and rune using filters on the same inventory. The three selections are retained while switching filters. Chance and cost are not fabricated: server will compute outcome after a validated request. `ЗАТОЧИТЬ` stays disabled until integration.
- The future NPC service snapshot should include `{ service, data: { inventory: [{ id, slot, name, kind, qty, rarity, upgrade, ... }], equipment: { weapon: {...}, ... } } }`. `slot` is an absolute 0-based bag position; item IDs alone are **not** unique stack/instance identifiers. For real mutations use verified unique item instance keys, ownership, inventory revisions and idempotent transaction IDs.
- No sample items are inserted into player inventory. Headless CI injects a test-only read-only fixture to verify selection, filters, listing controls, worn items and disabled server writes, then checks original private stash is unchanged.

## Global PPA menus vs world scene migration (2026-10-08)

Native now has one independent `ppa_global_hub.gd`, accessible from a **РАЗДЕЛЫ** HUD button beside **ГЕРОЙ**. The four groups are premium store, TON/Gram wallet, source-backed event center, and map/location index. The HUD hub, character menu and NPC menu never stack; tapping an NPC closes the hub, tapping the hero action closes the hub and opens the five-page hero screen.

### Current working scope
- **Premium store:** PPA-inspired visual layout for subscriptions, services and items. No invented premium currency balances/prices. All purchases locked pending verified server catalog and shop routes.
- **Wallet:** TON Connect and Gram overview, Kazna distinct from withdrawals. No embedded signer or unsafe simulated wallet connection. Top-up/withdraw controls disabled. Later use a verifiable TON Connect bridge plus server-side transaction and admin approval flow, not local balance mutation.
- **Events:** original `gateway/native-events-srcdoc.html` menu categories and events, as present in `ppa-phoenixpixarena`: Great Ruri, Crystal Titan, Mimic-Sombrero, Phoenix Citadel and updates. Read-only event names/details; no made-up active status, drop ownership or countdown. Server snapshot flow is prepared but not yet implemented.
- **Locations:** read-only world index describing Peace City, dungeon 1–60, Fart/farming, arena, clan boss and event maps. **Only Peace City currently has a native Godot gameplay scene**. A location listing is not a replacement for terrain art, masks/collisions, monster spawning, fight simulation, separate map scenes, save state, server entry permissions or live events. Entrances/teleports stay disabled until real maps and routes exist.
- **Global snapshot interface:** `global_snapshot_requested(section)` and `apply_snapshot({section, data})` provide a future verified read-only bridge. Never enable transaction controls from a UI snapshot alone.

### Required location port
1. Export/audit original PPA authoritative maps, collision masks, spawn rooms and overlays (dungeon 1–60, farm/Fart zone, and each event arena).
2. Create Godot scenes with native movement/collision/visuals and scene transition manager, with return-to-city path and async asset-loading bounds.
3. Move entry validation, monster states and all rewards to shared server authority; ensure Telegram and Godot see same character and timers.
4. Stress-test FPS on tablet, portrait/landscape layouts, world scenes and event entry/exit, especially UI overlays and returning to city.
