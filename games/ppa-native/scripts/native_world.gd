extends Node3D

const MOVE_SPEED := 6.8
const ACCELERATION := 28.0
const GRAVITY := 24.0
const CAMERA_OFFSET := Vector3(0.0, 10.8, 10.8)
const WORLD_HALF_SIZE := 28.0
const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")

var profile: Dictionary = {}
var player: CharacterBody3D
var player_visual: Node3D
var camera: Camera3D
var move_input := Vector2.ZERO
var fps_label: Label
var coords_label: Label
var _fps_clock := 0.0

func _ready() -> void:
    profile = get_tree().get_meta("phoenix_account", {})
    _build_environment()
    _build_city()
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

    var desired := Vector3(input_vec.x, 0.0, input_vec.y) * MOVE_SPEED
    player.velocity.x = move_toward(player.velocity.x, desired.x, ACCELERATION * delta)
    player.velocity.z = move_toward(player.velocity.z, desired.z, ACCELERATION * delta)

    if player.is_on_floor():
        player.velocity.y = -0.5
    else:
        player.velocity.y -= GRAVITY * delta

    if desired.length_squared() > 0.03:
        var target_angle := atan2(desired.x, desired.z)
        player_visual.rotation.y = lerp_angle(player_visual.rotation.y, target_angle, min(1.0, delta * 12.0))

    player.move_and_slide()

    player.global_position.x = clamp(player.global_position.x, -WORLD_HALF_SIZE + 1.2, WORLD_HALF_SIZE - 1.2)
    player.global_position.z = clamp(player.global_position.z, -WORLD_HALF_SIZE + 1.2, WORLD_HALF_SIZE - 1.2)

func _process(delta: float) -> void:
    if player != null and camera != null:
        var desired_camera := player.global_position + CAMERA_OFFSET
        camera.global_position = camera.global_position.lerp(desired_camera, min(1.0, delta * 7.0))
        camera.look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

    _fps_clock += delta
    if _fps_clock >= 0.25:
        _fps_clock = 0.0
        if fps_label:
            fps_label.text = "%d FPS" % Engine.get_frames_per_second()
        if coords_label and player:
            coords_label.text = "X %.1f   Z %.1f" % [player.global_position.x, player.global_position.z]

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#10151B")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#B7C5D6")
    env.ambient_light_energy = 0.58
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.light_color = Color("#FFE0B5")
    sun.light_energy = 1.35
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 48.0
    add_child(sun)

