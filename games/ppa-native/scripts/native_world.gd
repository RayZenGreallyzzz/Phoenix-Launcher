extends Control

# The deployed Phoenix Pix Arena Peace City: exact PPA map, world size, spawn,
# Plaza polygon and source collision rectangles. 2D world, ONLY player in 3D.
# Source: live v668 PPA BG_SAFE /assets/c73ef6814017bda6.png (PNG 1254x1254).
const CITY_ART := 1254.0
const CITY_W := 2822.0
const CITY_H := 2822.0
const SCN_SCALE := CITY_W / CITY_ART
const CITY_ENTRY := Vector2(1395.0, 1463.0) # round(620,650) * SCN_SCALE
const MAP_SCALE := Vector2.ONE
const PLAYER_RADIUS := 13.0
const MOVE_SPEED_PX := 165.0
const PX_PER_3D_UNIT := 34.0

const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")
const DWARF_FIT = preload("res://scripts/dwarf_model_fit.gd")
const PLAZA_POINTS := [
    Vector2(191.0, 293.0),
    Vector2(977.0, 293.0),
    Vector2(983.0, 331.0),
    Vector2(983.0, 608.0),
    Vector2(977.0, 713.0),
    Vector2(977.0, 923.0),
    Vector2(959.0, 947.0),
    Vector2(887.0, 951.0),
    Vector2(792.0, 951.0),
    Vector2(742.0, 943.0),
    Vector2(697.0, 943.0),
    Vector2(657.0, 941.0),
    Vector2(612.0, 941.0),
    Vector2(567.0, 941.0),
    Vector2(522.0, 943.0),
    Vector2(472.0, 948.0),
    Vector2(397.0, 951.0),
    Vector2(317.0, 951.0),
    Vector2(268.0, 950.0),
    Vector2(259.0, 918.0),
    Vector2(254.0, 879.0),
    Vector2(243.0, 838.0),
    Vector2(231.0, 798.0),
    Vector2(221.0, 748.0),
    Vector2(210.0, 693.0),
    Vector2(202.0, 638.0),
    Vector2(195.0, 583.0),
    Vector2(191.0, 518.0),
    Vector2(188.0, 448.0),
    Vector2(188.0, 378.0),
    Vector2(189.0, 328.0)
]
# Rectangles are stored in the original 1254px image coordinate system,
# exactly as in the live web PPA source (the polygon already excludes roofs).
const BUILDING_RECTS := [
    Rect2(10.0, 8.0, 222.0, 255.0),
    Rect2(268.0, 12.0, 238.0, 250.0),
    Rect2(528.0, 12.0, 228.0, 225.0),
    Rect2(800.0, 12.0, 224.0, 205.0)
]

var profile: Dictionary = {}
var world_pos_px := CITY_ENTRY
var move_input := Vector2.ZERO
var facing_input := Vector2(0.0, 1.0)

var city_world: Control
var _plaza_poly: PackedVector2Array = PackedVector2Array()

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

    _plaza_poly = PackedVector2Array(PLAZA_POINTS)
    _build_city_2d()
    _build_3d_overlay()
    _build_hud()
    world_pos_px = CITY_ENTRY
    _sync_world_visuals()

func _build_city_2d() -> void:
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("#191514")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.z_index = -10
    add_child(background)

    city_world = Control.new()
    city_world.name = "PPAPeaceCity2D"
    city_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.clip_contents = false
    add_child(city_world)

    # One intact original map, no city reassembly or duplicated building sprites.
    var map_texture := TextureRect.new()
    map_texture.name = "CurrentPPACityMap"
    map_texture.texture = load("res://assets/peace_city.png")
    map_texture.size = Vector2(CITY_W, CITY_H)
    map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    map_texture.stretch_mode = TextureRect.STRETCH_SCALE
    map_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.add_child(map_texture)

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

    # The live PPA dwarf has a skinned body, a cannon and Idle/Run/Attack.
    # Keep the capsule fallback strictly for broken/missing resources in dev.
    if ResourceLoader.exists("res://assets/Dwarf.glb"):
        var model_resource = load("res://assets/Dwarf.glb")
        if model_resource is PackedScene:
            var model := (model_resource as PackedScene).instantiate() as Node3D
            if model != null:
                player_visual.add_child(model)
                if DWARF_FIT.fit(model, 3.20):
                    _find_model_animations(model)
                else:
                    model.queue_free()
                    _build_fallback_player()
                print("[PPA-NATIVE] Loaded live Dwarf.glb with idle=", _idle_animation, " run=", _run_animation)
            else:
                push_warning("[PPA-NATIVE] Dwarf.glb root is not Node3D")
                _build_fallback_player()
        else:
            push_warning("[PPA-NATIVE] Dwarf.glb is not a PackedScene")
            _build_fallback_player()
    else:
        push_warning("[PPA-NATIVE] Dwarf.glb missing from build")
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
    class_label.text = "МИРНЫЙ ГОРОД · %s" % (class_key if not class_key.is_empty() else "PLAYER3D")
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
            coords_label.text = "PPA X %.0f   Y %.0f" % [world_pos_px.x, world_pos_px.y]

