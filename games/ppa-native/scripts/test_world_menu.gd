extends Control

# Lightweight local beta UI. No production trading, forging, purchases or
# save mutations happen here. Menu/stash persists across all 8 visual classes.
const HERO_CATALOG = preload("res://scripts/test_hero_catalog.gd")
const SHARED_STASH = preload("res://scripts/test_shared_storage.gd")

var account: Dictionary = {}
var class_key := "gnome"
var stash: RefCounted
var nearby_npc: Dictionary = {}
var current_page := "character"
var _background: ColorRect
var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _interact_button: Button
var _menu_button: Button
var _notice: Label

func configure(profile: Dictionary, selected_class: String) -> void:
    account = profile.duplicate(true)
    class_key = selected_class
    stash = SHARED_STASH.new(account)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if stash == null:
        stash = SHARED_STASH.new(account)
    _build_buttons()
    _build_window()
    _panel.visible = false
    _background.visible = false

func _button_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color("#B17A3F")
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    return style

func _build_buttons() -> void:
    _menu_button = Button.new()
    _menu_button.text = "МЕНЮ"
    _menu_button.anchor_left = 1.0
    _menu_button.anchor_right = 1.0
    _menu_button.offset_left = -150.0
    _menu_button.offset_right = -20.0
    _menu_button.offset_top = 142.0
    _menu_button.offset_bottom = 185.0
    _menu_button.z_index = 65
    _menu_button.add_theme_stylebox_override("normal", _button_style(Color("#35291E")))
    _menu_button.add_theme_color_override("font_color", Color("#F6E2CC"))
    _menu_button.pressed.connect(func(): open_page("character"))
    add_child(_menu_button)

    _interact_button = Button.new()
    _interact_button.text = "ПОГОВОРИТЬ"
    _interact_button.anchor_left = 1.0
    _interact_button.anchor_right = 1.0
    _interact_button.anchor_top = 1.0
    _interact_button.anchor_bottom = 1.0
    _interact_button.offset_left = -214.0
    _interact_button.offset_right = -20.0
    _interact_button.offset_top = -144.0
    _interact_button.offset_bottom = -96.0
    _interact_button.add_theme_stylebox_override("normal", _button_style(Color("#774318")))
    _interact_button.add_theme_color_override("font_color", Color.WHITE)
    _interact_button.z_index = 65
    _interact_button.visible = false
    _interact_button.pressed.connect(_interact)
    add_child(_interact_button)

func _build_window() -> void:
    _background = ColorRect.new()
    _background.color = Color(0.0, 0.0, 0.0, 0.70)
    _background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _background.mouse_filter = Control.MOUSE_FILTER_STOP
    _background.z_index = 90
    _background.gui_input.connect(_outside_input)
    add_child(_background)

    _panel = PanelContainer.new()
    _panel.anchor_left = 0.5
    _panel.anchor_right = 0.5
    _panel.anchor_top = 0.5
    _panel.anchor_bottom = 0.5
    _panel.offset_left = -430.0
    _panel.offset_right = 430.0
    _panel.offset_top = -263.0
    _panel.offset_bottom = 263.0
    _panel.z_index = 95
    _panel.add_theme_stylebox_override("panel", _button_style(Color(0.055, 0.066, 0.078, 0.98)))
    add_child(_panel)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 16)
    margins.add_theme_constant_override("margin_right", 16)
    margins.add_theme_constant_override("margin_top", 12)
    margins.add_theme_constant_override("margin_bottom", 12)
    _panel.add_child(margins)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    margins.add_child(column)

    var header := HBoxContainer.new()
    column.add_child(header)
    _title = Label.new()
    _title.text = "МЕНЮ ПЕРСОНАЖА"
    _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title.add_theme_font_size_override("font_size", 21)
    _title.add_theme_color_override("font_color", Color("#F5D1AB"))
    header.add_child(_title)
    var close_button := Button.new()
    close_button.text = "✕"
    close_button.custom_minimum_size = Vector2(48.0, 34.0)
    close_button.pressed.connect(close_menu)
    header.add_child(close_button)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 7)
    column.add_child(tabs)
    for spec in [
        ["character", "ПЕРСОНАЖ"],
        ["bag", "ИНВЕНТАРЬ"],
        ["warehouse", "СКЛАД"],
        ["npcs", "NPC ГОРОДА"]
    ]:
        var b := Button.new()
        b.text = str(spec[1])
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.custom_minimum_size = Vector2(0.0, 38.0)
        b.add_theme_stylebox_override("normal", _button_style(Color("#2F3034")))
        b.pressed.connect(open_page.bind(str(spec[0])))
        tabs.add_child(b)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)

    _list = VBoxContainer.new()
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.add_theme_constant_override("separation", 8)
    scroll.add_child(_list)

    _notice = Label.new()
    _notice.text = "ТЕСТОВОЕ МЕНЮ · ПРЕДМЕТЫ НЕ СВЯЗАНЫ С БОЕВОЙ PPA"
    _notice.add_theme_color_override("font_color", Color("#C69B72"))
    _notice.add_theme_font_size_override("font_size", 11)
    column.add_child(_notice)

