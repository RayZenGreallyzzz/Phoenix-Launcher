extends "res://scripts/native_world.gd"

# First REAL native PPA dungeon map port: the original deployed stone floor and
# original walk-mask, not an invented procedural dungeon. Movement is test-only;
# server mobs, quest progression, dungeon rewards and live entry are NOT enabled.
const FLOOR := "res://assets/dungeon_layout.webp"
const MASK := "res://assets/dungeon_walk_mask.png"
const SAFE_ENTRY = preload("res://scripts/ppa_dungeon_spawn_generated.gd")
const ENEMY_CATALOG = preload("res://scripts/ppa_dungeon_entities_generated.gd")
const ENEMY_VISUAL = preload("res://scripts/ppa_dungeon_enemy_test_visual.gd")
const PREVIEW_CAP := 24
const PREVIEW_RADIUS := 675.0
const PREVIEW_AGGRO_RADIUS := 235.0
const BOSS_ACTIVATION_RADIUS := 850.0
const MASK_R := 112.0 / 255.0
const MASK_A := 48.0 / 255.0
# Align the movement point almost flush with the walk-mask wall boundary.
# Two world pixels of clearance handle the 2048px source mask sampling;
# the 3D model/shadow are NOT part of dungeon collision detection.
const WALL_RADIUS := 2.0
const COLLISION_SUBSTEP := 2.0

# Requested tablet calibration: shift the WALK MASK downward by 14 native
# world/screen pixels. The decorative floor remains at its original position.
# Both collision sampling and its translucent debug overlay use this offset.
# Test branch only: revert this single value to 0 if upper walls look wrong.
const MASK_Y_OFFSET_PX := 14.0
const MASK_WORLD_OFFSET := Vector2(0.0, MASK_Y_OFFSET_PX)

# Same logical dungeon units as original PPA build.mjs:
# DG_ART_W=2048; DG_SCALE=(1852*5.1435)/2048;
# DG_W=round(DG_ART_W*DG_SCALE) ~= 9526, NOT 4096 render pixels.
# The old native build confused high-resolution export pixels with world
# coordinates, making stones tiny relative to the unscaled 3D hero.
const ORIGINAL_PPA_ART_W := 2048.0
const ORIGINAL_PPA_SCALE := (1852.0 * 5.1435) / ORIGINAL_PPA_ART_W

var _render_to_world_scale := 1.0
var _walk_overlay: TextureRect
var _ground_collision_marker: Node2D
var _alignment_button: Button

var _floor_texture: Texture2D
var _mask_image: Image
var _dungeon_bounds := Vector2(4096.0, 2048.0)
var _entrance := Vector2.ZERO

# Native-only visual test. Original PPA coordinates, no server state or damage.
var _enemy_layer: Node2D
var _enemy_spawns: Array[Vector2] = []
var _enemy_branch: Array[int] = []
var _enemy_active: Dictionary = {}
var _boss_visual: Node2D
var _boss_home := Vector2.ZERO
var _boss_world := Vector2.ZERO
var _preview_mode := 0
var _preview_clock := 0.0
var _enemy_ai_clock := 0.0
var _preview_mode_button: Button

func _ready() -> void:
    super._ready()
    if _mask_image == null or _floor_texture == null:
        push_error("PPA_DUNGEON_ASSET_MISSING: original PPA mask/map unavailable")
        _back_to_city()
        return
    _entrance = _find_safe_entrance()
    if _entrance == Vector2.ZERO:
        push_error("PPA_DUNGEON_ENTRANCE_INVALID: unable to find safe mask interior")
        _back_to_city()
        return
    world_pos_px = _entrance
    _load_original_enemy_spawns()
    _sync_world_visuals()
    _add_dungeon_hud()
    _refresh_preview_enemies()
    print("PPA_NATIVE_DUNGEON_MAP_OK map=", _dungeon_bounds, " mask=", _mask_image.get_size(), " entry=", _entrance, " mask_offset_y=", MASK_Y_OFFSET_PX)

