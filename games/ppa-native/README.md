# Phoenix Pix Arena — native Godot client

This directory is the standalone native PPA runtime launched by Phoenix Launcher.

Current milestone:
- Android package: `com.phoenixgames.ppa`
- Godot 4.6 stable, GDScript, GL Compatibility renderer
- Launcher requests a 60-second, one-time game ticket from Phoenix backend
- Launcher starts the PPA package with the ticket in an explicit Android Intent extra
- Godot reads the Intent extra through Godot's AndroidRuntime API
- ticket is exchanged once for a 12-hour game session
- the same existing PPA account/nickname is loaded from the shared D1 backend

The Phoenix launcher session token is never placed into the Android Intent.

This first native milestone proves the secure launcher/runtime/account bridge. It does not yet port the full current web MMORPG gameplay. Subsequent native milestones port world rendering, Player3D, movement, combat, realtime and game systems on top of this authenticated runtime.
