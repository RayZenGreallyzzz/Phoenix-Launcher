extends Node

# Shared resources and the existing viewport/camera, with no extra renderer,
# lights or shadows per peer. Offscreen rigs stop their AnimationPlayer.
const HEROES = preload("res://scripts/test_hero_catalog.gd")
const FIT = preload("res://scripts/dwarf_model_fit.gd")
var render_models := true
var host: Control
var entries: Dictionary = {}

func bind_world(world: Control) -> void:
    host = world

func update_players(rows: Array) -> void:
    if host == null:
        return
    for value in rows:
        if not (value is Dictionary):
            continue
        var row: Dictionary = value
        var pid := str(row.get("i", ""))
        if pid.is_empty():
            continue
        var point := Vector2(float(row["x"]), float(row["y"]))
        var entry: Dictionary = entries.get(pid, {})
        if entry.is_empty():
            var label := Label.new()
            label.name = "SharedCityPlayerLabel"
            label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            label.size = Vector2(220, 42)
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            label.add_theme_font_size_override("font_size", 11)
            label.add_theme_color_override("font_color", Color("#F2D39A"))
            label.add_theme_color_override("font_shadow_color", Color("#161010"))
            label.add_theme_constant_override("shadow_offset_x", 1)
            label.add_theme_constant_override("shadow_offset_y", 1)
            label.z_index = 10
            host.add_child(label)
            entry = {"row":row, "point":point, "target":point, "label":label,
                "root":null, "model":null, "animator":null, "clips":{}, "anim":"",
                "yaw":0.0, "direction":_face_vector(int(row.get("f", 4)))}
            entries[pid] = entry
        elif str(entry["row"].get("c", "")) != str(row.get("c", "")):
            if entry["root"] != null:
                entry["root"].queue_free()
            entry["root"] = null
            entry["model"] = null
            entry["animator"] = null
            entry["clips"] = {}
            entry["anim"] = ""
        var movement: Vector2 = point - entry["target"]
        if movement.length_squared() > 0.01:
            entry["direction"] = movement.normalized()
        entry["target"] = point
        entry["row"] = row
        entry["seen"] = Time.get_ticks_msec()
        var clan := str(row.get("cn", ""))
        entry["label"].text = (("[" + clan + "]\n") if not clan.is_empty() else "") + str(row.get("n", "Игрок"))

func _face_vector(face: int) -> Vector2:
    # Same startup/legacy aliases used by unified web Player3D.
    var direction := 6 if face == -1 else 2 if face == 1 else 0 if face == 8 else face
    var angle := float(direction) * TAU / 8.0
    return Vector2(sin(angle), -cos(angle))

func _ensure_model(entry: Dictionary) -> void:
    if not render_models or entry["root"] != null or host.viewport_3d == null:
        return
    var info: Dictionary = HEROES.hero_info(str(entry["row"]["c"]))
    var resource_path := str(info["model"])
    if not ResourceLoader.exists(resource_path):
        return # No fabricated placeholder hero when an authentic GLB is missing.
    var resource := load(resource_path) as PackedScene
    if resource == null:
        return
    var rig := Node3D.new()
    var model := resource.instantiate() as Node3D
    if model == null:
        rig.free()
        return
    rig.add_child(model)
    if not FIT.fit(model, float(info["height"])):
        rig.free()
        return
    host.viewport_3d.add_child(rig)
    entry["root"] = rig
    entry["model"] = model
    for candidate in model.find_children("*", "AnimationPlayer", true, false):
        var animator := candidate as AnimationPlayer
        if animator == null:
            continue
        var clips: Dictionary = {}
        for animation_name in animator.get_animation_list():
            var lower := str(animation_name).to_lower()
            var state := "run" if "run" in lower or "walk" in lower or "jog" in lower else "idle" if "idle" in lower or "stand" in lower or "breath" in lower else ""
            if state.is_empty() or clips.has(state):
                continue
            clips[state] = str(animation_name)
            var animation := animator.get_animation(animation_name)
            if animation != null:
                animation.loop_mode = Animation.LOOP_LINEAR
        if not clips.is_empty():
            entry["animator"] = animator
            entry["clips"] = clips
            break

func _process(delta: float) -> void:
    if host == null or not is_instance_valid(host):
        return
    var expired: Array = []
    var now := Time.get_ticks_msec()
    var loaded_this_frame := false
    for pid in entries:
        var entry: Dictionary = entries[pid]
        if now - int(entry.get("seen", now)) > 12000:
            expired.append(pid)
            continue
        var point: Vector2 = entry["point"]
        var target: Vector2 = entry["target"]
        # Short interpolation, with immediate placement after a teleport.
        point = target if point.distance_squared_to(target) > 40000.0 else point.lerp(target, 1.0 - exp(-delta * 18.0))
        entry["point"] = point
        var screen: Vector2 = point + host.city_world.position
        var visible_now := Rect2(Vector2(-120, -160), host.size + Vector2(240, 320)).has_point(screen)
        if float(entry["row"].get("hu", 0)) > Time.get_unix_time_from_system() * 1000.0:
            visible_now = false
        var label: Label = entry["label"]
        label.visible = visible_now
        label.position = screen - Vector2(110, 122)
        # Spread model creation across frames when a crowded snapshot arrives.
        if visible_now and entry["root"] == null and not loaded_this_frame:
            _ensure_model(entry)
            loaded_this_frame = true
        var rig: Node3D = entry["root"]
        var animator: AnimationPlayer = entry["animator"]
        if rig != null:
            rig.visible = visible_now
        if animator != null:
            animator.active = visible_now and not host._modal_world_frozen
        if not visible_now or rig == null or host._modal_world_frozen:
            continue
        var ground: Vector3 = host._screen_to_ground(screen)
        rig.position = ground
        var ahead: Vector3 = host._screen_to_ground(screen + entry["direction"] * 64.0) - ground
        if ahead.length_squared() > 0.0001:
            entry["yaw"] = lerp_angle(float(entry["yaw"]), atan2(ahead.x, ahead.z), 1.0 - exp(-delta * 18.0))
            entry["model"].rotation.y = entry["yaw"]
        var state := str(entry["row"].get("a", "idle"))
        if animator != null and state != entry["anim"] and entry["clips"].has(state):
            entry["anim"] = state
            animator.play(str(entry["clips"][state]), 0.1)
    for pid in expired:
        remove_player(str(pid))

func remove_player(pid: String) -> void:
    if not entries.has(pid):
        return
    var entry: Dictionary = entries[pid]
    if entry["root"] != null:
        entry["root"].queue_free()
    entry["label"].queue_free()
    entries.erase(pid)

func clear_players() -> void:
    for pid in entries.keys():
        remove_player(str(pid))

func _exit_tree() -> void:
    clear_players()
