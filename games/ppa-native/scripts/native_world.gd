extends Node3D

# PPA native 2.5D baseline:
# map/gameplay stay on a flat 2D plane; only the player is a real 3D model.
const MOVE_SPEED := 6.8
const ACCELERATION := 30.0
const WORLD_HALF_SIZE := 36.0
const CAMERA_OFFSET := Vector3(5.0, 7.4, 9.0)
const CAMERA_SIZE := 21.18
const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")

var profile: Dictionary = {}
var player: Node3D
var player_visual: Node3D
var camera: Camera3D
var move_input := Vector2.ZERO
var planar_velocity := Vector2.ZERO
var fps_label: Label
var coords_label: Label
var input_label: Label
var _fps_clock := 0.0
var _animation_player: AnimationPlayer
var _run_animation := ""
var _idle_animation := ""
var _anim_state := ""

func _ready() -> void:
    profile = get_tree().get_meta("phoenix_account", {})
    _build_environment()
    _build_flat_map_layer()
    _build_player()
    _build_camera()
    _build_hud()

func _physics_process(delta: float) -> void:
    if player == null:
        return

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

    var desired_planar := input_vec * MOVE_SPEED
    planar_velocity.x = move_toward(planar_velocity.x, desired_planar.x, ACCELERATION * delta)
    planar_velocity.y = move_toward(planar_velocity.y, desired_planar.y, ACCELERATION * delta)

    # Joystick coordinates are PPA map coordinates: +X right, +Y down.
    # Project them onto the tilted 3D ground so movement still follows the finger.
    var forward := Vector3(-CAMERA_OFFSET.x, 0.0, -CAMERA_OFFSET.z).normalized()
    var right := Vector3(forward.z, 0.0, -forward.x).normalized()
    var ground_velocity := right * planar_velocity.x + forward * (-planar_velocity.y)

    player.position += ground_velocity * delta
    player.position.x = clamp(player.position.x, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)
    player.position.z = clamp(player.position.z, -WORLD_HALF_SIZE, WORLD_HALF_SIZE)

    if ground_velocity.length_squared() > 0.01:
        var target_yaw := atan2(ground_velocity.x, ground_velocity.z)
        player_visual.rotation.y = lerp_angle(player_visual.rotation.y, target_yaw, min(1.0, delta * 14.0))
        _set_animation("run")
    elif planar_velocity.length() < 0.12:
        _set_animation("idle")

func _process(delta: float) -> void:
    if player != null and camera != null:
        var desired_camera := player.global_position + CAMERA_OFFSET
        camera.global_position = camera.global_position.lerp(desired_camera, min(1.0, delta * 10.0))
        camera.look_at(player.global_position + Vector3(0.0, 0.72, 0.0), Vector3.UP)

    _fps_clock += delta
    if _fps_clock >= 0.25:
        _fps_clock = 0.0
        if fps_label:
            fps_label.text = "%d FPS" % Engine.get_frames_per_second()
        if coords_label and player:
            coords_label.text = "native X %.2f   Y %.2f" % [player.global_position.x, player.global_position.z]

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#111820")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#FFF7EA")
    env.ambient_light_energy = 1.15
    world_env.environment = env
    add_child(world_env)

    # No dynamic shadows in the 2.5D baseline.
    var sun := DirectionalLight3D.new()
    sun.light_color = Color("#FFF0CF")
    sun.light_energy = 2.1
    sun.rotation_degrees = Vector3(-46.0, -30.0, 0.0)
    sun.shadow_enabled = false
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.light_color = Color("#9EC8FF")
    fill.light_energy = 0.55
    fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
    fill.shadow_enabled = false
    add_child(fill)

func _build_flat_map_layer() -> void:
    # One flat unlit layer stands in for the existing PPA 2D map.
    # The next port step replaces this material with the real city texture + walk mask.
    var plane_mesh := PlaneMesh.new()
    plane_mesh.size = Vector2(WORLD_HALF_SIZE * 2.0 + 8.0, WORLD_HALF_SIZE * 2.0 + 8.0)
    var plane := MeshInstance3D.new()
    plane.name = "PPA2DMapLayer"
    plane.mesh = plane_mesh
    plane.material_override = _unshaded_material(Color("#26342F"))
    add_child(plane)

    # Flat 2D-style road markers: zero-height quads, not 3D buildings.
    _add_flat_rect(Vector2(8.0, 70.0), Vector3(0.0, 0.012, 0.0), Color("#3B4146"))
    _add_flat_rect(Vector2(70.0, 8.0), Vector3(0.0, 0.014, 0.0), Color("#3B4146"))
    _add_flat_rect(Vector2(14.0, 14.0), Vector3(0.0, 0.016, 0.0), Color("#4A5055"))

    # A few flat reference tiles make joystick/camera motion obvious without
    # reintroducing the heavy 3D test city.
    for x in [-24.0, -12.0, 12.0, 24.0]:
        _add_flat_rect(Vector2(6.0, 6.0), Vector3(x, 0.018, -18.0), Color("#31433B"))
        _add_flat_rect(Vector2(6.0, 6.0), Vector3(x, 0.018, 18.0), Color("#31433B"))

