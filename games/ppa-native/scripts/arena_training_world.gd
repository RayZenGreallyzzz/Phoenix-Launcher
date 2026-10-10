extends "res://scripts/native_world.gd"

# Real, playable LOCAL AI training. Never pretends to be online PvP.
# No wallet, drop, ranking, rewards or server save mutations.
# Reuses the approved 3D player, touch joystick, floor camera and FPS counter.
const CENTER := Vector2(1395.0, 1463.0)
const ARENA_HALF := Vector2(460.0, 315.0)
const PLAYER_MAX_HP := 240
const ATTACK_COOLDOWN := 0.48
const MELEE_RANGE := 118.0
const RANGED_RANGE := 380.0

var player_hp := PLAYER_MAX_HP
var bots: Array[Dictionary] = []
var finished := false
var attack_timer := 0.0
var bot_counter := 0.0
var _health_label: Label
var _state_label: Label
var _round_label: Label
var _attack_button: Button
var _return_button: Button

func _ready() -> void:
    super._ready()
    world_pos_px = CENTER
    _make_bot(Vector2(-270, -165), 0, Color("#A55A58"))
    _make_bot(Vector2(275, -140), 1, Color("#7189A5"))
    _make_bot(Vector2(120, 205), 2, Color("#9A835D"))
    _update_hud()
    _sync_world_visuals()

func _build_city_2d() -> void:
    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color("#100F15")
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.z_index = -10
    add_child(backdrop)

    city_world = Control.new()
    city_world.name = "PPAOfflineArenaTrainingWorld"
    city_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(city_world)

    var outer := ColorRect.new()
    outer.color = Color("#2B2627")
    outer.position = CENTER - ARENA_HALF - Vector2(36, 36)
    outer.size = ARENA_HALF * 2.0 + Vector2(72, 72)
    outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.add_child(outer)

    var floor_rect := ColorRect.new()
    floor_rect.color = Color("#51463D")
    floor_rect.position = CENTER - ARENA_HALF
    floor_rect.size = ARENA_HALF * 2.0
    floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.add_child(floor_rect)

    # Single reusable polygon grid. Avoid hundreds of shadowed UI nodes.
    for x in range(-4, 5):
        var stripe := ColorRect.new()
        stripe.color = Color(0.1, 0.08, 0.07, 0.22)
        stripe.position = CENTER + Vector2(float(x) * 90.0, -ARENA_HALF.y)
        stripe.size = Vector2(2, ARENA_HALF.y * 2)
        stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
        city_world.add_child(stripe)
    for y in range(-3, 4):
        var stripe := ColorRect.new()
        stripe.color = Color(0.1, 0.08, 0.07, 0.22)
        stripe.position = CENTER + Vector2(-ARENA_HALF.x, float(y) * 90.0)
        stripe.size = Vector2(ARENA_HALF.x * 2, 2)
        stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
        city_world.add_child(stripe)
    var mark := Line2D.new()
    mark.width = 5.0
    mark.default_color = Color("#A78654")
    mark.closed = true
    for i in range(72):
        var angle := TAU * float(i) / 72.0
        mark.add_point(CENTER + Vector2(cos(angle), sin(angle)) * 230.0)
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    city_world.add_child(mark)

func _build_city_npcs() -> void:
    pass # Only combat dummies live in the isolated training room.

func _build_test_menu() -> void:
    pass # Never spawn all 9 NPC menus in the combat scene.

func _build_server_readonly_bridge() -> void:
    pass # Practice never requests nor changes a live save.

