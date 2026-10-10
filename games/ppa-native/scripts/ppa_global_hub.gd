extends Control

# Global PPA menus (not NPC screens and not the character inventory).
# UI navigation + source-backed labels only. No TON signatures, deposits,
# server teleports, premium purchases or event rewards are simulated here.
signal close_requested
signal character_requested
signal snapshot_requested(section: String)
signal dungeon_visual_test_requested
signal arena_requested

const SAVE_VIEWS = preload("res://scripts/ppa_shared_save_views.gd")
const ORIGINAL_PREMIUM = preload("res://scripts/ppa_premium_catalog_generated.gd")
const CATEGORIES := [
    {"id":"premium", "title":"ПРЕМИУМ МАГАЗИН"},
    {"id":"wallet", "title":"КОШЕЛЁК"},
    {"id":"events", "title":"СОБЫТИЯ"},
    {"id":"locations", "title":"ЛОКАЦИИ"},
    {"id":"arena", "title":"АРЕНА"}
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
# Reference exchange from original deployed PPA TITAN_SHARD_OFFERS.
# Real claims and spending must be server-authoritative and are disabled.
const TITAN_SHARD_OFFERS = [
    {"name":"Обычная заточка ×3","icon":"◆","cost":1},
    {"name":"Премиум-реген HP ×3","icon":"❤","cost":2},
    {"name":"Свиток телепорта ×2","icon":"📜","cost":3},
    {"name":"Редкий материал ×1","icon":"✦","cost":4},
    {"name":"Премиум-заточка ×1","icon":"💎","cost":6},
    {"name":"Премиум руна ×1","icon":"ᚱ","cost":12}
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
    if not ["premium", "wallet", "events", "locations", "arena"].has(which):
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
        "events":"ЦЕНТР СОБЫТИЙ", "locations":"КАРТА И ЛОКАЦИИ", "arena":"АРЕНА PPA"}
    _heading.text = str(caption[section])
    match section:
        "premium": _premium()
        "wallet": _wallet()
        "events": _events()
        "locations": _locations()
        "arena": _arena()
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

func _original_premium_cards(title_text: String, offers: Array) -> void:
    _section(title_text, "Реальный ассортимент Telegram PPA · цены из оригинального магазина")
    var cards := GridContainer.new()
    cards.name = "OriginalPpaPremiumGrid_" + title_text.replace(" ", "_")
    # Window is at most 980px wide, even on a wide tablet. Using the entire
    # viewport width here made three very narrow/clipped premium cards.
    # One column on phones, two readable columns on tablet landscape.
    cards.columns = 2 if _frame != null and _frame.size.x >= 840.0 else 1
    cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("h_separation", 6)
    cards.add_theme_constant_override("v_separation", 7)
    _body.add_child(cards)
    for raw in offers:
        if not (raw is Dictionary):
            continue
        var item: Dictionary = raw
        var tile := PanelContainer.new()
        tile.add_theme_stylebox_override("panel", _style(Color("#171A1E"), LINE))
        tile.custom_minimum_size.y = 125.0
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cards.add_child(tile)
        var column := VBoxContainer.new()
        column.add_theme_constant_override("separation", 4)
        column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tile.add_child(column)
        var art := str(item.get("img", ""))
        if art.begins_with("res://") and ResourceLoader.exists(art):
            var picture := TextureRect.new()
            picture.texture = load(art) as Texture2D
            picture.custom_minimum_size = Vector2(60.0, 55.0)
            picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            column.add_child(picture)
        var name_label := _label(str(item.get("name", "")), 12, WHITE)
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        column.add_child(name_label)
        column.add_child(_label(str(item.get("price", "?")) + " Gram", 12, GOLD))
        var details := _label(str(item.get("desc","")), 10, MUTED)
        details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        column.add_child(details)
    if offers.is_empty():
        _section("НЕТ ПРЕДЛОЖЕНИЙ", "Публичный каталог игры пуст, выдуманные товары не показываем.")

func _premium() -> void:
    _section("ПРЕМИУМ PPA", "Все товары, наборы и тарифы ниже извлечены из работающего Telegram PPA. Покупки пока защищённо отключены.")
    _section("ВАШИ GRAM · СЕРВЕРНЫЙ БАЛАНС",
        str(_player_data_readonly.get("gramDisplay", "— · нет подтверждённого баланса")))
    var catalog: Dictionary = ORIGINAL_PREMIUM.CATALOG
    _original_premium_cards("ПРЕМИУМ ПРЕДМЕТЫ И УСЛУГИ", catalog.get("goods", []))
    _original_premium_cards("ГОТОВЫЕ НАБОРЫ", catalog.get("bundles", []))
    _original_premium_cards("ПРЕМИУМ ПОДПИСКИ", catalog.get("subscriptions", []))
    _locked("КУПИТЬ · ТОЛЬКО ПОСЛЕ СЕРВЕРНОЙ ПРОВЕРКИ")
    _section("БЕЗОПАСНОСТЬ", "Показ цены не является оплатой. Реальные Gram и выдача вещей должны проверяться общим сервером PPA.")

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
    _section("ЦЕНТР СОБЫТИЙ", "Утверждённые события PPA. Живые таймеры и билеты требуют отдельного серверного статуса.")
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
            if id == "titan":
                var shards: Variant = _player_data_readonly.get("titanShards", null)
                _section("ОСКОЛКИ КРИСТАЛЬНОГО ТИТАНА", str(shards) if shards != null else "— · нет сохранённых данных")
                _section("ОБМЕН ТРОФЕЕВ · КАТАЛОГ PPA", "Оригинальные награды и цены. Обмен заблокирован до серверной операции.")
                for offer in TITAN_SHARD_OFFERS:
                    _section(str(offer["icon"]) + " " + str(offer["name"]),
                        str(offer["cost"]) + " осколк(ов) · не доступно для покупки")
            elif id == "ruri":
                _section("РАСПИСАНИЕ РУРИ", "В оригинальном событии цикл начинается 1-го числа, длительность 10 дней. Текущий статус подтвердит сервер.")
            elif id == "mimic":
                _section("РАСПИСАНИЕ МИМИКА-СОМБРЕРО", "В оригинальном событии цикл начинается 25-го числа, длительность 5 дней. Текущий статус подтвердит сервер.")
            _section("СТАТУС / ВРЕМЯ", "— · требуется подтверждение от сервера PPA")
            _locked("ВОЙТИ / ПОЛУЧИТЬ НАГРАДУ")
    if found == 0:
        _section("КЛАНОВЫЕ СОБЫТИЯ", "В Telegram-центре событий пока нет отдельных событий этой категории.")

func _arena() -> void:
    _section("PVP И ИСПЫТАНИЯ", "Общая арена PPA. Игроки, рейтинг и бой должны обслуживаться оригинальным сервером.")
    var tokens: Variant = _player_data_readonly.get("arenaTokens", null)
    _section("⚔ ЖЕТОНЫ АРЕНЫ", str(tokens) if tokens != null else "— · нет данных")
    for mode in ["1×1 PVP", "3×3 PVP", "5×5 PVP", "ВОЛНЫ И ИСПЫТАНИЯ", "РЕЙТИНГ", "МАГАЗИН АРЕНЫ"]:
        _section(mode, "Информация и доступность матча должны поступать из сервера PPA")
    var open_ui := _button("ОТКРЫТЬ МЕНЮ МЕЧНИКА АРЕНЫ")
    open_ui.name = "OpenExistingArenaNpcMenu"
    open_ui.pressed.connect(func(): arena_requested.emit())
    _body.add_child(open_ui)
    _section("ОБЩИЙ ОНЛАЙН", "Вход в матч остаётся выключен до защищённого native WebSocket-билета и серверного подбора.")
    _locked("НАЧАТЬ PVP МАТЧ")

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