func _build_city_2d() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#171311")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.z_index = -10
    add_child(background)

    city_world = Control.new()
    city_world.name = "PPADungeonOriginalTileMask"
    city_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.clip_contents = false
    add_child(city_world)

    if not ResourceLoader.exists(FLOOR) or not ResourceLoader.exists(MASK):
        return
    _floor_texture = load(FLOOR) as Texture2D
    var mask_texture := load(MASK) as Texture2D
    if _floor_texture == null or mask_texture == null:
        return
    _mask_image = mask_texture.get_image()
    if _mask_image.is_empty() or _mask_image.get_width() != int(ORIGINAL_PPA_ART_W):
        _mask_image = null
        return
    # The original art/mask are composed at one UV origin in Telegram.
    # Keep the same UV-to-world transform for BOTH render and collisions.
    # PPA's 4096px WebP is an art export, not the gameplay world width.
    var mw := float(_mask_image.get_width())
    var mh := float(_mask_image.get_height())
    _dungeon_bounds = Vector2(roundf(mw * ORIGINAL_PPA_SCALE), roundf(mh * ORIGINAL_PPA_SCALE))
    _render_to_world_scale = _dungeon_bounds.x / float(_floor_texture.get_width())
    if _floor_texture.get_width() != _mask_image.get_width() * 2 or _floor_texture.get_height() != _mask_image.get_height() * 2:
        push_error("PPA_DUNGEON_MAP_MISMATCH: floor and collision mask proportions changed")
        _mask_image = null
        return

    var tile := TextureRect.new()
    tile.name = "OriginalPPADungeonFloor"
    tile.texture = _floor_texture
    tile.size = _dungeon_bounds
    tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tile.stretch_mode = TextureRect.STRETCH_SCALE
    tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.add_child(tile)

    # TEST-ONLY diagnostic: paint exactly the walkable mask over the same
    # world-aligned rectangle. Initially hidden: zero overdraw in normal play.
    # This lets us verify any apparent vertical offset visually, WITHOUT
    # moving the collision map independently or breaking room entrances.
    _walk_overlay = TextureRect.new()
    _walk_overlay.name = "DungeonWalkMaskAlignmentOverlay"
    _walk_overlay.texture = mask_texture
    _walk_overlay.position = MASK_WORLD_OFFSET
    _walk_overlay.size = _dungeon_bounds
    _walk_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _walk_overlay.stretch_mode = TextureRect.STRETCH_SCALE
    _walk_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    # Strong preview tint; transparent mask cells remain transparent.
    _walk_overlay.modulate = Color(0.10, 1.0, 0.25, 0.72)
    _walk_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _walk_overlay.visible = false
    city_world.add_child(_walk_overlay)

    # Only visible in mask debug mode: shows the ACTUAL movement center
    # and tiny 2px clearance, not the 3D character mesh/boots.
    # It shares the same parent/transform as art and walk-mask overlay.
    _ground_collision_marker = Node2D.new()
    _ground_collision_marker.name = "DungeonActualGroundCollider"
    _ground_collision_marker.z_index = 8
    _ground_collision_marker.visible = false
    city_world.add_child(_ground_collision_marker)
    _enemy_layer = Node2D.new()
    _enemy_layer.name = "PPAOriginalDungeonEnemyTestLayer"
    _enemy_layer.z_index = 5
    city_world.add_child(_enemy_layer)
    var boundary := Line2D.new()
    boundary.name = "DungeonFootprintRadius"
    boundary.width = 1.6
    boundary.default_color = Color("#FFD35B")
    var ring_points := PackedVector2Array()
    for step in range(25):
        var phi := TAU * float(step) / 24.0
        ring_points.append(Vector2(cos(phi), sin(phi)) * WALL_RADIUS)
    boundary.points = ring_points
    _ground_collision_marker.add_child(boundary)
    for axis in ["horizontal", "vertical"]:
        var cross := Line2D.new()
        cross.width = 2.0
        cross.default_color = Color("#FFDB5D")
        cross.points = PackedVector2Array([
            Vector2(-5, 0) if axis == "horizontal" else Vector2(0, -5),
            Vector2(5, 0) if axis == "horizontal" else Vector2(0, 5)
        ])
        _ground_collision_marker.add_child(cross)

