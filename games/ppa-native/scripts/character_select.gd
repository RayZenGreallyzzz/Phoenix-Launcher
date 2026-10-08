extends Control

const DWARF_FIT = preload("res://scripts/dwarf_model_fit.gd")
const HERO_CATALOG = preload("res://scripts/test_hero_catalog.gd")

# Native beta class gallery: choose any of eight official 3D models without
# touching live server account class, inventory, progress or character ID.
# One server character remains authoritative; this gallery is visual test only.
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
var _preview_stage: Node3D
var _preview_model: Node3D
var _class_layout: GridContainer
var _preview_panel: PanelContainer
var _class_buttons_grid: GridContainer
var _class_buttons: Dictionary = {}
var _selected_class_key := "gnome"

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
    _adapt_orientation()
    resized.connect(_adapt_orientation)

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

    var columns := GridContainer.new()
    columns.name = "ResponsiveClassLayout"
    columns.columns = 2
    columns.add_theme_constant_override("h_separation", 22)
    columns.add_theme_constant_override("v_separation", 8)
    padding.add_child(columns)
    _class_layout = columns

    var preview_panel := PanelContainer.new()
    preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _preview_panel = preview_panel
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
    slot_heading.text = "ТЕСТ ВСЕХ 8 КЛАССОВ · ОБЩАЯ СУМКА И СКЛАД"
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

    var classes_heading := Label.new()
    classes_heading.text = "ВЫБЕРИ КЛАСС ДЛЯ ТЕСТА"
    classes_heading.add_theme_color_override("font_color", Color("#F9A364"))
    classes_heading.add_theme_font_size_override("font_size", 12)
    details.add_child(classes_heading)

    var button_grid := GridContainer.new()
    _class_buttons_grid = button_grid
    button_grid.columns = 2
    button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button_grid.add_theme_constant_override("h_separation", 9)
    button_grid.add_theme_constant_override("v_separation", 6)
    details.add_child(button_grid)
    for hero in HERO_CATALOG.CLASSES:
        var key := str(hero.get("key", ""))
        var button := Button.new()
        button.text = str(hero.get("name", key))
        button.custom_minimum_size = Vector2(175, 42)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 12)
        button.pressed.connect(_choose_class.bind(key))
        button_grid.add_child(button)
        _class_buttons[key] = button

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
    _enter_button.pressed.connect(_confirm_preview)
    _enter_button.disabled = true
    details.add_child(_enter_button)

    var footer := Label.new()
    footer.text = "ТЕСТОВАЯ ГАЛЕРЕЯ: СМЕНА КЛАССА НЕ ЗАПИСЫВАЕТСЯ НА СЕРВЕР PPA"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.anchor_left = 0.0
    footer.anchor_right = 1.0
    footer.anchor_top = 0.91
    footer.anchor_bottom = 0.98
    footer.add_theme_font_size_override("font_size", 10)
    footer.add_theme_color_override("font_color", Color("#AF9C89"))
    add_child(footer)

func _adapt_orientation() -> void:
    if _class_layout == null or size.x < 2.0 or size.y < 2.0:
        return
    var portrait := size.y > size.x
    # Use stacked preview and controls in portrait, side by side in landscape.
    _class_layout.columns = 1 if portrait else 2
    if _preview_panel != null:
        _preview_panel.custom_minimum_size.y = 185.0 if portrait else 0.0
    if _class_buttons_grid != null:
        _class_buttons_grid.columns = 2

func _refresh_account() -> void:
    if _name_label == null:
        return
    var server_key := str(account.get("classKey", "")).to_lower().strip_edges()
    if not HERO_CATALOG.valid_key(server_key):
        server_key = "gnome"
    _choose_class(server_key)

func _choose_class(key: String) -> void:
    if not HERO_CATALOG.valid_key(key):
        return
    _selected_class_key = key
    var hero: Dictionary = HERO_CATALOG.hero_info(key)
    var nickname := str(account.get("ppaNickname", account.get("nickname", "Phoenix")))
    _name_label.text = nickname
    _class_label.text = str(hero.get("name", key)) + " · " + str(hero.get("role", ""))
    _info_label.text = str(hero.get("description", "")) + "\n\nВсе классы используют одну локальную тестовую сумку и склад. Реальный класс и прогресс PPA не изменяются."
    _enter_button.disabled = account.is_empty()
    _enter_button.text = "ВОЙТИ В МИРНЫЙ ГОРОД · ТЕСТ"
    for id in _class_buttons.keys():
        var button := _class_buttons[id] as Button
        if button != null:
            button.modulate = Color("#FFB375") if str(id) == key else Color("#B2BAC3")
    _status_label.text = "ЗАГРУЖАЕМ 3D-МОДЕЛЬ..."
    # Delay heavy GLB imports until the user actually selects a class.
    call_deferred("_load_preview")

