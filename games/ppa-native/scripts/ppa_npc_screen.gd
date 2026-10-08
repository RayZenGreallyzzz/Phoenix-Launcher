extends Control

# Nine original Peace City NPC services, ONE native Godot screen. No player
# character frame, WebView, fake economy or server mutations in this UI.
# All actions that would change the live save remain locked until an
# authenticated Phoenix/PPA service adapter is implemented and verified.
signal close_requested
signal authoritative_state_requested(service: String)

const SHOP = preload("res://scripts/test_shop_catalog.gd")
const SERVICES := ["merchant", "forge", "storage", "auction", "clan", "arena", "blackmarket", "dungeon", "fartzone"]
const GOLD := Color("#F6C66F")
const TEXT := Color("#E5E4DE")
const SUB := Color("#9FA8AB")
const EDGE := Color("#94642E")
const BG := Color("#101519")
const HEAD := Color("#211A15")

var npc: Dictionary = {}
var service := ""
var tab := ""
var selected_id := ""
var quantity := 1
var authoritative: Dictionary = {}
var has_verified_state := false
var _shade: ColorRect
var _frame: PanelContainer
var _heading: Label
var _subheading: Label
var _portrait: TextureRect
var _tabs: HFlowContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _status: Label

func _ready() -> void:
    name = "PPANativeNpcMenu"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _create_shell()
    visible = false
    resized.connect(_fit)

func _style(bg: Color, edge: Color = EDGE, radius: int = 8, thickness: int = 1) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = edge
    s.set_border_width_all(thickness)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 9
    s.content_margin_right = 9
    s.content_margin_top = 7
    s.content_margin_bottom = 7
    return s

func _label(value: String, font_size: int = 13, color: Color = TEXT) -> Label:
    var l := Label.new()
    l.text = value
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_color_override("font_color", color)
    l.add_theme_font_size_override("font_size", font_size)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _button(value: String, enabled: bool = true) -> Button:
    var b := Button.new()
    b.text = value
    b.custom_minimum_size.y = 36
    b.add_theme_font_size_override("font_size", 12)
    b.add_theme_color_override("font_color", GOLD)
    b.add_theme_color_override("font_disabled_color", Color("#86878A"))
    b.add_theme_stylebox_override("normal", _style(Color("#24201B"), EDGE))
    b.add_theme_stylebox_override("hover", _style(Color("#382919"), Color("#D49C4A")))
    b.add_theme_stylebox_override("pressed", _style(Color("#171310"), GOLD))
    b.add_theme_stylebox_override("disabled", _style(Color("#191B1F"), Color("#414348")))
    b.disabled = not enabled
    return b