func _build_city_npcs() -> void:
    # Dungeon mobs are server-authoritative. Do NOT copy city NPCs or invent
    # spawns, level stats, HP or rewards just to fill the scene.
    pass

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if _ground_collision_marker != null:
        _ground_collision_marker.position = world_pos_px
    if _enemy_layer == null or _enemy_spawns.is_empty():
        return
    if test_menu != null and test_menu.is_open():
        return
    _preview_clock += delta
    _enemy_ai_clock += delta
    if _preview_clock >= 0.45:
        _preview_clock = 0.0
        _refresh_preview_enemies()
    if _enemy_ai_clock >= 0.10:
        var tick := minf(_enemy_ai_clock, 0.18)
        _enemy_ai_clock = 0.0
        _animate_preview_enemies(tick)

# All mob positions are taken from the exact published PPA code. The native
# client does not create a second backend, invent real HP, or send attacks.
func _load_original_enemy_spawns() -> void:
    _enemy_spawns.clear()
    _enemy_branch.clear()
    var source = JSON.parse_string(ENEMY_CATALOG.SPAWNS_JSON)
    if not (source is Array) or ENEMY_CATALOG.ROOM_LEVELS.size() != 20:
        push_error("PPA_DUNGEON_MOB_SOURCE_INVALID: published spawn catalog not loaded")
        return
    for row in source:
        if not (row is Array) or (row as Array).size() < 4:
            push_error("PPA_DUNGEON_MOB_SOURCE_INVALID: malformed entry")
            _enemy_spawns.clear()
            _enemy_branch.clear()
            return
        var branch := int(row[2])
        if branch < 0 or branch >= ENEMY_CATALOG.ROOM_LEVELS.size():
            push_error("PPA_DUNGEON_MOB_SOURCE_INVALID: wrong level branch")
            _enemy_spawns.clear()
            _enemy_branch.clear()
            return
        _enemy_spawns.append(Vector2(float(row[0]), float(row[1])) * ORIGINAL_PPA_SCALE + MASK_WORLD_OFFSET)
        _enemy_branch.append(branch)
    _boss_home = Vector2(ENEMY_CATALOG.BOSS_IMG) * ORIGINAL_PPA_SCALE + MASK_WORLD_OFFSET
    _boss_world = _boss_home
    print("PPA_DUNGEON_TEST_ENEMY_CATALOG_OK spawns=", _enemy_spawns.size(),
        " modes=3 boss_center=", _boss_home, " authoritative_spawns=1 server_writes=0")

func _mob_preview_level(spawn_idx: int) -> int:
    return int(ENEMY_CATALOG.ROOM_LEVELS[_enemy_branch[spawn_idx]]) + _preview_mode * 20

func _preview_boss_id() -> String:
    return ["phoenix", "lord", "dragon"][_preview_mode]

func _spawn_preview_enemy(index: int) -> void:
    if _enemy_active.has(index):
        return
    var home: Vector2 = _enemy_spawns[index]
    if not _can_walk(home):
        return
    var visual := ENEMY_VISUAL.new() as Node2D
    visual.call("setup", index, _mob_preview_level(index), false)
    visual.position = home
    visual.name = "LocalMobVisual_%d" % index
    _enemy_layer.add_child(visual)
    _enemy_active[index] = {
        "node":visual,"home":home,"pos":home,
        "wander_clock":float(index % 10) * 0.21,
        "dir":Vector2(cos(float(index) * 2.17), sin(float(index) * 2.17)),
        "pulse":0.0
    }