func _build_player() -> void:
    player = Node3D.new()
    player.name = "Player3DAnchor"
    player.position = Vector3(0.0, 0.0, 8.0)
    add_child(player)

    player_visual = Node3D.new()
    player_visual.name = "Player3DVisual"
    player.add_child(player_visual)

    if ResourceLoader.exists("res://assets/Dwarf.glb"):
        var model_resource := load("res://assets/Dwarf.glb")
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

    # Lightweight fake shadow: one unlit transparent disc, no shadow map.
    var shadow_mesh := CylinderMesh.new()
    shadow_mesh.top_radius = 0.58
    shadow_mesh.bottom_radius = 0.58
    shadow_mesh.height = 0.01
    var shadow := MeshInstance3D.new()
    shadow.mesh = shadow_mesh
    shadow.position = Vector3(0.0, 0.012, 0.0)
    var shadow_mat := _unshaded_material(Color(0.0, 0.0, 0.0, 0.28))
    shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow.material_override = shadow_mat
    player.add_child(shadow)

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
    head.material_override = _material(Color("#D9B28B"), 0.7)
    player_visual.add_child(head)

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

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.name = "PPAOrthographicCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = CAMERA_SIZE
    camera.near = 0.01
    camera.far = 100.0
    camera.position = player.position + CAMERA_OFFSET
    camera.current = true
    add_child(camera)
    camera.look_at(player.global_position + Vector3(0.0, 0.72, 0.0), Vector3.UP)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)

    var nickname := str(profile.get("ppaNickname", profile.get("nickname", "Phoenix")))
    var class_key := str(profile.get("classKey", ""))

    var name_label := Label.new()
    name_label.text = nickname
    name_label.position = Vector2(28, 22)
    name_label.add_theme_font_size_override("font_size", 22)
    name_label.add_theme_color_override("font_color", Color("#F2F4F6"))
    root.add_child(name_label)

    var class_label := Label.new()
    class_label.text = "PPA 2.5D NATIVE · %s" % (class_key if not class_key.is_empty() else "PLAYER3D")
    class_label.position = Vector2(30, 51)
    class_label.add_theme_font_size_override("font_size", 12)
    class_label.add_theme_color_override("font_color", Color("#FE6D1C"))
    root.add_child(class_label)

    fps_label = Label.new()
    fps_label.text = "0 FPS"
    fps_label.anchor_left = 1.0
    fps_label.anchor_right = 1.0
    fps_label.offset_left = -145.0
    fps_label.offset_right = -28.0
    fps_label.offset_top = 22.0
    fps_label.offset_bottom = 50.0
    fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    fps_label.add_theme_font_size_override("font_size", 17)
    fps_label.add_theme_color_override("font_color", Color("#53CDAB"))
    root.add_child(fps_label)

    coords_label = Label.new()
    coords_label.anchor_left = 1.0
    coords_label.anchor_right = 1.0
    coords_label.offset_left = -220.0
    coords_label.offset_right = -28.0
    coords_label.offset_top = 52.0
    coords_label.offset_bottom = 78.0
    coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    coords_label.add_theme_font_size_override("font_size", 12)
    coords_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
    root.add_child(coords_label)

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
    input_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
    root.add_child(input_label)

    var joystick: Control = JOYSTICK_SCRIPT.new()
    joystick.name = "SmartFloatingJoystick"
    joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    joystick.vector_changed.connect(_on_joystick_changed)
    joystick.active_changed.connect(_on_joystick_active_changed)
    root.add_child(joystick)

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
    root.add_child(exit_button)

func _on_joystick_changed(value: Vector2) -> void:
    move_input = value

func _on_joystick_active_changed(active: bool) -> void:
    if input_label:
        input_label.visible = not active

func _exit_game() -> void:
    get_tree().quit()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        get_tree().quit()

func _add_flat_rect(size: Vector2, position: Vector3, color: Color) -> void:
    var mesh := PlaneMesh.new()
    mesh.size = size
    var item := MeshInstance3D.new()
    item.mesh = mesh
    item.position = position
    item.material_override = _unshaded_material(color)
    add_child(item)

func _unshaded_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.roughness = 1.0
    return mat

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat
