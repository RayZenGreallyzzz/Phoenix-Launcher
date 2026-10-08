extends Control

# Lightweight local beta UI. No production trading, forging, purchases or
# save mutations happen here. Menu/stash persists across all 8 visual classes.
const HERO_CATALOG = preload("res://scripts/test_hero_catalog.gd")
const SHARED_STASH = preload("res://scripts/test_shared_storage.gd")
const NPC_CATALOG = preload("res://scripts/test_city_npcs.gd")
const SHOP_CATALOG = preload("res://scripts/test_shop_catalog.gd")

signal change_class_requested


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
var _selected_item_index := -1
var _selected_item_source := "bag"


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
        ["runes", "РУНЫ"],
        ["skills", "НАВЫКИ"],
        ["warehouse", "СКЛАД"]
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
    if not nearby_npc.is_empty():
        open_npc(nearby_npc)

func is_open() -> bool:
    return _panel != null and _panel.visible

func open_npc(npc: Dictionary) -> void:
    if npc.is_empty():
        return
    nearby_npc = npc.duplicate(true)
    match str(npc.get("service", "")):
        "storage":
            open_page("warehouse")
        "merchant", "blackmarket":
            open_page("shop")
        "forge":
            open_page("forge")
        "auction":
            open_page("auction")
        _:
            open_page("service")

func set_near_npc(npc: Dictionary) -> void:
    # Preserve the NPC whose shop is currently open, even if the player moves.
    if is_open():
        return
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
        "shop":
            _title.text = str(nearby_npc.get("name", "МАГАЗИН"))
            _show_shop()
        "forge":
            _title.text = "КУЗНИЦА"
            _show_forge()
        "auction":
            _title.text = "АУКЦИОН"
            _show_auction()
        "item":
            _title.text = "ПРЕДМЕТ · ИНВЕНТАРЬ"
            _show_item_details()
        "runes":
            _title.text = "СУМКА РУН"
            _show_runes()
        "skills":
            _title.text = "НАВЫКИ ПЕРСОНАЖА"
            _show_skills()
        "service":
            _title.text = str(nearby_npc.get("name", "NPC"))
            _show_service()
        _:
            _title.text = "МЕНЮ"
            _line("Раздел пока недоступен в native beta.")

# Character sheet with equipment slots, just like the in-game PPA flow.
# This entire page is a visual beta; no authoritative stats are fabricated.
func _show_character() -> void:
    var hero: Dictionary = HERO_CATALOG.hero_info(class_key)
    var nickname := str(account.get("ppaNickname", account.get("nickname", "Phoenix")))
    _line("ГЕРОЙ: " + nickname + "    ·    " + str(hero.get("name", "")), false, true)
    _line(str(hero.get("role", "")) + "    ·    " + str(hero.get("description", "")), true)
    _line("Основной класс Phoenix Account: " + str(account.get("classKey", "")), true)
    _spacer()
    _line("ЭКИПИРОВКА · ОБЩАЯ ТЕСТОВАЯ", false, true)
    var equipment_grid := GridContainer.new()
    equipment_grid.columns = 3
    equipment_grid.add_theme_constant_override("h_separation", 8)
    equipment_grid.add_theme_constant_override("v_separation", 8)
    _list.add_child(equipment_grid)
    for entry in SHOP_CATALOG.EQUIPMENT:
        var slot := str(entry.get("key", ""))
        var item: Dictionary = stash.equipment.get(slot, {})
        var button := Button.new()
        button.custom_minimum_size = Vector2(242, 64)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.text = str(entry.get("label", "")) + "\n" + (
            str(item.get("name", "ПУСТО")) +
            (" +" + str(item.get("upgrade")) if int(item.get("upgrade", 0)) > 0 else "")
        )
        button.add_theme_font_size_override("font_size", 12)
        if not item.is_empty():
            button.add_theme_color_override("font_color", SHOP_CATALOG.rarity_tint(str(item.get("rarity", "common"))))
        button.pressed.connect(_remove_equipment.bind(slot))
        equipment_grid.add_child(button)
    _spacer()
    _line("Характеристики и навыки настоящего персонажа появятся после подключения серверного сохранения.", true)
    _line("Это тестовый герой: никакие очки, уровни и характеристики реального аккаунта не меняются.", true)
    _spacer()
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 10)
    _list.add_child(actions)
    _action(actions, "СУМКА", func(): open_page("bag"))
    _action(actions, "СКЛАД", func(): open_page("warehouse"))
    _action(actions, "СМЕНИТЬ КЛАСС", func(): change_class_requested.emit())