func _refresh_preview_enemies() -> void:
    if _enemy_layer == null or _enemy_spawns.is_empty():
        return
    # Culling: at most 24 animated mobs exist in the Android scene.
    # The authentic level count is not reduced; distant ones are dormant.
    var near: Array[Dictionary] = []
    var limit_sq := PREVIEW_RADIUS * PREVIEW_RADIUS
    for i in range(_enemy_spawns.size()):
        var d := world_pos_px.distance_squared_to(_enemy_spawns[i])
        if d <= limit_sq:
            near.append({"index":i,"distance":d})
    near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["distance"]) < float(b["distance"])
    )
    var wanted := {}
    for k in range(mini(PREVIEW_CAP, near.size())):
        var index := int(near[k]["index"])
        wanted[index] = true
        if not _enemy_active.has(index):
            _spawn_preview_enemy(index)
    for key in _enemy_active.keys():
        if not wanted.has(key):
            var state: Dictionary = _enemy_active[key]
            var node := state["node"] as Node2D
            if node != null:
                node.queue_free()
            _enemy_active.erase(key)

    if world_pos_px.distance_to(_boss_home) < BOSS_ACTIVATION_RADIUS:
        if _boss_visual == null:
            _boss_visual = ENEMY_VISUAL.new() as Node2D
            _boss_visual.call("setup", -1, 20 + _preview_mode * 20, true, _preview_boss_id())
            _boss_visual.name = "LocalBossVisual_" + _preview_boss_id()
            _enemy_layer.add_child(_boss_visual)
            _boss_visual.position = _boss_world
    elif _boss_visual != null:
        _boss_visual.queue_free()
        _boss_visual = null
        _boss_world = _boss_home

func _animate_preview_enemies(dt: float) -> void:
    for key in _enemy_active.keys():
        var state: Dictionary = _enemy_active[key]
        var node := state["node"] as Node2D
        if node == null or not is_instance_valid(node):
            continue
        var pos: Vector2 = state["pos"]
        var home: Vector2 = state["home"]
        var diff := world_pos_px - pos
        var distance := diff.length()
        var aggro := distance < PREVIEW_AGGRO_RADIUS and home.distance_to(pos) < 170.0
        var direction: Vector2 = state["dir"]
        if aggro and distance > 55.0:
            direction = diff.normalized()
        elif home.distance_to(pos) > 95.0:
            direction = (home - pos).normalized()
        else:
            state["wander_clock"] = float(state["wander_clock"]) + dt
            if float(state["wander_clock"]) > 1.8:
                state["wander_clock"] = 0.0
                var angle := float(int(key) % 83) * 1.57 + float(Engine.get_physics_frames() % 17) * 0.41
                direction = Vector2(cos(angle), sin(angle))
                state["dir"] = direction
        var speed := 91.0 if aggro else 25.0
        var proposed := pos + direction * speed * dt
        if distance <= 55.0 and aggro:
            proposed = pos
        if home.distance_to(proposed) > 180.0 or not _can_walk(proposed):
            state["dir"] = -direction
            proposed = pos
        state["pos"] = proposed
        node.position = proposed
        node.call("set_aggro", aggro)
        node.call("set_attack", aggro and distance < 80.0)
        _enemy_active[key] = state
    if _boss_visual != null:
        var direction_to_player := world_pos_px - _boss_world
        var boss_distance := direction_to_player.length()
        if boss_distance < 440.0 and boss_distance > 95.0:
            var next_boss := _boss_world + direction_to_player.normalized() * dt * 65.0
            if next_boss.distance_to(_boss_home) < 250.0 and _can_walk(next_boss):
                _boss_world = next_boss
        _boss_visual.position = _boss_world
        _boss_visual.call("set_aggro", boss_distance < 440.0)
        _boss_visual.call("set_attack", boss_distance < 135.0)

func _cycle_preview_depth() -> void:
    _preview_mode = (_preview_mode + 1) % 3
    for state in _enemy_active.values():
        var node := state["node"] as Node2D
        if node != null:
            node.queue_free()
    _enemy_active.clear()
    if _boss_visual != null:
        _boss_visual.queue_free()
        _boss_visual = null
    _boss_world = _boss_home
    if _preview_mode_button != null:
        _preview_mode_button.text = ["ТЕСТ 1–20", "ТЕСТ 21–40", "ТЕСТ 41–60"][_preview_mode]
    _refresh_preview_enemies()
    print("PPA_DUNGEON_TEST_DEPTH_OK bracket=", _preview_mode,
        " boss=", _preview_boss_id(), " no_rewards=1")

func _map_world_size() -> Vector2:
    return _dungeon_bounds