func _create_shell() -> void:
    _shade = ColorRect.new()
    _shade.name = "NpcBackdrop"
    _shade.color = Color(0.0, 0.0, 0.0, 0.76)
    _shade.mouse_filter = Control.MOUSE_FILTER_STOP
    _shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _shade.gui_input.connect(_outside)
    add_child(_shade)

    _frame = PanelContainer.new()
    _frame.name = "OnlyNpcWindow"
    _frame.anchor_left = 0.5
    _frame.anchor_right = 0.5
    _frame.anchor_top = 0.5
    _frame.anchor_bottom = 0.5
    _frame.mouse_filter = Control.MOUSE_FILTER_STOP
    _frame.add_theme_stylebox_override("panel", _style(BG, EDGE, 13, 2))
    add_child(_frame)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 8)
    _frame.add_child(margin)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 7)
    margin.add_child(layout)

    var header := PanelContainer.new()
    header.custom_minimum_size.y = 77
    header.add_theme_stylebox_override("panel", _style(HEAD, Color("#8D5824"), 8))
    layout.add_child(header)
    var title_row := HBoxContainer.new()
    title_row.add_theme_constant_override("separation", 10)
    header.add_child(title_row)
    _portrait = TextureRect.new()
    _portrait.name = "CurrentNpcPortrait"
    _portrait.custom_minimum_size = Vector2(52, 59)
    _portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_row.add_child(_portrait)
    var headings := VBoxContainer.new()
    headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    headings.add_theme_constant_override("separation", 4)
    title_row.add_child(headings)
    _heading = _label("NPC", 19, GOLD)
    headings.add_child(_heading)
    _subheading = _label("Phoenix Pix Arena · Мирный город", 10, SUB)
    headings.add_child(_subheading)
    var close := _button("✕")
    close.name = "CloseNpcOnly"
    close.custom_minimum_size = Vector2(39, 37)
    close.pressed.connect(func(): close_requested.emit())
    title_row.add_child(close)

    _tabs = HFlowContainer.new()
    _tabs.name = "NpcOnlyCategoryTabs"
    _tabs.add_theme_constant_override("h_separation", 6)
    _tabs.add_theme_constant_override("v_separation", 5)
    layout.add_child(_tabs)

    var rule := ColorRect.new()
    rule.custom_minimum_size.y = 1
    rule.color = Color("#714E28")
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layout.add_child(rule)

    _scroll = ScrollContainer.new()
    _scroll.name = "NpcOnlyScroll"
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(_scroll)
    var scroller_margin := MarginContainer.new()
    scroller_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroller_margin.add_theme_constant_override("margin_left", 5)
    scroller_margin.add_theme_constant_override("margin_right", 10)
    scroller_margin.add_theme_constant_override("margin_top", 6)
    scroller_margin.add_theme_constant_override("margin_bottom", 12)
    _scroll.add_child(scroller_margin)
    _body = VBoxContainer.new()
    _body.name = "CurrentNpcContent"
    _body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _body.add_theme_constant_override("separation", 10)
    scroller_margin.add_child(_body)

    var foot := PanelContainer.new()
    foot.add_theme_stylebox_override("panel", _style(Color("#171B1E"), Color("#494033"), 6))
    layout.add_child(foot)
    _status = _label("PPA · ожидаем данные игрового сервера", 10, Color("#BEAE94"))
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    foot.add_child(_status)
    _fit()

func _fit() -> void:
    if _frame == null or size.x <= 2 or size.y <= 2:
        return
    var landscape := size.x > size.y
    var w := minf(size.x * (0.92 if landscape else 0.94), 980.0)
    var h := minf(size.y * (0.94 if landscape else 0.91), 690.0)
    _frame.offset_left = -w / 2.0
    _frame.offset_right = w / 2.0
    _frame.offset_top = -h / 2.0
    _frame.offset_bottom = h / 2.0

