extends "res://scripts/native_world.gd"

# First REAL native PPA dungeon map port: the original deployed stone floor and
# original walk-mask, not an invented procedural dungeon. Movement is test-only;
# server mobs, quest progression, dungeon rewards and live entry are NOT enabled.
const FLOOR := "res://assets/dungeon_layout.webp"
const MASK := "res://assets/dungeon_walk_mask.png"
const MASK_R := 112.0 / 255.0
const MASK_A := 48.0 / 255.0
const WALL_RADIUS := 14.0

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
    _dungeon_bounds = Vector2(_floor_texture.get_width(), _floor_texture.get_height())
    if _mask_image.is_empty() or _dungeon_bounds.x < 1024.0 or _dungeon_bounds.y < 300.0:
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

func _build_city_npcs() -> void:
    # Dungeon mobs are server-authoritative. Do NOT copy city NPCs or invent
    # spawns, level stats, HP or rewards just to fill the scene.
    pass

func _map_world_size() -> Vector2:
    return _dungeon_bounds

func _walk_sample(pos: Vector2) -> bool:
    if _mask_image == null:
        return false
    if pos.x <= 0.0 or pos.y <= 0.0 or pos.x >= _dungeon_bounds.x or pos.y >= _dungeon_bounds.y:
        return false
    var cell_x := clampi(int(pos.x * float(_mask_image.get_width()) / _dungeon_bounds.x), 0, _mask_image.get_width() - 1)
    var cell_y := clampi(int(pos.y * float(_mask_image.get_height()) / _dungeon_bounds.y), 0, _mask_image.get_height() - 1)
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
    # TEST entrance, discovered from the ACTUAL published mask rather than a
    # guessed coordinate. Seek broad walkable ground near the left corridor.
    var w := _mask_image.get_width()
    var h := _mask_image.get_height()
    var origin_y := int(h * 0.5)
    for x in range(maxi(20, int(w * 0.035)), maxi(24, int(w * 0.38)), 6):
        for off in range(0, maxi(6, int(h * 0.33)), 6):
            for direction in [1, -1]:
                var y := origin_y + off * direction
                if y < 0 or y >= h:
                    continue
                var world := Vector2((float(x) + 0.5) * _dungeon_bounds.x / float(w),
                    (float(y) + 0.5) * _dungeon_bounds.y / float(h))
                if _can_walk(world):
                    return world
    return Vector2.ZERO

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

func _back_to_city() -> void:
    if is_inside_tree():
        var result := get_tree().change_scene_to_file("res://world.tscn")
        if result != OK:
            push_error("PPA_DUNGEON_RETURN_FAILED: " + error_string(result))

# Godot world changes, not a backend save or entry ticket. The original
# Telegram dungeon will still use its real server entry and progression.
