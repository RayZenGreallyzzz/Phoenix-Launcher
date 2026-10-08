extends Control

const DWARF_FIT = preload("res://scripts/dwarf_model_fit.gd")

# Native Phoenix Pix Arena selection screen. Only authoritative Phoenix/PPA
# account heroes may be played. Empty slots are visual placeholders until the
# existing one-character server schema is migrated to true per-slot saves.
signal character_confirmed

var account: Dictionary = {}
var _name_label: Label
var _class_label: Label
var _info_label: Label
var _status_label: Label
var _enter_button: Button
var _preview_host: TextureRect
var _preview_viewport: SubViewport
var _preview_camera: Camera3D

const CLASS_NAMES := {
    "gnome": "ГНОМ · КАНОНИР",
    "tank": "ТАНК",
    "barbarian": "ВАРВАР",
    "paladin": "ПАЛАДИН",
    "archer": "ЛУЧНИК",
    "mage": "МАГ",
    "assassin": "АССАСИН",
    "priest": "ЖРЕЦ"
}

func set_account(value: Dictionary) -> void:
    account = value.duplicate(true)
    if is_node_ready():
        _refresh_account()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_ui()
    _refresh_account()

func _build_ui() -> void:
    var art := TextureRect.new()
    art.name = "PPALaunchArt"
    art.texture = load("res://assets/ppa_hero.jpg")
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(art)

    var veil := ColorRect.new()
    veil.color = Color(0.018, 0.025, 0.036, 0.80)
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(veil)

    var top := MarginContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_bottom = 104.0
    top.add_theme_constant_override("margin_left", 32)
    top.add_theme_constant_override("margin_right", 32)
    top.add_theme_constant_override("margin_top", 22)
    add_child(top)

    var header := HBoxContainer.new()
    top.add_child(header)
    var heading := Label.new()
    heading.text = "PHOENIX PIX ARENA"
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_theme_font_size_override("font_size", 27)
    heading.add_theme_color_override("font_color", Color("#F6E2CC"))
    heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
    heading.add_theme_constant_override("shadow_offset_x", 1)
    heading.add_theme_constant_override("shadow_offset_y", 2)
    header.add_child(heading)

    var screen_title := Label.new()
    screen_title.text = "ВЫБОР ПЕРСОНАЖА"
    screen_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    screen_title.add_theme_font_size_override("font_size", 15)
    screen_title.add_theme_color_override("font_color", Color("#FBA66D"))
    header.add_child(screen_title)

    var frame := PanelContainer.new()
    frame.name = "SelectCard"
    frame.anchor_left = 0.07
    frame.anchor_right = 0.93
    frame.anchor_top = 0.175
    frame.anchor_bottom = 0.90
    frame.offset_left = 0
    frame.offset_right = 0
    frame.offset_top = 0
    frame.offset_bottom = 0
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.045, 0.053, 0.066, 0.96)
    frame_style.border_color = Color(0.42, 0.30, 0.18, 0.95)
    frame_style.set_border_width_all(1)
    frame_style.set_corner_radius_all(12)
    frame.add_theme_stylebox_override("panel", frame_style)
    add_child(frame)

    var padding := MarginContainer.new()
    padding.add_theme_constant_override("margin_left", 20)
    padding.add_theme_constant_override("margin_right", 20)
    padding.add_theme_constant_override("margin_top", 16)
    padding.add_theme_constant_override("margin_bottom", 16)
    frame.add_child(padding)

    var columns := HBoxContainer.new()
    columns.add_theme_constant_override("separation", 22)
    padding.add_child(columns)

    var preview_panel := PanelContainer.new()
    preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_panel.size_flags_stretch_ratio = 0.90
    var preview_style := StyleBoxFlat.new()
    preview_style.bg_color = Color(0.030, 0.040, 0.055, 1.0)
    preview_style.border_color = Color(0.25, 0.24, 0.27, 0.8)
    preview_style.set_border_width_all(1)
    preview_style.set_corner_radius_all(8)
    preview_panel.add_theme_stylebox_override("panel", preview_style)
    columns.add_child(preview_panel)

    var preview_stack := VBoxContainer.new()
    preview_panel.add_child(preview_stack)

    var preview_caption := Label.new()
    preview_caption.text = "ВАШ ГЕРОЙ"
    preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview_caption.add_theme_font_size_override("font_size", 12)
    preview_caption.add_theme_color_override("font_color", Color("#D2AF88"))
    preview_stack.add_child(preview_caption)

    _preview_host = TextureRect.new()
    _preview_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _preview_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _preview_host.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _preview_host.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    preview_stack.add_child(_preview_host)

    _status_label = Label.new()
    _status_label.text = "ЗАГРУЖАЕМ ПЕРСОНАЖА"
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.add_theme_color_override("font_color", Color("#8E9BA5"))
    _status_label.add_theme_font_size_override("font_size", 11)
    preview_stack.add_child(_status_label)

    var details := VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.size_flags_stretch_ratio = 1.10
    details.add_theme_constant_override("separation", 12)
    columns.add_child(details)

    var slot_heading := Label.new()
    slot_heading.text = "СЛОТ 01  ·  ОСНОВНОЙ ПЕРСОНАЖ"
    slot_heading.add_theme_font_size_override("font_size", 12)
    slot_heading.add_theme_color_override("font_color", Color("#F9A364"))
    details.add_child(slot_heading)

    _name_label = Label.new()
    _name_label.add_theme_font_size_override("font_size", 31)
    _name_label.add_theme_color_override("font_color", Color.WHITE)
    _name_label.clip_text = true
    details.add_child(_name_label)

    _class_label = Label.new()
    _class_label.add_theme_font_size_override("font_size", 16)
    _class_label.add_theme_color_override("font_color", Color("#CEB7A4"))
    details.add_child(_class_label)

    var line := HSeparator.new()
    details.add_child(line)

    _info_label = Label.new()
    _info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _info_label.add_theme_font_size_override("font_size", 12)
    _info_label.add_theme_color_override("font_color", Color("#A9B3BE"))
    details.add_child(_info_label)

    var empty_note := Label.new()
    empty_note.text = "ДОПОЛНИТЕЛЬНЫЕ СЛОТЫ"
    empty_note.add_theme_font_size_override("font_size", 11)
    empty_note.add_theme_color_override("font_color", Color("#D2AF88"))
    details.add_child(empty_note)

    var slots := HBoxContainer.new()
    slots.add_theme_constant_override("separation", 10)
    details.add_child(slots)
    for number in [2, 3]:
        var empty := PanelContainer.new()
        empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var empty_style := StyleBoxFlat.new()
        empty_style.bg_color = Color(0.060, 0.070, 0.080, 1.0)
        empty_style.border_color = Color(0.20, 0.23, 0.25, 0.9)
        empty_style.set_border_width_all(1)
        empty_style.set_corner_radius_all(5)
        empty.add_theme_stylebox_override("panel", empty_style)
        slots.add_child(empty)
        var empty_label := Label.new()
        empty_label.text = "СЛОТ %02d  ·  ПОКА ЗАКРЫТ" % number
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_label.add_theme_font_size_override("font_size", 11)
        empty_label.add_theme_color_override("font_color", Color("#81909D"))
        empty.add_child(empty_label)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    details.add_child(spacer)

    _enter_button = Button.new()
    _enter_button.text = "ВОЙТИ В МИРНЫЙ ГОРОД"
    _enter_button.custom_minimum_size = Vector2(0, 54)
    var button_style := StyleBoxFlat.new()
    button_style.bg_color = Color("#DF641C")
    button_style.set_corner_radius_all(7)
    _enter_button.add_theme_stylebox_override("normal", button_style)
    var hover_style := button_style.duplicate() as StyleBoxFlat
    hover_style.bg_color = Color("#FF8032")
    _enter_button.add_theme_stylebox_override("hover", hover_style)
    _enter_button.add_theme_color_override("font_color", Color.WHITE)
    _enter_button.add_theme_font_size_override("font_size", 14)
    _enter_button.pressed.connect(func(): character_confirmed.emit())
    _enter_button.disabled = true
    details.add_child(_enter_button)

    var footer := Label.new()
    footer.text = "ПРОГРЕСС И СНАРЯЖЕНИЕ ПРИВЯЗАНЫ К PHOENIX ACCOUNT"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.anchor_left = 0.0
    footer.anchor_right = 1.0
    footer.anchor_top = 0.91
    footer.anchor_bottom = 0.98
    footer.add_theme_font_size_override("font_size", 10)
    footer.add_theme_color_override("font_color", Color("#AF9C89"))
    add_child(footer)

