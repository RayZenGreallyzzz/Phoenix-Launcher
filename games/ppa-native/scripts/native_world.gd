extends Control

# Current PPA Peace City port.
# The map and gameplay coordinates remain 2D pixels; only player visuals render in 3D.
const TOWN_PX := 3048.0
const SOURCE_ART_PX := 1024.0
const SCN_SCALE := TOWN_PX / SOURCE_ART_PX
const PPA_MOVE_SPEED_PX := 180.0
const PLAYER_COLLISION_RADIUS_PX := 18.0
const PX_PER_3D_UNIT := 34.0

const START_POS_PX := Vector2(500.0 * SCN_SCALE, 620.0 * SCN_SCALE)
const RETURN_POS_PX := Vector2(640.0 * SCN_SCALE, 600.0 * SCN_SCALE)
const DUNGEON_PORTAL_PX := Vector2(TOWN_PX * 0.5, TOWN_PX - 20.0 * 32.0)
const DUNGEON_PORTAL_RADIUS_PX := 90.0

const SAFE_MIN_PX := 40.0 * SCN_SCALE
const SAFE_MAX_PX := TOWN_PX - SAFE_MIN_PX

const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")

var profile: Dictionary = {}
var world_pos_px := START_POS_PX
var move_input := Vector2.ZERO
var camera_top_left_px := Vector2.ZERO

var map_texture_rect: TextureRect
var viewport_3d: SubViewport
var viewport_3d_rect: TextureRect
var camera_3d: Camera3D
var player_3d: Node3D
var player_visual: Node3D
var joystick_visual: Control

var fps_label: Label
var coords_label: Label
var input_label: Label
var portal_label: Label

var _joy_touch_id := -1
var _joy_mouse_active := false
var _joy_center := Vector2.ZERO
var _fps_clock := 0.0

var _animation_player: AnimationPlayer
var _run_animation := ""
var _idle_animation := ""
var _anim_state := ""

var _buildings: Array[Rect2] = []

func _ready() -> void:
    profile = get_tree().get_meta("phoenix_account", {})
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)

    _build_collision_geometry()
    _build_map_layer()
    _build_3d_overlay()
    _build_hud()

    world_pos_px = START_POS_PX
    _sync_world_visuals()

func _build_collision_geometry() -> void:
    # Exact current PPA safe-zone collision boxes, authored on 1024 art and
    # scaled to the 3048x3048 Peace City world.
    _buildings = [
        Rect2(Vector2(10.0, 8.0) * SCN_SCALE, Vector2(222.0, 255.0) * SCN_SCALE),
        Rect2(Vector2(268.0, 12.0) * SCN_SCALE, Vector2(238.0, 250.0) * SCN_SCALE),
        Rect2(Vector2(528.0, 12.0) * SCN_SCALE, Vector2(228.0, 225.0) * SCN_SCALE),
        Rect2(Vector2(800.0, 12.0) * SCN_SCALE, Vector2(224.0, 205.0) * SCN_SCALE)
    ]

