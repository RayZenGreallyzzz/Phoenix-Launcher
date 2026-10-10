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
const HERO_CATALOG = preload("res://scripts/test_hero_catalog.gd")
const NPC_CATALOG = preload("res://scripts/test_city_npcs.gd")
const TEST_WORLD_MENU = preload("res://scripts/test_world_menu.gd")
const PPA_READONLY = preload("res://scripts/ppa_server_readonly_snapshot.gd")
const NPC_SERVICE_READONLY = preload("res://scripts/ppa_native_npc_service_bridge.gd")
const GLOBAL_REALTIME_READONLY = preload("res://scripts/ppa_native_shared_realtime.gd")
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
var selected_visual_class := "gnome"
var test_menu: Control
var _npc_probe_clock := 0.0
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
var _server_snapshot_loader: Node
var _npc_service_loader: Node
var _native_global_realtime: Node
var _server_snapshot_status: Label

var _joy_touch_id := -1
var _joy_mouse_active := false
var _joy_center := Vector2.ZERO
var _fps_clock := 0.0
var _modal_world_frozen := false

var _animation_player: AnimationPlayer
var _run_animation := ""
var _idle_animation := ""
var _anim_state := ""

func _ready() -> void:
    profile = get_tree().get_meta("phoenix_account", {})
    # The 3D hero in the actual native world is the account's SERVER class.
    # Previewing another model in the gallery never changes this character.
    var server_key := str(profile.get("classKey", "")).to_lower().strip_edges()
    selected_visual_class = server_key if HERO_CATALOG.valid_key(server_key) else "gnome"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)

    _plaza_poly = PackedVector2Array(PLAZA_POINTS)
    _build_city_2d()
    _build_city_npcs()
    _build_3d_overlay()
    _build_hud()
    _build_test_menu()
    _build_server_readonly_bridge()
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

# 2D NPCs at the exact authoritative live PPA image-space locations.
# They scroll in the same 2D map layer, not in the Godot 3D player viewport.
func _build_city_npcs() -> void:
    for npc in NPC_CATALOG.NPCS:
        var source := str(npc.get("image", ""))
        if not ResourceLoader.exists(source):
            push_warning("[PPA-NPC] Missing deployed artwork: " + source)
            continue
        var texture := load(source) as Texture2D
        if texture == null or texture.get_height() <= 0:
            push_warning("[PPA-NPC] Invalid image: " + source)
            continue
        var anchor: Vector2 = NPC_CATALOG.world_pos(npc, SCN_SCALE)
        var image_height: float = float(npc.get("height", 112.0))
        var sprite := Sprite2D.new()
        sprite.name = "NPC_" + str(npc.get("id", ""))
        sprite.texture = texture
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var pixel_scale: float = image_height / float(texture.get_height())
        sprite.scale = Vector2.ONE * pixel_scale
        sprite.position = anchor + Vector2(0.0, 18.0 - image_height * 0.5)
        sprite.z_index = 1
        city_world.add_child(sprite)

        var label := Label.new()
        label.name = "NPCLabel_" + str(npc.get("id", ""))
        label.text = str(npc.get("name", "NPC"))
        label.position = anchor + Vector2(-120.0, 23.0)
        label.size = Vector2(240.0, 24.0)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 12)
        label.add_theme_color_override("font_color", Color("#FFDBAD"))
        label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
        label.add_theme_constant_override("shadow_offset_x", 1)
        label.add_theme_constant_override("shadow_offset_y", 2)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.z_index = 1
        city_world.add_child(label)

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

    # The chosen native class is a *test preview*. It does not alter the
    # authoritative server class or inventory. Only local player is 3D.
    var hero: Dictionary = HERO_CATALOG.hero_info(selected_visual_class)
    var path := str(hero.get("model", ""))
    if ResourceLoader.exists(path):
        var model_resource = load(path)
        if model_resource is PackedScene:
            var model := (model_resource as PackedScene).instantiate() as Node3D
            if model != null:
                player_visual.add_child(model)
                if DWARF_FIT.fit(model, float(hero.get("height", 2.25))):
                    _find_model_animations(model)
                else:
                    model.queue_free()
                    _build_fallback_player()
                print("[PPA-NATIVE] Test class=", selected_visual_class, " glb=", path,
                    " idle=", _idle_animation, " run=", _run_animation)
            else:
                push_warning("[PPA-NATIVE] GLB root is not a Node3D: " + path)
                _build_fallback_player()
        else:
            push_warning("[PPA-NATIVE] GLB failed scene import: " + path)
            _build_fallback_player()
    else:
        push_warning("[PPA-NATIVE] Missing class GLB: " + path)
        _build_fallback_player()

    # NO fake ground shadows. The black cylinder used to float beneath the
    # hero in the tilted 2.5D camera; original floor texture is unchanged.
    # Both lights already have shadow_enabled=false.

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
    var preview_name := str(HERO_CATALOG.hero_info(selected_visual_class).get("name", selected_visual_class))
    class_label.text = "МИРНЫЙ ГОРОД · ТЕСТ %s" % preview_name
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