func _outside(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        close_requested.emit()
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        close_requested.emit()
        accept_event()

func is_open() -> bool:
    return visible

func open_npc(source: Dictionary) -> void:
    var requested := str(source.get("service", ""))
    if not SERVICES.has(requested):
        push_warning("Unknown PPA NPC service: " + requested)
        return
    npc = source.duplicate(true)
    service = requested
    tab = _default_tab(service)
    selected_id = ""
    quantity = 1
    authoritative.clear()
    has_verified_state = false
    visible = true
    _fit()
    _render()
    authoritative_state_requested.emit(service)

func close_npc() -> void:
    visible = false
    authoritative.clear()
    has_verified_state = false

# Read-only future bridge contract. Call ONLY after authenticated server
# account+service validation; rendering these fields is not permission to buy.
func apply_authoritative_snapshot(snapshot: Dictionary) -> void:
    if not visible or str(snapshot.get("service", "")) != service:
        return
    if not snapshot.has("data") or not (snapshot["data"] is Dictionary):
        return
    authoritative = (snapshot["data"] as Dictionary).duplicate(true)
    has_verified_state = true
    _render()

func _default_tab(which: String) -> String:
    match which:
        "merchant": return "potions"
        "forge": return "enhance"
        "auction": return "all"
        "clan": return "my"
        "arena": return "fights"
        "blackmarket": return "all"
        "dungeon": return "floors"
        "fartzone": return "about"
        _: return "storage"

func _tab_specs() -> Array:
    match service:
        "merchant": return SHOP.MERCHANT_TABS
        "forge": return SHOP.SMITH_TABS
        "blackmarket": return SHOP.BM_CATEGORIES
        "storage": return [{"key":"storage","label":"ХРАНИЛИЩЕ"}]
        "auction": return [{"key":"all","label":"ТОРГИ"}, {"key":"mine","label":"МОИ ЛОТЫ"}, {"key":"sell","label":"ПРОДАЖА"}]
        "clan": return [{"key":"my","label":"МОЙ КЛАН"}, {"key":"list","label":"КЛАНЫ"}, {"key":"rank","label":"РЕЙТИНГ"}, {"key":"boss","label":"КЛАН-БОСС"}]
        "arena": return [{"key":"fights","label":"БОИ"}, {"key":"rating","label":"РЕЙТИНГ"}, {"key":"rewards","label":"НАГРАДЫ"}]
        "dungeon": return [{"key":"floors","label":"ЭТАЖИ"}, {"key":"bosses","label":"БОССЫ"}, {"key":"rewards","label":"ДОБЫЧА"}]
        "fartzone": return [{"key":"about","label":"О ЗОНЕ"}, {"key":"mining","label":"ДОБЫЧА"}, {"key":"guards","label":"СТРАЖИ"}]
        _: return []

func _select_tab(key: String) -> void:
    tab = key
    selected_id = ""
    quantity = 1
    _render()

func _select_item(id: String) -> void:
    selected_id = id
    quantity = 1
    _render()

func _change_quantity(by: int) -> void:
    quantity = clampi(quantity + by, 1, 999)
    _render()

func _clear(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()

func _render() -> void:
    if not is_node_ready() or not visible:
        return
    _clear(_tabs)
    _clear(_body)
    _heading.text = str(npc.get("name", "NPC"))
    _subheading.text = "МИРНЫЙ ГОРОД · " + _service_name()
    _portrait.texture = null
    var portrait_path := str(npc.get("image", ""))
    if ResourceLoader.exists(portrait_path):
        _portrait.texture = load(portrait_path) as Texture2D
    for entry in _tab_specs():
        var id := str(entry.get("key", ""))
        var b := _button(str(entry.get("label", "")))
        b.name = "NpcTab_" + id
        b.add_theme_color_override("font_color", GOLD if id == tab else SUB)
        b.add_theme_stylebox_override("normal", _style(Color("#44301D") if id == tab else Color("#191B1E"),
            GOLD if id == tab else Color("#66513B"), 6))
        b.pressed.connect(_select_tab.bind(id))
        _tabs.add_child(b)
    match service:
        "merchant": _show_merchant()
        "blackmarket": _show_blackmarket()
        "forge": _show_forge()
        "storage": _show_storage()
        "auction": _show_auction()
        "clan": _show_clan()
        "arena": _show_arena()
        "dungeon": _show_dungeon()
        "fartzone": _show_fartzone()
    _status.text = "PPA · серверные операции заблокированы до синхронизации"
    if has_verified_state:
        _status.text = "PPA · данные получены · операции пока недоступны"
    _scroll.set_deferred("scroll_vertical", 0)

func _service_name() -> String:
    match service:
        "merchant": return "ТОРГОВЛЯ"
        "blackmarket": return "РЕДКИЕ ПРЕДМЕТЫ"
        "forge": return "КУЗНИЦА"
        "storage": return "СКЛАД"
        "auction": return "АУКЦИОН"
        "clan": return "КЛАНЫ"
        "arena": return "PVP"
        "dungeon": return "ПОДЗЕМЕЛЬЕ"
        "fartzone": return "ФАРТ-ЗОНА"
        _: return "УСЛУГИ"

func _section(title: String, note: String = "") -> void:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _style(Color("#241B13"), Color("#77502B"), 5))
    _body.add_child(p)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 4)
    p.add_child(v)
    v.add_child(_label(title, 16, GOLD))
    if not note.is_empty():
        v.add_child(_label(note, 11, SUB))

func _message(title: String, detail: String, tint: Color = EDGE) -> void:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _style(Color("#151B1F"), tint, 8))
    _body.add_child(p)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 7)
    p.add_child(col)
    col.add_child(_label(title, 15, GOLD))
    col.add_child(_label(detail, 12, SUB))

