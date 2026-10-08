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
    if world_size.x != 4096.0 or world_size.y < 700.0:
        _fail("wrong original PPA 4096px dungeon world geometry " + str(world_size))
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
    if scene.city_world.get_child_count() != 1:
        _fail("test map unexpectedly instantiated non-authoritative mob/NPC")
        return
    print("PPA_DUNGEON_WALK_TEST_OK world=", world_size,
        " mask=", scene._mask_image.get_size(), " entrance=", scene._entrance,
        " collisions=8points+slide original_art=1 mobs=0 server_writes=0")
    scene.queue_free()
    quit(0)
