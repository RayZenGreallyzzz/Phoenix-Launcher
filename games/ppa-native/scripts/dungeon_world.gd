extends "res://scripts/native_world.gd"

# First REAL native PPA dungeon map port: the original deployed stone floor and
# original walk-mask, not an invented procedural dungeon. Movement is test-only;
# server mobs, quest progression, dungeon rewards and live entry are NOT enabled.
const FLOOR := "res://assets/dungeon_layout.webp"
const MASK := "res://assets/dungeon_walk_mask.png"
const SAFE_ENTRY = preload("res://scripts/ppa_dungeon_spawn_generated.gd")
const MASK_R := 112.0 / 255.0
const MASK_A := 48.0 / 255.0
# A 14px circle made the gnome stop too early at corridor boundaries.
# Keep the nine-direction wall probe, but use a compact ground footprint.
# This is test-only world physics, not server combat hitboxes or shadows.
const WALL_RADIUS := 9.0

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
    _sync_world_visuals()
    _add_dungeon_hud()
    print("PPA_NATIVE_DUNGEON_MAP_OK map=", _dungeon_bounds, " mask=", _mask_image.get_size(), " entry=", _entrance)

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
    _walk_overlay.position = Vector2.ZERO
    _walk_overlay.size = _dungeon_bounds
    _walk_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _walk_overlay.stretch_mode = TextureRect.STRETCH_SCALE
    _walk_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    # Strong preview tint; transparent mask cells remain transparent.
    _walk_overlay.modulate = Color(0.10, 1.0, 0.25, 0.72)
    _walk_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _walk_overlay.visible = false
    city_world.add_child(_walk_overlay)

    # Only visible in mask debug mode: shows the ACTUAL physics center
    # and 9px radius, not the decorative 3D ellipse/shadow or mesh boots.
    # It shares the same parent/transform as art and walk-mask overlay.
    _ground_collision_marker = Node2D.new()
    _ground_collision_marker.name = "DungeonActualGroundCollider"
    _ground_collision_marker.z_index = 8
    _ground_collision_marker.visible = false
    city_world.add_child(_ground_collision_marker)
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

func _map_world_size() -> Vector2:
    return _dungeon_bounds

func _movement_speed_px() -> float:
    # Preserve movement relative to the rendered tiles when the same
    # original texture is displayed at PPA's larger logical world size.
    return MOVE_SPEED_PX * _render_to_world_scale

func _world_to_mask_uv(world: Vector2) -> Vector2:
    if _dungeon_bounds.x <= 0.0 or _dungeon_bounds.y <= 0.0:
        return Vector2.ZERO
    # A SINGLE coordinate transform for every collision check and overlay.
    # No guessed independent Y-offset: both input images share source origin.
    return Vector2(world.x / _dungeon_bounds.x, world.y / _dungeon_bounds.y)

func _walk_sample(pos: Vector2) -> bool:
    if _mask_image == null:
        return false
    if pos.x <= 0.0 or pos.y <= 0.0 or pos.x >= _dungeon_bounds.x or pos.y >= _dungeon_bounds.y:
        return false
    var uv := _world_to_mask_uv(pos)
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
        SAFE_ENTRY.UV.y * _dungeon_bounds.y)
    return entry if _can_walk(entry) else Vector2.ZERO

func _resolve_city_collision(target: Vector2) -> Vector2:
    if _mask_image == null:
        return world_pos_px
    # Axis-separated collision sliding; no polygon outline, white edging,
    # arbitrary roof rectangles or placeholder physics blocking entrances.
    var clamped := Vector2(clampf(target.x, WALL_RADIUS, _dungeon_bounds.x - WALL_RADIUS),
        clampf(target.y, WALL_RADIUS, _dungeon_bounds.y - WALL_RADIUS))
    if _can_walk(clamped):
        return clamped
    var slide_x := Vector2(clamped.x, world_pos_px.y)
    var slide_y := Vector2(world_pos_px.x, clamped.y)
    if _can_walk(slide_x):
        return slide_x
    if _can_walk(slide_y):
        return slide_y
    return world_pos_px

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

func _back_to_city() -> void:
    if is_inside_tree():
        var result := get_tree().change_scene_to_file("res://world.tscn")
        if result != OK:
            push_error("PPA_DUNGEON_RETURN_FAILED: " + error_string(result))

# Godot world changes, not a backend save or entry ticket. The original
# Telegram dungeon will still use its real server entry and progression.
