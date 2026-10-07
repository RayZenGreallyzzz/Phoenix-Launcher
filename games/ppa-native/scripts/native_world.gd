extends Control

# Native 2.5D port of the CURRENT City of Ashes world.
# World/map/NPC objects stay 2D. Only the local player is rendered in 3D.
const CITY_W := 4347.0
const CITY_H := 3333.0
const CITY_ENTRY := Vector2(2174.0, 1666.0)

# Exact current compositor projection from the approved City of Ashes build:
# ZOOM=4.00 and vertical projection = ZOOM*cos(0.75).
const MAP_SCALE := Vector2(4.0, 2.9267554755)
const PLAYER_RADIUS := 13.0
const MOVE_SPEED_PX := 165.0
const CITY_LEFT := 290.0
const CITY_RIGHT := 335.0
const CITY_TOP := 225.0
const CITY_BOTTOM := 290.0
const BUILDING_STRETCH_Y := 1.3660254
const PX_PER_3D_UNIT := 34.0

const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")

const BUILDING_TEXTURES := [
    "res://assets/city_building_0.webp",
    "res://assets/city_building_1.webp",
    "res://assets/city_building_2.webp",
    "res://assets/city_building_3.webp",
    "res://assets/city_building_4.webp",
    "res://assets/city_building_5.webp",
    "res://assets/city_building_6.webp",
    "res://assets/city_building_7.webp",
    "res://assets/city_building_8.webp"
]