func _refresh_account() -> void:
    if _name_label == null:
        return
    var nickname := str(account.get("ppaNickname", "")).strip_edges()
    var class_key := str(account.get("classKey", "")).strip_edges().to_lower()
    var available := not nickname.is_empty() and CLASS_NAMES.has(class_key)
    _name_label.text = nickname if not nickname.is_empty() else "НЕТ ПЕРСОНАЖА"
    _class_label.text = str(CLASS_NAMES.get(class_key, "ГЕРОЙ НЕ СОЗДАН"))
    _enter_button.disabled = not available
    if available:
        _info_label.text = "Герой зарегистрирован на сервере PPA. Войти можно только этим персонажем: клиент не меняет класс и не создаёт другое сохранение."
    else:
        _info_label.text = "В аккаунте ещё нет зарегистрированного персонажа PPA. Создание героя в native станет доступно после подключения серверных слотов."
    _status_label.text = "ПРЕВЬЮ 3D" if class_key == "gnome" else "ПРОФИЛЬ PPA"
    if class_key == "gnome":
        _build_dwarf_preview()
    else:
        _status_label.text = "3D-ПРЕВЬЮ ЭТОГО КЛАССА ПОКА НЕТ"

func _build_dwarf_preview() -> void:
    if _preview_viewport != null or not ResourceLoader.exists("res://assets/Dwarf.glb"):
        return
    var res = load("res://assets/Dwarf.glb")
    if not (res is PackedScene):
        _status_label.text = "ОШИБКА ИМПОРТА 3D"
        return
    var model := (res as PackedScene).instantiate() as Node3D
    if model == null:
        _status_label.text = "НЕТ 3D-МОДЕЛИ"
        return

    _preview_viewport = SubViewport.new()
    _preview_viewport.transparent_bg = true
    _preview_viewport.own_world_3d = true
    _preview_viewport.size = Vector2i(340, 360)
    _preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_preview_viewport)

    var stage := Node3D.new()
    _preview_viewport.add_child(stage)
    stage.add_child(model)
    _fit_preview_model(model)

    var sun := DirectionalLight3D.new()
    sun.light_color = Color("#FFE7BC")
    sun.light_energy = 2.3
    sun.rotation_degrees = Vector3(-35, -30, 0)
    stage.add_child(sun)

    var light := DirectionalLight3D.new()
    light.light_color = Color("#95B4DA")
    light.light_energy = 0.9
    light.rotation_degrees = Vector3(-10, 130, 0)
    stage.add_child(light)

    _preview_camera = Camera3D.new()
    _preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _preview_camera.size = 4.00
    _preview_camera.near = 0.05
    _preview_camera.far = 40.0
    _preview_camera.position = Vector3(4.0, 2.7, 6.0)
    stage.add_child(_preview_camera)
    _preview_camera.look_at(Vector3(0, 1.05, 0), Vector3.UP)
    _preview_camera.current = true
    _preview_host.texture = _preview_viewport.get_texture()

    var anim_players = model.find_children("*", "AnimationPlayer", true, false)
    for node in anim_players:
        var player := node as AnimationPlayer
        if player == null:
            continue
        for anim_name in player.get_animation_list():
            if str(anim_name).to_lower().contains("idle"):
                var anim := player.get_animation(anim_name)
                if anim != null:
                    anim.loop_mode = Animation.LOOP_LINEAR
                player.play(anim_name)
                return

func _fit_preview_model(model: Node3D) -> void:
    if not DWARF_FIT.fit(model, 2.10):
        push_error("[PPA-DWARF] Unable to fit 3D selection preview")