func _outside_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.pressed:
            close_menu()
    elif event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            close_menu()

func _interact() -> void:
    if nearby_npc.is_empty():
        return
    var service := str(nearby_npc.get("service", ""))
    if service == "storage":
        open_page("warehouse")
    else:
        open_page("service")

func set_near_npc(npc: Dictionary) -> void:
    var old_id := str(nearby_npc.get("id", ""))
    var new_id := str(npc.get("id", ""))
    if new_id == old_id:
        return
    nearby_npc = npc.duplicate(true)
    _interact_button.visible = not new_id.is_empty()
    _interact_button.text = "ПОГОВОРИТЬ" if new_id.is_empty() else "NPC · " + str(npc.get("name", ""))

func open_page(page: String) -> void:
    current_page = page
    _panel.visible = true
    _background.visible = true
    _refresh()

func close_menu() -> void:
    _panel.visible = false
    _background.visible = false

func _clear() -> void:
    for node in _list.get_children():
        _list.remove_child(node)
        node.queue_free()

func _line(value: String, small: bool = false, accent: bool = false) -> void:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 13 if small else 16)
    label.add_theme_color_override("font_color", Color("#E8B67F") if accent else Color("#DFE6EA"))
    _list.add_child(label)

func _spacer() -> void:
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(1.0, 8.0)
    _list.add_child(spacer)

func _refresh() -> void:
    if _list == null:
        return
    _clear()
    match current_page:
        "character":
            _title.text = "ПЕРСОНАЖ · ТЕСТ"
            _show_character()
        "bag":
            _title.text = "ОБЩИЙ ТЕСТОВЫЙ ИНВЕНТАРЬ"
            _show_items("bag")
        "warehouse":
            _title.text = "ОБЩИЙ ТЕСТОВЫЙ СКЛАД"
            _show_items("warehouse")
        "npcs":
            _title.text = "NPC МИРНОГО ГОРОДА"
            _show_npcs()
        "service":
            _title.text = str(nearby_npc.get("name", "NPC"))
            _show_service()
        _:
            _title.text = "МЕНЮ"
            _line("Раздел пока недоступен в native beta.")

func _show_character() -> void:
    var hero: Dictionary = HERO_CATALOG.get_class(class_key)
    var nickname := str(account.get("ppaNickname", account.get("nickname", "Phoenix")))
    var server_class := str(account.get("classKey", ""))
    _line("Ник: " + nickname, false, true)
    _line("Тестовый 3D-класс: " + str(hero.get("name", "")))
    _line("Роль: " + str(hero.get("role", "")), true)
    _line(str(hero.get("description", "")), true)
    _spacer()
    _line("Класс на сервере PPA: " + server_class, true)
    _line("Уровень, характеристики и экипировка сервера пока не загружены.", true)
    _line("Смена класса в этой сборке влияет только на модель и анимацию.", true)
    _spacer()
    var bag_button := Button.new()
    bag_button.text = "ОТКРЫТЬ ОБЩИЙ ИНВЕНТАРЬ"
    bag_button.custom_minimum_size = Vector2(0, 44)
    bag_button.pressed.connect(open_page.bind("bag"))
    _list.add_child(bag_button)
    var storage_button := Button.new()
    storage_button.text = "ОТКРЫТЬ СКЛАД"
    storage_button.custom_minimum_size = Vector2(0, 44)
    storage_button.pressed.connect(open_page.bind("warehouse"))
    _list.add_child(storage_button)