func _locked_action(label_text: String) -> void:
    var b := _button(label_text + " · НУЖЕН СЕРВЕР", false)
    b.name = "ServerActionLocked"
    _body.add_child(b)

func _item_picture(path: String, side: float = 64.0) -> TextureRect:
    var p := TextureRect.new()
    p.custom_minimum_size = Vector2(side, side)
    p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(path):
        p.texture = load(path) as Texture2D
    return p

func _slot_grid(container: VBoxContainer, count: int, tag: String = "") -> void:
    var grid := GridContainer.new()
    grid.name = "NpcItemSlotGrid_" + tag
    grid.columns = 5 if _frame.size.x > 410 else 4
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    container.add_child(grid)
    var cell := minf(76.0, maxf(48.0, (_frame.size.x - 105.0) / float(grid.columns)))
    for i in range(count):
        var blank := PanelContainer.new()
        blank.custom_minimum_size = Vector2(cell, cell)
        blank.add_theme_stylebox_override("panel", _style(Color("#101518"), Color("#554532"), 5))
        grid.add_child(blank)

func _product_grid(products: Array, is_merchant: bool) -> void:
    var grid := GridContainer.new()
    grid.name = "NpcProductGrid"
    grid.columns = 3 if _frame.size.x > 670 else 2
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    _body.add_child(grid)
    if products.is_empty():
        _message("ПОКА НЕТ ПРЕДЛОЖЕНИЙ", "Ассортимент этого раздела поступит с сервера PPA.")
        return
    for entry in products:
        var item: Dictionary = entry
        var id := str(item.get("id", ""))
        var tile := PanelContainer.new()
        tile.name = "NpcProduct_" + id
        tile.custom_minimum_size.y = 140
        tile.add_theme_stylebox_override("panel", _style(Color("#161B1F"),
            GOLD if id == selected_id else Color("#5E4B35"), 7))
        grid.add_child(tile)
        var inner := VBoxContainer.new()
        inner.add_theme_constant_override("separation", 4)
        tile.add_child(inner)
        if is_merchant:
            inner.add_child(_item_picture(str(item.get("img", "")), 50))
        inner.add_child(_label(str(item.get("name", "")), 12, TEXT))
        var currency := " PPA" if str(item.get("currency", "")) == "ppa" else " Gold"
        inner.add_child(_label(str(item.get("price", 0)) + currency, 12, GOLD))
        var choice := _button("ПОДРОБНЕЕ")
        choice.name = "SelectNpcItem_" + id
        choice.pressed.connect(_select_item.bind(id))
        inner.add_child(choice)

func _selected_details(products: Array, with_quantity: bool) -> void:
    var item: Dictionary = {}
    for row in products:
        if str(row.get("id", "")) == selected_id:
            item = row
            break
    if item.is_empty():
        _message("ВЫБЕРИ ПРЕДМЕТ", "Нажми «Подробнее» на карточке, чтобы посмотреть описание и стоимость.")
        _locked_action("КУПИТЬ")
        return
    _section("ПРЕДМЕТ · " + str(item.get("name", "")))
    if item.has("img"):
        _body.add_child(_item_picture(str(item.get("img", "")), 82))
    _body.add_child(_label(str(item.get("desc", "")), 13))
    var suffix := " PPA" if str(item.get("currency", "")) == "ppa" else " Gold"
    _body.add_child(_label("Цена: " + str(item.get("price", 0)) + suffix, 15, GOLD))
    if with_quantity:
        var row := HBoxContainer.new()
        _body.add_child(row)
        var minus := _button("−")
        minus.pressed.connect(_change_quantity.bind(-1))
        row.add_child(minus)
        var count := _label("   ×" + str(quantity) + "   ", 15, TEXT)
        count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        row.add_child(count)
        var plus := _button("+")
        plus.pressed.connect(_change_quantity.bind(1))
        row.add_child(plus)
        _body.add_child(_label("Итого: " + str(int(item.get("price", 0)) * quantity) + suffix, 14, GOLD))
    _locked_action("КУПИТЬ")