func _build_city() -> void:
    _add_box_static("Ground", Vector3(58.0, 0.25, 58.0), Vector3(0.0, -0.14, 0.0), Color("#25302C"))

    _add_visual_box(Vector3(7.0, 0.035, 54.0), Vector3(0.0, 0.02, 0.0), Color("#363B40"))
    _add_visual_box(Vector3(54.0, 0.035, 7.0), Vector3(0.0, 0.024, 0.0), Color("#363B40"))
    _add_visual_box(Vector3(13.5, 0.04, 13.5), Vector3(0.0, 0.03, 0.0), Color("#41474D"))

    _add_building(Vector3(-19.5, 2.3, -19.5), Vector3(8.0, 4.6, 7.0), Color("#4E4037"))
    _add_building(Vector3(-9.2, 1.8, -20.5), Vector3(7.0, 3.6, 5.0), Color("#3C4652"))
    _add_building(Vector3(10.0, 2.2, -20.0), Vector3(8.0, 4.4, 6.0), Color("#514238"))
    _add_building(Vector3(20.0, 2.8, -18.8), Vector3(6.0, 5.6, 8.0), Color("#384552"))

    _add_building(Vector3(-20.0, 2.5, 18.6), Vector3(6.5, 5.0, 8.0), Color("#384552"))
    _add_building(Vector3(-9.0, 1.9, 20.5), Vector3(8.0, 3.8, 5.0), Color("#514238"))
    _add_building(Vector3(10.0, 2.4, 20.0), Vector3(8.5, 4.8, 6.5), Color("#3C4652"))
    _add_building(Vector3(20.5, 2.0, 19.5), Vector3(6.0, 4.0, 7.0), Color("#4E4037"))

    _add_building(Vector3(-20.5, 2.0, -7.5), Vector3(6.0, 4.0, 6.0), Color("#414B55"))
    _add_building(Vector3(-20.5, 2.7, 7.5), Vector3(6.0, 5.4, 6.0), Color("#55463B"))
    _add_building(Vector3(20.5, 2.1, -7.5), Vector3(6.0, 4.2, 6.0), Color("#55463B"))
    _add_building(Vector3(20.5, 2.5, 7.5), Vector3(6.0, 5.0, 6.0), Color("#414B55"))

    _add_fountain(Vector3(0.0, 0.25, 0.0))

    for x in [-14.0, 14.0]:
        for z in [-14.0, 14.0]:
            _add_lamp(Vector3(x, 0.0, z))

    _add_boundary(Vector3(0.0, 1.5, -29.2), Vector3(60.0, 3.0, 0.6))
    _add_boundary(Vector3(0.0, 1.5, 29.2), Vector3(60.0, 3.0, 0.6))
    _add_boundary(Vector3(-29.2, 1.5, 0.0), Vector3(0.6, 3.0, 60.0))
    _add_boundary(Vector3(29.2, 1.5, 0.0), Vector3(0.6, 3.0, 60.0))

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player3D"
    player.position = Vector3(0.0, 1.05, 8.0)
    player.floor_snap_length = 0.35
    player.floor_max_angle = deg_to_rad(48.0)
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule_shape := CapsuleShape3D.new()
    capsule_shape.radius = 0.42
    capsule_shape.height = 1.65
    collision.shape = capsule_shape
    player.add_child(collision)

    player_visual = Node3D.new()
    player_visual.name = "Visual"
    player.add_child(player_visual)

    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.42
    body_mesh.height = 1.35
    var body := MeshInstance3D.new()
    body.mesh = body_mesh
    body.material_override = _material(Color("#D85E1C"), 0.55)
    player_visual.add_child(body)

    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.32
    head_mesh.height = 0.64
    var head := MeshInstance3D.new()
    head.mesh = head_mesh
    head.position = Vector3(0.0, 0.95, 0.0)
    head.material_override = _material(Color("#D9B28B"), 0.7)
    player_visual.add_child(head)

    var class_key := str(profile.get("classKey", "")).to_lower()
    if "gnome" in class_key or "dwarf" in class_key or "cannon" in class_key:
        player_visual.scale = Vector3(1.06, 0.84, 1.06)
        var cannon_mesh := BoxMesh.new()
        cannon_mesh.size = Vector3(0.26, 0.26, 0.9)
        var cannon := MeshInstance3D.new()
        cannon.mesh = cannon_mesh
        cannon.position = Vector3(-0.48, 0.16, -0.2)
        cannon.rotation_degrees = Vector3(0.0, 0.0, -12.0)
        cannon.material_override = _material(Color("#2F343B"), 0.35)
        player_visual.add_child(cannon)

    var shadow_mesh := CylinderMesh.new()
    shadow_mesh.top_radius = 0.62
    shadow_mesh.bottom_radius = 0.62
    shadow_mesh.height = 0.012
    var shadow := MeshInstance3D.new()
    shadow.mesh = shadow_mesh
    shadow.position = Vector3(0.0, -0.82, 0.0)
    var shadow_mat := _material(Color(0.0, 0.0, 0.0, 0.35), 1.0)
    shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow.material_override = shadow_mat
    player_visual.add_child(shadow)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.name = "FollowCamera"
    camera.fov = 54.0
    camera.position = player.position + CAMERA_OFFSET
    camera.current = true
    add_child(camera)
    camera.look_at(player.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)

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
    name_label.position = Vector2(28, 24)
    name_label.add_theme_font_size_override("font_size", 24)
    name_label.add_theme_color_override("font_color", Color("#F2F4F6"))
    root.add_child(name_label)

    var class_label := Label.new()
    class_label.text = "PPA NATIVE CITY · %s" % (class_key if not class_key.is_empty() else "PLAYER3D")
    class_label.position = Vector2(30, 56)
    class_label.add_theme_font_size_override("font_size", 13)
    class_label.add_theme_color_override("font_color", Color("#FE6D1C"))
    root.add_child(class_label)

    fps_label = Label.new()
    fps_label.text = "0 FPS"
    fps_label.anchor_left = 1.0
    fps_label.anchor_right = 1.0
    fps_label.offset_left = -145.0
    fps_label.offset_right = -28.0
    fps_label.offset_top = 24.0
    fps_label.offset_bottom = 52.0
    fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    fps_label.add_theme_font_size_override("font_size", 17)
    fps_label.add_theme_color_override("font_color", Color("#53CDAB"))
    root.add_child(fps_label)

    coords_label = Label.new()
    coords_label.anchor_left = 1.0
    coords_label.anchor_right = 1.0
    coords_label.offset_left = -210.0
    coords_label.offset_right = -28.0
    coords_label.offset_top = 54.0
    coords_label.offset_bottom = 80.0
    coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    coords_label.add_theme_font_size_override("font_size", 12)
    coords_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
    root.add_child(coords_label)

    var hint := Label.new()
    hint.text = "NATIVE GODOT MOVEMENT · 60 HZ"
    hint.anchor_left = 0.5
    hint.anchor_right = 0.5
    hint.anchor_top = 1.0
    hint.anchor_bottom = 1.0
    hint.offset_left = -180.0
    hint.offset_right = 180.0
    hint.offset_top = -42.0
    hint.offset_bottom = -18.0
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
    root.add_child(hint)

    var joystick: Control = JOYSTICK_SCRIPT.new()
    joystick.anchor_left = 0.0
    joystick.anchor_top = 1.0
    joystick.anchor_right = 0.0
    joystick.anchor_bottom = 1.0
    joystick.offset_left = 24.0
    joystick.offset_top = -248.0
    joystick.offset_right = 248.0
    joystick.offset_bottom = -24.0
    joystick.vector_changed.connect(_on_joystick_changed)
    root.add_child(joystick)

    var exit_button := Button.new()
    exit_button.text = "ВЫХОД"
    exit_button.anchor_left = 1.0
    exit_button.anchor_right = 1.0
    exit_button.offset_left = -142.0
    exit_button.offset_right = -28.0
    exit_button.offset_top = 88.0
    exit_button.offset_bottom = 132.0
    exit_button.add_theme_font_size_override("font_size", 13)
    exit_button.pressed.connect(_exit_game)
    root.add_child(exit_button)

