# Phoenix Pix Arena — native Godot client

Standalone native PPA runtime launched by Phoenix Launcher.

Current native bridge:
- Android package: `com.phoenixgames.ppa`
- Godot 4.6, GL Compatibility
- one-time Launcher ticket -> native PPA session
- same Phoenix/PPA account and nickname

Current City of Ashes milestone:
- legacy 1024/3048 Peace City art is no longer used
- current 2D City of Ashes world is 4347 x 3333
- map is the exact two-WEBP compositor used by the approved City build
- current map projection is preserved: zoom 4.00, vertical scale 4*cos(0.75)
- city entry is (2174, 1666)
- perimeter is left 290 / right 335 / top 225 / bottom 290
- all 31 approved building placements are rendered as 2D sprites
- current building collision rectangles are ported
- current tree trunk collision circles are ported
- buildings can move in front of the 3D player using the same depth rule as the web prototype
- smart floating native joystick is unchanged
- only the local player is rendered in 3D; world, buildings, mobs, bosses and pets stay 2D

The approved GLB player asset is still pending transfer into this repository; the lightweight orange fallback remains for native world tests.