func _build_hud() -> void:
    super._build_hud()
    if input_label != null:
        input_label.text = "АРЕНА ИИ · движение слева, удар справа"
    _round_label = Label.new()
    _round_label.text = "АРЕНА · ТРЕНИРОВКА С ИИ"
    _round_label.position = Vector2(24, 80)
    _round_label.add_theme_font_size_override("font_size", 15)
    _round_label.add_theme_color_override("font_color", Color("#F4CA84"))
    _round_label.z_index = 25
    add_child(_round_label)

    _health_label = Label.new()
    _health_label.position = Vector2(24, 109)
    _health_label.add_theme_font_size_override("font_size", 16)
    _health_label.add_theme_color_override("font_color", Color("#87E3A9"))
    _health_label.z_index = 25
    add_child(_health_label)

    _state_label = Label.new()
    _state_label.position = Vector2(24, 137)
    _state_label.add_theme_font_size_override("font_size", 14)
    _state_label.add_theme_color_override("font_color", Color("#F0D9B7"))
    _state_label.z_index = 25
    add_child(_state_label)

    _attack_button = Button.new()
    _attack_button.text = "⚔ АТАКА"
    _attack_button.anchor_left = 1.0
    _attack_button.anchor_right = 1.0
    _attack_button.anchor_top = 1.0
    _attack_button.anchor_bottom = 1.0
    _attack_button.offset_left = -174
    _attack_button.offset_right = -23
    _attack_button.offset_top = -141
    _attack_button.offset_bottom = -69
    _attack_button.add_theme_font_size_override("font_size", 19)
    _attack_button.z_index = 40
    _attack_button.pressed.connect(_player_attack)
    add_child(_attack_button)

    _return_button = Button.new()
    _return_button.text = "В ГОРОД"
    _return_button.anchor_left = 1.0
    _return_button.anchor_right = 1.0
    _return_button.offset_left = -142
    _return_button.offset_right = -28
    _return_button.offset_top = 136
    _return_button.offset_bottom = 181
    _return_button.z_index = 40
    _return_button.pressed.connect(_back_to_city)
    add_child(_return_button)

func _exit_game() -> void:
    _back_to_city()

func _back_to_city() -> void:
    if _joy_touch_id >= 0 or _joy_mouse_active:
        _joy_touch_id = -1
        _joy_mouse_active = false
        _joy_end()
    var err := get_tree().change_scene_to_file("res://world.tscn")
    if err != OK:
        push_error("PPA_ARENA_RETURN_CITY_ERROR: " + error_string(err))

func _resolve_city_collision(target: Vector2) -> Vector2:
    return Vector2(
        clampf(target.x, CENTER.x - ARENA_HALF.x + 35.0, CENTER.x + ARENA_HALF.x - 35.0),
        clampf(target.y, CENTER.y - ARENA_HALF.y + 35.0, CENTER.y + ARENA_HALF.y - 35.0)
    )

func _make_bot(offset: Vector2, index: int, color: Color) -> void:
    var root := Node2D.new()
    root.name = "AITrainingBot%d" % (index + 1)
    root.position = CENTER + offset
    root.z_index = 5
    city_world.add_child(root)

    var silhouette := Polygon2D.new()
    silhouette.color = color
    var points := PackedVector2Array()
    for i in range(12):
        var angle := TAU * float(i) / 12.0
        points.append(Vector2(cos(angle), sin(angle)) * 25.0)
    silhouette.polygon = points
    root.add_child(silhouette)

    var ring := Line2D.new()
    ring.width = 3.0
    ring.default_color = Color("#EFD4A9")
    ring.closed = true
    for point in points:
        ring.add_point(point * 1.12)
    root.add_child(ring)

    var title := Label.new()
    title.text = "СПАРРИНГ-БОТ %d" % (index + 1)
    title.position = Vector2(-91, -59)
    title.size = Vector2(182, 19)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 12)
    title.add_theme_color_override("font_color", Color("#FBE8D6"))
    root.add_child(title)

    var hp_bg := ColorRect.new()
    hp_bg.position = Vector2(-34, -34)
    hp_bg.size = Vector2(68, 8)
    hp_bg.color = Color("#391B1B")
    root.add_child(hp_bg)
    var hp_fill := ColorRect.new()
    hp_fill.position = hp_bg.position
    hp_fill.size = hp_bg.size
    hp_fill.color = Color("#EC7858")
    root.add_child(hp_fill)

    bots.append({
        "node": root, "fill": hp_fill, "body": silhouette,
        "hp": 90 + index * 25, "max_hp": 90 + index * 25,
        "cooldown": 0.2 + index * 0.3, "speed": 72.0 + index * 7.0,
        "damage": 11 + index * 3
    })