func _action(parent: Control, title: String, pressed: Callable) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(138, 39)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 12)
    button.pressed.connect(pressed)
    parent.add_child(button)
    return button

func _inventory_tile(item: Dictionary, label_suffix: String = "") -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(122, 96)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 11)
    button.text = str(item.get("short", "◈")) + "\n" + str(item.get("name", "?")) + label_suffix
    var style := _button_style(Color("#1B252D"))
    style.border_color = SHOP_CATALOG.rarity_tint(str(item.get("rarity", "common")))
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_stylebox_override("hover", style)
    return button

func _show_items(source_name: String) -> void:
    var is_bag := source_name == "bag"
    var source: Array = stash.bag if is_bag else stash.warehouse
    _line("ОБЩИЙ " + ("ИНВЕНТАРЬ" if is_bag else "СКЛАД") + "  •  " + str(source.size()) + " / 64", false, true)
    _line("Все 8 классов используют одну локальную тестовую сумку и склад. Нажми на предмет.", true)
    _spacer()
    var grid := GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    _list.add_child(grid)
    for index in range(source.size()):
        var item: Dictionary = source[index]
        var tile := _inventory_tile(item, "\n×" + str(item.get("qty", 1)))
        tile.pressed.connect(_open_item.bind(source_name, index))
        grid.add_child(tile)
    # PPA-like empty slot placeholders make the inventory clearly readable.
    for empty in range(maxi(0, 15 - source.size())):
        var blank := PanelContainer.new()
        blank.custom_minimum_size = Vector2(122, 92)
        var style := _button_style(Color("#10171D"))
        style.border_color = Color("#30404C")
        blank.add_theme_stylebox_override("panel", style)
        grid.add_child(blank)
    _spacer()
    var actions := HBoxContainer.new()
    _list.add_child(actions)
    _action(actions, "ИНВЕНТАРЬ", func(): open_page("bag"))
    _action(actions, "СКЛАД", func(): open_page("warehouse"))
    _action(actions, "ТОРГОВЕЦ", func(): _open_service_by_id("merchant"))

func _open_item(source_name: String, index: int) -> void:
    _selected_item_source = source_name
    _selected_item_index = index
    open_page("item")

func _show_item_details() -> void:
    var from_bag := _selected_item_source == "bag"
    var items: Array = stash.bag if from_bag else stash.warehouse
    if _selected_item_index < 0 or _selected_item_index >= items.size():
        open_page("bag" if from_bag else "warehouse")
        return
    var item: Dictionary = items[_selected_item_index]
    _line(str(item.get("name", "")), false, true)
    _line("Количество: " + str(item.get("qty", 1)))
    _line("Редкость: " + str(item.get("rarity", "common")), true)
    _line("Это тестовый предмет; действие не изменит оригинальную PPA.", true)
    _spacer()
    var actions := HBoxContainer.new()
    _list.add_child(actions)
    if from_bag and not SHOP_CATALOG.equipment_slot(str(item.get("kind", ""))).is_empty():
        _action(actions, "НАДЕТЬ", _equip_selected)
    _action(actions, "В СКЛАД" if from_bag else "В СУМКУ", _transfer_selected)
    if from_bag:
        _action(actions, "ПРОДАТЬ", _sell_selected)
    var back := Button.new()
    back.text = "НАЗАД"
    back.custom_minimum_size = Vector2(0, 42)
    back.pressed.connect(open_page.bind("bag" if from_bag else "warehouse"))
    _list.add_child(back)

func _transfer_selected() -> void:
    var source_name := _selected_item_source
    if stash.move(source_name, _selected_item_index):
        open_page("bag" if source_name == "bag" else "warehouse")
        _notice.text = "Предмет перемещён в общий тестовый склад/инвентарь."
    else:
        _notice.text = "Нет места в целевом хранилище."

