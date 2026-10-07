# Phoenix Pix Arena — native Godot client

Standalone native PPA runtime launched by Phoenix Launcher.

Current native bridge:
- Android package: `com.phoenixgames.ppa`
- Godot 4.6, GL Compatibility
- 60-second one-time Launcher ticket -> 12-hour game session
- same Phoenix/PPA profile and nickname from the shared backend

Current 2.5D movement milestone:
- PPA architecture is now enforced: flat map/gameplay layer, 3D only for player characters
- no 3D buildings, no 3D mob conversion, no dynamic shadow map
- approved current PPA `Dwarf.glb` is imported into the APK during CI
- orthographic camera mirrors the current PPA Player3D overlay geometry
- native smart floating joystick ports the current web behavior:
  - appears at the first touch point on the left half
  - one dedicated touch owns movement
  - 8 px dead zone
  - 50 px movement radius
  - input remains full-rate; decorative redraw is capped around 30 Hz
  - release/focus loss resets movement
  - other touches remain free for attack/UI
- live FPS and native coordinates remain visible for tablet testing

The current flat test layer is intentionally lightweight. The next migration step replaces it with the real PPA city/map data and the 2D walk/collision mask; mobs, bosses, pets and effects stay 2D.