func _on_joystick_changed(value: Vector2) -> void:
    move_input = value

func _exit_game() -> void:
    get_tree().quit()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        get_tree().quit()

func _add_building(position: Vector3, size: Vector3, color: Color) -> void:
    _add_box_static("Building", size, position, color)

func _add_boundary(position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = position
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

func _add_fountain(position: Vector3) -> void:
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 2.1
    base_mesh.bottom_radius = 2.1
    base_mesh.height = 0.45
    var base := MeshInstance3D.new()
    base.mesh = base_mesh
    base.position = position
    base.material_override = _material(Color("#59636D"), 0.8)
    add_child(base)

    var water_mesh := CylinderMesh.new()
    water_mesh.top_radius = 1.75
    water_mesh.bottom_radius = 1.75
    water_mesh.height = 0.08
    var water := MeshInstance3D.new()
    water.mesh = water_mesh
    water.position = position + Vector3(0, 0.25, 0)
    water.material_override = _material(Color("#2E7896"), 0.25)
    add_child(water)

    var column_mesh := CylinderMesh.new()
    column_mesh.top_radius = 0.28
    column_mesh.bottom_radius = 0.38
    column_mesh.height = 2.0
    var column := MeshInstance3D.new()
    column.mesh = column_mesh
    column.position = position + Vector3(0, 1.1, 0)
    column.material_override = _material(Color("#707982"), 0.82)
    add_child(column)

func _add_lamp(position: Vector3) -> void:
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = 0.07
    pole_mesh.bottom_radius = 0.09
    pole_mesh.height = 2.8
    var pole := MeshInstance3D.new()
    pole.mesh = pole_mesh
    pole.position = position + Vector3(0, 1.4, 0)
    pole.material_override = _material(Color("#252A30"), 0.45)
    add_child(pole)

    var lamp := OmniLight3D.new()
    lamp.position = position + Vector3(0, 2.75, 0)
    lamp.light_color = Color("#FFB35C")
    lamp.light_energy = 2.0
    lamp.omni_range = 5.5
    lamp.shadow_enabled = false
    add_child(lamp)

func _add_box_static(node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = position

    var mesh := BoxMesh.new()
    mesh.size = size
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _material(color, 0.82)
    body.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)

func _add_visual_box(size: Vector3, position: Vector3, color: Color) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _material(color, 0.92)
    add_child(mesh_instance)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat
