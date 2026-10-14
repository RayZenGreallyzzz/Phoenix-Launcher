extends "res://scripts/native_world.gd"

# EXACT Telegram PPA 1×1, shared 3×3/5×5 and XP arena backgrounds.
# Exact original PvP Uint8 collision grids are extracted during Android build.
# This is a walkable, read-only map inspection scene, NOT matchmaking, XP or PvP.
const MAPS = preload("res://scripts/ppa_arena_maps_generated.gd")
const PREVIEW_MODES := ["1x1","3x3","5x5","xp"]
const WALK_RADIUS := 13.0
# Player-requested lower collision edge adjustment in WORLD pixels.
# Original Telegram masks and artwork remain byte-for-byte unchanged.
const LOWER_COLLISION_SHIFT := 50.0

var arena_mode := "1x1"
var _map_dims := Vector2(1536,1024)
var _walk_map: Image = null
# Cached last originally walkable mask row per x, used only to shift the
# lowest wall DOWN; interior rocks, side walls and top remain original.
var _lower_walk_row := PackedInt32Array()
var _caption: Label = null
var _map_status: Label = null

func _ready() -> void:
    arena_mode = str(get_tree().root.get_meta("ppa_preview_arena_mode","1x1")).to_lower()
    if not PREVIEW_MODES.has(arena_mode):
        arena_mode = "1x1"
    _map_dims = MAPS.XP_WORLD_SIZE if arena_mode == "xp" else MAPS.PVP_WORLD_SIZE
    if arena_mode != "xp":
        var mask_type := "duel" if arena_mode == "1x1" else "team"
        var image_path := "res://assets/ppa_original_arena_" + mask_type + "_walk.png"
        var image_texture := load(image_path) as Texture2D
        if image_texture == null:
            push_error("PPA_ARENA_ORIGINAL_WALK_MASK_MISSING: " + image_path)
            return
        _walk_map = image_texture.get_image()
        if _walk_map == null or _walk_map.get_size() != MAPS.MASK_SIZE:
            push_error("PPA_ARENA_ORIGINAL_WALK_MASK_INVALID: " + image_path)
            return
        _cache_lower_boundary()
    super._ready()
    match arena_mode:
        "1x1": world_pos_px = MAPS.DUEL_BLUE
        "3x3", "5x5": world_pos_px = MAPS.TEAM_BLUE[2]
        _: world_pos_px = MAPS.XP_CENTER
    _sync_world_visuals()
    if _caption != null:
        _caption.text = str(MAPS.MODE_NAMES.get(arena_mode,"АРЕНА"))
    if _map_status != null:
        _map_status.text = ("Оригинальная маска PPA · нижняя коллизия +50 px" if arena_mode != "xp"
            else "Арена опыта PPA · нижняя коллизия +50 px")

func _map_world_size() -> Vector2:
    return _map_dims

func _build_city_2d() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#080C11")
    background.z_index = -10
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    city_world = Control.new()
    city_world.name = "PPAOriginalArenaVisualMap"
    city_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(city_world)
    var path := "res://assets/ppa_original_arena_" + ("duel" if arena_mode=="1x1"
        else "xp" if arena_mode=="xp" else "team") + (".jpg" if arena_mode=="xp" else ".png")
    var map_texture := load(path) as Texture2D
    if map_texture == null:
        push_error("PPA_ARENA_ORIGINAL_IMAGE_MISSING: " + path)
        return
    var floor := TextureRect.new()
    floor.name = "PPAExactOriginalArenaArtwork"
    floor.texture = map_texture
    floor.size = _map_dims
    floor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    floor.stretch_mode = TextureRect.STRETCH_SCALE
    floor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.add_child(floor)

func _build_city_npcs() -> void:
    pass # Original PvP map has no city traders and no ghost player replicas.

func _build_test_menu() -> void:
    pass # Prevent NPC menu and connected city actions from leaking into arena.

func _build_server_readonly_bridge() -> void:
    pass # No tickets, gold, XP, party state, ranking, or save updates.

func _build_hud() -> void:
    super._build_hud()
    if input_label != null:
        input_label.text = "КАРТА PPA · проверка стен · движение слева"
    _caption = Label.new()
    _caption.name = "PPAOriginalArenaModeTitle"
    _caption.position = Vector2(16,64)
    _caption.add_theme_font_size_override("font_size",15)
    _caption.add_theme_color_override("font_color",Color("#F6CF91"))
    _caption.z_index = 35
    add_child(_caption)
    _map_status = Label.new()
    _map_status.name = "PPAOriginalArenaCollisionStatus"
    _map_status.position = Vector2(16,88)
    _map_status.add_theme_font_size_override("font_size",11)
    _map_status.add_theme_color_override("font_color",Color("#A5ECCB"))
    _map_status.z_index = 35
    add_child(_map_status)
    var info := Label.new()
    info.name = "PPAOriginalArenaNoMatchDisclaimer"
    info.text = "ПРОСМОТР · PvP / опыт / награды выключены до подключения сервера"
    info.position = Vector2(16,114)
    info.add_theme_font_size_override("font_size",10)
    info.add_theme_color_override("font_color",Color("#C8BAC0"))
    info.z_index = 35
    add_child(info)
    var back := Button.new()
    back.name = "PPAOriginalArenaReturnToCity"
    back.text = "В ГОРОД"
    back.anchor_left = 1.0
    back.anchor_right = 1.0
    back.offset_left = -150.0
    back.offset_right = -16.0
    back.offset_top = 150.0
    back.offset_bottom = 197.0
    back.z_index = 40
    back.pressed.connect(_back_to_city)
    add_child(back)
    # Combat controls remain the approved global layout, but cannot generate
    # unverified damage/XP in an inspection-only scene.
    if _combat_hud != null:
        _combat_hud.set_training(false)

func _on_hud_action(_action: String, _slot: int) -> void:
    if _combat_hud != null:
        _combat_hud.show_notice("Режим осмотра карты · бой требует сервер PPA")

func _exit_game() -> void:
    _back_to_city()

func _back_to_city() -> void:
    get_tree().root.remove_meta("ppa_preview_arena_mode")
    if _joy_touch_id >= 0 or _joy_mouse_active:
        _joy_touch_id = -1
        _joy_mouse_active = false
        _joy_end()
    var error := get_tree().change_scene_to_file("res://world.tscn")
    if error != OK:
        push_error("PPA_ARENA_MAP_RETURN_CITY_FAILED: " + error_string(error))

func _cache_lower_boundary() -> void:
    _lower_walk_row.resize(MAPS.MASK_SIZE.x)
    for x in range(MAPS.MASK_SIZE.x):
        _lower_walk_row[x] = -1
        # Source mask stays exact. Find each column's OUTERMOST lower edge;
        # we do not turn internal obstacles or other disconnected walls into floor.
        for y in range(MAPS.MASK_SIZE.y-1,-1,-1):
            if _walk_map.get_pixel(x,y).a > 0.5:
                _lower_walk_row[x] = y
                break

func _original_lower_edge_y(mask_x: int) -> float:
    if mask_x < 0 or mask_x >= _lower_walk_row.size():
        return -1.0
    if _lower_walk_row[mask_x] < 0:
        return -1.0
    return float(_lower_walk_row[mask_x]+1) * MAPS.PVP_WORLD_SIZE.y / float(MAPS.MASK_SIZE.y)

func _walkable(point: Vector2) -> bool:
    if arena_mode == "xp":
        # Keep the original map, top/side collision and CENTER unchanged.
        # Only lower bound moves down by 50 world pixels (984 -> 1034).
        return (point.x >= 40.0 and point.x <= 984.0
            and point.y >= 40.0 and point.y <= 984.0 + LOWER_COLLISION_SHIFT)
    if _walk_map == null:
        return false
    if point.x < 0.0 or point.x >= _map_dims.x or point.y < 0.0:
        return false
    # The original image occupies 1536×1024. The moved lower collision can
    # exceed its extent only within the requested 50px margin. No map art
    # or mask pixels are stretched or rewritten.
    if point.y > _map_dims.y + LOWER_COLLISION_SHIFT:
        return false
    var mx := clampi(int(floorf(point.x * float(MAPS.MASK_SIZE.x) / _map_dims.x)),
        0,MAPS.MASK_SIZE.x-1)
    if point.y < _map_dims.y:
        var my := clampi(int(floorf(point.y * float(MAPS.MASK_SIZE.y) / _map_dims.y)),
            0,MAPS.MASK_SIZE.y-1)
        if _walk_map.get_pixel(mx,my).a > 0.5:
            return true
    var lower_y := _original_lower_edge_y(mx)
    if lower_y < 0.0:
        return false
    # Only the OUTSIDE lip BELOW the original floor can gain clearance.
    # A 50px downward shift does not shift the entire bitmap or unlock
    # blocked columns, side walls or obstacles between walkable cells.
    return point.y >= lower_y and point.y <= lower_y + LOWER_COLLISION_SHIFT

func _can_stand(point: Vector2) -> bool:
    for offset in [Vector2.ZERO,Vector2(WALK_RADIUS,0),Vector2(-WALK_RADIUS,0),
        Vector2(0,WALK_RADIUS),Vector2(0,-WALK_RADIUS),
        Vector2(9,9),Vector2(-9,9),Vector2(9,-9),Vector2(-9,-9)]:
        if not _walkable(point+offset):
            return false
    return true

func _resolve_city_collision(target: Vector2) -> Vector2:
    var current := world_pos_px
    if _can_stand(target):
        return target
    var horizontal := Vector2(target.x,current.y)
    var vertical := Vector2(current.x,target.y)
    if _can_stand(horizontal):
        return horizontal
    if _can_stand(vertical):
        return vertical
    return current