func _build_server_readonly_bridge() -> void:
    # Can be used by City and Dungeon. No save/write request is possible.
    _server_snapshot_status = Label.new()
    _server_snapshot_status.name = "PPAReadOnlyServerSnapshotStatus"
    _server_snapshot_status.text = "СЕРВЕР: получаем данные персонажа…"
    _server_snapshot_status.position = Vector2(28.0, 81.0)
    _server_snapshot_status.size = Vector2(490.0, 24.0)
    _server_snapshot_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _server_snapshot_status.z_index = 20
    _server_snapshot_status.add_theme_font_size_override("font_size", 11)
    _server_snapshot_status.add_theme_color_override("font_color", Color("#B6C0CD"))
    add_child(_server_snapshot_status)
    _server_snapshot_loader = PPA_READONLY.new()
    _server_snapshot_loader.name = "PPAServerReadOnly"
    add_child(_server_snapshot_loader)
    _server_snapshot_loader.snapshot_ready.connect(_on_readonly_snapshot_ready)
    _server_snapshot_loader.snapshot_failed.connect(_on_readonly_snapshot_failed)
    _server_snapshot_loader.call("fetch_once")
    # A single small NPC request is made only when the player opens its menu.
    _npc_service_loader = NPC_SERVICE_READONLY.new()
    _npc_service_loader.name = "PPANativeNpcReadOnly"
    add_child(_npc_service_loader)
    _npc_service_loader.service_ready.connect(_on_npc_service_ready)
    _npc_service_loader.service_failed.connect(_on_npc_service_failed)
    _native_global_realtime = GLOBAL_REALTIME_READONLY.new()
    _native_global_realtime.name = "PPASharedRealtimePresenceOnly"
    add_child(_native_global_realtime)
    _native_global_realtime.presence_changed.connect(_on_native_presence)
    _native_global_realtime.presence_failed.connect(_on_native_presence_failure)
    if test_menu != null:
        test_menu.npc_snapshot_requested.connect(_request_npc_service)
        test_menu.native_realtime_requested.connect(_connect_native_realtime)

func _request_npc_service(service: String) -> void:
    if _npc_service_loader == null or test_menu == null:
        return
    _npc_service_loader.request_service(service)

func _on_npc_service_ready(payload: Dictionary) -> void:
    if test_menu != null:
        test_menu.apply_native_npc_service(payload)

func _on_npc_service_failed(_service: String, _code: String) -> void:
    # The server feature flags default OFF. Local NPC menus must keep working
    # without creating fake purchases, blocking input or spamming retries.
    pass

func _connect_native_realtime() -> void:
    # Only an explicit tap at the arena NPC can displace Telegram's socket.
    if _native_global_realtime != null:
        _native_global_realtime.connect_explicitly()

func _on_native_presence(count: int, room_total: int) -> void:
    if test_menu != null:
        test_menu.apply_native_presence(count, room_total)

func _on_native_presence_failure(message: String) -> void:
    if test_menu != null:
        test_menu.apply_native_presence_failure(message)

func _refresh_server_readonly_save() -> void:
    # Authenticated GET only, no save writes. Never cache another character.
    if _server_snapshot_loader == null:
        return
    if bool(_server_snapshot_loader.get("loading")):
        return
    if _server_snapshot_status != null:
        _server_snapshot_status.text = "PPA СЕРВЕР · перепроверяем облачное сохранение…"
    _server_snapshot_loader.call("fetch_once")

func _on_readonly_snapshot_ready(payload: Dictionary) -> void:
    var save = payload.get("state", {})
    if not (save is Dictionary):
        return
    if test_menu != null:
        test_menu.call("apply_readonly_snapshot", payload)
    # Display real values exactly as received; never replace with fabricated
    # class stats or mutate a save from this visual 3D testing client.
    var level_text := str(save.get("lvl", save.get("level", "—")))
    var hp_text := str(save.get("hp", "—"))
    var mp_text := str(save.get("mp", "—"))
    var name_text := str(save.get("playerName", save.get("nickname", "PPA")))
    if _server_snapshot_status != null:
        _server_snapshot_status.text = "PPA СЕРВЕР · %s · ур.%s · HP %s · MP %s · чтение" % [
            name_text, level_text, hp_text, mp_text
        ]
        _server_snapshot_status.add_theme_color_override("font_color", Color("#76D4A0"))
    print("PPA_NATIVE_SAVE_READONLY_OK version=", payload.get("version", null),
        " linked=1 server_writes=0")