func _show_merchant() -> void:
    _section("ЛАВКА ТОРГОВЦА", "Оригинальные 12 товаров PPA · просмотр без списания валюты")
    var filtered: Array = []
    for entry in SHOP.MERCHANT:
        if str(entry.get("tab", "")) == tab:
            filtered.append(entry)
    _product_grid(filtered, true)
    _selected_details(filtered, true)
    _body.add_child(_label("Баланс Gold / PPA: — · будет получен с сервера", 11, SUB))

func _show_blackmarket() -> void:
    _section("ЧЁРНЫЙ РЫНОК", "Ассортимент PPA персональный и меняется на сервере")
    var listed: Array = []
    if has_verified_state and authoritative.get("offers", null) is Array:
        # The server data remains read-only; ID/price belong to that snapshot.
        listed = authoritative.get("offers", [])
    else:
        _message("ПРИМЕРЫ ПОСТОЯННЫХ ТОВАРОВ", "Это справочные цены из PPA, не доступные сейчас лоты.")
        listed = SHOP.BLACK_MARKET_REFERENCE
    var filtered: Array = []
    for entry in listed:
        if not (entry is Dictionary):
            continue
        if tab == "all" or str(entry.get("category", "")) == tab:
            filtered.append(entry)
    _product_grid(filtered, false)
    _selected_details(filtered, false)
    _locked_action("ПОКУПКА / СКУПКА")

func _show_forge() -> void:
    _section("КУЗНЕЦ · " + tab.to_upper(), "Схема подготавливается под настоящий серверный инвентарь PPA")
    if tab == "enhance":
        _message("ЗАТОЧКА ЭКИПИРОВКИ", "Выбери предмет, камень и подходящие руны после получения серверного инвентаря.")
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 9)
        _body.add_child(row)
        for name in ["ВЕЩЬ", "КАМЕНЬ", "РУНА"]:
            var slot := PanelContainer.new()
            slot.custom_minimum_size = Vector2(125, 100)
            slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            slot.add_theme_stylebox_override("panel", _style(Color("#171A1F"), EDGE))
            row.add_child(slot)
            slot.add_child(_label(name + "\n\n◇", 12, GOLD))
        _body.add_child(_label("Шанс / расход / результат: — (рассчитывает сервер)", 12, SUB))
        _locked_action("ЗАТОЧИТЬ")
    else:
        var names := {"equipment":"СНАРЯЖЕНИЕ", "legendary":"ЛЕГЕНДАРНОЕ СНАРЯЖЕНИЕ",
            "accessories":"АКСЕССУАРЫ", "pets":"ПИТОМЦЫ"}
        _message(str(names.get(tab, "КРАФТ")), "Каталог рецептов и требования будут показаны по подтверждённым данным PPA.")
        _slot_grid(_body, 10, "forge")
        _locked_action("СОЗДАТЬ")
    _body.add_child(_label("Ни один ресурс или предмет не меняется локально.", 11, SUB))

func _show_storage() -> void:
    _section("СКЛАД ПЕРСОНАЖА", "Один склад PPA для Telegram и Native после подключения аккаунта")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    _body.add_child(row)
    for part in ["ИНВЕНТАРЬ", "ХРАНИЛИЩЕ"]:
        var box := VBoxContainer.new()
        box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(box)
        box.add_child(_label(part, 14, GOLD))
        var area := PanelContainer.new()
        area.custom_minimum_size.y = 154
        area.add_theme_stylebox_override("panel", _style(Color("#12191D"), Color("#52412C")))
        box.add_child(area)
        area.add_child(_label("—\nОжидаем серверные предметы", 12, SUB))
    _message("ПЕРЕМЕЩЕНИЕ ПРЕДМЕТОВ", "Положить и забрать можно будет только по подтверждённому запросу к серверу, без локальных копий.")
    _locked_action("ПОЛОЖИТЬ / ЗАБРАТЬ")

