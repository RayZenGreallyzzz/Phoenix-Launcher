extends Control

# Nine original Peace City NPC services, ONE native Godot screen. No player
# character frame, WebView, fake economy or server mutations in this UI.
# All actions that would change the live save remain locked until an
# authenticated Phoenix/PPA service adapter is implemented and verified.
signal close_requested
signal authoritative_state_requested(service: String)
# Local offline dungeon visual test, explicitly separate from server entry.
signal dungeon_visual_test_requested

const SHOP = preload("res://scripts/test_shop_catalog.gd")
const STORAGE = preload("res://scripts/ppa_storage_contract.gd")
const VIRTUAL_GRID = preload("res://scripts/ppa_virtual_storage_grid.gd")
const ITEM_PICKER = preload("res://scripts/ppa_inventory_picker.gd")
const ORIGINAL_ITEM_ICONS = preload("res://scripts/ppa_item_icon_loader.gd")
const ORIGINAL_ITEM_VIEWS = preload("res://scripts/ppa_server_inventory_view.gd")
const SAVE_VIEWS = preload("res://scripts/ppa_shared_save_views.gd")
const SERVICES := ["merchant", "forge", "storage", "auction", "clan", "arena", "blackmarket", "dungeon", "fartzone"]
# Exact deployed original PPA PVP_SHOP_ITEMS (reference catalog only).
# Current rating, purchased-today limits, and live purchases require arena API.
const ORIGINAL_PVP_SHOP = [
    {"id":"hp_medium_3","name":"Среднее зелье HP ×3","icon":"❤","price":15,"limit":5,"minRating":0},
    {"id":"mp_medium_3","name":"Среднее зелье MP ×3","icon":"◆","price":15,"limit":5,"minRating":0},
    {"id":"stone_normal","name":"Камень заточки","icon":"◇","price":35,"limit":5,"minRating":1000},
    {"id":"xp_scroll","name":"Свиток опыта +10% · 3 мин","icon":"✦","price":50,"limit":3,"minRating":1000},
    {"id":"stone_premium","name":"Премиум камень заточки","icon":"✧","price":90,"limit":2,"minRating":1200},
    {"id":"stone_rune","name":"Рунический камень заточки","icon":"⬢","price":180,"limit":1,"minRating":1400}
]
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
var _auction_category := "all"
var _quest_tier := "21-30"
var preview_stash: RefCounted
var _auction_item_key := ""
var _asking_price := 1
var _asking_quantity := 1
var _asking_currency := "PPA"
var _forge_filter := "equipment"
var _forge_keys: Dictionary = {"equipment":"", "stone":"", "rune":""}
var _last_clan_layout := false
var authoritative: Dictionary = {}
var has_verified_state := false
var _player_save_readonly: Dictionary = {}
var _player_view_readonly: Dictionary = {}
var _preview_icons: Node
var _shade: ColorRect
var _frame: PanelContainer
var _heading: Label
var _subheading: Label
var _portrait: TextureRect
var _tabs: GridContainer
var _tab_scroller: ScrollContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _status: Label

func _ready() -> void:
    name = "PPANativeNpcMenu"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _create_shell()
    _preview_icons = ORIGINAL_ITEM_ICONS.new()
    _preview_icons.name = "PPAOriginalNpcProductIconLoader"
    add_child(_preview_icons)
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

    # Telegram PPA uses a horizontally browsable category strip. Prevent
    # nine clan tabs from filling the entire portrait screen in multiple rows.
    _tab_scroller = ScrollContainer.new()
    _tab_scroller.name = "NpcScrollableTabs"
    _tab_scroller.custom_minimum_size.y = 45
    _tab_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _tab_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _tab_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_child(_tab_scroller)
    _tabs = GridContainer.new()
    _tabs.name = "NpcOnlyCategoryTabs"
    _tabs.columns = 3
    _tabs.add_theme_constant_override("h_separation", 5)
    _tabs.add_theme_constant_override("v_separation", 5)
    _tab_scroller.add_child(_tabs)

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
    var w := minf(size.x * (0.92 if landscape else 0.96), 980.0)
    # Old portrait maximum of 690 px cut the lower NPC tab row on phones
    # and wasted almost half of a portrait tablet. Use nearly all available
    # height in portrait, while preserving the landscape dimensions.
    var h := minf(size.y * (0.94 if landscape else 0.975),
        690.0 if landscape else 1460.0)
    _frame.offset_left = -w / 2.0
    _frame.offset_right = w / 2.0
    _frame.offset_top = -h / 2.0
    _frame.offset_bottom = h / 2.0
    _layout_tabs()