func _movement_speed_px() -> float:
    # Preserve movement relative to the rendered tiles when the same
    # original texture is displayed at PPA's larger logical world size.
    return MOVE_SPEED_PX * _render_to_world_scale

func _world_to_mask_uv(world: Vector2) -> Vector2:
    if _dungeon_bounds.x <= 0.0 or _dungeon_bounds.y <= 0.0:
        return Vector2.ZERO
    # Sample at the SAME source pixel seen in the down-shifted overlay.
    # World Y=offset corresponds to mask texture Y=0, so never move the
    # decorative floor, camera, rig or hero's ground anchor.
    return Vector2(world.x / _dungeon_bounds.x,
        (world.y - MASK_Y_OFFSET_PX) / _dungeon_bounds.y)

func _walk_sample(pos: Vector2) -> bool:
    if _mask_image == null:
        return false
    if pos.x <= 0.0 or pos.y <= 0.0 or pos.x >= _dungeon_bounds.x or pos.y >= _dungeon_bounds.y:
        return false
    var uv := _world_to_mask_uv(pos)
    if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
        return false
    var cell_x := clampi(int(uv.x * float(_mask_image.get_width())), 0, _mask_image.get_width() - 1)
    var cell_y := clampi(int(uv.y * float(_mask_image.get_height())), 0, _mask_image.get_height() - 1)
    var pixel := _mask_image.get_pixel(cell_x, cell_y)
    # Same strict red/alpha thresholds as the approved PPA build.mjs walk mask.
    return pixel.r >= MASK_R and pixel.a >= MASK_A

func _can_walk(pos: Vector2) -> bool:
    if not _walk_sample(pos):
        return false
    var r := WALL_RADIUS
    var diag := r * 0.70710678
    for delta in [
        Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r),
        Vector2(diag, diag), Vector2(diag, -diag),
        Vector2(-diag, diag), Vector2(-diag, -diag)
    ]:
        if not _walk_sample(pos + delta):
            return false
    return true

func _find_safe_entrance() -> Vector2:
    # Generated from the exact publicly deployed PPA collision bits at BUILD
    # time. No per-launch 100k get_pixel scan, avoiding tablet stalls.
    if _mask_image == null or _mask_image.get_size() != SAFE_ENTRY.MASK_DIMS:
        return Vector2.ZERO
    var entry := Vector2(SAFE_ENTRY.UV.x * _dungeon_bounds.x,
        SAFE_ENTRY.UV.y * _dungeon_bounds.y) + MASK_WORLD_OFFSET
    return entry if _can_walk(entry) else Vector2.ZERO

func _resolve_city_collision(target: Vector2) -> Vector2:
    if _mask_image == null:
        return world_pos_px
    # Reject obviously invalid coordinates without walking thousands of
    # samples during an unintended teleport or an out-of-map input.
    if target.x < WALL_RADIUS or target.y < WALL_RADIUS:
        return world_pos_px
    if target.x >= _dungeon_bounds.x - WALL_RADIUS or target.y >= _dungeon_bounds.y - WALL_RADIUS:
        return world_pos_px
    # The original one-shot endpoint check could stop a whole frame early,
    # while a large frame delta could jump over a thin wall. Move in 2px
    # substeps instead, with axis-separated sliding at each wall.
    var motion := target - world_pos_px
    var count := maxi(1, ceili(motion.length() / COLLISION_SUBSTEP))
    var movement_step := motion / float(count)
    var current := world_pos_px
    for n in range(count):
        var destination := current + movement_step
        if _can_walk(destination):
            current = destination
            continue
        var x_only := Vector2(destination.x, current.y)
        if _can_walk(x_only):
            current = x_only
        var y_only := Vector2(current.x, destination.y)
        if _can_walk(y_only):
            current = y_only
    return current

# NativeWorld listens in _input(), which is dispatched BEFORE GUI buttons.
# Without this exclusion the smart joystick claims all left-screen touches
# and marks them handled, so the mask diagnostic never receives 'pressed'.
func _joy_point_allowed(point: Vector2) -> bool:
    if _alignment_button != null and _alignment_button.is_visible_in_tree():
        if _alignment_button.get_global_rect().has_point(point):
            return false
    return super._joy_point_allowed(point)

