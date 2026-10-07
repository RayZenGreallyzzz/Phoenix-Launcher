# Phoenix Pix Arena — native Godot client

Standalone native PPA runtime launched by Phoenix Launcher.

Current native bridge:
- Android package: `com.phoenixgames.ppa`
- Godot 4.6, GL Compatibility
- 60-second one-time Launcher ticket -> 12-hour game session
- same Phoenix/PPA profile and nickname from the shared backend

Current Peace City milestone:
- real current PPA Peace City background is used, not a replacement map
- canonical PPA world remains 3048 x 3048 gameplay pixels
- source art coordinates keep the existing 1024 -> 3048 scale
- current PPA start position is preserved: source (500,620)
- current PPA return position is preserved: source (640,600)
- current four Peace City building collision rectangles are ported exactly
- current safe-zone outer bounds are preserved
- current dungeon-portal coordinates are preserved
- map remains true 2D screen-space rendering
- only the player visual is rendered in a transparent 3D Godot overlay
- the 3D overlay uses the same 34 px/unit projection baseline as the current PPA Player3D runtime
- smart floating joystick remains native and multi-touch safe
- HUD reports canonical PPA X/Y coordinates plus FPS

Mobs, bosses, pets, world effects and gameplay objects remain 2D by design. The current build still uses the lightweight fallback 3D body until the approved GLB is transferred into the native project.