func _equip_selected() -> void:
    var message: String = stash.equip_test_item(_selected_item_index)
    open_page("character")
    _notice.text = message

func _sell_selected() -> void:
    var message: String = stash.sell_test_item(_selected_item_index)
    open_page("bag")
    _notice.text = message

func _remove_equipment(slot: String) -> void:
    var message: String = stash.unequip_test_item(slot)
    _refresh()
    _notice.text = message

func _show_runes() -> void:
    _line("РУНЫ · ТЕСТОВАЯ СУМКА", false, true)
    var runes := 0
    for item in stash.bag:
        if str(item.get("kind", "")) == "rune" or str(item.get("id", "")) == "test_rune":
            _line(str(item.get("name", "Руна")) + " ×" + str(item.get("qty", 1)))
            runes += 1
    if runes == 0:
        _line("В сумке рун пока пусто.")
    _spacer()
    _line("Вставка/слияние реальных рун отключена в тестовой сборке.", true)

func _show_skills() -> void:
    _line("НАВЫКИ · " + str(HERO_CATALOG.hero_info(class_key).get("name", "")), false, true)
    _spacer()
    for name in ["АКТИВНЫЕ НАВЫКИ", "ПАССИВНЫЕ НАВЫКИ", "РАНГИ КНИГ"]:
        _line(name + " · тестовый слот", true)
    _spacer()
    _line("Серверные книги, ранги и бонусы PPA не меняются при переключении классов.", true)

func _show_npcs() -> void:
    _line("9 NPC размещены по оригинальным координатам живой PPA.", true, true)
    _line("Подойди к NPC в городе и нажми «ПОГОВОРИТЬ».", true)
    _spacer()
    for npc in NPC_CATALOG.NPCS:
        _line(str(npc.get("name", "?")) + " · (" + str(int(npc.get("x", 0))) + ", " + str(int(npc.get("y", 0))) + ") исходного арта", true)

func _open_service_by_id(id: String) -> void:
    for npc in NPC_CATALOG.NPCS:
        if str(npc.get("id", "")) == id:
            open_npc(npc)
            return

func _show_shop() -> void:
    var service := str(nearby_npc.get("service", ""))
    var goods: Array = SHOP_CATALOG.goods(service)
    _line(str(nearby_npc.get("name", "МАГАЗИН")) + "     УЧЕБНЫЕ МОНЕТЫ: " + str(stash.coins), false, true)
    _line("Каталог для проверки интерфейса. Цены и покупки только тестовые; реальное золото и PPA не расходуются.", true)
    _spacer()
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 9)
    grid.add_theme_constant_override("v_separation", 9)
    _list.add_child(grid)
    for item in goods:
        var product: Dictionary = item
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(177, 153)
        var style := _button_style(Color("#17212A"))
        style.border_color = SHOP_CATALOG.rarity_tint(str(product.get("rarity", "common")))
        panel.add_theme_stylebox_override("panel", style)
        grid.add_child(panel)
        var column := VBoxContainer.new()
        column.add_theme_constant_override("separation", 4)
        panel.add_child(column)
        var item_name := Label.new()
        item_name.text = str(product.get("short", "")) + "  " + str(product.get("name", ""))
        item_name.add_theme_font_size_override("font_size", 12)
        item_name.add_theme_color_override("font_color", SHOP_CATALOG.rarity_tint(str(product.get("rarity", "common"))))
        item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        column.add_child(item_name)
        var description := Label.new()
        description.text = str(product.get("description", ""))
        description.add_theme_font_size_override("font_size", 10)
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.size_flags_vertical = Control.SIZE_EXPAND_FILL
        column.add_child(description)
        var price := Label.new()
        price.text = str(product.get("price", 0)) + " МОНЕТ"
        price.add_theme_font_size_override("font_size", 11)
        price.add_theme_color_override("font_color", Color("#F7C176"))
        column.add_child(price)
        var buy := Button.new()
        buy.text = "КУПИТЬ · ТЕСТ"
        buy.custom_minimum_size = Vector2(0, 32)
        buy.disabled = stash.coins < int(product.get("price", 0))
        buy.add_theme_font_size_override("font_size", 11)
        buy.pressed.connect(_buy_demo_item.bind(product))
        column.add_child(buy)
    _spacer()
    _line("Приобретённые учебные вещи сразу появятся в общей сумке.", true)
    var open_bag := Button.new()
    open_bag.text = "ОТКРЫТЬ СУМКУ"
    open_bag.custom_minimum_size = Vector2(0, 40)
    open_bag.pressed.connect(open_page.bind("bag"))
    _list.add_child(open_bag)

