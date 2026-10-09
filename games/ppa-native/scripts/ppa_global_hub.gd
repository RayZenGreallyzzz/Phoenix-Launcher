extends Control

# Global PPA menus (not NPC screens and not the character inventory).
# UI navigation + source-backed labels only. No TON signatures, deposits,
# server teleports, premium purchases or event rewards are simulated here.
signal close_requested
signal character_requested
signal snapshot_requested(section: String)
signal dungeon_visual_test_requested

const SAVE_VIEWS = preload("res://scripts/ppa_shared_save_views.gd")
const CATEGORIES := [
    {"id":"premium", "title":"ПРЕМИУМ МАГАЗИН"},
    {"id":"wallet", "title":"КОШЕЛЁК"},
    {"id":"events", "title":"СОБЫТИЯ"},
    {"id":"locations", "title":"ЛОКАЦИИ"}
]
const EVENT_GROUPS := [
    {"id":"game", "title":"ИГРОВЫЕ"},
    {"id":"clan", "title":"КЛАНОВЫЕ"},
    {"id":"war", "title":"ВОЙНА"},
    {"id":"updates", "title":"ОБНОВЛЕНИЯ"}
]
const EVENT_ITEMS := [
    {"id":"ruri", "group":"game", "title":"ВЕЛИКИЙ РУРИ", "detail":"Событие с легендарным питомцем. Ресурсы и награды берутся из серверного события."},
    {"id":"titan", "group":"game", "title":"КРИСТАЛЬНЫЙ ТИТАН", "detail":"Мировой босс. Доступ, откат и осколки Титана определяет сервер PPA."},
    {"id":"mimic", "group":"game", "title":"МИМИК-СОМБРЕРО", "detail":"Событийный бой с билетами и наградами. В Telegram PPA предусмотрены уровни 20, 40 и 60."},
    {"id":"citadel", "group":"war", "title":"ЦИТАДЕЛЬ ФЕНИКСА", "detail":"Клановая война, захват, вход и награды — только через общий сервер."},
    {"id":"updates", "group":"updates", "title":"ПОСЛЕДНИЕ ОБНОВЛЕНИЯ", "detail":"Здесь появятся изменения из общего списка обновлений PPA."}
]
const GOLD := Color("#F5CA79")
const WHITE := Color("#E8E0D1")
const MUTED := Color("#A99A81")
const LINE := Color("#8E623B")

var section := "events"
var subsection := "game"
var selected_event := "ruri"
var snapshot: Dictionary = {}
var _player_data_readonly: Dictionary = {}
var _back: ColorRect
var _frame: PanelContainer
var _heading: Label
var _tabs: GridContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _status: Label

func _ready() -> void:
    name = "PPAGlobalMenus"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build()
    visible = false
    resized.connect(_fit)

func _style(color: Color, rim: Color = LINE) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.border_color = rim
    s.set_border_width_all(1)
    s.set_corner_radius_all(8)
    s.content_margin_left = 9
    s.content_margin_right = 9
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _label(value: String, size: int = 12, color: Color = WHITE) -> Label:
    var l := Label.new()
    l.text = value
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _button(value: String, active: bool = false) -> Button:
    var b := Button.new()
    b.text = value
    b.custom_minimum_size.y = 40
    b.add_theme_font_size_override("font_size", 11)
    b.add_theme_color_override("font_color", GOLD if active else WHITE)
    b.add_theme_stylebox_override("normal", _style(Color("#422C1B") if active else Color("#211C18"), GOLD if active else LINE))
    b.add_theme_stylebox_override("hover", _style(Color("#54341C"), GOLD))
    b.add_theme_stylebox_override("disabled", _style(Color("#171B1F"), Color("#4C4944")))
    b.add_theme_color_override("font_disabled_color", MUTED)
    return b

func _build() -> void:
    _back = ColorRect.new()
    _back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _back.color = Color(0.0, 0.0, 0.0, 0.80)
    _back.mouse_filter = Control.MOUSE_FILTER_STOP
    _back.gui_input.connect(_outside)
    add_child(_back)
    _frame = PanelContainer.new()
    _frame.name = "GlobalOnlyWindow"
    _frame.anchor_left = 0.5
    _frame.anchor_right = 0.5
    _frame.anchor_top = 0.5
    _frame.anchor_bottom = 0.5
    _frame.mouse_filter = Control.MOUSE_FILTER_STOP
    _frame.add_theme_stylebox_override("panel", _style(Color("#0D1115"), LINE))
    add_child(_frame)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 8)
    _frame.add_child(layout)
    var heading_row := HBoxContainer.new()
    heading_row.add_theme_constant_override("separation", 8)
    layout.add_child(heading_row)
    _heading = _label("РАЗДЕЛЫ PPA", 18, GOLD)
    _heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading_row.add_child(_heading)
    var hero := _button("ГЕРОЙ")
    hero.name = "GlobalOpenHero"
    hero.pressed.connect(func(): character_requested.emit())
    heading_row.add_child(hero)
    var close := _button("✕")
    close.name = "GlobalClose"
    close.pressed.connect(func(): close_requested.emit())
    heading_row.add_child(close)
    _tabs = GridContainer.new()
    _tabs.name = "GlobalCategoryTabs"
    _tabs.columns = 4
    _tabs.add_theme_constant_override("h_separation", 6)
    _tabs.add_theme_constant_override("v_separation", 6)
    layout.add_child(_tabs)
    _scroll = ScrollContainer.new()
    _scroll.name = "GlobalContentScroll"
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(_scroll)
    _body = VBoxContainer.new()
    _body.name = "GlobalContent"
    _body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _body.add_theme_constant_override("separation", 10)
    _scroll.add_child(_body)
    _status = _label("PPA · Только просмотр · Операции требуют подключения сервера", 10, MUTED)
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(_status)
    _fit()

