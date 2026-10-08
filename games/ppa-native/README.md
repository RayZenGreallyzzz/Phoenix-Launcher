# Phoenix Pix Arena — native Godot client

Native PPA 2.5D module launched from Phoenix Launcher on Android.

## Verified baseline
- Package: `com.phoenixgames.ppa`, Godot 4.6 GL Compatibility
- Launcher issues a one-time ticket; native client exchanges it for a server session.
- Phoenix Account/profile and the live PPA hero come from the same backend.
- The current Peace City bitmap is exactly the live `/assets/c73ef6814017bda6.png` (1254 × 1254) enlarged to the canonical 2822 × 2822 game world.
- City walkability and building collision use the authoritative deployed PPA geometry.
- Smart floating joystick, Android multi-touch and canonical directional movement.
- Only players are 3D. The map, NPCs, mobs, pets and bosses remain 2D.
- Live `Dwarf.glb` includes rigged cannon and Idle / Run / Attack clips. The character and cannon share one scaling root.

## Launch sequence
1. Phoenix Launcher authorizes the same Phoenix Account and passes a one-time ticket.
2. PPA starts with custom Phoenix-branded engine boot splash (not Godot logo).
3. The on-screen PPA hero image appears while the session is checked.
4. The account-bound native character-selection screen previews the real registered hero and class.
5. Only the registered character can enter Peace City.

The current backend stores **one** authoritative player/profile/save per Telegram ID. Additional character slots are *not yet enabled*; rendering them as selectable would risk replacing existing save data. Empty slot placeholders are intentionally disabled until a genuine server-side multi-slot migration.

## Publishing
The native Android CI build verifies image, GLB, splash imports and APK signature. It stamps a monotonically increasing Android versionCode, and publishes the verified game APK to the Phoenix Launcher beta update release channel after a successful build. Launcher updates install through the Android package installer (with explicit confirmation).

## Character screen — five Godot pages (native Android pilot)
The Android character menu now defaults to the same native Godot screen used for desktop visual tests; it does **not** require WebView to open. The five pages follow Telegram PPA's structure and navigation:
1. Inventory — equipment around the portrait, cosmetics, 5-column bag and locked slots.
2. Characteristics — level/XP, stat rows, stat distribution and rebirth controls.
3. Active skills — four grimoire slots with five rank indicators.
4. Passive skills — five grimoire slots with five rank indicators.
5. Runes — rune sockets and rune bag preview.

Left/right arrows, five dots and horizontal swipes change pages. Vertical swipes scroll the current page. These are **UI-only previews** until an authenticated PPA character snapshot and server mutations are connected. Local TEST stash/warehouse are not Telegram PPA saves; unavailable progress, skill ranks and prices must not be invented.

The old original-iframe Android WebView experiment remains packaged for A/B comparison only: set `ppa/ui/use_original_webview=true` in `project.godot` for an explicit test build. Both interfaces are never displayed simultaneously.