const BUILDINGS := [
    {"x":702, "y":414.5, "type":0, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":1006.5, "y":415.5, "type":1, "sprite_w":165.0, "hw":72.0, "hh":72.0},
    {"x":1311, "y":416, "type":4, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":2219.5, "y":417.5, "type":2, "sprite_w":155.0, "hw":72.0, "hh":72.0},
    {"x":398.5, "y":715.5, "type":6, "sprite_w":162.0, "hw":72.0, "hh":72.0},
    {"x":1006, "y":716.5, "type":7, "sprite_w":168.0, "hw":72.0, "hh":72.0},
    {"x":1611.5, "y":717.5, "type":5, "sprite_w":152.0, "hw":72.0, "hh":72.0},
    {"x":2219, "y":719, "type":0, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":2523, "y":719.5, "type":3, "sprite_w":160.0, "hw":72.0, "hh":72.0},
    {"x":398.5, "y":1016.5, "type":4, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":701.5, "y":1017.5, "type":1, "sprite_w":165.0, "hw":72.0, "hh":72.0},
    {"x":1004.5, "y":1017.5, "type":8, "sprite_w":162.0, "hw":72.0, "hh":72.0},
    {"x":1308, "y":1018, "type":2, "sprite_w":155.0, "hw":72.0, "hh":72.0},
    {"x":1914.5, "y":1019.5, "type":5, "sprite_w":152.0, "hw":72.0, "hh":72.0},
    {"x":700.5, "y":1316.5, "type":0, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":1913.5, "y":1319, "type":7, "sprite_w":168.0, "hw":72.0, "hh":72.0},
    {"x":2217, "y":1319, "type":4, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":2521.5, "y":1320, "type":6, "sprite_w":162.0, "hw":72.0, "hh":72.0},
    {"x":398, "y":1616.5, "type":1, "sprite_w":165.0, "hw":72.0, "hh":72.0},
    {"x":701.5, "y":1617.5, "type":0, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":1004, "y":1617.5, "type":5, "sprite_w":152.0, "hw":72.0, "hh":72.0},
    {"x":1004.5, "y":1918.5, "type":3, "sprite_w":160.0, "hw":72.0, "hh":72.0},
    {"x":397, "y":2218.5, "type":2, "sprite_w":155.0, "hw":72.0, "hh":72.0},
    {"x":701, "y":2219.5, "type":7, "sprite_w":168.0, "hw":72.0, "hh":72.0},
    {"x":1307, "y":2220, "type":4, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":1003.5, "y":2520.5, "type":8, "sprite_w":162.0, "hw":72.0, "hh":72.0},
    {"x":2518.5, "y":2524, "type":0, "sprite_w":150.0, "hw":72.0, "hh":72.0},
    {"x":699.5, "y":2819.5, "type":6, "sprite_w":162.0, "hw":72.0, "hh":72.0},
    {"x":1002.5, "y":2820.5, "type":1, "sprite_w":165.0, "hw":72.0, "hh":72.0},
    {"x":1305, "y":2821, "type":5, "sprite_w":152.0, "hw":72.0, "hh":72.0},
    {"x":2518, "y":2823, "type":2, "sprite_w":155.0, "hw":72.0, "hh":72.0}
]

const TREE_COLLIDERS := [
    {"x":3792.5, "y":312.9, "r":6.0},
    {"x":398.8, "y":426.7, "r":13.0},
    {"x":2515.7, "y":428.8, "r":15.0},
    {"x":3475, "y":435, "r":14.0},
    {"x":1608.3, "y":439.4, "r":14.0},
    {"x":2819.1, "y":446.2, "r":12.0},
    {"x":3162.8, "y":615.4, "r":7.0},
    {"x":3715, "y":625, "r":12.0},
    {"x":3373.1, "y":720.2, "r":6.0},
    {"x":1913.8, "y":726.1, "r":14.0},
    {"x":1309.1, "y":733.7, "r":14.0},
    {"x":713.5, "y":734.3, "r":13.0},
    {"x":3676.2, "y":925.5, "r":15.0},
    {"x":3127.8, "y":996, "r":6.0},
    {"x":1608.5, "y":1038.3, "r":12.0},
    {"x":2521.2, "y":1038.4, "r":12.0},
    {"x":3143, "y":1242.5, "r":6.0},
    {"x":3417.6, "y":1271.3, "r":9.0},
    {"x":1008.6, "y":1333.3, "r":12.0},
    {"x":3203.4, "y":1334.1, "r":7.0},
    {"x":402.5, "y":1336.3, "r":12.0},
    {"x":3725.3, "y":1339.6, "r":13.0},
    {"x":1298.8, "y":1640, "r":13.0},
    {"x":2205, "y":1925, "r":12.0},
    {"x":400, "y":1930, "r":12.0},
    {"x":1303.7, "y":1932.2, "r":12.0},
    {"x":2825, "y":1935, "r":12.0},
    {"x":3696.2, "y":2111.6, "r":14.0},
    {"x":1900, "y":2220, "r":11.0},
    {"x":996, "y":2238.7, "r":12.0},
    {"x":3164.5, "y":2240.7, "r":13.0},
    {"x":2809.2, "y":2517.3, "r":14.0},
    {"x":400.4, "y":2529.6, "r":12.0},
    {"x":700, "y":2530, "r":12.0},
    {"x":1605, "y":2535, "r":13.0},
    {"x":1910, "y":2535, "r":12.0},
    {"x":2212.7, "y":2542.5, "r":13.0},
    {"x":1302.8, "y":2545.7, "r":12.0},
    {"x":3415.9, "y":2574.2, "r":6.0},
    {"x":3735.7, "y":2815.6, "r":11.0},
    {"x":393.4, "y":2835.7, "r":12.0},
    {"x":1605, "y":2840, "r":12.0},
    {"x":1905, "y":2842.6, "r":12.0},
    {"x":2219.9, "y":2849.7, "r":12.0},
    {"x":839.2, "y":2973.8, "r":10.0}
]

var profile: Dictionary = {}
var world_pos_px := CITY_ENTRY
var move_input := Vector2.ZERO
var facing_input := Vector2(0.0, 1.0)

var city_world: Control
var building_nodes: Array = []

var viewport_3d: SubViewport
var viewport_3d_rect: TextureRect
var camera_3d: Camera3D
var player_3d: Node3D
var player_visual: Node3D
var joystick_visual: Control

var fps_label: Label
var coords_label: Label
var input_label: Label

var _joy_touch_id := -1
var _joy_mouse_active := false
var _joy_center := Vector2.ZERO
var _fps_clock := 0.0

var _animation_player: AnimationPlayer
var _run_animation := ""
var _idle_animation := ""
var _anim_state := ""

func _ready() -> void:
    profile = get_tree().get_meta("phoenix_account", {})
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)

    _build_city_2d()
    _build_3d_overlay()
    _build_hud()
    world_pos_px = CITY_ENTRY
    _sync_world_visuals()

func _build_city_2d() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#332D27")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.z_index = -10
    add_child(background)

    city_world = Control.new()
    city_world.name = "CityOfAshes2D"
    city_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.clip_contents = false
    city_world.scale = MAP_SCALE
    add_child(city_world)

    _add_map_tile("res://assets/city_map_left.webp", Vector2.ZERO, Vector2(2174.0, CITY_H))
    _add_map_tile("res://assets/city_map_right.webp", Vector2(2174.0, 0.0), Vector2(2173.0, CITY_H))

    for building_data in BUILDINGS:
        _add_building(building_data)

func _add_map_tile(path: String, pos: Vector2, tile_size: Vector2) -> void:
    if not ResourceLoader.exists(path):
        return
    var tile := TextureRect.new()
    tile.texture = load(path)
    tile.position = pos
    tile.size = tile_size
    tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tile.stretch_mode = TextureRect.STRETCH_SCALE
    tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    tile.z_index = 0
    city_world.add_child(tile)

func _add_building(data: Dictionary) -> void:
    var type_index: int = int(data.get("type", 0))
    if type_index < 0 or type_index >= BUILDING_TEXTURES.size():
        return

    var path: String = BUILDING_TEXTURES[type_index]
    if not ResourceLoader.exists(path):
        return

    var texture: Texture2D = load(path)
    if texture == null or texture.get_width() <= 0:
        return

    var width_px: float = float(data.get("sprite_w", 150.0))
    var image_ratio: float = float(texture.get_height()) / float(texture.get_width())
    var height_px: float = width_px * image_ratio * BUILDING_STRETCH_Y
    var x: float = float(data.get("x", 0.0))
    var y: float = float(data.get("y", 0.0))
    var hh: float = float(data.get("hh", 72.0))

    var sprite := TextureRect.new()
    sprite.texture = texture
    sprite.size = Vector2(width_px, height_px)
    sprite.position = Vector2(x - width_px * 0.5, y + hh - height_px)
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_SCALE
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    sprite.z_index = 1
    city_world.add_child(sprite)

    building_nodes.append({"data": data, "node": sprite})

func _build_3d_overlay() -> void:
    viewport_3d = SubViewport.new()
    viewport_3d.name = "Player3DViewport"
    viewport_3d.transparent_bg = true
    viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_3d.own_world_3d = true
    viewport_3d.size = _viewport_size_i()
    add_child(viewport_3d)

    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.0, 0.0, 0.0, 0.0)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#FFF7EA")
    env.ambient_light_energy = 1.35
    env_node.environment = env
    viewport_3d.add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.light_color = Color("#FFF0CF")
    sun.light_energy = 2.15
    sun.rotation_degrees = Vector3(-46.0, -30.0, 0.0)
    sun.shadow_enabled = false
    viewport_3d.add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.light_color = Color("#9EC8FF")
    fill.light_energy = 0.58
    fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
    fill.shadow_enabled = false
    viewport_3d.add_child(fill)

    camera_3d = Camera3D.new()
    camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera_3d.near = 0.01
    camera_3d.far = 100.0
    camera_3d.position = Vector3(5.0, 7.4, 9.0)
    camera_3d.current = true
    viewport_3d.add_child(camera_3d)
    camera_3d.look_at(Vector3(0.0, 0.72, 0.0), Vector3.UP)

    player_3d = Node3D.new()
    viewport_3d.add_child(player_3d)

    player_visual = Node3D.new()
    player_3d.add_child(player_visual)

    if ResourceLoader.exists("res://assets/Dwarf.glb"):
        var model_resource = load("res://assets/Dwarf.glb")
        if model_resource is PackedScene:
            var model := (model_resource as PackedScene).instantiate()
            model.scale = Vector3.ONE * 0.88
            player_visual.add_child(model)
            _find_model_animations(model)
        else:
            _build_fallback_player()
    else:
        _build_fallback_player()

    var shadow_mesh := CylinderMesh.new()
    shadow_mesh.top_radius = 0.58
    shadow_mesh.bottom_radius = 0.58
    shadow_mesh.height = 0.01
    var shadow := MeshInstance3D.new()
    shadow.mesh = shadow_mesh
    shadow.position = Vector3(0.0, 0.012, 0.0)
    var shadow_mat := StandardMaterial3D.new()
    shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.30)
    shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow.material_override = shadow_mat
    player_3d.add_child(shadow)

    viewport_3d_rect = TextureRect.new()
    viewport_3d_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_3d_rect.texture = viewport_3d.get_texture()
    viewport_3d_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    viewport_3d_rect.stretch_mode = TextureRect.STRETCH_SCALE
    viewport_3d_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    viewport_3d_rect.z_index = 2
    add_child(viewport_3d_rect)

func _build_fallback_player() -> void:
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.38
    body_mesh.height = 1.32
    var body := MeshInstance3D.new()
    body.mesh = body_mesh
    body.position.y = 0.72
    body.material_override = _material(Color("#D85E1C"), 0.55)
    player_visual.add_child(body)

    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.29
    head_mesh.height = 0.58
    var head := MeshInstance3D.new()
    head.mesh = head_mesh
    head.position = Vector3(0.0, 1.52, 0.0)
    head.material_override = _material(Color("#D9B28B"), 0.70)
    player_visual.add_child(head)

func _build_hud() -> void:
    var nickname := str(profile.get("ppaNickname", profile.get("nickname", "Phoenix")))
    var class_key := str(profile.get("classKey", ""))

    var name_label := Label.new()
    name_label.text = nickname
    name_label.position = Vector2(28.0, 22.0)
    name_label.add_theme_font_size_override("font_size", 22)
    name_label.add_theme_color_override("font_color", Color("#F2F4F6"))
    name_label.z_index = 20
    add_child(name_label)

    var class_label := Label.new()
    class_label.text = "ГОРОД ПЕПЛА · %s" % (class_key if not class_key.is_empty() else "PLAYER3D")
    class_label.position = Vector2(30.0, 51.0)
    class_label.add_theme_font_size_override("font_size", 12)
    class_label.add_theme_color_override("font_color", Color("#FE6D1C"))
    class_label.z_index = 20
    add_child(class_label)

    fps_label = Label.new()
    fps_label.anchor_left = 1.0
    fps_label.anchor_right = 1.0
    fps_label.offset_left = -145.0
    fps_label.offset_right = -28.0
    fps_label.offset_top = 22.0
    fps_label.offset_bottom = 50.0
    fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    fps_label.add_theme_font_size_override("font_size", 17)
    fps_label.add_theme_color_override("font_color", Color("#53CDAB"))
    fps_label.z_index = 20
    add_child(fps_label)

    coords_label = Label.new()
    coords_label.anchor_left = 1.0
    coords_label.anchor_right = 1.0
    coords_label.offset_left = -250.0
    coords_label.offset_right = -28.0
    coords_label.offset_top = 52.0
    coords_label.offset_bottom = 78.0
    coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    coords_label.add_theme_font_size_override("font_size", 12)
    coords_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.60))
    coords_label.z_index = 20
    add_child(coords_label)

    input_label = Label.new()
    input_label.text = "SMART JOYSTICK · коснись левой половины"
    input_label.anchor_left = 0.5
    input_label.anchor_right = 0.5
    input_label.anchor_top = 1.0
    input_label.anchor_bottom = 1.0
    input_label.offset_left = -230.0
    input_label.offset_right = 230.0
    input_label.offset_top = -40.0
    input_label.offset_bottom = -16.0
    input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    input_label.add_theme_font_size_override("font_size", 12)
    input_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.42))
    input_label.z_index = 20
    add_child(input_label)

    joystick_visual = JOYSTICK_SCRIPT.new()
    joystick_visual.z_index = 30
    add_child(joystick_visual)
    joystick_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var exit_button := Button.new()
    exit_button.text = "ВЫХОД"
    exit_button.anchor_left = 1.0
    exit_button.anchor_right = 1.0
    exit_button.offset_left = -142.0
    exit_button.offset_right = -28.0
    exit_button.offset_top = 84.0
    exit_button.offset_bottom = 128.0
    exit_button.add_theme_font_size_override("font_size", 13)
    exit_button.z_index = 20
    exit_button.pressed.connect(_exit_game)
    add_child(exit_button)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if _joy_touch_id == -1 and _joy_point_allowed(event.position):
                _joy_touch_id = event.index
                _joy_begin(event.position)
                get_viewport().set_input_as_handled()
        elif event.index == _joy_touch_id:
            _joy_touch_id = -1
            _joy_end()
            get_viewport().set_input_as_handled()
        return

    if event is InputEventScreenDrag:
        if event.index == _joy_touch_id:
            _joy_update(event.position)
            get_viewport().set_input_as_handled()
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if not _joy_mouse_active and _joy_touch_id == -1 and _joy_point_allowed(event.position):
                _joy_mouse_active = true
                _joy_begin(event.position)
                get_viewport().set_input_as_handled()
        elif _joy_mouse_active:
            _joy_mouse_active = false
            _joy_end()
            get_viewport().set_input_as_handled()
        return

    if event is InputEventMouseMotion and _joy_mouse_active:
        _joy_update(event.position)
        get_viewport().set_input_as_handled()

func _joy_point_allowed(point: Vector2) -> bool:
    return size.x > 1.0 and point.x <= size.x * 0.5

func _joy_begin(point: Vector2) -> void:
    _joy_center = point
    move_input = Vector2.ZERO
    if joystick_visual:
        joystick_visual.begin_at(point)
    if input_label:
        input_label.text = "JOY ACTIVE · 0.00  0.00"

func _joy_update(point: Vector2) -> void:
    var raw := point - _joy_center
    var distance: float = raw.length()
    const DEAD := 8.0
    const MAX_R := 50.0

    if distance <= DEAD:
        move_input = Vector2.ZERO
    else:
        var magnitude: float = (minf(distance, MAX_R) - DEAD) / (MAX_R - DEAD)
        move_input = raw / maxf(distance, 0.001) * magnitude

    if joystick_visual:
        joystick_visual.update_visual_offset(raw)
    if input_label:
        input_label.text = "JOY ACTIVE · %.2f  %.2f" % [move_input.x, move_input.y]

func _joy_end() -> void:
    move_input = Vector2.ZERO
    _joy_center = Vector2.ZERO
    if joystick_visual:
        joystick_visual.end()
    if input_label:
        input_label.text = "SMART JOYSTICK · коснись левой половины"

func _physics_process(delta: float) -> void:
    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        keyboard.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        keyboard.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        keyboard.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        keyboard.y += 1.0

    var input_vec := keyboard.normalized() if keyboard.length() > 0.05 else move_input
    if input_vec.length() > 1.0:
        input_vec = input_vec.normalized()

    if input_vec.length_squared() > 0.0001:
        facing_input = input_vec.normalized()
        world_pos_px = _resolve_city_collision(world_pos_px + input_vec * MOVE_SPEED_PX * delta)
        _set_animation("run")
    else:
        _set_animation("idle")

    _sync_world_visuals()

func _process(delta: float) -> void:
    _fps_clock += delta
    if _fps_clock >= 0.25:
        _fps_clock = 0.0
        if fps_label:
            fps_label.text = "%d FPS" % Engine.get_frames_per_second()
        if coords_label:
            coords_label.text = "CITY X %.0f   Y %.0f" % [world_pos_px.x, world_pos_px.y]

func _resolve_city_collision(target: Vector2) -> Vector2:
    var x: float = clampf(target.x, CITY_LEFT + PLAYER_RADIUS, CITY_W - CITY_RIGHT - PLAYER_RADIUS)
    var y: float = clampf(target.y, CITY_TOP + PLAYER_RADIUS, CITY_H - CITY_BOTTOM - PLAYER_RADIUS)

    for building_data in BUILDINGS:
        var bx: float = float(building_data.get("x", 0.0))
        var by: float = float(building_data.get("y", 0.0))
        var hw: float = float(building_data.get("hw", 72.0))
        var hh: float = float(building_data.get("hh", 72.0))
        var left: float = bx - hw
        var right: float = bx + hw
        var top: float = by - hh
        var bottom: float = by + hh

        if x + PLAYER_RADIUS > left and x - PLAYER_RADIUS < right and y + PLAYER_RADIUS > top and y - PLAYER_RADIUS < bottom:
            var dl: float = (x + PLAYER_RADIUS) - left
            var dr: float = right - (x - PLAYER_RADIUS)
            var dt: float = (y + PLAYER_RADIUS) - top
            var db: float = bottom - (y - PLAYER_RADIUS)
            var shortest: float = minf(minf(dl, dr), minf(dt, db))

            if is_equal_approx(shortest, dl):
                x = left - PLAYER_RADIUS
            elif is_equal_approx(shortest, dr):
                x = right + PLAYER_RADIUS
            elif is_equal_approx(shortest, dt):
                y = top - PLAYER_RADIUS
            else:
                y = bottom + PLAYER_RADIUS

    for tree_data in TREE_COLLIDERS:
        var tx: float = float(tree_data.get("x", 0.0))
        var ty: float = float(tree_data.get("y", 0.0))
        var tr: float = float(tree_data.get("r", 0.0))
        var dx: float = x - tx
        var dy: float = y - ty
        var rr: float = PLAYER_RADIUS + tr
        var d2: float = dx * dx + dy * dy

        if d2 < rr * rr:
            if d2 < 0.0001:
                y = ty + rr
            else:
                var distance: float = sqrt(d2)
                var push: float = rr - distance
                x += dx / distance * push
                y += dy / distance * push

    x = clampf(x, CITY_LEFT + PLAYER_RADIUS, CITY_W - CITY_RIGHT - PLAYER_RADIUS)
    y = clampf(y, CITY_TOP + PLAYER_RADIUS, CITY_H - CITY_BOTTOM - PLAYER_RADIUS)
    return Vector2(x, y)

func _sync_world_visuals() -> void:
    if size.x < 2.0 or size.y < 2.0:
        return

    if city_world:
        city_world.scale = MAP_SCALE
        city_world.position = Vector2(
            size.x * 0.5 - world_pos_px.x * MAP_SCALE.x,
            size.y * 0.5 - world_pos_px.y * MAP_SCALE.y
        )

    _update_building_depth()

    if viewport_3d:
        var desired_size := _viewport_size_i()
        if viewport_3d.size != desired_size:
            viewport_3d.size = desired_size

    if camera_3d:
        camera_3d.size = size.y / PX_PER_3D_UNIT

    if player_3d and camera_3d:
        var player_screen := size * 0.5
        var ground := _screen_to_ground(player_screen)
        player_3d.position = ground

        var ahead_screen := player_screen + facing_input * 64.0
        var ahead_ground := _screen_to_ground(ahead_screen)
        var ground_dir := ahead_ground - ground
        ground_dir.y = 0.0
        if ground_dir.length_squared() > 0.0001 and player_visual:
            var target_yaw: float = atan2(ground_dir.x, ground_dir.z)
            player_visual.rotation.y = lerp_angle(player_visual.rotation.y, target_yaw, 0.24)

func _update_building_depth() -> void:
    for rec in building_nodes:
        var data: Dictionary = rec.get("data", {})
        var node: TextureRect = rec.get("node")
        if node == null:
            continue

        var bx: float = float(data.get("x", 0.0))
        var by: float = float(data.get("y", 0.0))
        var dx: float = absf(world_pos_px.x - bx)
        var dy: float = world_pos_px.y - by
        var should_front: bool = dx < 125.0 and dy < 20.0 and dy > -185.0

        node.z_index = 3 if should_front else 1
        node.modulate.a = 0.66 if should_front and dx < 95.0 and dy > -145.0 else 1.0

func _screen_to_ground(screen_position: Vector2) -> Vector3:
    if camera_3d == null:
        return Vector3.ZERO

    var origin: Vector3 = camera_3d.project_ray_origin(screen_position)
    var direction: Vector3 = camera_3d.project_ray_normal(screen_position)
    if absf(direction.y) < 0.00001:
        return Vector3.ZERO

    var distance: float = -origin.y / direction.y
    return origin + direction * distance

func _viewport_size_i() -> Vector2i:
    return Vector2i(maxi(2, int(round(size.x))), maxi(2, int(round(size.y))))

func _find_model_animations(root: Node) -> void:
    var players := root.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty():
        return

    _animation_player = players[0] as AnimationPlayer
    if _animation_player == null:
        return

    for animation_name in _animation_player.get_animation_list():
        var lower := str(animation_name).to_lower()
        if _idle_animation.is_empty() and ("idle" in lower or "stand" in lower or "breath" in lower):
            _idle_animation = str(animation_name)
        if _run_animation.is_empty() and ("run" in lower or "jog" in lower or "walk" in lower):
            _run_animation = str(animation_name)

    if _idle_animation.is_empty() and not _animation_player.get_animation_list().is_empty():
        _idle_animation = str(_animation_player.get_animation_list()[0])

    _set_animation("idle")

func _set_animation(state: String) -> void:
    if _animation_player == null or _anim_state == state:
        return

    var animation_name := _run_animation if state == "run" else _idle_animation
    if animation_name.is_empty():
        return

    _anim_state = state
    _animation_player.play(animation_name, 0.10)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat

func _exit_game() -> void:
    get_tree().quit()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_sync_world_visuals")
    elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _joy_touch_id = -1
        _joy_mouse_active = false
        _joy_end()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        get_tree().quit()
