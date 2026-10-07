# Phoenix Pix Arena — native Godot client

This directory is the standalone native PPA runtime launched by Phoenix Launcher.

Current milestone:
- Android package: `com.phoenixgames.ppa`
- Godot 4.6 stable, GDScript, GL Compatibility renderer
- Launcher requests a 60-second, one-time game ticket from Phoenix backend
- Launcher starts the PPA package with the ticket in an explicit Android Intent extra
- Godot exchanges the one-time ticket for a 12-hour game session
- the same existing PPA account/nickname is loaded from the shared D1 backend
- authenticated client can now enter a real native Godot world scene
- first native city test area with collisions, follow camera and Player3D controller
- fixed mobile virtual joystick with multi-touch-safe tracking
- movement runs in 60 Hz physics and also supports WASD/arrows for desktop testing
- live FPS and player coordinates HUD are included for performance testing

The Phoenix launcher session token is never placed into the Android Intent.

The current Player3D visual and city geometry are lightweight native placeholders used to validate movement, camera, collision and mobile input without risking the existing web MMORPG. The next milestone replaces the placeholder visual/world with the approved PPA assets, then ports mobs, targeting, combat and realtime systems.