func _combat_range() -> float:
    return RANGED_RANGE if ["archer", "gnome", "mage", "priest"].has(selected_visual_class) else MELEE_RANGE

func _player_attack() -> void:
    if finished or attack_timer > 0:
        return
    attack_timer = ATTACK_COOLDOWN
    var nearest_index := -1
    var nearest_distance := _combat_range()
    for i in range(bots.size()):
        var data: Dictionary = bots[i]
        if int(data["hp"]) <= 0:
            continue
        var target := data["node"] as Node2D
        var distance := world_pos_px.distance_to(target.position)
        if distance <= nearest_distance:
            nearest_distance = distance
            nearest_index = i
    if nearest_index < 0:
        _state_label.text = "Враги вне радиуса удара"
        return
    var chosen: Dictionary = bots[nearest_index]
    var body := chosen["node"] as Node2D
    facing_input = (body.position - world_pos_px).normalized()
    chosen["hp"] = maxi(0, int(chosen["hp"]) - 35)
    (chosen["fill"] as ColorRect).size.x = 68.0 * float(chosen["hp"]) / float(chosen["max_hp"])
    if int(chosen["hp"]) == 0:
        body.visible = false
    bots[nearest_index] = chosen
    _state_label.text = "Попадание! Урон 35 · бот HP %d" % int(chosen["hp"])
    var enemies := 0
    for bot in bots:
        if int(bot["hp"]) > 0:
            enemies += 1
    if enemies == 0:
        _finish("ПОБЕДА! Все спарринг-боты повержены")
    _update_hud()

func _physics_process(delta: float) -> void:
    if finished:
        move_input = Vector2.ZERO
        return
    super._physics_process(delta)
    attack_timer = maxf(0.0, attack_timer - delta)
    bot_counter += delta
    if bot_counter < 0.05:
        return
    var elapsed := bot_counter
    bot_counter = 0.0
    for i in range(bots.size()):
        var bot: Dictionary = bots[i]
        if int(bot["hp"]) <= 0:
            continue
        var node := bot["node"] as Node2D
        var relative := world_pos_px - node.position
        var distance := relative.length()
        if distance > 95.0 and distance < 630.0:
            node.position = _resolve_city_collision(node.position + relative.normalized() * float(bot["speed"]) * elapsed)
        bot["cooldown"] = maxf(0.0, float(bot["cooldown"]) - elapsed)
        if distance <= 106.0 and float(bot["cooldown"]) <= 0:
            player_hp = maxi(0, player_hp - int(bot["damage"]))
            bot["cooldown"] = 1.15
            _update_hud()
            if player_hp <= 0:
                _finish("ПОРАЖЕНИЕ · тренировка окончена")
        bots[i] = bot

func _update_hud() -> void:
    if _health_label != null:
        _health_label.text = "HP %d / %d" % [player_hp, PLAYER_MAX_HP]
    if _round_label != null:
        var enemies := 0
        for bot in bots:
            if int(bot["hp"]) > 0:
                enemies += 1
        _round_label.text = "АРЕНА · ИИ-ТРЕНИРОВКА · врагов %d" % enemies

func _finish(message: String) -> void:
    finished = true
    move_input = Vector2.ZERO
    if _attack_button != null:
        _attack_button.disabled = true
    _state_label.text = message + " · без наград и изменений сейва"
    _state_label.add_theme_color_override("font_color", Color("#FFE58C"))
    var retry := Button.new()
    retry.text = "ПОВТОРИТЬ"
    retry.anchor_left = 0.5
    retry.anchor_right = 0.5
    retry.anchor_top = 0.5
    retry.anchor_bottom = 0.5
    retry.offset_left = -100
    retry.offset_right = 100
    retry.offset_top = 54
    retry.offset_bottom = 108
    retry.z_index = 50
    retry.pressed.connect(_restart)
    add_child(retry)

func _restart() -> void:
    var err := get_tree().reload_current_scene()
    if err != OK:
        push_error("PPA_ARENA_RESTART_ERROR: " + error_string(err))
