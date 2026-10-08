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
    if scene.city_world.get_child_count() != 2:
        _fail("dungeon must contain only aligned floor and hidden collision overlay")
        return
    toggle.pressed.emit()
    if not overlay.visible:
        _fail("mask alignment overlay toggle doesn't show geometry")
        return
    toggle.pressed.emit()
    if overlay.visible:
        _fail("mask alignment overlay toggle cannot hide geometry")
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
    print("PPA_DUNGEON_WALK_TEST_OK world=", world_size,
        " mask=", scene._mask_image.get_size(), " entrance=", scene._entrance,
        " collisions=8points+slide original_art=1 world_scale=", scene._render_to_world_scale,
        " mask_y_drift=0 overlay=1 portrait=1 mobs=0 server_writes=0")
    scene.queue_free()
    quit(0)