func _on_readonly_snapshot_failed(code: String) -> void:
    if test_menu != null:
        test_menu.call("clear_readonly_snapshot")
    # An unavailable backend must never silently switch to fake stats, create
    # another character, override inventory or block local map/asset QA.
    if _server_snapshot_status != null:
        _server_snapshot_status.text = "PPA СЕРВЕР · нет снимка (" + code.left(50) + ")"
        _server_snapshot_status.add_theme_color_override("font_color", Color("#ECB477"))
    print("PPA_NATIVE_SAVE_READONLY_WAIT code=", code.left(56), " server_writes=0")

func _input(event: InputEvent) -> void:
    # No virtual joystick or 3D click handlers may steal touches from
    # character panels, store buttons or inventory slots.
    if test_menu != null and test_menu.is_open():
        if _joy_touch_id != -1 or _joy_mouse_active:
            _joy_touch_id = -1
            _joy_mouse_active = false
            _joy_end()
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            if _try_world_tap(event.position):
                get_viewport().set_input_as_handled()
                return
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
            if _try_world_tap(event.position):
                get_viewport().set_input_as_handled()
                return
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

func _build_test_menu() -> void:
    test_menu = TEST_WORLD_MENU.new()
    test_menu.configure(profile, selected_visual_class)
    add_child(test_menu)
    test_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    test_menu.change_class_requested.connect(_back_to_character_select)
    test_menu.dungeon_visual_test_requested.connect(_open_dungeon_map_test)
    test_menu.arena_training_requested.connect(_open_arena_training)
    test_menu.refresh_readonly_save_requested.connect(_refresh_server_readonly_save)

func _open_arena_training() -> void:
    # Explicit user click starts a real LOCAL AI combat scene. PPA multiplayer
    # and rewards remain server-owned and are not simulated in this beta.
    if test_menu != null:
        test_menu.close_menu()
    if _joy_touch_id != -1 or _joy_mouse_active:
        _joy_touch_id = -1
        _joy_mouse_active = false
        _joy_end()
    var err := get_tree().change_scene_to_file("res://arena_training.tscn")
    if err != OK:
        push_error("PPA_ARENA_TRAINING_ENTRY_FAILED: " + error_string(err))

func _open_dungeon_map_test() -> void:
    # Native visual test only. Never writes scene, loot or entry permissions
    # to the shared PPA server. Production entry remains locked in the hub.
    if test_menu != null:
        test_menu.close_menu()
    if _joy_touch_id != -1 or _joy_mouse_active:
        _joy_touch_id = -1
        _joy_mouse_active = false
        _joy_end()
    var error := get_tree().change_scene_to_file("res://dungeon_test.tscn")
    if error != OK:
        push_error("PPA_DUNGEON_MAP_TEST_ENTRY_FAILED: " + error_string(error))

# Native tap dispatch. GUI panels/buttons are handled by Godot first and
# this method is never invoked while a menu is open. Clicking the character
# or any visible NPC sprite opens the corresponding familiar PPA-style window.
# Only visual 2D map/NPC coordinates are touched; movement/collision is intact.
func _back_to_character_select() -> void:
    if _joy_touch_id != -1 or _joy_mouse_active:
        _joy_touch_id = -1
        _joy_mouse_active = false
        _joy_end()
    var err := get_tree().change_scene_to_file("res://main.tscn")
    if err != OK:
        push_warning("[PPA-UI] Cannot reopen class selection: " + error_string(err))