func _buy_demo_item(item: Dictionary) -> void:
    var message: String = stash.buy_test_item(item)
    _refresh()
    _notice.text = message

func _show_forge() -> void:
    _line("КУЗНЕЦ · ТЕСТОВАЯ ЗАТОЧКА", false, true)
    _line("Кузница проверяет слоты и действие, не меняя настоящие характеристики предметов PPA.", true)
    _spacer()
    var equipped: Dictionary = stash.equipment.get("weapon", {})
    _line("ОРУЖИЕ: " + (str(equipped.get("name", "")) if not equipped.is_empty() else "НЕТ"), false, true)
    _line("ТЕСТОВАЯ ЗАТОЧКА: " + str(equipped.get("upgrade", 0)) + " / 10", true)
    var enchant_count := 0
    for item in stash.bag:
        if str(item.get("id", "")) == "test_enchant":
            enchant_count = int(item.get("qty", 1))
            break
    _line("МАТЕРИАЛ В СУМКЕ: " + str(enchant_count))
    _spacer()
    var row := HBoxContainer.new()
    _list.add_child(row)
    _action(row, "ЭКИПИРОВКА", func(): open_page("character"))
    _action(row, "ЗАТОЧИТЬ · ТЕСТ", _sharpen_demo)
    _action(row, "МАТЕРИАЛЫ", func(): _open_service_by_id("blackmarket"))
    _spacer()
    _line("Заточка из тестового инвентаря только локальная. Серверный кузнец PPA не затрагивается.", true)

func _sharpen_demo() -> void:
    var result: String = stash.sharpen_test_weapon()
    _refresh()
    _notice.text = result

func _show_auction() -> void:
    _line("АУКЦИОН · ТЕСТОВЫЙ ИНТЕРФЕЙС", false, true)
    _line("Вкладки и переходы доступны для проверки. Сетевые торги, ставки и граммы не активны.", true)
    _spacer()
    var row := HBoxContainer.new()
    _list.add_child(row)
    _action(row, "ТОВАРЫ", func(): _notice.text = "Серверные лоты PPA пока не подключены.")
    _action(row, "МОИ ЛОТЫ", func(): _notice.text = "Тест: активных лотов нет.")
    _action(row, "ПРОДАТЬ", func(): open_page("bag"))
    _spacer()
    _line("НЕТ АКТИВНЫХ ТЕСТОВЫХ ЛОТОВ", true)
    _line("Продажу реальных предметов включим после подключения серверного аукциона.", true)

func _show_service() -> void:
    var name := str(nearby_npc.get("name", "NPC"))
    var service := str(nearby_npc.get("service", ""))
    _line(name, false, true)
    _spacer()
    match service:
        "arena":
            _line("АРЕНА PVP", false, true)
            _line("Кнопки подбора матча и выхода вернутся при переносе PvP-системы.", true)
        "clan":
            _line("КЛАНЫ · ЦИТАДЕЛЬ", false, true)
            _line("Создание, рейтинг, война и клан-босс будут работать после подключения серверных систем.", true)
        "dungeon":
            _line("ПОДЗЕМЕЛЬЕ · 1–60", false, true)
            _line("Вход и выбор этажей появятся после переноса подземелья и синхронизации прогресса.", true)
        "fartzone":
            _line("ФАРТ ЗОНА", false, true)
            _line("Зона добычи и кирки пока только в веб-версии PPA.", true)
        _:
            _line("Услуга NPC пока недоступна в native.", true)
    _spacer()
    _line("Временно здесь показывается меню услуги. Серверные переходы не выполняются.", true)