func _outside(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        close_requested.emit()
        accept_event()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        close_requested.emit()
        accept_event()

func _fit() -> void:
    if _frame == null or size.x <= 2.0 or size.y <= 2.0:
        return
    var width := minf(size.x * 0.94, 980.0)
    var height := minf(size.y * 0.92, 700.0)
    _frame.offset_left = -width / 2.0
    _frame.offset_right = width / 2.0
    _frame.offset_top = -height / 2.0
    _frame.offset_bottom = height / 2.0
    if _tabs != null:
        _tabs.columns = 2 if size.y > size.x else 4

func is_open() -> bool:
    return visible

func apply_player_save_readonly(save: Dictionary) -> void:
    _player_data_readonly = SAVE_VIEWS.global_player_view(save)
    if visible:
        _render()

func clear_player_save_readonly() -> void:
    _player_data_readonly.clear()
    if visible:
        _render()

func open_section(which: String = "events") -> void:
    if not ["premium", "wallet", "events", "locations"].has(which):
        return
    section = which
    subsection = "game" if which == "events" else "all"
    selected_event = "ruri"
    snapshot.clear()
    visible = true
    _fit()
    _render()
    snapshot_requested.emit(which)

func close_global() -> void:
    visible = false
    snapshot.clear()

func apply_snapshot(payload: Dictionary) -> void:
    if not visible or str(payload.get("section", "")) != section:
        return
    if payload.get("data") is Dictionary:
        snapshot = (payload["data"] as Dictionary).duplicate(true)
        _render()

func _clear(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()

func _change_section(which: String) -> void:
    open_section(which)

func _change_sub(which: String) -> void:
    subsection = which
    _render()

func _change_event(event_id: String) -> void:
    selected_event = event_id
    _render()

func _render() -> void:
    if not visible or not is_node_ready():
        return
    _clear(_tabs)
    _clear(_body)
    for entry in CATEGORIES:
        var id := str(entry["id"])
        var b := _button(str(entry["title"]), id == section)
        b.name = "GlobalTab_" + id
        b.pressed.connect(_change_section.bind(id))
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _tabs.add_child(b)
    var caption := {"premium":"ПРЕМИУМ МАГАЗИН", "wallet":"КОШЕЛЁК",
        "events":"ЦЕНТР СОБЫТИЙ", "locations":"КАРТА И ЛОКАЦИИ"}
    _heading.text = str(caption[section])
    match section:
        "premium": _premium()
        "wallet": _wallet()
        "events": _events()
        "locations": _locations()
    _scroll.set_deferred("scroll_vertical", 0)

func _section(title: String, detail: String) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(Color("#251A13"), LINE))
    _body.add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 5)
    panel.add_child(v)
    v.add_child(_label(title, 15, GOLD))
    v.add_child(_label(detail, 12, MUTED))

func _locked(label_text: String) -> void:
    var b := _button(label_text)
    b.disabled = true
    b.name = "GlobalServerActionLocked"
    _body.add_child(b)

func _premium() -> void:
    _section("ПРЕМИУМ PPA", "Подписки и игровые услуги. Наличие, цены и ограничения должны поступать из настоящего магазина Telegram PPA.")
    _section("ПОДПИСКИ", "Срок действия, бонусы и текущий статус — данные игрового сервера.")
    _locked("ОФОРМИТЬ ПОДПИСКУ")
    _section("ИГРОВЫЕ УСЛУГИ", "Смена класса, разблокировки и другие покупки не осуществляются в тестовом клиенте.")
    _locked("ПЕРЕЙТИ К ПОКУПКЕ")
    _section("ПРЕМИУМ ПРЕДМЕТЫ", "Заточки, руны, расходники, кирки. Без выдуманных остатков и цен.")
    _locked("КУПИТЬ ПРЕДМЕТ")