func _show_items(source_name: String) -> void:
    var is_bag := source_name == "bag"
    var source: Array = stash.bag if is_bag else stash.warehouse
    var other: Array = stash.warehouse if is_bag else stash.bag
    var destination_name := "В СКЛАД" if is_bag else "В СУМКУ"
    _line("Общая тестовая " + ("сумка" if is_bag else "кладовая") + " · " + str(source.size()) + " / 64", false, true)
    _line("Доступна всем восьми выбранным классам. Это отдельные тестовые вещи, а не реальный инвентарь PPA.", true)
    _spacer()
    if source.is_empty():
        _line("Пока пусто. Переложи предметы из другого раздела.", true)
    for index in range(source.size()):
        var item: Dictionary = source[index]
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        _list.add_child(row)
        var caption := Label.new()
        caption.text = str(item.get("name", "?")) + " ×" + str(item.get("qty", 1))
        caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        caption.add_theme_font_size_override("font_size", 14)
        row.add_child(caption)
        var button := Button.new()
        button.text = destination_name
        button.custom_minimum_size = Vector2(156, 38)
        button.disabled = other.size() >= 64
        button.pressed.connect(_move_item.bind(source_name, index))
        row.add_child(button)
    _spacer()
    var switch_button := Button.new()
    switch_button.text = "ПЕРЕЙТИ: " + ("СКЛАД" if is_bag else "ИНВЕНТАРЬ")
    switch_button.custom_minimum_size = Vector2(0, 42)
    switch_button.pressed.connect(open_page.bind("warehouse" if is_bag else "bag"))
    _list.add_child(switch_button)

func _move_item(source_name: String, index: int) -> void:
    if stash.move(source_name, index):
        _refresh()
    else:
        _notice.text = "Нет места или предмет уже перемещён."

func _show_npcs() -> void:
    _line("9 NPC размещены по оригинальным координатам живой PPA.", true, true)
    _line("Подойди к NPC в городе и нажми «ПОГОВОРИТЬ».", true)
    _spacer()
    const NPC_CATALOG = preload("res://scripts/test_city_npcs.gd")
    for npc in NPC_CATALOG.NPCS:
        _line(str(npc.get("name", "?")) + " · (" + str(int(npc.get("x", 0))) + ", " + str(int(npc.get("y", 0))) + ") исходного арта", true)

func _show_service() -> void:
    var name := str(nearby_npc.get("name", "NPC"))
    var service := str(nearby_npc.get("service", ""))
    _line("Вы разговариваете с NPC: " + name, false, true)
    _spacer()
    if service == "forge":
        _line("Кузница: точка взаимодействия проверяется. Настоящая заточка будет подключена отдельно.", true)
    elif service == "merchant":
        _line("Торговец: тестовая точка. Покупки и продажа реальных предметов отключены.", true)
    elif service == "auction" or service == "blackmarket":
        _line("Торговая площадка: тестовая точка. Боевой аукцион и платежи не меняются.", true)
    elif service == "arena":
        _line("Арена: точка входа. Реальный PvP-клиент подключим после проверки классов.", true)
    elif service == "clan":
        _line("Кланы: NPC на штатной позиции. Серверный функционал не затронут.", true)
    elif service == "dungeon":
        _line("Подземелье: точка входа. Карта данжа пока не перенесена в native.", true)
    elif service == "fartzone":
        _line("Фарт-зона: точка входа. Добыча пока доступна только в прежней PPA.", true)
    else:
        _line("Сервис будет подключён после тестирования города.", true)
    _spacer()
    _line("В этой сборке NPC не выполняют серверные транзакции.", true)