func _layout_tabs() -> void:
    if _tabs == null or _tab_scroller == null:
        return
    # The nine clan destinations are never hidden behind side swipes.
    # Three rows in portrait, two in landscape. Other NPCs keep one
    # horizontally scrollable category strip like the live Telegram UI.
    var clan_grid := service == "clan"
    var columns := (5 if size.x > size.y else 3) if clan_grid else maxi(1, _tab_specs().size())
    _tabs.columns = columns
    _tab_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if clan_grid else ScrollContainer.SCROLL_MODE_AUTO
    # The final clan row used to be clipped: 123px is less than three
    # touch-sized rows plus gap, margins and theme padding.
    _tab_scroller.custom_minimum_size.y = 169.0 if (clan_grid and columns == 3) else (112.0 if clan_grid else 54.0)
    _last_clan_layout = clan_grid

func _outside(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        close_requested.emit()
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        close_requested.emit()
        accept_event()

func is_open() -> bool:
    return visible

func apply_player_save_readonly(save: Dictionary) -> void:
    # The authenticated save read by /api/game/state is NOT a signed
    # quote, market order, clan permission or combat state. Project only
    # the current player's possessions and balances into all NPC pages.
    _player_save_readonly = save.duplicate(true)
    _player_view_readonly = SAVE_VIEWS.npc_player_view(save)
    if visible:
        _render()

func clear_player_save_readonly() -> void:
    _player_save_readonly.clear()
    _player_view_readonly.clear()
    if visible:
        _render()

func set_preview_stash(storage: RefCounted) -> void:
    # This private local stash is not Telegram or the game server.
    preview_stash = storage

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
    _auction_category = "all"
    _quest_tier = "21-30"
    _auction_item_key = ""
    _asking_price = 1
    _asking_quantity = 1
    _asking_currency = "PPA"
    _forge_filter = "equipment"
    _forge_keys = {"equipment":"", "stone":"", "rune":""}
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
        "clan": return "overview"
        "arena": return "fights"
        "blackmarket": return "all"
        "dungeon": return "floors"
        "fartzone": return "about"
        "storage": return "personal"
        _: return "personal"

func _tab_specs() -> Array:
    match service:
        "merchant": return SHOP.MERCHANT_TABS
        "forge": return SHOP.SMITH_TABS
        "blackmarket": return SHOP.BM_CATEGORIES + [{"key":"buyback","label":"СКУПКА"}]
        "storage": return [
            {"key":"personal","label":"ЛИЧНОЕ"}, {"key":"clan","label":"КЛАНОВОЕ"},
            {"key":"premium","label":"ПРЕМИУМ"}, {"key":"sort","label":"СОРТИРОВАТЬ"}]
        "auction": return [
            {"key":"all","label":"КУПИТЬ"}, {"key":"sell","label":"ПРОДАТЬ"},
            {"key":"mine","label":"МОИ ЛОТЫ"}]
        "clan": return [
            {"key":"overview","label":"ОБЗОР"}, {"key":"clans","label":"КЛАНЫ / РЕЙТИНГ"},
            {"key":"members","label":"УЧАСТНИКИ"}, {"key":"storage","label":"СКЛАД"},
            {"key":"exchange","label":"ОБМЕН"}, {"key":"bosses","label":"БОССЫ"},
            {"key":"bonuses","label":"БОНУСЫ"}, {"key":"wars","label":"ВОЙНЫ"},
            {"key":"journal","label":"ЖУРНАЛ"}]
        "arena": return [
            {"key":"fights","label":"ИСПЫТАНИЯ"}, {"key":"attempts","label":"ПОПЫТКИ"},
            {"key":"rating","label":"РЕЙТИНГ"}, {"key":"shop","label":"МАГАЗИН"},
            {"key":"history","label":"ИСТОРИЯ"}]
        "dungeon": return [
            {"key":"floors","label":"ПОДЗЕМЕЛЬЯ"}, {"key":"quests","label":"ПОРУЧЕНИЯ"},
            {"key":"bosses","label":"БОССЫ"}, {"key":"rewards","label":"ДОБЫЧА"}]
        "fartzone": return [
            {"key":"about","label":"ШАХТЁР"}, {"key":"mining","label":"КИРКИ"},
            {"key":"guards","label":"СТРАЖИ"}]
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
    _layout_tabs()
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
        b.custom_minimum_size.y = 43.0
        if service == "clan":
            var available := _frame.offset_right - _frame.offset_left - 43.0
            var slot_width := floorf(available / float(_tabs.columns)) - 5.0
            b.custom_minimum_size.x = maxf(68.0, slot_width)
            b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            b.add_theme_font_size_override("font_size", 9 if _tabs.columns == 3 else 10)
            # Compact only the longest category on narrow portrait screens.
            if _tabs.columns == 3 and id == "clans":
                b.text = "КЛАНЫ"
        else:
            b.custom_minimum_size.x = maxf(105.0, float(str(entry.get("label", "")).length()) * 9.0)
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
    if not _player_view_readonly.is_empty():
        _status.text = "PPA · реальные вещи и баланс из D1 · операции заблокированы"
    if has_verified_state:
        _status.text = "PPA · подтверждённые данные сервиса · операции пока недоступны"
    _scroll.set_deferred("scroll_vertical", 0)


func _auction_filter(key: String) -> void:
    _auction_category = key
    _render()

func _quest_filter(key: String) -> void:
    _quest_tier = key
    _render()

func _mini_row(value: String, right: String = "") -> void:
    # A long arena price/rating string must never shrink into a one-character
    # column on portrait Android screens. Use full-width stacked labels.
    if right.length() > 13 or value.length() > 42:
        var stacked := VBoxContainer.new()
        stacked.name = "NpcFullWidthPriceRow_" + str(_body.get_child_count())
        stacked.add_theme_constant_override("separation", 2)
        stacked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _body.add_child(stacked)
        var caption := _label(value, 12, SUB)
        caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        stacked.add_child(caption)
        if not right.is_empty():
            var details := _label(right, 12, GOLD)
            details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            stacked.add_child(details)
        return
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _body.add_child(row)
    var lhs := _label(value, 12, SUB)
    lhs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(lhs)
    if not right.is_empty():
        var amount := _label(right, 12, GOLD)
        amount.autowrap_mode = TextServer.AUTOWRAP_OFF
        row.add_child(amount)

func _choice_tiles(options: Array, current: String, selected: Callable) -> void:
    var tiles := HFlowContainer.new()
    tiles.add_theme_constant_override("h_separation", 5)
    tiles.add_theme_constant_override("v_separation", 5)
    _body.add_child(tiles)
    for opt in options:
        var key := str(opt.get("key", ""))
        var b := _button(str(opt.get("label", "")))
        b.add_theme_color_override("font_color", GOLD if key == current else SUB)
        b.pressed.connect(selected.bind(key))
        tiles.add_child(b)

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

func _readonly_icon_item(item: Dictionary, side: float = 62.0) -> Button:
    # One icon resolver for inventory, warehouse, forge and arena. This is
    # not a purchase button and never transmits anything to PPA.
    var button := _button("◆")
    button.custom_minimum_size = Vector2(side, side)
    button.disabled = true
    button.tooltip_text = str(item.get("name", "Предмет PPA"))
    button.add_theme_stylebox_override("disabled", _style(Color("#14191F"), GOLD, 5))
    var img: String = str(item.get("img", ""))
    if img.begins_with("res://") and ResourceLoader.exists(img):
        button.icon = load(img) as Texture2D
        button.expand_icon = true
        button.text = ""
    elif _preview_icons != null:
        _preview_icons.bind_button(item, "", button)
    return button

func _readonly_owned_grid(title: String, items: Array, limit: int = 24) -> void:
    _section(title, "Подлинные предметы этого персонажа из D1 · только просмотр")
    var grid := GridContainer.new()
    grid.name = "NpcServerOwnedItems"
    grid.columns = 4 if size.x < 570.0 else 6
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    _body.add_child(grid)
    var count := 0
    for raw in items:
        if not(raw is Dictionary):
            continue
        var item: Dictionary = raw
        if item.is_empty():
            continue
        var tile := VBoxContainer.new()
        tile.custom_minimum_size.x = 65.0
        tile.add_theme_constant_override("separation", 2)
        grid.add_child(tile)
        tile.add_child(_readonly_icon_item(item, 61))
        var label := _label(str(item.get("name","")).left(17), 9, SUB)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        tile.add_child(label)
        var amount := maxi(1,int(item.get("qty",item.get("count",1))))
        tile.add_child(_label("×" + str(amount), 9, GOLD))
        count += 1
        if count >= limit:
            break
    if count == 0:
        _message("НЕТ ПРЕДМЕТОВ", "Этот список пуст в подтверждённом сохранении PPA.")

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
        # Original images are the same APK-bundled assets used in hero bag.
        # Do not suppress Black Market artwork when it is available.
        if not str(item.get("img", "")).is_empty():
            inner.add_child(_readonly_icon_item(item, 50))
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
    var money: Dictionary = _player_view_readonly.get("money", {})
    _body.add_child(_label("Ваш баланс D1 · Gold: " +
        (str(money["gold"]) if money.get("gold", null) != null else "—") +
        " / PPA: " +
        (str(money["ppa"]) if money.get("ppa", null) != null else "—"), 11, SUB))

func _show_blackmarket() -> void:
    _section("БЛЕК МАРКЕТ", "Telegram PPA · индивидуальные предложения и скупка")
    if tab == "buyback":
        _message("СКУПКА", "Список предметов и доступные дневные лимиты загружаются с сервера. Никаких локальных продаж.")
        _locked_action("ПРОДАТЬ")
        return
    var listed: Array = []
    if has_verified_state and authoritative.get("offers", null) is Array:
        listed = authoritative.get("offers", [])
    else:
        _message("СПРАВОЧНЫЙ АССОРТИМЕНТ", "Ниже показаны известные постоянные позиции. Это не текущие лоты персонажа.")
        listed = SHOP.BLACK_MARKET_REFERENCE
    var filtered: Array = []
    for entry in listed:
        if not (entry is Dictionary):
            continue
        if tab == "all" or str(entry.get("category", "")) == tab:
            filtered.append(entry)
    if not filtered.is_empty():
        _product_grid(filtered, false)
        _selected_details(filtered, false)
    else:
        _message("НЕТ ДАННЫХ", "Лоты этого раздела определяет оригинальный сервер PPA.")
    _message("ТОВАР ИЗ-ПОД ПРИЛАВКА", "500 PPA · скрытое содержимое, 1 раз за обновление. Покупка отключена до серверной синхронизации.")
    _locked_action("КУПИТЬ / СКУПКА")


func _inventory_items() -> Array:
    if not _player_view_readonly.is_empty():
        return _player_view_readonly.get("inventory", [])
    if has_verified_state:
        var from_server = authoritative.get("inventory", [])
        return from_server if from_server is Array else []
    if preview_stash != null:
        return preview_stash.bag
    return []

func _worn_items() -> Dictionary:
    if not _player_view_readonly.is_empty():
        return _player_view_readonly.get("equipment", {})
    if has_verified_state:
        var equipped = authoritative.get("equipment", {})
        return equipped if equipped is Dictionary else {}
    if preview_stash != null:
        return preview_stash.equipment
    return {}

func _chosen_item(key: String) -> Dictionary:
    if key.begins_with("bag:"):
        var position := int(key.trim_prefix("bag:"))
        var inventory := _inventory_items()
        for n in range(inventory.size()):
            var entry = inventory[n]
            if entry is Dictionary and int(entry.get("slot", n)) == position:
                return entry
    elif key.begins_with("equip:"):
        return _worn_items().get(key.trim_prefix("equip:"), {})
    return {}

func _add_picker(mode: String, selected_key: String, destination: Callable) -> void:
    var title := _label("ВЫБОР ИЗ ИНВЕНТАРЯ · 100 ЯЧЕЕК", 13, GOLD)
    _body.add_child(title)
    var picker = ITEM_PICKER.new()
    picker.name = "NpcPicker_" + mode
    _body.add_child(picker)
    picker.item_chosen.connect(destination)
    picker.configure(_inventory_items(), _worn_items(), mode, selected_key)
    if _player_view_readonly.is_empty() and not has_verified_state:
        _body.add_child(_label("Ожидаем авторизованное сохранение PPA · тестовую сумку не выдаём за реальные вещи.", 11, SUB))

func _details(key: String) -> void:
    var item := _chosen_item(key)
    if item.is_empty():
        _message("ПРЕДМЕТ НЕ ВЫБРАН", "Коснись вещи в инвентаре выше. Пустая ячейка недоступна.")
        return
    _section("ВЫБРАНО · " + str(item.get("name", "Предмет")))
    _mini_row("Редкость", str(item.get("rarity", "—")))
    _mini_row("Количество", str(item.get("qty", 1)))
    if item.has("upgrade"):
        _mini_row("Заточка", "+" + str(item["upgrade"]))
    if item.has("attack"):
        _mini_row("Атака", str(item["attack"]))
    if item.has("defense"):
        _mini_row("Защита", str(item["defense"]))
    _mini_row("Источник", "Экипировка" if key.begins_with("equip:") else "Инвентарь")

func _choose_auction(key: String) -> void:
    _auction_item_key = key
    _asking_quantity = 1
    _render()

func _choose_forge(key: String) -> void:
    _forge_keys[_forge_filter] = key
    _render()

func _set_forge_filter(mode: String) -> void:
    _forge_filter = mode
    _render()

func _set_asking_price(value: float) -> void:
    _asking_price = maxi(1, int(value))

func _set_asking_qty(value: float) -> void:
    _asking_quantity = maxi(1, int(value))

func _set_currency(index: int) -> void:
    _asking_currency = "PPA" if index == 0 else "Gram"

func _show_forge() -> void:
    _section("КУЗНЕЦ · " + tab.to_upper(), "Точные вещи и компоненты будут получены из серверного инвентаря PPA.")
    if tab == "enhance":
        _section("ЗАТОЧКА · ВЫБОР ЭКИПИРОВКИ", "Вещь, заточка и руна выбираются отдельно. Надетые предметы тоже доступны.")
        var chosen := HBoxContainer.new()
        chosen.name = "NpcForgeSelectedSlots"
        chosen.add_theme_constant_override("separation", 6)
        _body.add_child(chosen)
        for role in ["equipment", "stone", "rune"]:
            var panel := PanelContainer.new()
            panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            panel.add_theme_stylebox_override("panel", _style(Color("#141A20"), GOLD if role == _forge_filter else EDGE, 6))
            chosen.add_child(panel)
            var name_label := {"equipment":"ВЕЩЬ", "stone":"ЗАТОЧКА", "rune":"РУНА"}
            var thing := _chosen_item(str(_forge_keys.get(role, "")))
            panel.add_child(_label(str(name_label[role]) + "\n" +
                (str(thing.get("name", "◇ пусто")).substr(0, 23)), 11, GOLD if not thing.is_empty() else SUB))
        _choice_tiles([
            {"key":"equipment","label":"ВЕЩИ"},
            {"key":"stone","label":"ЗАТОЧКИ"},
            {"key":"rune","label":"РУНЫ"}], _forge_filter, _set_forge_filter)
        _add_picker(_forge_filter, str(_forge_keys.get(_forge_filter, "")), _choose_forge)
        _details(str(_forge_keys.get(_forge_filter, "")))
        _mini_row("Шанс успеха / ресурсы", "рассчитывает сервер")
        _locked_action("ЗАТОЧИТЬ ВЕЩЬ")
    elif tab == "rune_fusion":
        _message("СЛИЯНИЕ РУН", "Отображаются реальные руны из отдельной сумки персонажа. Слияние пока не выполняется.")
        if _player_view_readonly.is_empty():
            _message("НЕТ СЕРВЕРНОГО СНИМКА", "Ожидаем настоящее сохранение персонажа.")
        else:
            var runes: Dictionary = ORIGINAL_ITEM_VIEWS.rune_view_from_save(_player_save_readonly)
            _readonly_owned_grid("ВАШИ РУНЫ", runes.get("inventory", []))
        _locked_action("СЛИТЬ РУНЫ")
    else:
        var names := {"equipment":"СНАРЯЖЕНИЕ", "legendary":"ЛЕГЕНДАРНОЕ",
            "accessories":"АКСЕССУАРЫ", "pets":"ПЕТЫ"}
        _message(str(names.get(tab, "КРАФТ")), "Точные рецепты и стоимость подключим из оригинального PPA-каталога.")
        if _player_view_readonly.is_empty():
            _message("НЕТ СЕРВЕРНОГО СНИМКА", "Ожидаем настоящее сохранение персонажа.")
        else:
            _readonly_owned_grid("ВАШИ МАТЕРИАЛЫ И ЭКИПИРОВКА", _inventory_items())
        _locked_action("СОЗДАТЬ")
    _body.add_child(_label("Ни одна операция не списывает реальные предметы без подключения игрового сервера.", 11, SUB))

func _storage_slot_panel(parent: BoxContainer, scope: String) -> void:
    # No pagination or arrows. The user swipes a continuous square-cell
    # grid; 100/200/500/50 total slots share a single drawing canvas.
    var cap := STORAGE.capacity(scope)
    var panel := VBoxContainer.new()
    panel.name = "NpcStoragePanel_" + scope
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.add_theme_constant_override("separation", 5)
    parent.add_child(panel)
    var heading := "ИНВЕНТАРЬ" if scope == "inventory" else (
        "ЛИЧНЫЙ СКЛАД" if scope == "personal" else (
        "КЛАНОВЫЙ СКЛАД" if scope == "clan" else "ПРЕМИУМ СКЛАД"))
    panel.add_child(_label(heading, 12, GOLD))
    var saved_items: Array = []
    var known := false
    if not _player_view_readonly.is_empty():
        if scope == "inventory":
            saved_items = _player_view_readonly.get("inventory", [])
            known = true
        else:
            var scopes: Dictionary = _player_view_readonly.get("storage", {})
            var seen: Dictionary = _player_view_readonly.get("storageFieldsPresent", {})
            if bool(seen.get(scope, false)):
                saved_items = scopes.get(scope, [])
                known = true
    var occupied := 0
    for raw in saved_items:
        if raw is Dictionary and not (raw as Dictionary).is_empty():
            occupied += 1
    panel.add_child(_label((str(occupied) if known else "—") + " / " + str(cap) +
        (" · подтверждено D1" if known else " · серверные данные недоступны"), 10, SUB))
    var shell := PanelContainer.new()
    shell.name = "NpcStorageFrame_" + scope
    shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shell.add_theme_stylebox_override("panel", _style(Color("#0B1014"), Color("#5D4B35"), 8))
    panel.add_child(shell)
    var scrolling := ScrollContainer.new()
    scrolling.name = "NpcStorageScroll_" + scope
    scrolling.custom_minimum_size.y = 296.0 if size.x >= 570.0 else 240.0
    scrolling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scrolling.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scrolling.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    # Godot ScrollContainer owns touchscreen drag + kinetic scrolling.
    # Child canvas is IGNORE to keep touch input exclusively with scroll.
    shell.add_child(scrolling)
    var grid := VIRTUAL_GRID.new()
    grid.custom_minimum_size.x = maxf(150.0,
        (_frame.offset_right - _frame.offset_left) / 2.0 - 56.0) if size.x >= 570.0 else maxf(150.0, _frame.offset_right - _frame.offset_left - 60.0)
    scrolling.add_child(grid)
    grid.configure(scope, scrolling, 5 if size.x >= 570.0 else 4)
    if known:
        grid.call("apply_items_readonly", saved_items)

func _storage_pair(scope: String) -> void:
    # Two independent, smooth scrolls. The whole 500-slot area uses just
    # one virtual-draw node and one ScrollContainer, not 500 child nodes.
    var narrow := size.x < 570.0
    var split: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
    split.name = "NpcStoragePair_" + scope
    split.add_theme_constant_override("separation", 9)
    _body.add_child(split)
    _storage_slot_panel(split, "inventory")
    _storage_slot_panel(split, scope)

func _show_storage() -> void:
    var captions := {"personal":"ЛИЧНОЕ ХРАНИЛИЩЕ", "clan":"КЛАНОВОЕ ХРАНИЛИЩЕ",
        "premium":"ПРЕМИУМ ХРАНИЛИЩЕ", "sort":"СОРТИРОВКА"}
    _section(str(captions.get(tab, "ХРАНИЛИЩЕ")), "Все ёмкости берутся из единого контракта; предметы получим с сервера")
    if tab == "sort":
        _message("СОРТИРОВКА ПРЕДМЕТОВ", "Сортировка сохранится только после подтверждения игрового сервера.")
        _choice_tiles([
            {"key":"rarity","label":"ПО РЕДКОСТИ"},
            {"key":"type","label":"ПО ТИПУ"},
            {"key":"name","label":"ПО НАЗВАНИЮ"}], selected_id, _select_item)
        _locked_action("СОХРАНИТЬ ПОРЯДОК")
        return
    _storage_pair(tab)
    if tab == "clan":
        _message("КЛАНОВЫЕ ПРАВА", "Переносить вещи смогут только участники с подтверждёнными правами.")
    elif tab == "premium":
        _message("ПРЕМИУМ ДОСТУП", "Содержимое премиум-хранилища читается только с сервера PPA.")
    _locked_action("ПОЛОЖИТЬ")
    _locked_action("ЗАБРАТЬ")

func _show_auction() -> void:
    var captions := {"all":"КУПИТЬ", "mine":"МОИ ЛОТЫ", "sell":"ПРОДАТЬ"}
    _section("АУКЦИОН · " + str(captions.get(tab, "")), "Выбор вещи и параметры лота независимы от операций на сервере PPA.")
    if tab != "mine":
        _choice_tiles([
            {"key":"all","label":"ВСЕ"}, {"key":"weapon","label":"ОРУЖИЕ"},
            {"key":"armor","label":"БРОНЯ"}, {"key":"accessories","label":"АКСЕССУАРЫ"},
            {"key":"consumables","label":"РАСХОДНИКИ"}, {"key":"materials","label":"МАТЕРИАЛЫ"},
            {"key":"books","label":"КНИГИ"}, {"key":"quest","label":"КВЕСТОВЫЕ"},
            {"key":"misc","label":"РАЗНОЕ"}], _auction_category, _auction_filter)
    if tab == "all":
        _message("ТОРГОВЫЕ ПРЕДЛОЖЕНИЯ", "Реальные объявления появятся после подключения серверного аукциона.")
        _locked_action("КУПИТЬ")
    elif tab == "sell":
        _section("ЧТО ПРОДАЁМ", "Только вещи из инвентаря, подходящие по правилам PPA. Нажми на слот.")
        _add_picker("sell", _auction_item_key, _choose_auction)
        _details(_auction_item_key)
        _section("УСЛОВИЯ ПРОДАЖИ", "Цена, количество и валюта выбираются до отправки лота.")
        var selected := _chosen_item(_auction_item_key)
        var settings := GridContainer.new()
        settings.name = "NpcAuctionListingInputs"
        settings.columns = 2
        settings.add_theme_constant_override("h_separation", 10)
        settings.add_theme_constant_override("v_separation", 8)
        _body.add_child(settings)
        settings.add_child(_label("Цена за единицу", 12, GOLD))
        var price := SpinBox.new()
        price.name = "NpcAuctionPrice"
        price.min_value = 1
        price.max_value = 999999999
        price.step = 1
        price.value = _asking_price
        price.custom_minimum_size = Vector2(130, 38)
        price.value_changed.connect(_set_asking_price)
        settings.add_child(price)
        settings.add_child(_label("Количество", 12, GOLD))
        var amount := SpinBox.new()
        amount.name = "NpcAuctionQuantity"
        amount.min_value = 1
        amount.max_value = maxi(1, int(selected.get("qty", 1)))
        amount.value = mini(_asking_quantity, int(amount.max_value))
        amount.custom_minimum_size = Vector2(130, 38)
        amount.value_changed.connect(_set_asking_qty)
        settings.add_child(amount)
        settings.add_child(_label("Валюта", 12, GOLD))
        var currency := OptionButton.new()
        currency.name = "NpcAuctionCurrency"
        currency.custom_minimum_size = Vector2(130, 38)
        currency.add_item("PPA")
        currency.add_item("Gram")
        currency.select(0 if _asking_currency == "PPA" else 1)
        currency.item_selected.connect(_set_currency)
        settings.add_child(currency)
        _mini_row("Комиссия / число свободных лотов", "рассчитает сервер")
        _locked_action("ВЫСТАВИТЬ ЛОТ")
    else:
        _message("МОИ ЛОТЫ", "Только подтверждённые объявления из серверного аукциона.")
        _locked_action("СНЯТЬ С ПРОДАЖИ")

func _show_clan() -> void:
    var captions := {"overview":"ОБЗОР КЛАНА", "clans":"КЛАНЫ И РЕЙТИНГ",
        "members":"УЧАСТНИКИ", "storage":"КЛАНОВЫЙ СКЛАД",
        "exchange":"ОБМЕН", "bosses":"КЛАНОВЫЕ БОССЫ",
        "bonuses":"БОНУСЫ КЛАНА", "wars":"ВОЙНЫ И ЦИТАДЕЛЬ", "journal":"ЖУРНАЛ"}
    _section(str(captions.get(tab, "МАГИСТР КЛАНОВ")), "Структура Telegram PPA · все операции через общий сервер")
    match tab:
        "overview":
            _message("ВАШ КЛАН", "Название, глава, режим и уровень загрузятся из PPA.")
            _message("СОСТАВ", "Участники · приглашения · заявки · управление по правам.")
            _message("КЛАНОВЫЙ СКЛАД", "Общая ёмкость и разрешения будут получены из PPA.")
            _message("РАЗВИТИЕ КЛАНА", "Уровень, вклад и активные бонусы — только сервер.")
            _locked_action("УПРАВЛЯТЬ")
        "clans":
            _message("СПИСОК КЛАНОВ", "Кланы, заявки, вступление, создание и позиции рейтинга.")
            _locked_action("ВСТУПИТЬ / СОЗДАТЬ")
        "members":
            _message("УЧАСТНИКИ И ЗАЯВКИ", "Роли, онлайн, урон, управление, исключение и приглашения — по полномочиям.")
            _locked_action("УПРАВЛЕНИЕ СОСТАВОМ")
        "storage":
            _message("ОБЩИЙ КЛАНОВЫЙ СКЛАД", "500 слотов с плавной прокруткой, без перелистывания; инвентарь 100 слотов.")
            _storage_pair("clan")
            _locked_action("ПОЛОЖИТЬ / ЗАБРАТЬ")
        "exchange":
            _message("КЛАНОВЫЙ ОБМЕН", "Раздел доступен напрямую в сетке вкладок. Состав предложений и ограничения проверит сервер.")
            _mini_row("Мои доступные ресурсы", "— · ожидаем сервер")
            _mini_row("Клановые предложения", "— · ожидаем сервер")
            _locked_action("ОБМЕНЯТЬ")
        "bosses":
            _message("КЛАН-БОССЫ", "Возрождение, HP, личный вклад, сундук, распределение и ролл наград — серверные.")
            _locked_action("ВОЙТИ К БОССУ")
        "bonuses":
            _message("БОНУСЫ И РАЗВИТИЕ", "Вклад, исследования, уровни и доступные усиления.")
            _locked_action("УЛУЧШИТЬ")
        "wars":
            _message("ВОЙНЫ И ЦИТАДЕЛЬ", "Захват, владение, защита и кнопка выхода управляются сервером.")
            _locked_action("УЧАСТВОВАТЬ")
        "journal":
            _message("ЖУРНАЛ СОБЫТИЙ", "История клана, операции склада и результаты войн придут из PPA.")

func _show_arena() -> void:
    _section("МЕЧНИК АРЕНЫ", "Telegram PPA · испытания, PvP и рейтинг")
    var wallet: Dictionary = _player_view_readonly.get("money", {})
    var tokens: Variant = wallet.get("arenaTokens", null)
    _mini_row("⚔ ЖЕТОНЫ АРЕНЫ · ЛИЧНЫЙ СЕЙВ D1",
        str(tokens) if tokens != null else "— · нет данных")
    match tab:
        "fights":
            _message("БЕСКОНЕЧНЫЕ ВОЛНЫ", "Бой с монстрами, прогресс волн и сезонные награды.")
            _message("ПРОТИВ ИИ", "Испытание против ботов. Состав и доступность определяет сервер.")
            _message("PVP АРЕНА", "Режимы 1×1 и 3×3 / 5×5 — где они доступны в живой PPA.")
            _message("СЕЗОННЫЙ РЕЙТИНГ", "Позиция и подбор на сервере.")
            _locked_action("ВОЙТИ В ИСПЫТАНИЕ")
        "attempts":
            _message("PVP · ПОПЫТКИ", "Лимит, остаток попыток, жетоны арены и обновление доступны после синхронизации.")
            _locked_action("НАЧАТЬ МАТЧ")
        "rating":
            _message("РЕЙТИНГ PVP", "Бои, победы, позиции и таблица лидеров должны совпадать с Telegram.")
        "shop":
            _message("МАГАЗИН АРЕНЫ", "Шесть оригинальных товаров PPA и утверждённые цены. Остатки покупок сегодня и рейтинг требуют онлайн-состояния.")
            for offer in ORIGINAL_PVP_SHOP:
                _mini_row(str(offer["icon"]) + " " + str(offer["name"]),
                    str(offer["price"]) + " ⚔ · рейтинг " + str(offer["minRating"]) + "+ · лимит " + str(offer["limit"]))
            _locked_action("КУПИТЬ")
        "history":
            _message("ИСТОРИЯ БОЁВ", "Исходы матчей и награды по подтверждённым серверным записям.")

func _show_dungeon() -> void:
    _section("ХРАНИТЕЛЬ ПОДЗЕМЕЛЬЯ", "Реальный серверный вход пока не подключён. Но карту уже можно проверить в Godot!")
    # Keep test access prominent on every Keeper page, rather than hiding
    # it under quests or behind the disabled live-entry button.
    var preview := _button("ПРОЙТИ ПО КАРТЕ · ТЕСТ БЕЗ СЕРВЕРА")
    preview.name = "NpcDungeonWalkTest"
    preview.custom_minimum_size.y = 46.0
    preview.add_theme_stylebox_override("normal", _style(Color("#3A2917"), GOLD, 7, 2))
    preview.pressed.connect(func(): dungeon_visual_test_requested.emit())
    _body.add_child(preview)
    _body.add_child(_label("Только прогулка по оригинальной карте. Без мобов, дропа и изменения аккаунта.", 11, SUB))
    match tab:
        "floors":
            for floor_range in ["1–20", "21–40", "41–60"]:
                _message("ПОДЗЕМЕЛЬЕ " + floor_range, "Доступ, комнаты, боссы и телепорт проверяются сервером.")
            _locked_action("ВОЙТИ В ПОДЗЕМЕЛЬЕ")
            _section("ПОРУЧЕНИЯ ХРАНИТЕЛЯ", "Награды только после подтверждённого выполнения")
            _quest_tiles()
        "quests":
            _quest_tiles()
            if _quest_tier == "21-30":
                for quest in [
                    "Новые враги · 80 мобов",
                    "Синяя охота · синяя экипировка или ресурсы",
                    "Элитная угроза · 8 элитных врагов",
                    "Охотник за рунами · руна с монстров",
                    "Испытание Хранителя II · 200 мобов",
                    "Награда за цепочку · после выполнения поручений"]:
                    _message(quest, "Из Telegram PPA · личный прогресс ещё не подключён.")
            else:
                _message("ПОРУЧЕНИЯ " + _quest_tier, "Получим список, прогресс и награды из общего сервера PPA.")
            _locked_action("СДАТЬ ПОРУЧЕНИЕ")
        "bosses":
            for boss_name in ["ФЕНИКС · 20", "ВЛАДЫКА · 40", "ДРАКОН · 60"]:
                _message(boss_name, "Вход, живой HP и повторные попытки проверяет сервер.")
        "rewards":
            _message("ДОБЫЧА", "Шансы дропа, сундуки и ограничения берутся из утверждённых таблиц PPA.")

func _quest_tiles() -> void:
    _choice_tiles([
        {"key":"1-20","label":"1–20"},
        {"key":"21-30","label":"21–30"},
        {"key":"31-40","label":"31–40"},
        {"key":"daily","label":"ЕЖЕДНЕВНЫЕ"}], _quest_tier, _quest_filter)
    _body.add_child(_label("Задания доступны только по реальному прогрессу персонажа.", 11, SUB))

func _show_fartzone() -> void:
    _section("ШАХТЁР ФАРТ-ЗОНЫ", "Добыча, кирки и стражи · настоящая PPA")
    match tab:
        "about":
            _message("ДОСТУП В ЗОНУ", "Правила и уровень входа сервер проверит для выбранного персонажа.")
            _mini_row("ШЛАК · СПРАВОЧНАЯ ЦЕНА", "2 PPA / шт.")
            _locked_action("ВОЙТИ В ФАРТ-ЗОНУ")
        "mining":
            _message("ОБЫЧНАЯ КИРКА", "200 PPA · 4 часа · серверный таймер.")
            _message("ЛЕГЕНДАРНАЯ КИРКА", "2120 PPA · 14 часов · серверный таймер.")
            _locked_action("КУПИТЬ КИРКУ")
            _locked_action("ПРОДАТЬ ШЛАК")
        "guards":
            _message("СТРАЖИ И ДОБЫЧА", "Охрана месторождений, появление стражей и редкие награды только серверные.")
            _locked_action("ВОЙТИ В ЗОНУ")