func _plaza_circle_walk(point: Vector2) -> bool:
    # Exact circle probe geometry from the live PPA plazaCircleWalk().
    var art_point: Vector2 = point / SCN_SCALE
    var d: float = (PLAYER_RADIUS / SCN_SCALE) * 0.82
    var diag: float = d * 0.7
    return Geometry2D.is_point_in_polygon(art_point, _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(d, 0.0), _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(-d, 0.0), _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(0.0, d), _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(0.0, -d), _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(diag, diag), _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(-diag, diag), _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(diag, -diag), _plaza_poly) \
        and Geometry2D.is_point_in_polygon(art_point + Vector2(-diag, -diag), _plaza_poly)

func _resolve_city_collision(target: Vector2) -> Vector2:
    var margin := 40.0 * SCN_SCALE
    var nx: float = clampf(target.x, margin, CITY_W - margin)
    var ny: float = clampf(target.y, margin, CITY_H - margin)
    var resolved := Vector2(nx, ny)

    # Same X/Y sliding order as the live PPA: stay on paved plaza area.
    if not _plaza_circle_walk(resolved):
        if _plaza_circle_walk(Vector2(nx, world_pos_px.y)):
            resolved = Vector2(nx, world_pos_px.y)
        elif _plaza_circle_walk(Vector2(world_pos_px.x, ny)):
            resolved = Vector2(world_pos_px.x, ny)
        else:
            resolved = world_pos_px

    # Keep the web game's solid four roof/building rectangles.
    for rect in BUILDING_RECTS:
        var left: float = roundf(rect.position.x * SCN_SCALE) - PLAYER_RADIUS
        var top: float = roundf(rect.position.y * SCN_SCALE) - PLAYER_RADIUS
        var right: float = roundf((rect.position.x + rect.size.x) * SCN_SCALE) + PLAYER_RADIUS
        var bottom: float = roundf((rect.position.y + rect.size.y) * SCN_SCALE) + PLAYER_RADIUS

        if resolved.x > left and resolved.x < right and resolved.y > top and resolved.y < bottom:
            var dl: float = resolved.x - left
            var dr: float = right - resolved.x
            var dt: float = resolved.y - top
            var db: float = bottom - resolved.y
            var nearest: float = minf(minf(dl, dr), minf(dt, db))
            if is_equal_approx(nearest, dl):
                resolved.x = left
            elif is_equal_approx(nearest, dr):
                resolved.x = right
            elif is_equal_approx(nearest, dt):
                resolved.y = top
            else:
                resolved.y = bottom

    return resolved

func _sync_world_visuals() -> void:
    if size.x < 2.0 or size.y < 2.0:
        return

    if city_world:
        city_world.scale = MAP_SCALE
        # Match the web camera: clamp to the town edges, rather than exposing
        # an empty border. The 3D player is placed at the actual 2D screen pos.
        var offset_x := size.x * 0.5 - world_pos_px.x
        var offset_y := size.y * 0.5 - world_pos_px.y
        city_world.position = Vector2(
            clampf(offset_x, size.x - CITY_W, 0.0) if CITY_W > size.x else (size.x - CITY_W) * 0.5,
            clampf(offset_y, size.y - CITY_H, 0.0) if CITY_H > size.y else (size.y - CITY_H) * 0.5
        )

    if viewport_3d:
        var desired_size := _viewport_size_i()
        if viewport_3d.size != desired_size:
            viewport_3d.size = desired_size

    if camera_3d:
        camera_3d.size = size.y / PX_PER_3D_UNIT

    if player_3d and camera_3d:
        var player_screen: Vector2 = size * 0.5
        if city_world:
            player_screen = world_pos_px * MAP_SCALE + city_world.position
        var ground := _screen_to_ground(player_screen)
        player_3d.position = ground

        var ahead_screen := player_screen + facing_input * 64.0
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

# Scale exclusively from skeletal rest pose, never from unposed skinned mesh
# bounds or the cannon's distant export translation.
func _fit_gnome_model(model: Node3D) -> void:
    if not DWARF_FIT.fit(model, 3.20):
        push_error("[PPA-DWARF] Unable to calibrate body scale from skeleton")

func _find_model_animations(root: Node) -> void:
    var players := root.find_children("*", "AnimationPlayer", true, false)
    _animation_player = null
    _idle_animation = ""
    _run_animation = ""
    _anim_state = ""

    for candidate in players:
        var player := candidate as AnimationPlayer
        if player == null or player.get_animation_list().is_empty():
            continue
        _animation_player = player
        for animation_name in player.get_animation_list():
            var lower := str(animation_name).to_lower()
            if _idle_animation.is_empty() and ("idle" in lower or "stand" in lower or "breath" in lower):
                _idle_animation = str(animation_name)
            if _run_animation.is_empty() and ("run" in lower or "jog" in lower or "walk" in lower):
                _run_animation = str(animation_name)
        if not _idle_animation.is_empty() and not _run_animation.is_empty():
            break

    if _animation_player == null:
        push_warning("[PPA-NATIVE] Dwarf has no AnimationPlayer")
        return

    if _idle_animation.is_empty() or _run_animation.is_empty():
        push_warning("[PPA-NATIVE] Missing Idle or Run imported clips")
        return

    # Godot GLB importer may not mark named clips as looping by default.
    for anim_name in [_idle_animation, _run_animation]:
        var clip := _animation_player.get_animation(anim_name)
        if clip != null:
            clip.loop_mode = Animation.LOOP_LINEAR

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
