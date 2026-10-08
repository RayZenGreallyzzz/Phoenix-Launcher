extends SceneTree

# CI-only, real native dungeon floor+mask / joystick collision test.
# Never simulates server state, drops, mob kills, entry tickets or account saves.
const DUNGEON = preload("res://scripts/dungeon_world.gd")

func _initialize() -> void:
    call_deferred("_check")

func _fail(message: String) -> void:
    push_error("PPA_DUNGEON_AUDIT: " + message)
    quit(1)

func _check() -> void:
    var scene = DUNGEON.new()
    scene.size = Vector2(1280, 720)
    root.add_child(scene)
    await process_frame
    if scene._floor_texture == null or scene._mask_image == null:
        _fail("original dungeon floor/mask missing")
        return
    var world_size: Vector2 = scene._map_world_size()
    # The PNG/WebP 4096px asset is NOT PPA world units. build.mjs uses
    # DG_ART_W=2048 and DG_SCALE=(1852*5.1435)/2048 => 9526×4637.
    if world_size != Vector2(9526.0, 4637.0):
        _fail("wrong original PPA logical world geometry " + str(world_size))
        return
    var floor_art := scene.city_world.find_child("OriginalPPADungeonFloor", true, false) as TextureRect
    if floor_art == null or floor_art.texture.get_width() != 4096 or floor_art.size != world_size:
        _fail("original 4096px floor is not shown at the correct 9526px scale")
        return
    var overlay := scene.city_world.find_child("DungeonWalkMaskAlignmentOverlay", true, false) as TextureRect
    if overlay == null or overlay.size != floor_art.size or overlay.position != floor_art.position or overlay.visible:
        _fail("collision alignment overlay missing, offset or enabled in normal play")
        return
    var toggle := scene.find_child("DungeonMaskAlignmentToggle", true, false) as Button
    if toggle == null:
        _fail("mask-alignment diagnostic button missing")
        return
    # Regression for tablet report: NativeWorld._input receives touch BEFORE
    # button _gui_input. Joystick must not claim left-side toggle touches.
    if toggle.size.y < 44.0:
        _fail("mask toggle has a too-small touch target")
        return
    var toggle_center: Vector2 = toggle.get_global_rect().get_center()
    if toggle_center.x >= scene.size.x * 0.5:
        _fail("test did not exercise left-half joystick interception")
        return
    if scene._joy_point_allowed(toggle_center):
        _fail("smart joystick still intercepts mask-toggle touch")
        return
    var touch := InputEventScreenTouch.new()
    touch.pressed = true
    touch.index = 91
    touch.position = toggle_center
    scene._input(touch)
    if scene._joy_touch_id != -1:
        _fail("mask toggle claimed as joystick touch in _input")
        return
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = toggle_center
    scene._input(mouse)
    if scene._joy_mouse_active:
        _fail("mask toggle claimed as joystick mouse input")
        return
    if not scene._joy_point_allowed(Vector2(90.0, 230.0)):
        _fail("fix accidentally disabled ordinary left-side joystick")
        return
    if absf(scene._movement_speed_px() - scene.MOVE_SPEED_PX * world_size.x / 4096.0) > 0.01:
        _fail("dungeon move speed not matching world scaling")
        return
    if scene.city_world == null or scene.city_world.name != "PPADungeonOriginalTileMask":
        _fail("city art was incorrectly reused instead of original dungeon")
        return
    if scene.city_world.find_child("OriginalPPADungeonFloor", true, false) == null:
        _fail("real PPA stone floor not rendered")
        return
    if scene._mask_image.get_width() < 1000 or scene._mask_image.get_height() < 400:
        _fail("low-resolution or fake collision mask")
        return
    if scene._entrance == Vector2.ZERO or not scene._can_walk(scene._entrance):
        _fail("spawn isn't interior on original mask " + str(scene._entrance))
        return
    if scene._can_walk(Vector2(3,3)):
        _fail("outer solid map incorrectly walkable")
        return
    var old_pos: Vector2 = scene.world_pos_px
    var to_wall := Vector2(-100, -100)
    var accepted: Vector2 = scene._resolve_city_collision(to_wall)
    if accepted.distance_to(old_pos) > 1:
        _fail("player escaped mask by walking outside map " + str(accepted))
        return
    var move_candidate := Vector2(old_pos.x + 4.0, old_pos.y)
    var resolved: Vector2 = scene._resolve_city_collision(move_candidate)
    if not scene._can_walk(resolved):
        _fail("movement accepted wall point " + str(resolved))
        return
    if scene.find_child("DungeonReturnCity", true, false) == null:
        _fail("no return-to-city button")
        return
    if scene.find_child("DungeonVisualTestLabel", true, false) == null:
        _fail("no test-only label warning of missing live combat")
        return
    # The preview must never create server mobs or dungeon NPCs.
    if scene.city_world.get_child_count() != 3:
        _fail("dungeon must contain aligned floor, hidden mask and diagnostic ground-footprint marker")
        return
    var footprint := scene.city_world.find_child("DungeonActualGroundCollider", true, false) as Node2D
    if footprint == null or footprint.visible or scene.WALL_RADIUS != 9.0:
        _fail("initial collision radius or visibility is incorrect")
        return
    toggle.pressed.emit()
    if not overlay.visible or not footprint.visible or footprint.position.distance_to(scene.world_pos_px) > 0.01:
        _fail("mask toggle didn't show the exact ground collider and aligned overlay")
        return
    var circle := footprint.find_child("DungeonFootprintRadius", true, false) as Line2D
    if circle == null or circle.points.size() != 25 or absf(circle.points[0].length() - 9.0) > 0.1:
        _fail("the visible yellow circle does not match the 9px collider footprint")
        return
    if not overlay.visible:
        _fail("mask alignment overlay toggle doesn't show geometry")
        return
    toggle.pressed.emit()
    if overlay.visible or footprint.visible:
        _fail("mask alignment overlay toggle cannot hide geometry")
        return
    # Along the downward corridor, a nine-direction footprint should reach
    # within about a cell or two of the lower green/solid mask boundary.
    var entrance: Vector2 = scene.world_pos_px
    var reached_edge := false
    for step in range(1, 1350):
        var candidate := entrance + Vector2(0, float(step))
        if not scene._walk_sample(candidate):
            reached_edge = true
            var last_safe_y := float(step - 1)
            while last_safe_y > 0 and not scene._can_walk(entrance + Vector2(0, last_safe_y)):
                last_safe_y -= 1.0
            if last_safe_y < 1.0 or float(step) - last_safe_y > scene.WALL_RADIUS + 9.0:
                _fail("ground collider prevents approaching lower green edge: boundary=" +
                    str(step) + " last_safe=" + str(last_safe_y))
                return
            break
    if not reached_edge:
        _fail("no lower mask edge found from dungeon entrance")
        return
    # Numeric checks across map: a world-space point maps to the exact
    # matching floor and mask normalized coordinates, without any Y drift.
    for uv in [Vector2(0.10, 0.15), Vector2(0.50, 0.50),
        Vector2(0.80, 0.85), Vector2(0.95, 0.90)]:
        var world_point: Vector2 = uv * world_size
        var actual: Vector2 = scene._world_to_mask_uv(world_point)
        if actual.distance_to(uv) > 0.00002:
            _fail("map-to-mask world transform drift at " + str(uv))
            return
    # Portrait change and camera bounds must retain logical world size.
    scene.size = Vector2(720, 1280)
    scene._sync_world_visuals()
    if scene._map_world_size() != world_size or scene._world_to_mask_uv(scene.world_pos_px) != scene._world_to_mask_uv(scene._entrance):
        _fail("portrait resizing modified dungeon world/mask alignment")
        return
    if scene._joy_point_allowed(toggle.get_global_rect().get_center()):
        _fail("portrait joystick intercepts diagnostic button")
        return
    print("PPA_DUNGEON_WALK_TEST_OK world=", world_size,
        " mask=", scene._mask_image.get_size(), " entrance=", scene._entrance,
        " collisions=8points+slide original_art=1 world_scale=", scene._render_to_world_scale,
        " mask_y_drift=0 overlay=1 portrait=1 button_touch=1 joystick_ok=1 footprint_radius=9 lower_edge=1 mobs=0 server_writes=0")
    scene.queue_free()
    quit(0)
