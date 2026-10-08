extends SceneTree

# CI-only, real native dungeon floor+mask / joystick collision test.
# Never simulates server state, drops, mob kills, entry tickets or account saves.
const DUNGEON = preload("res://scripts/dungeon_world.gd")
const DWARF_FIT = preload("res://scripts/dwarf_model_fit.gd")

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
    # New requested calibration: only the overlay and mask collision shift.
    # The stone floor/3D character/map world origin must remain unchanged.
    if floor_art.position != Vector2.ZERO or scene.MASK_Y_OFFSET_PX != 14.0:
        _fail("floor moved or the requested 14px calibration is absent")
        return
    if overlay == null or overlay.size != floor_art.size or overlay.position != Vector2(0.0, 14.0) or overlay.visible:
        _fail("mask overlay is not aligned to the 14px collision shift")
        return
    if scene._world_to_mask_uv(Vector2(0, scene.MASK_Y_OFFSET_PX)) != Vector2.ZERO:
        _fail("collision sampling ignores visual Y-offset")
        return
    if scene._walk_sample(Vector2(500.0, 3.0)):
        _fail("above-shifted mask must remain a wall, not clamp to image row zero")
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
    if scene.city_world.get_child_count() != 4:
        _fail("dungeon should contain floor, mask, ground marker and local enemy preview layer")
        return
    # Critical: old 20 PNGs from the deployed 2026 PPA are explicitly
    # disallowed; the approved replacement art remains unpublished.
    if scene.ENEMY_VISUAL.NEW_MOBS.size() != 20 or scene.ENEMY_VISUAL.LEVEL_NAMES.size() != 20:
        _fail("20 distinct approved mob names and level IDs required")
        return
    if scene.ENEMY_VISUAL.required_file_count() != 22 or scene.ENEMY_VISUAL.SLIME_VARIANTS.size() != 3:
        _fail("20 level species and 3 colors of level-4 slime require 22 PNGs")
        return
    var approved_names := [
        "Пепельная крыса", "Пещерный паук", "Обугленный жук",
        "Слайм-падальщик", "Костяной грызун", "Гоблин-разведчик",
        "Костяной воин", "Пепельный волк", "Грибная тварь",
        "Гоблин-шаман", "Культист", "Проклятый рыцарь",
        "Каменный голем", "Лавовый элементаль", "Пепельный страж",
        "Адская гончая", "Огненный демон", "Пустотный наблюдатель",
        "Элитный голем", "Пепельный палач"
    ]
    for level in range(1, 21):
        if scene.ENEMY_VISUAL.LEVEL_NAMES[level - 1] != approved_names[level - 1]:
            _fail("Mob level/name mapping has drifted: " + str(level))
            return
        for sample_id in range(4):
            if scene.ENEMY_VISUAL.art_index_for_spawn(level, sample_id) != level - 1:
                _fail("Cross-species mixed into room level " + str(level))
                return
            if level != 4 and scene.ENEMY_VISUAL.sprite_filename_for_spawn(level, sample_id) != scene.ENEMY_VISUAL.NEW_MOBS[level - 1]:
                _fail("Wrong monster asset for level " + str(level))
                return
    var approved_slimes := [
        "mob_04_slime_green.png", "mob_04_slime_red.png", "mob_04_slime_blue.png"
    ]
    for i in range(6):
        if scene.ENEMY_VISUAL.sprite_filename_for_spawn(4, i) != approved_slimes[i % 3]:
            _fail("Fourth level must mix only green/red/blue slime variants")
            return
    if scene.ENEMY_VISUAL.sprite_filename_for_spawn(1, 0) != "mob_01_ash_rat.png" or scene.ENEMY_VISUAL.sprite_filename_for_spawn(3, 0) != "mob_03_charred_beetle.png":
        _fail("Approved rat/spider/beetle order changed")
        return
    if scene.ENEMY_VISUAL.art_index_for_spawn(21, 0) != -1:
        _fail("missing 21–60 new art must not silently reuse 1–20 art")
        return
    var new_count: int = scene.ENEMY_VISUAL.available_count()
    if new_count != 0 and new_count != 22:
        _fail("partial PNG import is unsafe for dungeon: " + str(new_count))
        return
    if scene.APPROVED_DUNGEON_ENEMY_ART_READY != scene.ENEMY_VISUAL.artwork_complete():
        _fail("new sprite gate disagrees with actual imported files")
        return
    if scene.APPROVED_DUNGEON_BOSS_ART_READY:
        _fail("unverified old dungeon boss art unexpectedly enabled")
        return
    print("PPA_NEW_DUNGEON_SPRITE_CONTRACT_OK levels=20 png_required=22 slimes=green,red,blue old_bird=0")
    if ResourceLoader.exists("res://scripts/ppa_dungeon_art_generated.gd"):
        _fail("legacy original_dungeon_art_generated.gd was shipped in APK")
        return
    print("PPA_DUNGEON_LEGACY_ART_DISABLED_OK legacy_png=0 replacement_pending=1")

    var enemies := scene.city_world.find_child("PPAOriginalDungeonEnemyTestLayer", true, false) as Node2D
    if enemies == null or scene._enemy_spawns.size() < 250 or scene._enemy_spawns.size() > 2500:
        _fail("missing authentic published mob spawn list")
        return
    if scene._enemy_spawns.size() != scene._enemy_branch.size():
        _fail("original dungeon spawn coordinates and branch indices drifted")
        return
    if new_count == 0:
        if enemies.get_child_count() != 0 or not scene._enemy_active.is_empty() or scene._boss_visual != null:
            _fail("legacy mob/boss visuals appeared before new approved asset import")
            return
    else:
        if enemies.get_child_count() > scene.PREVIEW_CAP or scene._boss_visual != null:
            _fail("new dungeon art exceeded scene cap or spawned unapproved boss")
            return
        for state in scene._enemy_active.values():
            var sprite := (state["node"] as Node2D).find_child("NewDungeonMob_*", true, false) as Sprite2D
            if sprite == null or sprite.texture == null:
                _fail("new monster preview visible without its original Library PNG")
                return
    if not scene._can_walk(scene._boss_home):
        _fail("published boss chamber is outside the genuine shifted mask")
        return
    if scene._mob_preview_level(0) != int(scene.ENEMY_CATALOG.ROOM_LEVELS[scene._enemy_branch[0]]):
        _fail("default mob levels do not match the original 1–20 branch mapping")
        return
    var branch_counts: Array[int] = []
    branch_counts.resize(20)
    branch_counts.fill(0)
    for i in range(scene._enemy_spawns.size()):
        var branch: int = scene._enemy_branch[i]
        if branch < 0 or branch >= 20 or not scene._can_walk(scene._enemy_spawns[i]):
            _fail("mob spawned in wall or invalid original level room: " + str(i))
            return
        branch_counts[branch] += 1
    for branch in range(20):
        if branch_counts[branch] != int(scene.ENEMY_CATALOG.ROOM_COUNTS[branch]):
            _fail("published original mob count differs from source branch " + str(branch))
            return
    if scene._preview_mode != 0 or scene._preview_boss_id() != "phoenix":
        _fail("original 1–20 Phoenix preview missing")
        return
    var selector := scene.find_child("DungeonPreviewDepthSelector", true, false) as Button
    if selector == null:
        _fail("missing preview 1–20/21–40/41–60 level switcher")
        return
    selector.pressed.emit()
    if scene._preview_mode != 1 or scene._preview_boss_id() != "lord" or scene._mob_preview_level(0) > 40:
        _fail("21–40 Lord preview branch didn't switch")
        return
    selector.pressed.emit()
    if scene._preview_mode != 2 or scene._preview_boss_id() != "dragon" or scene._mob_preview_level(0) < 41:
        _fail("41–60 Dragon preview branch didn't switch")
        return
    selector.pressed.emit()
    if scene._preview_mode != 0 or scene._preview_boss_id() != "phoenix":
        _fail("test mode cannot return to original 1–20 branch")
        return
    print("PPA_DUNGEON_ENEMIES_TEST_OK authentic_spawn_points=",scene._enemy_spawns.size(),
        " physical_level_branches=20 modes=3 preview_mobs=0 preview_bosses=0",
        " old_art_removed=1 wall_spawn=0 server_damage=0 inventory_writes=0")
    var footprint := scene.city_world.find_child("DungeonActualGroundCollider", true, false) as Node2D
    if footprint == null or footprint.visible or scene.WALL_RADIUS != 2.0:
        _fail("initial collision radius or visibility is incorrect")
        return
    toggle.pressed.emit()
    if not overlay.visible or not footprint.visible or footprint.position.distance_to(scene.world_pos_px) > 0.01:
        _fail("mask toggle didn't show the exact ground collider and aligned overlay")
        return
    var circle := footprint.find_child("DungeonFootprintRadius", true, false) as Line2D
    if circle == null or circle.points.size() != 25 or absf(circle.points[0].length() - 2.0) > 0.1:
        _fail("the yellow marker must show the actual 2px footprint")
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
            if last_safe_y < 1.0 or float(step) - last_safe_y > scene.WALL_RADIUS + 6.0:
                _fail("ground collider prevents approaching lower green edge: boundary=" +
                    str(step) + " last_safe=" + str(last_safe_y))
                return
            # A longer, laggy frame must STOP at this wall, not skip across
            # to another walkable room beyond the blocked region.
            var safe_start := entrance + Vector2(0.0, last_safe_y - 9.0)
            if not scene._can_walk(safe_start):
                _fail("near-wall safe start is not walkable")
                return
            scene.world_pos_px = safe_start
            var swept := scene._resolve_city_collision(safe_start + Vector2(0.0, 38.0))
            if not scene._can_walk(swept) or swept.y >= entrance.y + float(step):
                _fail("substep resolver tunneled through the lower wall")
                return
            scene.world_pos_px = entrance
            break
    if not reached_edge:
        _fail("no lower mask edge found from dungeon entrance")
        return
    # The player's shadow mesh is deliberately REMOVED, rather than merely
    # hidden, in BOTH native City and Dungeon.
    if scene.player_3d == null or scene.player_3d.get_child_count() != 1:
        _fail("separate 3D ground-shadow mesh is still attached to player")
        return
    var model: Node3D = null
    if scene.player_visual.get_child_count() > 0:
        model = scene.player_visual.get_child(0) as Node3D
    if model != null and model.find_children("*", "Skeleton3D", true, false).size() > 0:
        var skeletal_bounds: AABB = DWARF_FIT.rest_bone_bounds(model)
        var foot_floor: float = DWARF_FIT.rest_foot_floor(model, skeletal_bounds)
        if absf(model.position.y + foot_floor * model.scale.y) > 0.035:
            _fail("3D foot bones are not resting on the y=0 ground plane")
            return
    # Collision and translucent overlay must use identical world-to-mask
    # transforms everywhere, including the Y=14 origin and upper/lower rooms.
    for uv in [Vector2(0.10, 0.15), Vector2(0.50, 0.50),
        Vector2(0.80, 0.85), Vector2(0.95, 0.90)]:
        var shifted_world_point: Vector2 = uv * world_size + scene.MASK_WORLD_OFFSET
        var actual: Vector2 = scene._world_to_mask_uv(shifted_world_point)
        if actual.distance_to(uv) > 0.00002:
            _fail("14px overlay/collision transform mismatch at " + str(uv))
            return
    var legacy_spawn := Vector2(scene.SAFE_ENTRY.UV.x * world_size.x,
        scene.SAFE_ENTRY.UV.y * world_size.y)
    if scene._entrance.distance_to(legacy_spawn + Vector2(0.0, 14.0)) > 0.001:
        _fail("spawn is still anchored to unshifted walk-mask origin")
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
        " mask_offset_y=14 overlay=1 portrait=1 button_touch=1 joystick_ok=1 footprint_radius=2 shadows=0 foot_grounded=1 mobs_source=1 boss_source=1 server_writes=0")
    scene.queue_free()
    quit(0)
