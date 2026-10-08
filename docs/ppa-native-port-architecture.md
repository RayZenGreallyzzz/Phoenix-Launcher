# Phoenix Pix Arena — Native Godot Port Contract

## Goal and scope
Preserve **Godot 4.6 GL Compatibility** as the sole rendering/gameplay
engine (scene tree, 3D GLB heroes, animations, movement, collisions and
local client prediction). Preserve **PPA server** as the sole authority
for character saves, inventory, books, stats, trading, drops, clans,
currency and combat adjudication.

Preserve actual Telegram PPA user interfaces as original HTML/CSS/JS
fragments inside **one Android WebView at a time**. Android's system
WebView is a UI surface, **not a second Three.js game instance**. Never
load the full Telegram RPG app inside WebView on top of Godot.

## Source and build integrity
- Read the deployed PPA `charFrame` iframe `srcdoc` unchanged at build
  time with `tools/extract_original_ppa_frame.py`.
- Android AAR packages `assets/ppa_original/charFrame.html`. CI verifies
  the exact frame, app signing and packaged plugin class.
- No editor approximations on Android. If WebView is unavailable, show
  a diagnostic instead of silently displaying the former Godot copies.
- Other menus (merchant, forge, warehouse, clan) are **not** yet migrated
  to original HTML. Do not call them 1:1.
- Imported 3D GLB meshes and original map art must remain unchanged.

## One-way read-only UI pilot (current)
- Godot activates `showCharacter(selectedVisualClass, page)`.
- The original iframe sends `charReady` and `charRequestState` to its
  host with `window.parent.postMessage`; the Android host accepts only
  verified messages from its own embedded iframe.
- No player-specific inventory, rank, owned book quantity, coins, gold,
  purchase, forge action, or delete-account action is simulated.
- Until a real authenticated snapshot is wired, empty slots and ranks
  are a **not-connected** state, not an assertion of a player's saved data.
- Closing via original red cross, outside tap or Android Back removes
  WebView and returns input to Godot; only one WebView may be visible.
- WebView's browser-native touch/scroll code handles the menu. Never add
  a parallel Godot swipe handler above it.

## Next production contract
1. Obtain a dedicated authenticated, **read-only character snapshot**
   from the PPA backend after the Phoenix Launcher game ticket is
   exchanged. Token must remain in Android/native code; don't send it
   through JS postMessage or query strings.
2. Adapt that verified response to the existing original
   `invState` payload fields: `inv`, `stats`, `bm`, `progress`,
   `skills`, `runes`; reject unknown/unverified data.
3. The iframe renders its original code with those values. State
   changes (equip, learn, forge, sell) must be explicit, typed,
   authenticated server requests and rehydrate from confirmed snapshots.
   Do not perform optimistic local purchases, duplicate inventory saves
   or local wallet/currency arithmetic.
4. Migrate each NPC menu by extracting its own original deployed frame
   and mapping allowed events through the **same** WebView plugin and
   same server-state layer (no new mini-app or custom fake shop).
5. Delete old Godot UI source only when all Android menu routes and CI
   smoke tests no longer depend on it.

## Performance and acceptance
- First measure on the target Android tablet with the same class, scene,
  map, sprite count and effects in the old web game and Godot.
- Measure idle, moving, combat with mobs, inventory open and reopening.
  Record 1% low FPS/95th percentile frame time, peak memory, warm
  opening latency, touch responsiveness and battery/thermal behavior.
- 60 FPS has a **16.7 ms frame budget**; 30 FPS has 33.3 ms. Do not
  infer game-load superiority from a near-empty native demo.
- GL Compatibility has low baseline rendering overhead but scales poorly
  when many lights/3D objects are added. Keep shadow-free lightweight
  materials and cull offscreen objects; profile before changing engine.
- In the current *local test town only*, stop unnecessary client
  collision/3D SubViewport refresh while a menu is open. Do not halt
  realtime server combat or world timers to accomplish this.

## Explicit non-goals of the prototype
- No claim that the native test profile is synced with the Telegram hero.
- No launch of the full original Three.js game inside Android WebView.
- No fabricated UI icons, items, combat stats, currencies or product prices.
- No automated gameplay/transactions until backend protocol and tests exist.