func _try_world_tap(screen_position: Vector2) -> bool:
    if test_menu == null or test_menu.is_open() or camera_3d == null or player_3d == null:
        return false
    var hero_center := camera_3d.unproject_position(player_3d.to_global(Vector3(0, 0.95, 0)))
    if hero_center.distance_to(screen_position) <= 62.0:
        _joy_end()
        test_menu.open_page("character")
        return true
    return false

func _add_dungeon_hud() -> void:
    var label := Label.new()
    label.name = "DungeonVisualTestLabel"
    label.text = "ПОДЗЕМЕЛЬЕ · ПРОВЕРКА КАРТЫ · БЕЗ БОЁВ И НАГРАД"
    label.anchor_left = 0.0
    label.anchor_right = 1.0
    label.offset_left = 14
    label.offset_right = -14
    label.offset_top = 77
    label.offset_bottom = 107
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color("#ECCC93"))
    label.z_index = 60
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)

    var back := Button.new()
    back.name = "DungeonReturnCity"
    back.text = "↶ В ГОРОД"
    back.anchor_left = 1.0
    back.anchor_right = 1.0
    back.anchor_top = 1.0
    back.anchor_bottom = 1.0
    back.offset_left = -172
    back.offset_right = -18
    back.offset_top = -88
    back.offset_bottom = -36
    back.z_index = 70
    back.add_theme_font_size_override("font_size", 14)
    back.pressed.connect(_back_to_city)
    add_child(back)

    var alignment := Button.new()
    alignment.name = "DungeonMaskAlignmentToggle"
    alignment.text = "ПОКАЗАТЬ МАСКУ"
    alignment.anchor_left = 0.0
    alignment.anchor_right = 0.0
    alignment.offset_left = 16.0
    alignment.offset_right = 222.0
    alignment.offset_top = 132.0
    alignment.offset_bottom = 184.0
    alignment.mouse_filter = Control.MOUSE_FILTER_STOP
    alignment.focus_mode = Control.FOCUS_ALL
    alignment.z_index = 70
    alignment.add_theme_font_size_override("font_size", 11)
    alignment.pressed.connect(func() -> void:
        if _walk_overlay == null:
            return
        _walk_overlay.visible = not _walk_overlay.visible
        if _ground_collision_marker != null:
            _ground_collision_marker.position = world_pos_px
            _ground_collision_marker.visible = _walk_overlay.visible
        alignment.text = "СКРЫТЬ МАСКУ" if _walk_overlay.visible else "ПОКАЗАТЬ МАСКУ"
        print("PPA_DUNGEON_MASK_TOGGLE_OK visible=", _walk_overlay.visible)
    )
    add_child(alignment)
    _alignment_button = alignment

    # Occupies the top-right slot vacated by the redundant HERO button.
    # Test-only level branch switch, never changes the server character.
    _preview_mode_button = Button.new()
    _preview_mode_button.name = "DungeonPreviewDepthSelector"
    _preview_mode_button.text = "ТЕСТ 1–20"
    _preview_mode_button.anchor_left = 1.0
    _preview_mode_button.anchor_right = 1.0
    _preview_mode_button.offset_left = -156.0
    _preview_mode_button.offset_right = -18.0
    _preview_mode_button.offset_top = 137.0
    _preview_mode_button.offset_bottom = 185.0
    _preview_mode_button.z_index = 71
    _preview_mode_button.mouse_filter = Control.MOUSE_FILTER_STOP
    _preview_mode_button.add_theme_font_size_override("font_size", 12)
    _preview_mode_button.pressed.connect(_cycle_preview_depth)
    add_child(_preview_mode_button)

func _back_to_city() -> void:
    if is_inside_tree():
        var result := get_tree().change_scene_to_file("res://world.tscn")
        if result != OK:
            push_error("PPA_DUNGEON_RETURN_FAILED: " + error_string(result))

# Godot world changes, not a backend save or entry ticket. The original
# Telegram dungeon will still use its real server entry and progression.
