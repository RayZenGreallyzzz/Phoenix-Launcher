extends Control

# The SAME Telegram PPA 2.5D combat HUD layout, added as a native overlay.
# Rendering only. A button emits an intent; it never changes real HP, MP,
# inventory, player state, cooldowns, or Durable Object state locally.
signal action_requested(action: String, slot: int)

const GRIMOIRES = preload("res://scripts/ppa_grimoire_catalog_generated.gd")
const GOLD := Color("#AB7740")
const MAIN_RED := Color("#78252C")
const DARK := Color("#1B1516")
const GROUP_W := 232.0
const GROUP_H := 324.0

var _group: Control
var _vitals: VBoxContainer
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _xp_bar: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _xp_text: Label
var _hint: Label
var _skills: Array[Button] = []
var _ranks: Array[Label] = []
var _skill_defs: Array[Dictionary] = []
var _snapshot: Dictionary = {}
var _class_key := ""
var _training := false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_vitals()
    _build_actions()
    resized.connect(_layout)
    call_deferred("_layout")

func set_class_key(key: String) -> void:
    _class_key = key.to_lower().strip_edges()
    _refresh_skills()

func set_training(value: bool) -> void:
    _training = value
    if _vitals != null:
        _vitals.visible = not value
    _refresh_skills()

func apply_server_save(save: Dictionary) -> void:
    # Only the authenticated server save is allowed to update this HUD.
    _snapshot = save.duplicate(true)
    _refresh_vitals()
    _refresh_skills()

func clear_server_save() -> void:
    _snapshot.clear()
    _refresh_vitals()
    _refresh_skills()

func show_notice(message: String) -> void:
    if _hint != null:
        _hint.text = message.left(75)

func _flat(fill: Color, edge: Color, corners: int = 9) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = edge
    style.set_border_width_all(2)
    style.set_corner_radius_all(corners)
    return style

func _build_vitals() -> void:
    _vitals = VBoxContainer.new()
    _vitals.name = "OriginalPPAVitals"
    _vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _vitals.add_theme_constant_override("separation", 3)
    add_child(_vitals)
    var row_hp := _vital_row("HP", Color("#D6434B"))
    _hp_bar = row_hp["bar"]
    _hp_text = row_hp["text"]
    var row_mp := _vital_row("MP", Color("#3284D6"))
    _mp_bar = row_mp["bar"]
    _mp_text = row_mp["text"]
    var row_xp := _vital_row("XP", Color("#D4B23B"))
    _xp_bar = row_xp["bar"]
    _xp_text = row_xp["text"]
    _refresh_vitals()

func _vital_row(title: String, fill: Color) -> Dictionary:
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_theme_constant_override("separation", 5)
    row.custom_minimum_size = Vector2(224, 16)
    _vitals.add_child(row)
    var icon := Label.new()
    icon.text = title
    icon.custom_minimum_size.x = 24
    icon.add_theme_font_size_override("font_size", 10)
    icon.add_theme_color_override("font_color", Color("#F2E9DC"))
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(icon)
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(115, 11)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.max_value = 100.0
    bar.value = 0.0
    bar.add_theme_stylebox_override("background", _flat(Color("#131313"), Color("#514035"), 3))
    bar.add_theme_stylebox_override("fill", _flat(fill, fill.darkened(0.28), 3))
    row.add_child(bar)
    var info := Label.new()
    info.text = "—"
    info.custom_minimum_size.x = 61
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    info.add_theme_font_size_override("font_size", 9)
    info.add_theme_color_override("font_color", Color("#EFE4D7"))
    info.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(info)
    return {"bar":bar, "text":info}

func _number(save: Dictionary, keys: Array, default: float = -1.0) -> float:
    for key in keys:
        if save.has(key):
            var value: Variant = save[key]
            if value is int or value is float:
                return maxf(0.0, float(value))
            if value is String and str(value).is_valid_float():
                return maxf(0.0, float(value))
    return default

func _set_vital(bar: ProgressBar, text_label: Label, current: float, maximum: float) -> void:
    if current < 0 or maximum <= 0:
        bar.value = 0
        text_label.text = "—"
        return
    bar.value = clampf(current / maximum * 100.0, 0.0, 100.0)
    text_label.text = "%d/%d" % [int(current), int(maximum)]

func _refresh_vitals() -> void:
    if _hp_bar == null:
        return
    _set_vital(_hp_bar, _hp_text,
        _number(_snapshot, ["hp", "currentHp"]),
        _number(_snapshot, ["maxHp", "hpMax", "maxHP"]))
    _set_vital(_mp_bar, _mp_text,
        _number(_snapshot, ["mp", "currentMp"]),
        _number(_snapshot, ["maxMp", "mpMax", "maxMP"]))
    _set_vital(_xp_bar, _xp_text,
        _number(_snapshot, ["xp"]),
        _number(_snapshot, ["xpNext", "xpToNext", "nextXp"]))