func _confirm_preview() -> void:
    if account.is_empty():
        return
    # Only in SceneTree memory. The server never receives this class choice.
    get_tree().set_meta("ppa_native_test_class", _selected_class_key)
    get_tree().set_meta("ppa_native_test_mode", true)
    character_confirmed.emit()

func _load_preview() -> void:
    if not is_inside_tree():
        return
    var hero: Dictionary = HERO_CATALOG.hero_info(_selected_class_key)
    var scene_path := str(hero.get("model", ""))
    if not ResourceLoader.exists(scene_path):
        _status_label.text = "3D-МОДЕЛЬ ЕЩЁ НЕ УСТАНОВЛЕНА"
        return
    var resource = load(scene_path)
    if not (resource is PackedScene):
        _status_label.text = "ОШИБКА ЗАГРУЗКИ GLB"
        return

    if _preview_viewport == null:
        _preview_viewport = SubViewport.new()
        _preview_viewport.name = "CharacterPreviewViewport"
        _preview_viewport.transparent_bg = true
        _preview_viewport.own_world_3d = true
        _preview_viewport.size = Vector2i(340, 360)
        _preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        add_child(_preview_viewport)
        _preview_stage = Node3D.new()
        _preview_viewport.add_child(_preview_stage)
        var sun := DirectionalLight3D.new()
        sun.light_color = Color("#FFE7BC")
        sun.light_energy = 2.3
        sun.rotation_degrees = Vector3(-35, -30, 0)
        _preview_stage.add_child(sun)
        var light := DirectionalLight3D.new()
        light.light_color = Color("#95B4DA")
        light.light_energy = 0.9
        light.rotation_degrees = Vector3(-10, 130, 0)
        _preview_stage.add_child(light)
        _preview_camera = Camera3D.new()
        _preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
        _preview_camera.near = 0.05
        _preview_camera.far = 40.0
        _preview_stage.add_child(_preview_camera)
        _preview_camera.current = true
        _preview_host.texture = _preview_viewport.get_texture()

    if _preview_model != null:
        _preview_model.queue_free()
        _preview_model = null

    var model := (resource as PackedScene).instantiate() as Node3D
    if model == null:
        _status_label.text = "НЕТ 3D-УЗЛА ПЕРСОНАЖА"
        return
    _preview_stage.add_child(model)
    _preview_model = model

    var is_dwarf := _selected_class_key == "gnome"
    var target_height := 2.10 if is_dwarf else 2.48
    if not DWARF_FIT.fit(model, target_height):
        _status_label.text = "ОШИБКА РАЗМЕРОВ СКЕЛЕТА"
        model.queue_free()
        _preview_model = null
        return

    # Preserve the 0.1.31 dwarf framing (head fully visible).
    # Taller classes get extra breathing room without changing the city camera.
    _preview_camera.size = 4.00 if is_dwarf else 4.80
    var target_y := 1.85 if is_dwarf else 1.85
    _preview_camera.position = Vector3(4.0, target_y + 1.65, 6.0)
    _preview_camera.look_at(Vector3(0.0, target_y, 0.0), Vector3.UP)
    _status_label.text = "IDLE · 3D-ПРЕВЬЮ"

    var players = model.find_children("*", "AnimationPlayer", true, false)
    for obj in players:
        var player := obj as AnimationPlayer
        if player == null:
            continue
        for anim_name in player.get_animation_list():
            if str(anim_name).to_lower().contains("idle"):
                var clip := player.get_animation(anim_name)
                if clip != null:
                    clip.loop_mode = Animation.LOOP_LINEAR
                player.play(anim_name)
                return
    _status_label.text = "3D-МОДЕЛЬ ЗАГРУЖЕНА · БЕЗ IDLE"