func _build_map_layer() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#15110D")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    map_texture_rect = TextureRect.new()
    map_texture_rect.name = "PeaceCityMap"
    map_texture_rect.position = Vector2.ZERO
    map_texture_rect.size = Vector2(TOWN_PX, TOWN_PX)
    map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    map_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
    map_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

    if ResourceLoader.exists("res://assets/peace_city.png"):
        map_texture_rect.texture = load("res://assets/peace_city.png")

    add_child(map_texture_rect)

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
    camera_3d.name = "PPAPlayerCamera"
    camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera_3d.near = 0.01
    camera_3d.far = 100.0
    camera_3d.position = Vector3(5.0, 7.4, 9.0)
    camera_3d.current = true
    viewport_3d.add_child(camera_3d)
    camera_3d.look_at(Vector3(0.0, 0.72, 0.0), Vector3.UP)

    player_3d = Node3D.new()
    player_3d.name = "Player3DAnchor"
    viewport_3d.add_child(player_3d)

    player_visual = Node3D.new()
    player_visual.name = "Player3DVisual"
    player_3d.add_child(player_visual)

    if ResourceLoader.exists("res://assets/Dwarf.glb"):
        var model_resource = load("res://assets/Dwarf.glb")
        if model_resource is PackedScene:
            var model := (model_resource as PackedScene).instantiate()
            model.name = "ApprovedDwarf"
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
    viewport_3d_rect.name = "Player3DOverlay"
    viewport_3d_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_3d_rect.texture = viewport_3d.get_texture()
    viewport_3d_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    viewport_3d_rect.stretch_mode = TextureRect.STRETCH_SCALE
    viewport_3d_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    add_child(name_label)

    var class_label := Label.new()
    class_label.text = "МИРНЫЙ ГОРОД · %s" % (class_key if not class_key.is_empty() else "PLAYER3D")
    class_label.position = Vector2(30.0, 51.0)
    class_label.add_theme_font_size_override("font_size", 12)
    class_label.add_theme_color_override("font_color", Color("#FE6D1C"))
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
    add_child(coords_label)

    portal_label = Label.new()
    portal_label.anchor_left = 0.5
    portal_label.anchor_right = 0.5
    portal_label.offset_left = -210.0
    portal_label.offset_right = 210.0
    portal_label.offset_top = 22.0
    portal_label.offset_bottom = 50.0
    portal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    portal_label.add_theme_font_size_override("font_size", 13)
    portal_label.add_theme_color_override("font_color", Color("#FEA25F"))
    portal_label.visible = false
    add_child(portal_label)

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
    add_child(input_label)

    joystick_visual = JOYSTICK_SCRIPT.new()
    joystick_visual.name = "SmartFloatingJoystickVisual"
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
    var viewport_size := size
    return viewport_size.x > 1.0 and point.x <= viewport_size.x * 0.5

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
        var target := world_pos_px + input_vec * PPA_MOVE_SPEED_PX * delta
        world_pos_px = _resolve_safe_collision(target)
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
            coords_label.text = "PPA X %.0f   Y %.0f" % [world_pos_px.x, world_pos_px.y]

    if portal_label:
        var portal_distance: float = world_pos_px.distance_to(DUNGEON_PORTAL_PX)
        portal_label.visible = portal_distance <= DUNGEON_PORTAL_RADIUS_PX + 40.0
        if portal_label.visible:
            portal_label.text = "ПОРТАЛ В ПОДЗЕМЕЛЬЕ · координаты PPA совпали"

func _resolve_safe_collision(target: Vector2) -> Vector2:
    var x: float = clampf(target.x, SAFE_MIN_PX, SAFE_MAX_PX)
    var y: float = clampf(target.y, SAFE_MIN_PX, SAFE_MAX_PX)

    for building in _buildings:
        var cx0: float = building.position.x - PLAYER_COLLISION_RADIUS_PX
        var cy0: float = building.position.y - PLAYER_COLLISION_RADIUS_PX
        var cx1: float = building.end.x + PLAYER_COLLISION_RADIUS_PX
        var cy1: float = building.end.y + PLAYER_COLLISION_RADIUS_PX

        if x > cx0 and x < cx1 and y > cy0 and y < cy1:
            var left: float = x - cx0
            var right: float = cx1 - x
            var top: float = y - cy0
            var bottom: float = cy1 - y
            var shortest: float = minf(minf(left, right), minf(top, bottom))

            if is_equal_approx(shortest, left):
                x = cx0
            elif is_equal_approx(shortest, right):
                x = cx1
            elif is_equal_approx(shortest, top):
                y = cy0
            else:
                y = cy1

    return Vector2(x, y)

func _sync_world_visuals() -> void:
    var viewport_size := size
    if viewport_size.x < 2.0 or viewport_size.y < 2.0:
        return

    var max_cam_x: float = maxf(0.0, TOWN_PX - viewport_size.x)
    var max_cam_y: float = maxf(0.0, TOWN_PX - viewport_size.y)

    camera_top_left_px.x = clampf(world_pos_px.x - viewport_size.x * 0.5, 0.0, max_cam_x)
    camera_top_left_px.y = clampf(world_pos_px.y - viewport_size.y * 0.5, 0.0, max_cam_y)

    if map_texture_rect:
        map_texture_rect.position = -camera_top_left_px

    if viewport_3d:
        var desired_size := _viewport_size_i()
        if viewport_3d.size != desired_size:
            viewport_3d.size = desired_size

    if camera_3d:
        camera_3d.size = viewport_size.y / PX_PER_3D_UNIT

    var player_screen := world_pos_px - camera_top_left_px
    if player_3d and camera_3d:
        var ground := _screen_to_ground(player_screen)
        player_3d.position = ground

        if move_input.length_squared() > 0.0001:
            var ahead_screen := player_screen + move_input.normalized() * 64.0
            var ahead_ground := _screen_to_ground(ahead_screen)
            var ground_dir := ahead_ground - ground
            ground_dir.y = 0.0
            if ground_dir.length_squared() > 0.0001 and player_visual:
                var target_yaw: float = atan2(ground_dir.x, ground_dir.z)
                player_visual.rotation.y = lerp_angle(player_visual.rotation.y, target_yaw, 0.24)

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