func _build_actions() -> void:
    _group = Control.new()
    _group.name = "OriginalPPARightCombatControls"
    _group.size = Vector2(GROUP_W, GROUP_H)
    _group.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_group)
    _hint = Label.new()
    _hint.position = Vector2(-18, 4)
    _hint.size = Vector2(240, 40)
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hint.add_theme_font_size_override("font_size", 10)
    _hint.add_theme_color_override("font_color", Color("#F6D7A5"))
    _hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _group.add_child(_hint)
    _small_toggle("ПК", Vector2(115, 61), "pk")
    _small_toggle("АВТО", Vector2(173, 61), "auto")
    _small_round("HP", Vector2(132, 126), Color("#7E2328"), "potion_hp")
    _small_round("MP", Vector2(191, 126), Color("#183C83"), "potion_mp")
    # Original Telegram screenshot: four skills arc up/left from attack.
    for location in [Vector2(43, 282), Vector2(56, 223),
        Vector2(102, 181), Vector2(166, 169)]:
        var skill := _round("✦", location, 48.0, Color("#392419"), Color("#AA6C3C"))
        skill.pressed.connect(_emit_skill.bind(_skills.size()))
        _skills.append(skill)
        var rank := Label.new()
        rank.text = ""
        rank.position = Vector2(25, 31)
        rank.size = Vector2(21, 15)
        rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        rank.add_theme_font_size_override("font_size", 10)
        rank.add_theme_color_override("font_color", Color("#F0CD89"))
        rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
        skill.add_child(rank)
        _ranks.append(rank)
    var attack := _round("⚔", Vector2(145, 239), 80.0, MAIN_RED, Color("#D84E52"))
    attack.name = "PPAOriginalAttackButton"
    attack.add_theme_font_size_override("font_size", 30)
    attack.pressed.connect(func(): action_requested.emit("attack", -1))
    _refresh_skills()

func _round(label: String, pos: Vector2, diameter: float, fill: Color, edge: Color) -> Button:
    var button := Button.new()
    button.name = "PPACombatButton"
    button.text = label
    button.position = pos
    button.size = Vector2(diameter, diameter)
    button.custom_minimum_size = button.size
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.z_index = 32
    button.add_theme_font_size_override("font_size", 17)
    button.add_theme_color_override("font_color", Color("#FFE8C7"))
    button.add_theme_color_override("font_disabled_color", Color("#77716D"))
    button.add_theme_stylebox_override("normal", _flat(fill, edge, 100))
    button.add_theme_stylebox_override("hover", _flat(fill.lightened(0.15), edge, 100))
    button.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.2), edge, 100))
    button.add_theme_stylebox_override("disabled", _flat(Color("#252021"), Color("#564A40"), 100))
    _group.add_child(button)
    return button

func _small_toggle(title: String, pos: Vector2, action: String) -> void:
    var button := Button.new()
    button.text = title
    button.position = pos
    button.size = Vector2(51, 28)
    button.focus_mode = Control.FOCUS_NONE
    button.z_index = 32
    button.add_theme_font_size_override("font_size", 10)
    button.add_theme_color_override("font_color", Color("#D7BA87"))
    button.add_theme_stylebox_override("normal", _flat(DARK, GOLD, 6))
    button.add_theme_stylebox_override("pressed", _flat(Color("#3A2B21"), GOLD, 6))
    _group.add_child(button)
    button.pressed.connect(func(): action_requested.emit(action, -1))

func _small_round(title: String, pos: Vector2, fill: Color, action: String) -> void:
    var button := _round(title, pos, 44.0, fill, Color("#AD7C47"))
    button.add_theme_font_size_override("font_size", 13)
    button.pressed.connect(func(): action_requested.emit(action, -1))

func _emit_skill(index: int) -> void:
    action_requested.emit("skill", index)

func _refresh_skills() -> void:
    if _skills.is_empty():
        return
    var classes: Dictionary = GRIMOIRES.class_info(_class_key) if not _class_key.is_empty() else {}
    var catalog: Array = classes.get("active", [])
    var ranks: Dictionary = _snapshot.get("skillRanks", {}) if _snapshot.get("skillRanks", {}) is Dictionary else {}
    _skill_defs.clear()
    for index in range(4):
        var button := _skills[index]
        var data: Dictionary = catalog[index] if index < catalog.size() and catalog[index] is Dictionary else {}
        _skill_defs.append(data)
        var skill_id := str(data.get("id", ""))
        var rank := maxi(0, int(ranks.get(skill_id, 0))) if not skill_id.is_empty() else 0
        var skill_name := str(data.get("n", data.get("name", "")))
        button.tooltip_text = skill_name + " · ранг %d" % rank if rank > 0 else "Навык пока не изучен"
        button.text = "✦" if rank > 0 else "—"
        _ranks[index].text = "I" if rank == 1 else str(rank) if rank > 1 else ""
        button.disabled = rank <= 0
        var card_art := str(data.get("cardArt", ""))
        if rank > 0 and not card_art.is_empty() and ResourceLoader.exists(card_art):
            var texture := load(card_art) as Texture2D
            if texture != null:
                button.icon = texture
                button.expand_icon = true
        else:
            button.icon = null

func is_over_action_area(point: Vector2) -> bool:
    return _group != null and _group.visible and _group.get_global_rect().has_point(point)


func skill_info(index: int) -> Dictionary:
    return _skill_defs[index].duplicate(true) if index >= 0 and index < _skill_defs.size() else {}

func _layout() -> void:
    if _group == null or size.x < 1.0 or size.y < 1.0:
        return
    # Keep the approved tablet layout unchanged; shrink uniformly on phones.
    var factor := clampf(minf(size.x / 550.0, size.y / 640.0), 0.70, 1.0)
    _group.scale = Vector2.ONE * factor
    _group.position = Vector2(size.x - GROUP_W * factor - 12.0,
        size.y - GROUP_H * factor - 16.0)
    _vitals.scale = Vector2.ONE * clampf(size.x / 490.0, 0.77, 1.0)
    _vitals.position = Vector2(24.0, 112.0)