func _show_auction() -> void:
    var heading := {"all":"ТОРГИ", "mine":"МОИ ЛОТЫ", "sell":"ВЫСТАВИТЬ ПРЕДМЕТ"}
    _section("АУКЦИОН · " + str(heading.get(tab, "")), "Лоты и ставки хранятся на сервере PPA")
    if tab == "all":
        _message("ОЖИДАНИЕ АКТИВНЫХ ЛОТОВ", "После синхронизации здесь появятся реальные товары, фильтры и цены.")
        _locked_action("КУПИТЬ")
    elif tab == "mine":
        _message("МОИ ЛОТЫ", "Сервер должен вернуть выставленные предметы и число свободных слотов.")
        _locked_action("СНЯТЬ ЛОТ")
    else:
        _message("ПРОДАЖА", "Выбор вещи из подтверждённого серверного инвентаря и установка цены.")
        _slot_grid(_body, 5, "auction")
        _locked_action("ВЫСТАВИТЬ")
    _body.add_child(_label("Валюта аукциона и комиссия берутся только из PPA.", 11, SUB))

func _show_clan() -> void:
    var title := {"my":"МОЙ КЛАН", "list":"СПИСОК КЛАНОВ",
        "rank":"РЕЙТИНГ КЛАНОВ", "boss":"КЛАНОВЫЙ БОСС"}
    _section(str(title.get(tab, "КЛАНЫ")), "Общий сервер: участники, казна, войны и награды")
    match tab:
        "my": _message("КЛАН ПЕРСОНАЖА", "Имя, состав, бонусы и хранилище будут загружены из PPA.")
        "list": _message("КАТАЛОГ КЛАНОВ", "Реальные заявки и список кланов появятся после подключения.")
        "rank": _message("ТАБЛИЦА ЛИДЕРОВ", "Рейтинг не подменяется тестовыми числами.")
        "boss": _message("БОСС · ВКЛАД · НАГРАДЫ", "Урон, сундук и распределение наград считает сервер PPA.")
    _locked_action("КЛАНОВОЕ ДЕЙСТВИЕ")

func _show_arena() -> void:
    var title := {"fights":"PVP АРЕНА", "rating":"РЕЙТИНГ АРЕНЫ", "rewards":"НАГРАДЫ"}
    _section(str(title.get(tab, "АРЕНА")), "Настоящий подбор соперников — через PPA")
    match tab:
        "fights": _message("ПОИСК СОПЕРНИКА", "Автоподбор, бой и завершение матча будут синхронизированы через сервер.")
        "rating": _message("РЕЙТИНГ И ИСТОРИЯ", "Победы, поражения и позиции приходят из PPA.")
        "rewards": _message("НАГРАДЫ АРЕНЫ", "Доступны после подтверждения сервером.")
    _locked_action("НАЧАТЬ ПОИСК")

func _show_dungeon() -> void:
    _section("ПОДЗЕМЕЛЬЕ 1–60", "Доступ к этажам и убийства боссов проверяет сервер")
    match tab:
        "floors":
            for name in ["ЭТАЖИ 1–20", "ЭТАЖИ 21–40", "ЭТАЖИ 41–60"]:
                _message(name, "Открытые уровни и телепорты будут отмечены после синхронизации.")
        "bosses":
            for name in ["ФЕНИКС · 20", "ВЛАДЫКА · 40", "ДРАКОН · 60"]:
                _message(name, "Комната босса, доступ и таймеры — данные сервера.")
        "rewards": _message("ДОБЫЧА ПОДЗЕМЕЛЬЯ", "Таблицы дропа, шансы и ограничения берутся из PPA.")
    _locked_action("ВОЙТИ / ТЕЛЕПОРТ")

func _show_fartzone() -> void:
    _section("ФАРТ-ЗОНА", "Зона добычи и охраны ресурсов из Telegram PPA")
    match tab:
        "about": _message("ОСОБАЯ ЗОНА", "Правила входа, доступный уровень и экипировка уточняются по серверным данным.")
        "mining": _message("ШАХТА И КИРКИ", "Добыча и время кирки должны считаться сервером, даже если приложение закрыто.")
        "guards": _message("СТРАЖИ И НАГРАДЫ", "Охрана месторождений, редкий дроп и повторное появление задаются PPA.")
    _locked_action("ПЕРЕЙТИ В ЗОНУ")