func _wallet() -> void:
    _section("TON CONNECT · КОШЕЛЁК PPA", "Кошелёк нельзя подключить простой имитацией кнопки в Godot. Требуется безопасный TON Connect и серверная проверка переводов.")
    _section("ПОДКЛЮЧЁННЫЙ TON АДРЕС", "— · статус ещё не получен от TON Connect")
    # D1 game currency is not the TON address balance.
    var game_gram: String = str(_player_data_readonly.get("gramDisplay", "— · нет подтверждённого баланса"))
    _section("ИГРОВОЙ БАЛАНС GRAM", str(game_gram) + " · из сохранения PPA")
    _section("GOLD / PPA", str(_player_data_readonly.get("goldDisplay", "—")) +
        " Gold · " + str(_player_data_readonly.get("ppaDisplay", "—")) + " PPA · сохранение D1")
    _section("ПОПОЛНЕНИЕ / ВЫВОД", "Минимум пополнения — 1 Gram, минимальный вывод — 15 Gram. Вывод одобряет администратор.")
    _locked("ПРИВЯЗАТЬ КОШЕЛЁК")
    _locked("ПОПОЛНИТЬ / ВЫВЕСТИ")
    _section("КАЗНА", "Игровой банк PPA не является автоматическим TON-выводом.")

func _events() -> void:
    _section("ЦЕНТР СОБЫТИЙ", "Категории сверены с Telegram PPA. Активность, таймеры, билеты и награды станут видны после серверной синхронизации.")
    var nav := GridContainer.new()
    nav.name = "GlobalEventGroups"
    nav.columns = 2 if size.y > size.x else 4
    nav.add_theme_constant_override("h_separation", 6)
    nav.add_theme_constant_override("v_separation", 6)
    _body.add_child(nav)
    for cat in EVENT_GROUPS:
        var key := str(cat["id"])
        var b := _button(str(cat["title"]), key == subsection)
        b.name = "GlobalEventGroup_" + key
        b.pressed.connect(_change_sub.bind(key))
        nav.add_child(b)
    var found := 0
    for event_item in EVENT_ITEMS:
        if str(event_item["group"]) != subsection:
            continue
        found += 1
        var id := str(event_item["id"])
        var b := _button(str(event_item["title"]), selected_event == id)
        b.name = "GlobalEvent_" + id
        b.pressed.connect(_change_event.bind(id))
        _body.add_child(b)
        if selected_event == id:
            _section(str(event_item["title"]), str(event_item["detail"]))
            _section("СТАТУС / ВРЕМЯ", "— · требуется подтверждение от сервера PPA")
            _locked("ВОЙТИ / ПОЛУЧИТЬ НАГРАДУ")
    if found == 0:
        _section("КЛАНОВЫЕ СОБЫТИЯ", "В Telegram-центре событий пока нет отдельных событий этой категории.")

func _locations() -> void:
    _section("МИР PPA", "Тестовая карта подземелья уже доступна без сервера. Полный игровой вход с монстрами и наградами подключим позднее.")
    for item in [
        {"title":"МИРНЫЙ ГОРОД", "detail":"Текущая игровая сцена Godot. Отдельный вход не требуется."},
        {"title":"ПОДЗЕМЕЛЬЯ 1–60", "detail":"Оригинальная новая каменная карта и маска проходов теперь доступны для проверки в Godot. Мобы, боссы и награды пока не подключены."},
        {"title":"ФАРТ-ЗОНА / ФАРМ", "detail":"Месторождения, стражи, кирки и добыча. Нужны карта и серверный режим."},
        {"title":"КЛАНОВЫЙ БОСС", "detail":"Отдельная арена, вклады игроков, сундук и распределение лута."},
        {"title":"АРЕНА PVP", "detail":"Отдельная боевая сцена, подбор и серверные удары."},
        {"title":"ЦИТАДЕЛЬ ФЕНИКСА", "detail":"Карта клановой осады — пока не перенесена."},
        {"title":"МИМИК-СОМБРЕРО", "detail":"Временная событийная арена. Вход по серверным билетам и расписанию."},
        {"title":"КРИСТАЛЬНЫЙ ТИТАН", "detail":"Мировой босс со своим серверным откатом."}
    ]:
        _section(str(item["title"]), str(item["detail"]))
        if str(item["title"]) == "ПОДЗЕМЕЛЬЯ 1–60":
            # Place the enabled preview DIRECTLY under dungeon entry, not at
            # the end of the entire locations index beneath disabled actions.
            var inspect := _button("ПРОЙТИ ПО КАРТЕ ДАНЖА · ТЕСТ БЕЗ СЕРВЕРА", true)
            inspect.name = "GlobalDungeonMapPreview"
            inspect.custom_minimum_size.y = 46.0
            inspect.pressed.connect(func(): dungeon_visual_test_requested.emit())
            _body.add_child(inspect)
    _locked("РЕАЛЬНЫЙ ВХОД В ЛОКАЦИИ · НУЖЕН СЕРВЕР")