func _try_world_tap(screen_position: Vector2) -> bool:
    if test_menu == null or test_menu.is_open():
        return false
    if size.x <= 0.0 or size.y <= 0.0:
        return false

    # Buttons over the right side should stay clickable, even if the world
    # happens to be scrolled under them.
    if screen_position.x > size.x - 224.0:
        if screen_position.y < 204.0 or screen_position.y > size.y - 175.0:
            return false

    if city_world == null:
        return false
    var npc_hit: Dictionary = {}
    var best_distance := INF
    for npc in NPC_CATALOG.NPCS:
        var anchor: Vector2 = NPC_CATALOG.world_pos(npc, SCN_SCALE) + city_world.position
        var dx: float = absf(screen_position.x - anchor.x)
        var dy: float = screen_position.y - anchor.y
        var height: float = float(npc.get("height", 112.0))
        var half_width: float = maxf(38.0, height * 0.52)
        if dx > half_width or dy < -height - 15.0 or dy > 43.0:
            continue
        var distance: float = (screen_position - anchor).length_squared()
        if distance < best_distance:
            best_distance = distance
            npc_hit = npc
    if not npc_hit.is_empty():
        _joy_touch_id = -1
        _joy_mouse_active = false
        _joy_end()
        test_menu.open_npc(npc_hit)
        return true

    # Priority: a visible NPC tap MUST win over the nearby hero hitbox.
    # Otherwise the old order wrongly opened the character window while
    # interacting with an NPC standing close to the player.
    if camera_3d != null and player_3d != null:
        var hero_center: Vector2 = camera_3d.unproject_position(
            player_3d.to_global(Vector3(0.0, 0.95, 0.0))
        )
        if hero_center.distance_to(screen_position) <= 62.0:
            _joy_touch_id = -1
            _joy_mouse_active = false
            _joy_end()
            test_menu.open_page("character")
            return true
    return false

func _probe_nearest_npc() -> void:
    if test_menu == null:
        return
    var closest: Dictionary = {}
    var best := INF
    for npc in NPC_CATALOG.NPCS:
        var target: Vector2 = NPC_CATALOG.world_pos(npc, SCN_SCALE)
        var distance := world_pos_px.distance_to(target)
        var radius := maxf(96.0, float(npc.get("radius", 72.0)))
        if distance <= radius and distance < best:
            closest = npc
            best = distance
    test_menu.set_near_npc(closest)

# Overridden in DungeonWorld because PPA dungeon logical coordinates are
# larger than its exported 4096px visual texture.
func _movement_speed_px() -> float:
    return MOVE_SPEED_PX

func _physics_process(delta: float) -> void:
    # Do not run the local test hero's movement, collision resolver, NPC
    # proximity checks or repeated 3D transforms behind a modal WebView.
    # This does NOT pause any future server-authoritative world AI/timers.
    # Saving CPU here is especially useful on entry-level Android tablets.
    if test_menu != null and test_menu.is_open():
        if _joy_touch_id != -1 or _joy_mouse_active:
            _joy_touch_id = -1
            _joy_mouse_active = false
            _joy_end()
        move_input = Vector2.ZERO
        if not _modal_world_frozen:
            _modal_world_frozen = true
            _set_animation("idle")
            # Freeze the last 3D frame while the original HTML WebView is
            # active. Render one final idle frame, then stop updating this
            # dedicated hero viewport. Godot world data is never unloaded.
            if viewport_3d != null:
                viewport_3d.render_target_update_mode = SubViewport.UPDATE_ONCE
            print("PPA_NATIVE_MODAL_RENDER_PAUSED")
        return
    if _modal_world_frozen:
        _modal_world_frozen = false
        if viewport_3d != null:
            viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        print("PPA_NATIVE_MODAL_RENDER_RESUMED")
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
        world_pos_px = _resolve_city_collision(world_pos_px + input_vec * _movement_speed_px() * delta)
        _set_animation("run")
    else:
        _set_animation("idle")

    _npc_probe_clock += delta
    if _npc_probe_clock >= 0.20:
        _npc_probe_clock = 0.0
        _probe_nearest_npc()
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

# Shared camera bounds for Peace City and future native world scenes.
# Overridden by DungeonWorld to match the genuine PPA dungeon texture.
func _map_world_size() -> Vector2:
    return Vector2(CITY_W, CITY_H)

func _sync_world_visuals() -> void:
    if size.x < 2.0 or size.y < 2.0:
        return

    if city_world:
        city_world.scale = MAP_SCALE
        # Match the web camera: clamp to the town edges, rather than exposing
        # an empty border. The 3D player is placed at the actual 2D screen pos.
        var bounds := _map_world_size()
        var offset_x := size.x * 0.5 - world_pos_px.x
        var offset_y := size.y * 0.5 - world_pos_px.y
        city_world.position = Vector2(
            clampf(offset_x, size.x - bounds.x, 0.0) if bounds.x > size.x else (size.x - bounds.x) * 0.5,
            clampf(offset_y, size.y - bounds.y, 0.0) if bounds.y > size.y else (size.y - bounds.y) * 0.5
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
    if not DWARF_FIT.fit(model, 1.90):
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
