extends Control

# Nine original Peace City NPC services, ONE native Godot screen. No player
# character frame, WebView or fake economy in this UI.
# Only server-advertised typed clan and merchant actions are enabled.
# Other mutations stay locked until their shared adapters are verified.
signal close_requested
signal authoritative_state_requested(service: String)
signal clan_action_requested(action: String, fields: Dictionary)
signal clan_retry_requested
signal merchant_action_requested(fields: Dictionary)
signal merchant_retry_requested
signal forge_action_requested(fields: Dictionary)
signal forge_retry_requested
signal inventory_action_requested(fields: Dictionary)
signal inventory_retry_requested
signal personal_storage_action_requested(fields: Dictionary)
signal personal_storage_retry_requested
signal clan_storage_action_requested(fields: Dictionary)
signal clan_storage_retry_requested
signal auction_action_requested(fields: Dictionary)
signal auction_retry_requested
# Local offline dungeon visual test, explicitly separate from server entry.
signal dungeon_visual_test_requested
signal arena_training_requested
signal native_realtime_requested

const SHOP = preload("res://scripts/test_shop_catalog.gd")
const LIVE_FORGE = preload("res://scripts/ppa_forge_catalog_generated.gd")
const STORAGE = preload("res://scripts/ppa_storage_contract.gd")
const VIRTUAL_GRID = preload("res://scripts/ppa_virtual_storage_grid.gd")
const ITEM_PICKER = preload("res://scripts/ppa_inventory_picker.gd")
const ORIGINAL_ITEM_ICONS = preload("res://scripts/ppa_item_icon_loader.gd")
const ORIGINAL_ITEM_VIEWS = preload("res://scripts/ppa_server_inventory_view.gd")
const SAVE_VIEWS = preload("res://scripts/ppa_shared_save_views.gd")
const VERIFIED_PLAYER = preload("res://scripts/ppa_verified_player_projection.gd")
const CLAN_CONTENT = preload("res://scripts/ppa_clan_menu_content.gd")
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
var _craft_rarity := "all"
var _forge_resources_expanded := false
var _forge_equipment_tools_expanded := false
var _forge_inventory_host: VBoxContainer
var _forge_wallet_host: HBoxContainer
var _forge_recipe_target: Control
var _forge_keys: Dictionary = {"equipment":"", "stone":"", "rune":""}
var _enhance_uid := ""
var _enhance_mode := "normal"
var _last_clan_layout := false
var authoritative: Dictionary = {}
var has_verified_state := false
var clan_state: Dictionary = {}
var clan_actions: Array = []
var clan_busy := false
var clan_pending := false
var clan_notice := ""
var merchant_state: Dictionary = {}
var merchant_actions: Array = []
var merchant_busy := false
var merchant_pending := false
var merchant_notice := ""
var forge_state: Dictionary = {}
var forge_actions: Array = []
var forge_busy := false
var forge_pending := false
var forge_notice := ""
var inventory_state: Dictionary = {}
var inventory_actions: Array = []
var inventory_busy := false
var inventory_pending := false
var inventory_notice := ""
var personal_storage_state: Dictionary = {}
var personal_storage_actions: Array = []
var personal_storage_busy := false
var personal_storage_pending := false
var personal_storage_notice := ""
var _storage_bag_uid := ""
var _storage_personal_uid := ""
var clan_storage_state: Dictionary = {}
var clan_storage_actions: Array = []
var clan_storage_busy := false
var clan_storage_pending := false
var clan_storage_notice := ""
var _clan_put_uid := ""
var _clan_take_uid := ""
var auction_state: Dictionary = {}
var auction_notice := ""
var auction_loading := false
var auction_actions: Array = []
var auction_pending := false
var _auction_sell_uid := ""
var native_online_status := "ОБЩИЙ ОНЛАЙН · не подключён"
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
    _tabs.add_theme_constant_override("h_separation", 3)
    _tabs.add_theme_constant_override("v_separation", 3)
    _tab_scroller.add_child(_tabs)

    var rule := ColorRect.new()
    rule.custom_minimum_size.y = 1
    rule.color = Color("#714E28")
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layout.add_child(rule)

    # Original Telegram smith keeps a short, separately scrollable 100-slot
    # inventory beneath the 4+2 category tabs, before the recipe pane.
    _forge_inventory_host = VBoxContainer.new()
    _forge_inventory_host.name = "PPAForgePinnedInventory"
    _forge_inventory_host.visible = false
    layout.add_child(_forge_inventory_host)

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

    # Keep the three real PPA currency balances in sight, as in the Telegram
    # smith. Unknown server balances are shown as an em dash, NEVER zero.
    _forge_wallet_host = HBoxContainer.new()
    _forge_wallet_host.name = "PPAForgeFixedWallet"
    _forge_wallet_host.visible = false
    _forge_wallet_host.add_theme_constant_override("separation", 4)
    layout.add_child(_forge_wallet_host)

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
    # The actual Telegram blacksmith has FOUR buttons on its first row and
    # TWO buttons on the second row (verified against the original 2026-10-11
    # gameplay recording), not a 3x2 grid.
    var forge_grid := service == "forge"
    var columns := (5 if size.x > size.y else 3) if clan_grid else (4 if forge_grid else maxi(1, _tab_specs().size()))
    _tabs.columns = columns
    _tab_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if (clan_grid or forge_grid) else ScrollContainer.SCROLL_MODE_AUTO
    # Each row has a >=43px touch target and 5px spacing, plus safety space.
    _tab_scroller.custom_minimum_size.y = 169.0 if (clan_grid and columns == 3) else (112.0 if clan_grid else (101.0 if forge_grid else 54.0))
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
    clan_state.clear()
    clan_actions.clear()
    merchant_state.clear()
    merchant_actions.clear()
    forge_state.clear()
    forge_actions.clear()
    inventory_state.clear()
    inventory_actions.clear()
    personal_storage_state.clear()
    personal_storage_actions.clear()
    clan_storage_state.clear()
    clan_storage_actions.clear()
    auction_state.clear()
    auction_actions.clear()
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
    _craft_rarity = "all"
    _forge_resources_expanded = false
    _forge_equipment_tools_expanded = false
    _forge_keys = {"equipment":"", "stone":"", "rune":""}
    _enhance_uid = ""
    _enhance_mode = "normal"
    authoritative.clear()
    has_verified_state = false
    clan_state.clear()
    clan_actions.clear()
    clan_notice = ""
    merchant_state.clear()
    merchant_actions.clear()
    merchant_notice = ""
    forge_state.clear()
    forge_actions.clear()
    forge_notice = ""
    personal_storage_state.clear()
    personal_storage_actions.clear()
    personal_storage_notice = ""
    _storage_bag_uid = ""
    _storage_personal_uid = ""
    clan_storage_state.clear()
    clan_storage_actions.clear()
    clan_storage_notice = ""
    _clan_put_uid = ""
    _clan_take_uid = ""
    auction_state.clear()
    auction_notice = ""
    auction_loading = false
    auction_actions.clear()
    auction_pending = false
    _auction_sell_uid = ""
    inventory_state.clear()
    inventory_actions.clear()
    inventory_notice = ""
    visible = true
    _fit()
    _render()
    authoritative_state_requested.emit(service)

func close_npc() -> void:
    visible = false
    authoritative.clear()
    has_verified_state = false
    clan_state.clear()
    clan_actions.clear()
    merchant_state.clear()
    merchant_actions.clear()
    forge_state.clear()
    forge_actions.clear()
    forge_notice = ""
    forge_busy = false
    forge_pending = false
    inventory_state.clear()
    inventory_actions.clear()
    inventory_notice = ""
    inventory_busy = false
    inventory_pending = false
    personal_storage_state.clear()
    personal_storage_actions.clear()
    personal_storage_notice = ""
    personal_storage_busy = false
    personal_storage_pending = false
    _storage_bag_uid = ""
    _storage_personal_uid = ""
    clan_storage_state.clear()
    clan_storage_actions.clear()
    clan_storage_busy = false
    clan_storage_pending = false
    clan_storage_notice = ""
    _clan_put_uid = ""
    _clan_take_uid = ""
    auction_state.clear()
    auction_notice = ""
    auction_loading = false
    auction_actions.clear()
    auction_pending = false
    _auction_sell_uid = ""
    _enhance_uid = ""
    _enhance_mode = "normal"

func apply_native_clan(payload: Dictionary) -> void:
    if not visible or service not in ["clan","storage"] or payload.get("gameId") != "phoenix-pix-arena" \
        or payload.get("contract") != "ppa-clan-v1" \
        or not (payload.get("state") is Dictionary) or not (payload.get("actions") is Array):
        return
    var state: Dictionary = payload["state"]
    var profile: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(profile.get("telegramId", "")) if profile is Dictionary else ""
    if owner.is_empty() or str(payload.get("ownerId", "")) != owner \
        or not (state.get("self") is Dictionary) or str(state["self"].get("id", "")) != owner:
        return
    clan_state = state.duplicate(true)
    clan_actions = payload["actions"].duplicate() if service == "clan" else []
    _render()

func apply_native_merchant(payload: Dictionary) -> void:
    if not visible or service != "merchant" or payload.get("gameId") != "phoenix-pix-arena" \
        or payload.get("contract") != "ppa-merchant-v1" \
        or not (payload.get("state") is Dictionary) or not (payload.get("actions") is Array):
        return
    var state: Dictionary = payload["state"]
    var profile: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(profile.get("telegramId", "")) if profile is Dictionary else ""
    if owner.is_empty() or str(payload.get("ownerId", "")) != owner \
        or not (state.get("self") is Dictionary) or str(state["self"].get("id", "")) != owner \
        or not (state.get("offers") is Array) or not (state.get("wallet") is Dictionary) \
        or int(state.get("version", 0)) < 1:
        return
    merchant_state = state.duplicate(true)
    merchant_actions = payload["actions"].duplicate()
    _render()

func apply_native_forge(payload: Dictionary) -> void:
    if not visible or service != "forge" or payload.get("gameId") != "phoenix-pix-arena" \
        or payload.get("contract") != "ppa-forge-v1" \
        or not (payload.get("state") is Dictionary) or not (payload.get("actions") is Array):
        return
    var state: Dictionary = payload["state"]
    var owner_data: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(owner_data.get("telegramId", "")) if owner_data is Dictionary else ""
    if owner.is_empty() or str(payload.get("ownerId", "")) != owner \
        or not (state.get("self") is Dictionary) or str(state["self"].get("id", "")) != owner \
        or not (state.get("offers") is Array) or not (state.get("wallet") is Dictionary) \
        or int(state.get("version", 0)) < 1:
        return
    forge_state = state.duplicate(true)
    forge_actions = payload["actions"].duplicate()
    _render()

func apply_native_inventory(payload: Dictionary) -> void:
    if not visible or service != "forge" or payload.get("gameId") != "phoenix-pix-arena" \
        or payload.get("contract") != "ppa-inventory-v1" \
        or not (payload.get("state") is Dictionary) or not (payload.get("actions") is Array):
        return
    var state: Dictionary = payload["state"]
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId", "")) if account is Dictionary else ""
    if owner.is_empty() or str(payload.get("ownerId", "")) != owner \
        or not (state.get("self") is Dictionary) or str(state["self"].get("id", "")) != owner \
        or not (state.get("bag") is Array) or not (state.get("equipped") is Dictionary) \
        or int(state.get("version", 0)) < 1:
        return
    inventory_state = state.duplicate(true)
    inventory_actions = payload["actions"].duplicate()
    _render()

func apply_native_personal_storage(payload: Dictionary) -> void:
    if not visible or service != "storage" or payload.get("gameId") != "phoenix-pix-arena" \
        or payload.get("contract") != "ppa-personal-storage-v1" \
        or not (payload.get("state") is Dictionary) or not (payload.get("actions") is Array):
        return
    var state: Dictionary = payload["state"]
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId", "")) if account is Dictionary else ""
    if owner.is_empty() or str(payload.get("ownerId", "")) != owner \
        or not (state.get("self") is Dictionary) or str(state["self"].get("id", "")) != owner \
        or not (state.get("bag") is Array) or not (state.get("personal") is Array) \
        or int(state.get("version", 0)) < 1:
        return
    personal_storage_state = state.duplicate(true)
    personal_storage_actions = payload["actions"].duplicate()
    _render()

func apply_native_auction(payload: Dictionary) -> void:
    if not visible or service != "auction" or payload.get("gameId") != "phoenix-pix-arena" \
        or payload.get("contract") != "ppa-auction-v1" \
        or not (payload.get("state") is Dictionary):
        return
    var state: Dictionary = payload["state"]
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId", "")) if account is Dictionary else ""
    if owner.is_empty() or str(payload.get("ownerId", "")) != owner \
        or not (state.get("self") is Dictionary) or str(state["self"].get("id", "")) != owner \
        or not (state.get("lots") is Array) or not (state.get("mine") is Array) \
        or not (state.get("pendingCredits") is Array) \
        or not (state.get("recoverable") is Array) \
        or not (state.get("wallet") is Dictionary) \
        or not (state.get("settlementEnabled") is bool) \
        or int(state.get("version", 0)) < 1:
        return
    auction_state = state.duplicate(true)
    auction_actions = payload.get("actions", []).duplicate()
    auction_loading = false
    _render()

func set_native_auction_loading(busy: bool) -> void:
    auction_loading = busy
    if visible and service == "auction":
        _render()

func set_native_auction_pending(busy: bool, pending: bool) -> void:
    auction_loading = busy
    auction_pending = pending
    if visible and service == "auction":
        _render()

func set_native_auction_notice(message: String) -> void:
    auction_notice = message.left(220)
    auction_loading = false
    if visible and service == "auction":
        _render()

func apply_native_clan_storage(payload: Dictionary) -> void:
    if not visible or service not in ["storage","clan"] \
        or payload.get("gameId") != "phoenix-pix-arena" \
        or payload.get("contract") != "ppa-clan-storage-v1" \
        or not (payload.get("state") is Dictionary) or not (payload.get("actions") is Array):
        return
    var state: Dictionary = payload["state"]
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId", "")) if account is Dictionary else ""
    if owner.is_empty() or str(payload.get("ownerId", "")) != owner \
        or not (state.get("self") is Dictionary) or str(state["self"].get("id", "")) != owner \
        or not (state.get("bag") is Array) or not (state.get("items") is Array) \
        or str(state.get("clanRevision", "")).length() != 64 \
        or int(state.get("version", 0)) < 1:
        return
    clan_storage_state = state.duplicate(true)
    clan_storage_actions = payload["actions"].duplicate()
    _render()

func set_clan_storage_loading(busy: bool, pending: bool) -> void:
    clan_storage_busy = busy
    clan_storage_pending = pending
    if visible and service in ["storage","clan"]:
        _render()

func set_clan_storage_notice(message: String, pending: bool) -> void:
    clan_storage_notice = message.left(240)
    clan_storage_pending = pending
    if visible and service in ["storage","clan"]:
        _render()

func set_personal_storage_loading(busy: bool, pending: bool) -> void:
    personal_storage_busy = busy
    personal_storage_pending = pending
    if visible and service == "storage":
        _render()

func set_personal_storage_notice(message: String, pending: bool) -> void:
    personal_storage_notice = message.left(240)
    personal_storage_pending = pending
    if visible and service == "storage":
        _render()

func set_inventory_loading(busy: bool, pending: bool) -> void:
    inventory_busy = busy
    inventory_pending = pending
    if visible and service == "forge":
        _render()

func set_inventory_notice(message: String, pending: bool) -> void:
    inventory_notice = message.left(240)
    inventory_pending = pending
    if visible and service == "forge":
        _render()

func set_forge_loading(busy: bool, pending: bool) -> void:
    forge_busy = busy
    forge_pending = pending
    if visible and service == "forge":
        _render()

func set_forge_notice(message: String, pending: bool) -> void:
    forge_notice = message.left(240)
    forge_pending = pending
    if visible and service == "forge":
        _render()

func set_merchant_loading(busy: bool, pending: bool) -> void:
    merchant_busy = busy
    merchant_pending = pending
    if visible and service == "merchant":
        _render()

func set_merchant_notice(message: String, pending: bool) -> void:
    merchant_notice = message.left(240)
    merchant_pending = pending
    if visible and service == "merchant":
        _render()

func set_clan_loading(busy: bool, pending: bool) -> void:
    clan_busy = busy
    clan_pending = pending
    if visible and service == "clan":
        _render()

func set_clan_notice(message: String, pending: bool) -> void:
    clan_notice = message.left(240)
    clan_pending = pending
    if visible and service == "clan":
        _render()

func request_clan_action(action: String, fields: Dictionary) -> void:
    if not visible or service != "clan" or not _owns_verified_state(clan_state) \
        or clan_busy or clan_pending or not clan_actions.has(action):
        return
    if action in ["leaveClan", "kickMember", "transferLeadership"]:
        var dialog := ConfirmationDialog.new()
        dialog.dialog_text = {"leaveClan":"Выйти из клана? Вступление и создание клана будут закрыты на 24 часа. Если ты последний участник, клан будет удалён.",
            "kickMember":"Исключить выбранного участника из клана?",
            "transferLeadership":"Передать выбранному участнику права главы?"}.get(action, "Подтвердить действие?")
        dialog.title = "Клан PPA"
        dialog.confirmed.connect(func():
            if visible and service == "clan" and _owns_verified_state(clan_state) \
                and not clan_busy and not clan_pending and clan_actions.has(action):
                clan_action_requested.emit(action, fields.duplicate(true))
            dialog.queue_free())
        dialog.canceled.connect(dialog.queue_free)
        add_child(dialog)
        dialog.popup_centered(Vector2i(350, 150))
    else:
        clan_action_requested.emit(action, fields.duplicate(true))

func _owns_verified_state(state: Dictionary) -> bool:
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var self_data: Variant = state.get("self")
    return account is Dictionary and self_data is Dictionary \
        and not str(account.get("telegramId", "")).is_empty() \
        and str(self_data.get("id", "")) == str(account.get("telegramId", ""))

func show_canonical_clan_storage(items: Array) -> void:
    var scroller := ScrollContainer.new()
    scroller.custom_minimum_size = Vector2(0, 260)
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _body.add_child(scroller)
    var grid = VIRTUAL_GRID.new()
    grid.custom_minimum_size.x = 300
    scroller.add_child(grid)
    grid.configure("clan", scroller, 5)
    grid.apply_items_readonly(items)

# Read-only future bridge contract. Call ONLY after authenticated server
# account+service validation; rendering these fields is not permission to buy.
func apply_authoritative_snapshot(snapshot: Dictionary) -> void:
    if not visible or str(snapshot.get("service", "")) != service \
            or snapshot.get("readOnly", false) != true \
            or str(snapshot.get("gameId", "")) != "phoenix-pix-arena":
        return
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId", "")) if account is Dictionary else ""
    if owner.is_empty() or str(snapshot.get("ownerId", "")) != owner:
        return
    if not snapshot.has("data") or not (snapshot["data"] is Dictionary):
        return
    var data: Dictionary = snapshot["data"]
    if data.get("readOnly", false) != true or data.get("actionsEnabled", true) != false:
        return
    authoritative = data.duplicate(true)
    authoritative["saveVersion"] = int(snapshot.get("version", 0))
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
    _craft_rarity = "all"
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
    _forge_recipe_target = null
    _layout_tabs()
    _heading.text = "КУЗНЕЦ" if service == "forge" else str(npc.get("name", "NPC"))
    _heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if service == "forge" else HORIZONTAL_ALIGNMENT_LEFT
    _subheading.text = ("ЗАТОЧКА · СНАРЯЖЕНИЕ · АКСЕССУАРЫ · ПЕТЫ" if service == "forge" else "МИРНЫЙ ГОРОД · " + _service_name())
    _subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if service == "forge" else HORIZONTAL_ALIGNMENT_LEFT
    _portrait.visible = service != "forge"
    _portrait.texture = null
    var portrait_path := str(npc.get("image", ""))
    if ResourceLoader.exists(portrait_path):
        _portrait.texture = load(portrait_path) as Texture2D
    for entry in _tab_specs():
        var id := str(entry.get("key", ""))
        var b := _button(str(entry.get("label", "")))
        b.name = "NpcTab_" + id
        b.custom_minimum_size.y = 43.0
        if service == "clan" or service == "forge":
            var available := _frame.offset_right - _frame.offset_left - 43.0
            var slot_width := floorf(available / float(_tabs.columns)) - 5.0
            b.custom_minimum_size.x = maxf(50.0 if service == "forge" else 68.0, slot_width)
            b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            b.add_theme_font_size_override("font_size", 8 if service == "forge" else (9 if _tabs.columns == 3 else 10))
            # Keep the original category labels; avoid making a 3-column
            # button wider than the panel and accidentally enabling swipe.
            if service == "clan" and _tabs.columns == 3 and id == "clans":
                b.text = "КЛАНЫ"
        else:
            b.custom_minimum_size.x = maxf(105.0, float(str(entry.get("label", "")).length()) * 9.0)
        b.add_theme_color_override("font_color", GOLD if id == tab else SUB)
        b.add_theme_stylebox_override("normal", _style(Color("#44301D") if id == tab else Color("#191B1E"),
            GOLD if id == tab else Color("#66513B"), 6))
        b.pressed.connect(_select_tab.bind(id))
        _tabs.add_child(b)
    if _forge_inventory_host != null:
        _clear(_forge_inventory_host)
        _forge_inventory_host.visible = service == "forge"
        if service == "forge":
            _show_forge_pinned_inventory()
    if _forge_wallet_host != null:
        _clear(_forge_wallet_host)
        _forge_wallet_host.visible = service == "forge"
        if service == "forge":
            _show_forge_wallet()
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
    if service == "clan" and not clan_state.is_empty():
        _status.text = "PPA · общий клан · подтверждённые серверные действия"
        if clan_actions.is_empty():
            _status.text = "PPA · общий клан · серверные действия ещё не включены"
        if clan_busy:
            _status.text = "PPA · запрос к серверу клана…"
    if service == "merchant" and not merchant_state.is_empty():
        _status.text = "PPA · общий торговец · покупка через сервер"
        if merchant_actions.is_empty():
            _status.text = "PPA · общий торговец · покупки ещё не включены"
        if merchant_busy:
            _status.text = "PPA · запрос к серверу торговца…"
    if service == "arena":
        _status.text += " · " + native_online_status
    if service == "forge" and _forge_recipe_target != null:
        _scroll.call_deferred("ensure_control_visible", _forge_recipe_target)
    else:
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
        var b := _button(str(opt.get("label", "")), bool(opt.get("enabled", true)))
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
        _preview_icons.bind_button(item, _forge_player_class() if service == "forge" else "", button)
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
    # Three columns squeeze Russian item names on portrait tablets.
    var compact_forge := service == "forge" and tab in ["equipment", "legendary", "accessories", "pets"]
    grid.columns = 2 if (compact_forge and _frame.size.x >= 430.0) or _frame.size.x >= 780.0 else 1
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    _body.add_child(grid)
    if products.is_empty():
        _message("ПОКА НЕТ ПРЕДЛОЖЕНИЙ", \
            "В оригинальном каталоге торговца в этой вкладке нет товаров." \
            if service == "merchant" else "Персональные предложения этого раздела проверяются по сохранению PPA.")
        return
    for entry in products:
        var item: Dictionary = entry
        var id := str(item.get("id", ""))
        if compact_forge:
            # Telegram original uses short two-column clickable item rows,
            # with icon left, text/price right and the selected row outlined.
            var forge_choice := _button("", true)
            forge_choice.name = "NpcProduct_" + id.to_utf8_buffer().hex_encode()
            forge_choice.set_meta("ppa_original_offer_id", id)
            forge_choice.custom_minimum_size.y = 76.0
            forge_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            forge_choice.add_theme_stylebox_override("normal",
                _style(Color("#13191C"), GOLD if id == selected_id else Color("#5E4B35"), 5))
            forge_choice.add_theme_stylebox_override("hover",
                _style(Color("#29251D"), GOLD, 5))
            forge_choice.pressed.connect(_select_item.bind(id))
            grid.add_child(forge_choice)
            var product_line := HBoxContainer.new()
            product_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
            product_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            product_line.offset_left = 6.0
            product_line.offset_right = -6.0
            product_line.offset_top = 3.0
            product_line.offset_bottom = -3.0
            product_line.add_theme_constant_override("separation", 5)
            forge_choice.add_child(product_line)
            var product_icon := _readonly_icon_item(item, 48)
            product_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
            product_line.add_child(product_icon)
            var captions := VBoxContainer.new()
            captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
            captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            product_line.add_child(captions)
            var text_name := _label(str(item.get("name", "")), 11, GOLD)
            captions.add_child(text_name)
            var forge_price := _label(str(item.get("price", "?")) + " PPA", 10, SUB)
            captions.add_child(forge_price)
            continue
        var tile := PanelContainer.new()
        # Live recipe IDs contain ':' (e.g. acc:ring:legendary), which Godot
        # forbids in Node.name. Preserve the exact ID as metadata while giving
        # the control a lossless, valid ASCII node name for QA and inspection.
        tile.name = "NpcProduct_" + id.to_utf8_buffer().hex_encode()
        tile.set_meta("ppa_original_offer_id", id)
        tile.custom_minimum_size.y = 140
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tile.add_theme_stylebox_override("panel", _style(Color("#161B1F"),
            GOLD if id == selected_id else Color("#5E4B35"), 7))
        grid.add_child(tile)
        var inner := VBoxContainer.new()
        inner.add_theme_constant_override("separation", 4)
        inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tile.add_child(inner)
        # The canonical Black Market save may carry artwork in offer.item.
        # Read existing visuals only; do not invent a random personal offer.
        var display_item := item.duplicate(true)
        var offer_item: Variant = item.get("item", null)
        if offer_item is Dictionary:
            for field in ["img", "image", "iconArt", "art", "src", "icon"]:
                if str(display_item.get(field, "")).is_empty():
                    display_item[field] = (offer_item as Dictionary).get(field, "")
        var image_found := false
        for field in ["img", "image", "iconArt", "art", "src"]:
            if not str(display_item.get(field, "")).is_empty():
                image_found = true
                break
        if image_found:
            inner.add_child(_readonly_icon_item(display_item, 50))
        elif not str(display_item.get("icon", "")).is_empty():
            inner.add_child(_label(str(display_item.get("icon", "")), 23, GOLD))
        else:
            inner.add_child(_label("◇", 23, GOLD))
        var product_name := _label(str(item.get("name", "")), 12, TEXT)
        product_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        product_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        inner.add_child(product_name)
        var currency_code := str(item.get("currency", "gold")).to_lower()
        var currency := " Gram" if currency_code == "gram" else (" PPA" if currency_code == "ppa" else " Gold")
        var price_text := str(item["price"]) + currency if item.get("price", null) != null \
            else "Цена не подтверждена"
        inner.add_child(_label(price_text, 12, GOLD))
        if bool(item.get("ppa_reference_only", false)):
            inner.add_child(_label("Справочная цена · не подтверждена", 10, SUB))
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
    var currency_code := str(item.get("currency", "gold")).to_lower()
    var suffix := " Gram" if currency_code == "gram" else (" PPA" if currency_code == "ppa" else " Gold")
    if item.has("limit"):
        # Telegram keeps Black Market purchases in the character-specific
        # blackMarket.bought dictionary. An absent counter is UNKNOWN, not 0.
        var bought: Variant = item.get("bought", null)
        if (bought is int or bought is float) and float(bought) >= 0.0 \
                and floorf(float(bought)) == float(bought):
            var left := maxi(0, int(item.get("limit", 1)) - int(bought))
            _mini_row("Дневной лимит", "осталось " + str(left))
        else:
            _mini_row("Дневной лимит", "остаток не подтверждён сервером")
    _body.add_child(_label("Цена: " + str(item["price"]) + suffix, 15, GOLD) \
        if item.get("price", null) != null else _label("Цена ещё не подтверждена", 15, SUB))
    if bool(item.get("ppa_reference_only", false)):
        _body.add_child(_label("Это справочный каталог Telegram PPA, не живое предложение для покупки.", 11, SUB))
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
    if service == "merchant" and not merchant_state.is_empty() \
            and not bool(item.get("ppa_reference_only", true)):
        var wallet: Dictionary = merchant_state.get("wallet", {})
        var total := int(item.get("price", 0)) * quantity
        var enabled: bool = merchant_actions.has("buy") and not merchant_busy and not merchant_pending \
            and float(wallet.get(currency_code, 0)) >= total
        var buy := _button("КУПИТЬ", enabled)
        buy.name = "MerchantCommand_buy"
        buy.pressed.connect(func():
            if visible and service == "merchant" and _owns_verified_state(merchant_state) \
                and merchant_actions.has("buy") and not merchant_busy and not merchant_pending:
                merchant_action_requested.emit({"id":str(item.get("id", "")), "qty":quantity,
                    "version":int(merchant_state.get("version", 0))}))
        _body.add_child(buy)
    else:
        _locked_action("КУПИТЬ")

func _merchant_products() -> Array:
    # Render ALL approved original Telegram products, even when the signed
    # merchant endpoint is gated/partial. Missing offers are reference-only.
    var verified: Dictionary = {}
    if not merchant_state.is_empty():
        var rows: Variant = merchant_state.get("offers", [])
        if rows is Array:
            for raw in rows:
                if not (raw is Dictionary):
                    continue
                var offer: Dictionary = raw
                var offer_id := str(offer.get("id", ""))
                var amount: Variant = offer.get("price", null)
                var currency := str(offer.get("currency", "")).to_lower()
                if offer_id.is_empty() or not (amount is int or amount is float) \
                        or float(amount) < 0.0 or currency not in ["gold", "ppa"]:
                    continue
                verified[offer_id] = offer
    var products: Array = []
    for source in SHOP.MERCHANT:
        var reference: Dictionary = source
        var product: Dictionary = reference.duplicate(true)
        var offer_id := str(reference.get("id", ""))
        product["ppa_reference_only"] = true
        if verified.has(offer_id):
            product.merge(verified[offer_id], true)
            # Original tab/approved local artwork are presentation-only.
            # Signed server response owns prices, names and quantities.
            product["tab"] = reference.get("tab", "")
            product["img"] = reference.get("img", "")
            product["ppa_reference_only"] = false
        products.append(product)
    return products

func _show_merchant() -> void:
    _section("ЛАВКА ТОРГОВЦА", "Товары PPA · цена и покупка подтверждаются общим сервером")
    var refresh := _button("ОБНОВИТЬ ТОРГОВЦА", not merchant_busy)
    refresh.pressed.connect(func(): authoritative_state_requested.emit("merchant"))
    _body.add_child(refresh)
    if not merchant_notice.is_empty():
        _body.add_child(_label(merchant_notice, 12, GOLD))
    if merchant_pending:
        var retry := _button("ПРОВЕРИТЬ ТО ЖЕ ДЕЙСТВИЕ", not merchant_busy)
        retry.name = "MerchantRetryPending"
        retry.pressed.connect(func(): merchant_retry_requested.emit())
        _body.add_child(retry)
    var filtered: Array = []
    for entry in _merchant_products():
        if str(entry.get("tab", "")) == tab:
            filtered.append(entry)
    _product_grid(filtered, true)
    _selected_details(filtered, true)
    if merchant_state.is_empty():
        _body.add_child(_label("Цены справочные · покупки требуют подтверждения сервером PPA.", 11, SUB))
    var money: Dictionary = _player_view_readonly.get("money", {})
    if not merchant_state.is_empty():
        money = merchant_state.get("wallet", {})
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
    var personal := false
    if has_verified_state and authoritative.get("offers", null) is Array:
        listed = authoritative.get("offers", [])
        personal = true
    else:
        # The ORIGINAL Telegram client persists each character's daily stock
        # under state.blackMarket. Use it ONLY from the authenticated save,
        # preserving real purchase limits; never invent random new offers.
        var raw_bm: Variant = _player_save_readonly.get("blackMarket", null)
        if raw_bm is Dictionary:
            var saved_bm: Dictionary = raw_bm
            var stored_offers: Variant = saved_bm.get("offers", null)
            var refresh_at := float(saved_bm.get("refreshAt",0))
            if stored_offers is Array and refresh_at > Time.get_unix_time_from_system() * 1000.0:
                var bought: Dictionary = saved_bm.get("bought", {}) if saved_bm.get("bought", {}) is Dictionary else {}
                for stored in stored_offers:
                    if not (stored is Dictionary):
                        continue
                    var offer: Dictionary = (stored as Dictionary).duplicate(true)
                    offer.erase("bought")
                    var original_id := str(offer.get("id", ""))
                    if bought.has(original_id):
                        var confirmed: Variant = bought[original_id]
                        if (confirmed is int or confirmed is float) and float(confirmed) >= 0.0 \
                                and floorf(float(confirmed)) == float(confirmed):
                            offer["bought"] = int(confirmed)
                    listed.append(offer)
                personal = true
                _mini_row("ОБНОВЛЕНИЕ АССОРТИМЕНТА", Time.get_datetime_string_from_unix_time(int(refresh_at / 1000.0)).replace("T"," "))
            elif stored_offers is Array:
                _message("АССОРТИМЕНТ УСТАРЕЛ", "Дневные предложения должны быть обновлены в оригинальной PPA. Старые лоты не выдаём за доступные.")
    if not personal:
        _message("СПРАВОЧНЫЙ АССОРТИМЕНТ", "Постоянные позиции оригинальной PPA. Текущие персональные лоты ещё не синхронизированы.")
        listed = SHOP.BLACK_MARKET_REFERENCE
    var filtered: Array = []
    for entry in listed:
        if not (entry is Dictionary):
            continue
        var offer: Dictionary = (entry as Dictionary).duplicate(true)
        var nested: Variant = offer.get("item", null)
        if nested is Dictionary:
            var underlying: Dictionary = nested
            # Items from the original randomized Telegram PPA market can
            # have artwork/name only in the actual offer's nested item.
            # Do not copy prices, stock, categories or availability from it.
            for key in ["name", "img", "image", "iconArt", "art", "icon"]:
                if str(offer.get(key, "")).is_empty():
                    offer[key] = underlying.get(key, "")
        if tab == "all" or str(offer.get("category", "")) == tab:
            filtered.append(offer)
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

func _show_verified_d1_forge_stock() -> void:
    # The initial signed /api/game/state snapshot already carries the actual
    # player's money, stones, materials, feathers and bag. Rendering them does
    # NOT authorize forging and never spends a material.
    if _player_view_readonly.is_empty():
        _message("ОЖИДАЕМ СЕЙВ PPA", "Вещи и ресурсы появятся после подтверждения аккаунта.")
        return
    _section("ВАШИ РЕСУРСЫ И ВАЛЮТА · D1", "Подтверждено общим сохранением персонажа · только просмотр")
    var money: Dictionary = _player_view_readonly.get("money", {})
    _mini_row("Gold / PPA / Gram", \
        (str(money["gold"]) if money.get("gold", null) != null else "—") + " / " + \
        (str(money["ppa"]) if money.get("ppa", null) != null else "—") + " / " + \
        (str(money["gram"]) if money.get("gram", null) != null else "—"))
    var stones: Variant = _player_save_readonly.get("stones", null)
    if stones is Dictionary:
        for row in [
            {"key":"normal", "title":"Обычные камни заточки"},
            {"key":"premium", "title":"Премиум камни заточки"},
            {"key":"rune", "title":"Премиум руны заточки"}
        ]:
            var value: Variant = (stones as Dictionary).get(row["key"], null)
            if value is int or value is float:
                if float(value) >= 0.0:
                    _mini_row(str(row["title"]), str(int(value)))
    var feathers: Variant = _player_save_readonly.get("feathers", null)
    if feathers is Dictionary:
        var count: Variant = (feathers as Dictionary).get("phoenix", null)
        if (count is int or count is float) and float(count) >= 0.0:
            _mini_row("Перо Феникса", str(int(count)))
    var materials: Variant = _player_save_readonly.get("materials", null)
    if materials is Dictionary:
        var names: Array[String] = []
        for name in (materials as Dictionary).keys():
            var value: Variant = (materials as Dictionary).get(name, null)
            if (value is int or value is float) and float(value) > 0.0:
                names.append(str(name))
        names.sort()
        for name in names.slice(0, 32):
            _mini_row(name, str(int((materials as Dictionary).get(name, 0))))
        if names.size() > 32:
            _body.add_child(_label("Показаны первые 32 ресурса из подтверждённого D1-снимка.", 11, SUB))
    if tab == "enhance":
        var real_items: Array = _player_view_readonly.get("inventory", [])
        var owned_gear: Array = []
        for entry in real_items:
            if not (entry is Dictionary):
                continue
            var item: Dictionary = entry
            var slot := str(item.get("ppaEquipmentSlot", item.get("equipSlot", "")))
            if str(item.get("kind", "")) == "gear" or slot in \
                    ["weapon","helmet","armor","gloves","ring","legs","boots","necklace","artifact","cloak","wings","pet"]:
                owned_gear.append(item)
        if not owned_gear.is_empty():
            _readonly_owned_grid("ВАША ЭКИПИРОВКА В СУМКЕ · ТОЛЬКО ПРОСМОТР", owned_gear, 32)


func _show_forge_wallet() -> void:
    if _forge_wallet_host == null:
        return
    var balances: Dictionary = _player_view_readonly.get("money", {})
    if not forge_state.is_empty() and _owns_verified_state(forge_state):
        var signed_wallet: Variant = forge_state.get("wallet", null)
        if signed_wallet is Dictionary:
            balances = balances.duplicate()
            for code in ["gold", "gram", "ppa"]:
                if (signed_wallet as Dictionary).get(code, null) != null:
                    balances[code] = signed_wallet[code]
    for spec in [
        {"code":"gold","name":"Gold","symbol":"●"},
        {"code":"gram","name":"Gram","symbol":"◆"},
        {"code":"ppa","name":"PPA","symbol":"✹"}
    ]:
        var panel := PanelContainer.new()
        panel.name = "PPAForgeWallet_" + str(spec["code"])
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.add_theme_stylebox_override("panel", _style(Color("#12191C"), Color("#77532E"), 4))
        _forge_wallet_host.add_child(panel)
        var value: Variant = balances.get(spec["code"], null)
        var shown := str(value) if value is int or value is float else "—"
        var caption := _label(str(spec["symbol"]) + " " + str(spec["name"]) + "  " + shown, 10, GOLD)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        panel.add_child(caption)


func _forge_player_class() -> String:
    # Extract only an explicitly authenticated class from the shared save.
    # The public smith art must never be assigned to an invented class.
    for key in ["classKey", "class", "cls", "playerClass", "heroClass"]:
        var value := str(_player_save_readonly.get(key, "")).to_lower()
        if ORIGINAL_ITEM_ICONS.CLASS_KEYS.has(value):
            return value
    var player: Variant = _player_save_readonly.get("player", null)
    if player is Dictionary:
        for key in ["classKey", "class", "cls"]:
            var value := str((player as Dictionary).get(key, "")).to_lower()
            if ORIGINAL_ITEM_ICONS.CLASS_KEYS.has(value):
                return value
    return ""


func _show_forge_pinned_inventory() -> void:
    # Same hierarchy as the Telegram original: 4+2 tabs, short 100-slot bag
    # preview, then the independently scrollable forge/recipe panel. All items
    # are taken from the signed player projection; no simulated inventory.
    if _forge_inventory_host == null:
        return
    var inventory: Array = _player_view_readonly.get("inventory", [])
    var header := HBoxContainer.new()
    _forge_inventory_host.add_child(header)
    var title := _label("ИНВЕНТАРЬ", 12, GOLD)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var shown := 0
    for raw in inventory:
        if raw is Dictionary and not (raw as Dictionary).is_empty():
            shown += 1
    header.add_child(_label(str(shown) + " / 100" if not _player_view_readonly.is_empty() else "— / 100", 10, SUB))

    var clip := ScrollContainer.new()
    clip.name = "PPAForgeBagScroller"
    clip.custom_minimum_size.y = 114.0 if size.x > size.y else 170.0
    clip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    clip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _forge_inventory_host.add_child(clip)
    var grid := GridContainer.new()
    grid.name = "PPAForgeInventoryGrid"
    grid.columns = 10
    grid.add_theme_constant_override("h_separation", 2)
    grid.add_theme_constant_override("v_separation", 2)
    clip.add_child(grid)
    var panel_width := _frame.offset_right - _frame.offset_left
    var cell := maxf(22.0, floorf((panel_width - 67.0) / 10.0) - 2.0)
    for i in range(100):
        var item: Dictionary = {}
        if i < inventory.size() and inventory[i] is Dictionary:
            item = inventory[i]
        var square: Control
        if item.is_empty():
            var blank := PanelContainer.new()
            blank.add_theme_stylebox_override("panel",
                _style(Color("#0B1114"), Color("#5B472D"), 1))
            square = blank
        else:
            var real_icon := _readonly_icon_item(item, cell)
            real_icon.add_theme_stylebox_override("disabled",
                _style(Color("#151A20"), SHOP.rarity_tint(str(item.get("rarity", "common"))), 1))
            square = real_icon
        square.name = "PPAForgeBagSlot_" + str(i)
        square.custom_minimum_size = Vector2(cell, cell)
        grid.add_child(square)


func _toggle_forge_resources() -> void:
    _forge_resources_expanded = not _forge_resources_expanded
    _render()

func _toggle_forge_equipment_tools() -> void:
    _forge_equipment_tools_expanded = not _forge_equipment_tools_expanded
    _render()


func _show_forge() -> void:
    # Show the selected Telegram-style craft or enhancement task FIRST.
    # Signed balances and the full D1 material list remain available on demand
    # without pushing the actual blacksmith controls below the first screen.
    var source_note := ("Оригинальные рецепты PPA · стоимость и материалы из каталога."
        if tab in ["equipment", "legendary", "accessories", "pets"]
        else "Вещи из сохранения PPA · операции проверяет игровой сервер.")
    if tab == "enhance" or tab == "rune_fusion":
        _section("ЗАТОЧКА" if tab == "enhance" else "СЛИЯНИЕ РУН", source_note)
    if not forge_notice.is_empty():
        _body.add_child(_label(forge_notice, 12, GOLD))
    if forge_pending:
        var retry := _button("ПРОВЕРИТЬ ТО ЖЕ СОЗДАНИЕ", not forge_busy)
        retry.pressed.connect(func(): forge_retry_requested.emit())
        _body.add_child(retry)

    if tab == "enhance":
        _show_authoritative_enhancement()
    elif tab == "rune_fusion":
        _message("СЛИЯНИЕ РУН",
            "2 одинаковые руны · попытка 5000 Gold. Серая → зелёная 37%, зелёная → синяя 30%, синяя → фиолетовая 22%.")
        if _player_view_readonly.is_empty():
            _message("НЕТ СЕРВЕРНОГО СНИМКА", "Ожидаем настоящее сохранение персонажа.")
        else:
            var runes: Dictionary = ORIGINAL_ITEM_VIEWS.rune_view_from_save(_player_save_readonly)
            _readonly_owned_grid("ВАШИ РУНЫ", runes.get("inventory", []))
        _locked_action("СЛИТЬ РУНЫ")
    else:
        _show_original_forge_recipes()

    if tab == "enhance":
        var equip_tools := _button("СКРЫТЬ ПЕРЕОДЕВАНИЕ ▲" if _forge_equipment_tools_expanded else "СНЯТЬ ИЛИ НАДЕТЬ ВЕЩЬ ▼")
        equip_tools.name = "PPAForgeEquipmentToolsToggle"
        equip_tools.pressed.connect(_toggle_forge_equipment_tools)
        _body.add_child(equip_tools)
        if _forge_equipment_tools_expanded:
            _show_shared_equipment_tools()

    var resources := _button("СКРЫТЬ МОИ РЕСУРСЫ ▲" if _forge_resources_expanded else "МОИ РЕСУРСЫ И БАЛАНС ▼")
    resources.name = "PPAForgeResourcesToggle"
    resources.pressed.connect(_toggle_forge_resources)
    _body.add_child(resources)
    if _forge_resources_expanded:
        if has_verified_state and authoritative.get("service") == "forge" \
            and authoritative.get("readOnly") == true:
            _body.add_child(_label("Серверный снимок · версия " +
                str(authoritative.get("saveVersion", "—")), 11, GOLD))
        elif _player_view_readonly.is_empty():
            _body.add_child(_label("Подтверждённое сохранение ещё не загружено.", 11, SUB))
        _show_verified_d1_forge_stock()

    var refresh := _button("ОБНОВИТЬ ДАННЫЕ С СЕРВЕРА PPA")
    refresh.pressed.connect(func(): authoritative_state_requested.emit("forge"))
    _body.add_child(refresh)
    _body.add_child(_label("Создание и заточка не выполняются локально: безопасность предметов проверяет сервер PPA.", 11, SUB))

func _choose_enhancement_item(uid: String) -> void:
    _enhance_uid = uid
    _render()

func _set_enhancement_mode(mode: String) -> void:
    if mode in ["normal", "normal_rune", "premium", "premium_rune"]:
        _enhance_mode = mode
    _render()

func _request_real_enhancement(uid: String, mode: String, version: int) -> void:
    if not visible or service != "forge" or forge_busy or forge_pending \
        or not forge_actions.has("enhance") or not _owns_verified_state(forge_state) \
        or int(forge_state.get("version", 0)) != version:
        return
    var match_found := false
    for saved in forge_state.get("enhanceItems", []):
        if saved is Dictionary and str(saved.get("uid", "")) == uid \
            and int(saved.get("enh", -1)) < 7 and not bool(saved.get("special", false)):
            match_found = true
            break
    if not match_found:
        return
    forge_action_requested.emit({"action":"enhance", "uid":uid, "stone":mode, "version":version})

func _request_original_equipment_move(action: String, target: String, version: int) -> void:
    if not visible or service != "forge" or inventory_busy or inventory_pending \
        or not inventory_actions.has(action) or not _owns_verified_state(inventory_state) \
        or version != int(inventory_state.get("version", -1)):
        return
    if action == "unequip":
        var equipped: Variant = inventory_state.get("equipped", {})
        if not (equipped is Dictionary) or not ((equipped as Dictionary).get(target) is Dictionary):
            return
        inventory_action_requested.emit({"action":"unequip","slot":target,"version":version})
    elif action == "equip":
        var match_found := false
        for entry in inventory_state.get("bag", []):
            if entry is Dictionary and str(entry.get("uid","")) == target:
                match_found = true
                break
        if match_found:
            inventory_action_requested.emit({"action":"equip","uid":target,"version":version})

func _show_shared_equipment_tools() -> void:
    _section("ЭКИПИРОВКА · ТОТ ЖЕ ПЕРСОНАЖ",
        "Снять вещь для заточки и надеть обратно · только через общий сервер PPA.")
    if not inventory_notice.is_empty():
        _body.add_child(_label(inventory_notice, 11, GOLD))
    if inventory_pending:
        var retry := _button("ПРОВЕРИТЬ ПРЕЖНЕЕ ПЕРЕМЕЩЕНИЕ", not inventory_busy)
        retry.pressed.connect(func(): inventory_retry_requested.emit())
        _body.add_child(retry)
    if not _owns_verified_state(inventory_state) or not (inventory_state.get("equipped") is Dictionary):
        _body.add_child(_label("Ожидаем подтверждённую серверную экипировку.", 11, SUB))
        return
    var server_version := int(inventory_state.get("version", 0))
    var action_allowed := not inventory_busy and not inventory_pending
    var worn: Dictionary = inventory_state.get("equipped", {})
    var grid := GridContainer.new()
    grid.columns = 2
    _body.add_child(grid)
    for slot in worn:
        var gear: Variant = worn[slot]
        if not (gear is Dictionary):
            continue
        var name_text := str((gear as Dictionary).get("name","Вещь")).left(24)
        var b := _button("СНЯТЬ · " + name_text, inventory_actions.has("unequip") and action_allowed)
        b.name = "PPARealUnequip_" + str(slot)
        b.pressed.connect(_request_original_equipment_move.bind("unequip", str(slot), server_version))
        grid.add_child(b)
    _body.add_child(_label("Сумка · выбери вещь для экипировки:", 11, SUB))
    var bag: Variant = inventory_state.get("bag", null)
    if bag is Array:
        var bag_grid := GridContainer.new()
        bag_grid.columns = 2
        _body.add_child(bag_grid)
        for entry in bag:
            if not (entry is Dictionary):
                continue
            var uid := str(entry.get("uid", ""))
            if uid.is_empty():
                continue
            var slot_name := str(entry.get("slot", ""))
            if slot_name not in ["weapon", "helmet", "armor", "gloves", "ring", "legs",
                "boots", "necklace", "artifact", "cloak", "wings", "pet"]:
                continue
            var label_text := str(entry.get("name", "Вещь")).left(22)
            var b := _button("НАДЕТЬ · " + label_text,
                inventory_actions.has("equip") and action_allowed)
            b.name = "PPARealEquip_" + uid.to_utf8_buffer().hex_encode()
            b.pressed.connect(_request_original_equipment_move.bind("equip", uid, server_version))
            bag_grid.add_child(b)

func _show_authoritative_enhancement() -> void:
    _section("ЗАТОЧКА СНАРЯЖЕНИЯ / АКСЕССУАРОВ / ПЕТОВ",
        "Выбери предмет и камень. Система показывает только подтверждённые сервером шансы и остатки.")
    if not _owns_verified_state(forge_state) or not (forge_state.get("enhanceItems") is Array):
        _message("ЖДЁМ ОБЩУЮ КУЗНИЦУ", "Заточка недоступна без подтверждённого сохранения сервера PPA.")
        _locked_action("ЗАТОЧИТЬ ВЕЩЬ")
        return
    var items: Array = forge_state.get("enhanceItems", [])
    var selected: Dictionary = {}
    for raw in items:
        if raw is Dictionary and str(raw.get("uid", "")) == _enhance_uid:
            selected = raw
            break
    if selected.is_empty() and not items.is_empty() and items[0] is Dictionary:
        selected = items[0]
        _enhance_uid = str(selected.get("uid", ""))
    var picker_row := HBoxContainer.new()
    picker_row.name = "PPAForgeOriginalDropdowns"
    picker_row.add_theme_constant_override("separation", 8)
    _body.add_child(picker_row)
    var gear_picker := OptionButton.new()
    gear_picker.name = "PPAForgeGearDropdown"
    gear_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gear_picker.custom_minimum_size.y = 43
    gear_picker.add_theme_font_size_override("font_size", 11)
    gear_picker.tooltip_text = "Выбор предмета из подтверждённого инвентаря PPA"
    picker_row.add_child(gear_picker)
    var pick_index := 0
    for entry in items:
        if not (entry is Dictionary):
            continue
        var uid := str((entry as Dictionary).get("uid", ""))
        if uid.is_empty():
            continue
        var label_text := str((entry as Dictionary).get("name", "Вещь")).left(22) + "  +" + str((entry as Dictionary).get("enh", 0))
        gear_picker.add_item(label_text)
        var idx := gear_picker.item_count - 1
        gear_picker.set_item_metadata(idx, uid)
        if uid == _enhance_uid:
            pick_index = idx
    if gear_picker.item_count > 0:
        gear_picker.select(pick_index)
        gear_picker.item_selected.connect(func(index: int):
            _choose_enhancement_item(str(gear_picker.get_item_metadata(index))))
    else:
        gear_picker.add_item("НЕТ ВЕЩЕЙ")
        gear_picker.disabled = true

    var mode_picker := OptionButton.new()
    mode_picker.name = "PPAForgeStoneDropdown"
    mode_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mode_picker.custom_minimum_size.y = 43
    mode_picker.add_theme_font_size_override("font_size", 11)
    mode_picker.tooltip_text = "Тип камня и руны заточки"
    picker_row.add_child(mode_picker)
    for option in [
        {"key":"normal","label":"ОБЫЧНЫЙ КАМЕНЬ"},
        {"key":"normal_rune","label":"ОБЫЧНЫЙ + РУНА"},
        {"key":"premium","label":"ПРЕМИУМ КАМЕНЬ"},
        {"key":"premium_rune","label":"ПРЕМИУМ + РУНА"}
    ]:
        mode_picker.add_item(str(option["label"]))
        var i := mode_picker.item_count - 1
        mode_picker.set_item_metadata(i, option["key"])
        if str(option["key"]) == _enhance_mode:
            mode_picker.select(i)
    mode_picker.item_selected.connect(func(index: int):
        _set_enhancement_mode(str(mode_picker.get_item_metadata(index))))
    if selected.is_empty():
        _message("НЕТ ВЕЩЕЙ", "В подтверждённой сервером сумке нет предметов для заточки.")
        _locked_action("ЗАТОЧИТЬ ВЕЩЬ")
        return

    var level := int(selected.get("enh", 0))
    var transition := HBoxContainer.new()
    transition.name = "PPAForgeEnhancementBeforeAfter"
    transition.alignment = BoxContainer.ALIGNMENT_CENTER
    transition.add_theme_constant_override("separation", 12)
    _body.add_child(transition)
    for shown_level in [level, level + 1]:
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(100, 100)
        panel.add_theme_stylebox_override("panel", _style(Color("#11191D"), EDGE, 6))
        transition.add_child(panel)
        var icon_col := VBoxContainer.new()
        icon_col.alignment = BoxContainer.ALIGNMENT_CENTER
        panel.add_child(icon_col)
        var icon := _readonly_icon_item(selected, 57)
        icon_col.add_child(icon)
        var caption := _label("+" + str(shown_level), 12, GOLD)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        icon_col.add_child(caption)
        if shown_level == level:
            transition.add_child(_label("➜", 23, GOLD))

    var supplied_stones: Variant = forge_state.get("stones", null)
    var supplies: Dictionary = supplied_stones as Dictionary if supplied_stones is Dictionary else {}
    _mini_row("Обычные / Премиум / Руны",
        str(supplies.get("normal", "—")) + " / " + str(supplies.get("premium", "—")) + " / " + str(supplies.get("rune", "—")))
    var premium := _enhance_mode.begins_with("premium")
    var rune := _enhance_mode.ends_with("_rune")
    var rule_data: Variant = forge_state.get("enhanceRules", null)
    var table_values: Variant = (rule_data as Dictionary).get("rune" if rune else "normal", []) if rule_data is Dictionary else []
    var chance := -1
    if table_values is Array and level >= 0 and level < (table_values as Array).size():
        chance = int(table_values[level])
    _mini_row("Следующая заточка", "+" + str(level + 1))
    _mini_row("Вероятность успеха", str(chance) + "%" if chance >= 0 else "не подтверждена")
    _mini_row("Неудача", "Вещь и + сохраняются" if premium else
        ("Эпик: откат −1" if str(selected.get("rarity", "")) == "epic" else "ВЕЩЬ МОЖЕТ СГОРЕТЬ"))
    var requires := "premium" if premium else "normal"
    var stock: Variant = supplies.get(requires, null)
    var rune_stock: Variant = supplies.get("rune", null)
    var enough: bool = stock is int and stock > 0 and (not rune or (rune_stock is int and rune_stock > 0))
    var blocked: bool = bool(selected.get("special", false)) or level >= 7 \
        or (not premium and level >= 5) or chance < 0 or not enough \
        or not forge_actions.has("enhance") or forge_busy or forge_pending
    if blocked:
        _locked_action("ЗАТОЧИТЬ ВЕЩЬ")
        if bool(selected.get("special", false)):
            _body.add_child(_label("Особый питомец пока требует дополнительной серверной проверки.", 11, SUB))
        return
    var uid := str(selected.get("uid", ""))
    var mode := _enhance_mode
    var version := int(forge_state.get("version", 0))
    var action := _button("ЗАТОЧИТЬ · " + str(chance) + "%", true)
    action.name = "PPARealForgeEnhance"
    action.pressed.connect(func():
        if premium:
            _request_real_enhancement(uid, mode, version)
        else:
            var confirm := ConfirmationDialog.new()
            confirm.dialog_text = ("При неудаче эпик потеряет уровень заточки. Продолжить?"
                if str(selected.get("rarity", "")) == "epic" else
                "При неудаче вещь может сгореть без восстановления. Продолжить?")
            add_child(confirm)
            confirm.confirmed.connect(func():
                _request_real_enhancement(uid, mode, version)
                confirm.queue_free())
            confirm.canceled.connect(func(): confirm.queue_free())
            confirm.popup_centered(Vector2i(430, 180)))
    _body.add_child(action)

# Original live PPA blacksmithFrame catalog (generated at build from its public
# srcdoc). Inventory/balances are ONLY from the authenticated game-state save.
# This intentionally never emits a craft/enhance/spend request.
func _set_craft_rarity(key: String) -> void:
    var former_slot := ""
    if tab == "accessories" and selected_id.begins_with("acc:"):
        former_slot = selected_id.get_slice(":", 1)
    _craft_rarity = key
    selected_id = ""
    if not former_slot.is_empty():
        _select_forge_accessory_slot(former_slot)
    else:
        _render()


func _select_forge_accessory_slot(slot: String) -> void:
    # The four shortcuts in the original Telegram smith SELECT an item but
    # do not remove the other accessory cards from the catalog.
    selected_id = ""
    for raw in LIVE_FORGE.CATALOG.get("rows", []):
        if not (raw is Dictionary):
            continue
        var item: Dictionary = raw
        if str(item.get("tab", "")) != "accessories" or str(item.get("slot", "")) != slot:
            continue
        if _craft_rarity != "all" and str(item.get("rarity", "")) != _craft_rarity:
            continue
        selected_id = str(item.get("id", ""))
        break
    _render()

func _forge_owned_material(material_name: String) -> Variant:
    # Most recent signed forge projection wins over a potentially stale
    # full save. No local stash/resource totals or invented zero values.
    if service == "forge" and not forge_state.is_empty() and _owns_verified_state(forge_state):
        var live: Variant = forge_state.get("feathers", null) if material_name == "Перо Феникса" else forge_state.get("materials", null)
        if live is Dictionary:
            return (live as Dictionary).get("phoenix" if material_name == "Перо Феникса" else material_name, null)
        return null
    if service == "forge" and has_verified_state \
        and authoritative.get("service") == "forge" and authoritative.get("readOnly") == true:
        if material_name == "Перо Феникса":
            var live_feathers: Variant = authoritative.get("feathers", null)
            return (live_feathers as Dictionary).get("phoenix", null) if live_feathers is Dictionary else null
        var live_materials: Variant = authoritative.get("materials", null)
        return (live_materials as Dictionary).get(material_name, null) if live_materials is Dictionary else null
    if _player_view_readonly.is_empty():
        return null
    if material_name == "Перо Феникса":
        var feathers: Variant = _player_save_readonly.get("feathers", null)
        if feathers is Dictionary:
            return (feathers as Dictionary).get("phoenix", null)
        return null
    var stored: Variant = _player_save_readonly.get("materials", null)
    if stored is Dictionary:
        return (stored as Dictionary).get(material_name, null)
    return null

func _show_original_forge_recipes() -> void:
    var descriptions := {
        "equipment":"ЭПИЧЕСКОЕ СНАРЯЖЕНИЕ",
        "legendary":"ЛЕГЕНДАРНОЕ СНАРЯЖЕНИЕ",
        "accessories":"АКСЕССУАРЫ",
        "pets":"ПИТОМЦЫ"
    }
    _section(str(descriptions.get(tab, "КРАФТ PPA")),
        "Подлинные рецепты кузнеца из работающей Telegram PPA · актуальная цена в PPA")
    if tab == "accessories":
        # Original Telegram order: cloak, necklace, artifact, wings.
        # A highlighted shortcut selects the corresponding original recipe.
        var selected_slot := selected_id.get_slice(":", 1) if selected_id.begins_with("acc:") else ""
        _choice_tiles([
            {"key":"cloak","label":"ПЛАЩ"},
            {"key":"necklace","label":"ОЖЕРЕЛЬЕ"},
            {"key":"artifact","label":"АРТЕФАКТ"},
            {"key":"wings","label":"КРЫЛЬЯ"}
        ], selected_slot, _select_forge_accessory_slot)
        _choice_tiles([
            {"key":"all","label":"ВСЕ"},
            {"key":"common","label":"ОБЫЧНЫЙ"},
            {"key":"uncommon","label":"НЕОБЫЧНЫЙ"},
            {"key":"rare","label":"РЕДКИЙ"},
            {"key":"epic","label":"ЭПИЧЕСКИЙ"},
            {"key":"legendary","label":"ЛЕГЕНДАРНЫЙ · СКОРО","enabled":false}
        ], _craft_rarity, _set_craft_rarity)
    elif tab == "pets":
        _choice_tiles([
            {"key":"all","label":"ВСЕ"}, {"key":"common","label":"ОБЫЧНЫЙ"},
            {"key":"uncommon","label":"НЕОБЫЧНЫЙ"}, {"key":"rare","label":"РЕДКИЙ"}
        ], _craft_rarity, _set_craft_rarity)
    var offers: Array = []
    for raw in LIVE_FORGE.CATALOG.get("rows", []):
        if not (raw is Dictionary):
            continue
        var row: Dictionary = raw
        if str(row.get("tab","")) != tab:
            continue
        if _craft_rarity != "all" and str(row.get("rarity","")) != _craft_rarity:
            continue
        offers.append(row)
    if offers.is_empty():
        _message("НЕТ РЕЦЕПТОВ", "В оригинальном каталоге PPA таких рецептов нет.")
        return
    var chosen: Dictionary = {}
    for entry in offers:
        if str(entry.get("id","")) == selected_id:
            chosen = entry
            break
    _product_grid(offers, false)
    if chosen.is_empty():
        _message("ВЫБЕРИ РЕЦЕПТ",
            "Коснись карточки, чтобы увидеть цену, бонус, материалы и остатки.")
        return
    var recipe_index := _body.get_child_count()
    _section("РЕЦЕПТ · " + str(chosen.get("name","")),
        str(chosen.get("desc","")) + " · " + str(chosen.get("rarity","")).to_upper())
    _forge_recipe_target = _body.get_child(recipe_index) as Control
    var art := str(chosen.get("img", ""))
    if not art.is_empty() and ResourceLoader.exists(art):
        _body.add_child(_item_picture(art, 88))
    var money: Dictionary = _player_view_readonly.get("money", {})
    var balance: Variant = money.get("ppa", null)
    if service == "forge" and has_verified_state \
        and authoritative.get("service") == "forge" and authoritative.get("readOnly") == true:
        var live_currency: Variant = authoritative.get("currency", null)
        balance = (live_currency as Dictionary).get("ppa", null) if live_currency is Dictionary else null
    if service == "forge" and not forge_state.is_empty() and _owns_verified_state(forge_state):
        var wallet: Variant = forge_state.get("wallet", null)
        balance = (wallet as Dictionary).get("ppa", null) if wallet is Dictionary else null
    var price := int(chosen.get("price",0))
    _mini_row("Цена · PPA",
        str(price) + (" · есть " + str(balance) if balance != null else " · баланс не загружен"))
    var enough := balance != null and float(balance) >= float(price)
    var all_known := balance != null
    for raw_material in chosen.get("materials", []):
        if not (raw_material is Dictionary):
            continue
        var entry: Dictionary = raw_material
        var material_name := str(entry.get("name",""))
        var required := int(entry.get("count",0))
        var owned: Variant = _forge_owned_material(material_name)
        if owned == null:
            all_known = false
        elif int(owned) < required:
            enough = false
        _mini_row(material_name + " ×" + str(required),
            "есть " + str(owned) if owned != null else "нет данных")
    if not all_known:
        _body.add_child(_label("Не все остатки удалось прочитать из подтверждённого сохранения PPA.", 11, SUB))
    elif not enough:
        _body.add_child(_label("Не хватает валюты или материалов для выбранного рецепта.", 11, Color("#E2A17C")))
    else:
        _body.add_child(_label("Ресурсов достаточно по последнему снимку; сервер всё равно должен проверить их заново.", 11, GOLD))
    # Enable ONLY recipes advertised by the currently authenticated canonical
    # PPA Forge server. Compare costs/materials with displayed original cards:
    # stale catalogs or client-supplied prices can NEVER authorize a craft.
    var offered := false
    if tab in ["equipment", "legendary", "accessories", "pets"] \
        and not forge_state.is_empty() and _owns_verified_state(forge_state) \
        and str(forge_state.get("catalogRecipeSha", "")) == str(LIVE_FORGE.CATALOG.get("recipe_sha256", "")):
        for server_row in forge_state.get("offers", []):
            if server_row is Dictionary and str(server_row.get("id", "")) == selected_id \
                and int(server_row.get("price", -1)) == price \
                and server_row.get("currency") == "ppa" \
                and server_row.get("materials") == chosen.get("materials", []):
                offered = true
                break
    var can_craft := offered and forge_actions.has("craft") and not forge_busy \
        and not forge_pending and all_known and enough \
        and int(forge_state.get("version", 0)) > 0
    if can_craft:
        var create_button := _button("СОЗДАТЬ", true)
        create_button.name = "PPARealForgeCraft"
        create_button.pressed.connect(func():
            if visible and service == "forge" and not forge_busy and not forge_pending \
                and forge_actions.has("craft") and _owns_verified_state(forge_state):
                forge_action_requested.emit({"id":selected_id,
                    "version":int(forge_state.get("version", 0))}))
        _body.add_child(create_button)
    else:
        _locked_action("СОЗДАТЬ")
        if not offered:
            _body.add_child(_label(
                "Рецепт не подтверждён общим сервером или каталог PPA обновился.", 11, SUB))
    _body.add_child(_label("Создание выполняет сервер PPA, не Godot.", 11, SUB))
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
    if service == "storage" and _owns_verified_state(personal_storage_state):
        if scope == "inventory" or scope == "personal":
            var live_key := "bag" if scope == "inventory" else "personal"
            var live: Variant = personal_storage_state.get(live_key, null)
            if live is Array:
                saved_items = live
                known = true
    # Clan items are stored in a shared clan D1 record, NOT player's
    # legacy storage.clan array. Display only signed clan state.
    if scope == "clan":
        known = false
        saved_items = []
        if _owns_verified_state(clan_storage_state) and clan_storage_state.get("items") is Array:
            saved_items = clan_storage_state["items"]
            known = true
        elif service == "storage" and _owns_verified_state(clan_state):
            var clan_storage: Variant = clan_state.get("storage", null)
            if clan_storage is Dictionary and (clan_storage as Dictionary).get("items") is Array:
                saved_items = (clan_storage as Dictionary)["items"]
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

func _select_personal_uid(which: String, uid: String) -> void:
    if which == "bag":
        _storage_bag_uid = uid
    elif which == "personal":
        _storage_personal_uid = uid

func _request_personal_storage_move(action: String, uid: String, version: int) -> void:
    if not visible or service != "storage" or tab != "personal" \
        or personal_storage_busy or personal_storage_pending \
        or not personal_storage_actions.has(action) \
        or not _owns_verified_state(personal_storage_state) \
        or int(personal_storage_state.get("version", -1)) != version:
        return
    var records: Variant = personal_storage_state.get("bag", null) if action == "put" else personal_storage_state.get("personal", null)
    if not (records is Array):
        return
    var matches := 0
    for entry in records:
        if entry is Dictionary and str(entry.get("uid", "")) == uid and not uid.is_empty():
            matches += 1
    if matches != 1:
        return
    personal_storage_action_requested.emit({"action":action,"uid":uid,"version":version})

func _show_personal_storage_controls() -> void:
    if not personal_storage_notice.is_empty():
        _body.add_child(_label(personal_storage_notice, 12, GOLD))
    if personal_storage_pending:
        var pending_button := _button("ПРОВЕРИТЬ ТО ЖЕ ПЕРЕМЕЩЕНИЕ", not personal_storage_busy)
        pending_button.pressed.connect(func(): personal_storage_retry_requested.emit())
        _body.add_child(pending_button)
    if not _owns_verified_state(personal_storage_state):
        _body.add_child(_label("Ожидаем серверный список предметов PPA.", 11, SUB))
        _locked_action("ПОЛОЖИТЬ / ЗАБРАТЬ")
        return
    var version := int(personal_storage_state.get("version", 0))
    var bag: Array = personal_storage_state.get("bag", [])
    var stored: Array = personal_storage_state.get("personal", [])
    _mini_row("Настоящая сумка", str(bag.size()) + " / 100")
    _mini_row("Личный склад", str(stored.size()) + " / 200")
    for direction in ["put","take"]:
        var source_items: Array = bag if direction == "put" else stored
        var which := "bag" if direction == "put" else "personal"
        var chosen_uid := _storage_bag_uid if direction == "put" else _storage_personal_uid
        var chooser := OptionButton.new()
        chooser.name = "PPAStorageChoose_" + direction
        var selected_index := 0
        for entry in source_items:
            if not (entry is Dictionary):
                continue
            var uid := str(entry.get("uid", ""))
            if uid.is_empty():
                continue
            var text_value := str(entry.get("name", "Предмет")).left(28) + " · +" + str(entry.get("enh", 0))
            var index := chooser.item_count
            chooser.add_item(text_value)
            chooser.set_item_metadata(index, uid)
            if uid == chosen_uid:
                selected_index = index
        if chooser.item_count > 0:
            chooser.select(selected_index)
            chosen_uid = str(chooser.get_item_metadata(selected_index))
            _select_personal_uid(which, chosen_uid)
        chooser.item_selected.connect(func(i: int): _select_personal_uid(which, str(chooser.get_item_metadata(i))))
        _body.add_child(chooser)
        var can_move := chooser.item_count > 0 and not personal_storage_busy and not personal_storage_pending \
            and personal_storage_actions.has(direction) \
            and (stored.size() < 200 if direction == "put" else bag.size() < 100)
        var button := _button("ПОЛОЖИТЬ В СКЛАД" if direction == "put" else "ЗАБРАТЬ В СУМКУ", can_move)
        button.name = "PPARealPersonalStorage_" + direction
        button.pressed.connect(func():
            var selected := _storage_bag_uid if direction == "put" else _storage_personal_uid
            _request_personal_storage_move(direction, selected, version))
        _body.add_child(button)

func _choose_clan_vault_uid(which: String, uid: String) -> void:
    if which == "bag":
        _clan_put_uid = uid
    elif which == "items":
        _clan_take_uid = uid

func _request_clan_storage_move(action: String, uid: String, version: int, revision: String) -> void:
    if not visible or service not in ["storage","clan"] or tab != "clan" and tab != "storage" \
        or clan_storage_busy or clan_storage_pending \
        or not clan_storage_actions.has(action) \
        or not _owns_verified_state(clan_storage_state) \
        or int(clan_storage_state.get("version", -1)) != version \
        or str(clan_storage_state.get("clanRevision", "")) != revision:
        return
    if action == "put" and not bool(clan_storage_state.get("canDeposit", false)):
        return
    var source: Variant = clan_storage_state.get("bag", null) if action == "put" else clan_storage_state.get("items", null)
    if not (source is Array):
        return
    var count := 0
    for entry in source:
        if entry is Dictionary and str(entry.get("uid", "")) == uid and not uid.is_empty():
            if action == "put" or bool(entry.get("canTake", false)):
                count += 1
    if count != 1:
        return
    clan_storage_action_requested.emit({"action":action,"uid":uid,"version":version,"clanRevision":revision})

func _clan_storage_choice_selected(index: int, chooser: OptionButton, action: String) -> void:
    if index < 0 or index >= chooser.item_count:
        return
    _choose_clan_vault_uid("bag" if action == "put" else "items",
        str(chooser.get_item_metadata(index)))

func _submit_selected_clan_storage_move(action: String, version: int, revision: String) -> void:
    var uid := _clan_put_uid if action == "put" else _clan_take_uid
    _request_clan_storage_move(action, uid, version, revision)

func _show_clan_storage_controls() -> void:
    _section("КЛАНОВЫЙ СКЛАД · ОБЩИЙ МИР",
        "Сервер одновременно переносит вещь между сумкой и общим складом клана.")
    if not clan_storage_notice.is_empty():
        _body.add_child(_label(clan_storage_notice, 12, GOLD))
    if clan_storage_pending:
        var pending_button := _button("ПРОВЕРИТЬ ПРЕЖНИЙ ПЕРЕНОС", not clan_storage_busy)
        pending_button.pressed.connect(func(): clan_storage_retry_requested.emit())
        _body.add_child(pending_button)
    if not _owns_verified_state(clan_storage_state):
        _body.add_child(_label("Ожидаем подтверждённое состояние кланового склада PPA.", 11, SUB))
        _locked_action("КЛАНОВЫЙ ПЕРЕНОС")
        return
    var version := int(clan_storage_state.get("version", 0))
    var revision := str(clan_storage_state.get("clanRevision", ""))
    var bag: Array = clan_storage_state.get("bag", [])
    var stored: Array = clan_storage_state.get("items", [])
    _mini_row("Инвентарь", str(bag.size()) + " / 100")
    _mini_row("Клановый склад", str(stored.size()) + " / 500")
    if not bool(clan_storage_state.get("storageUnlocked", false)):
        _body.add_child(_label("Склад ещё не открыт главой клана.", 11, SUB))
        _locked_action("ПОЛОЖИТЬ / ЗАБРАТЬ")
        return
    for action in ["put","take"]:
        var from_items: Array = bag if action == "put" else stored
        var choices := OptionButton.new()
        choices.name = "PPAClanStorageChoose_" + action
        var preferred := _clan_put_uid if action == "put" else _clan_take_uid
        var selected := 0
        for entry in from_items:
            if not (entry is Dictionary):
                continue
            var uid := str(entry.get("uid", ""))
            if uid.is_empty() or action == "take" and not bool(entry.get("canTake", false)):
                continue
            var index := choices.item_count
            choices.add_item(str(entry.get("name", "Вещь")).left(24) + " · +" + str(entry.get("enh", 0)))
            choices.set_item_metadata(index, uid)
            if preferred == uid:
                selected = index
        if choices.item_count > 0:
            choices.select(selected)
            _choose_clan_vault_uid("bag" if action == "put" else "items",
                str(choices.get_item_metadata(selected)))
        choices.item_selected.connect(_clan_storage_choice_selected.bind(choices, action))
        _body.add_child(choices)
        var allowed: bool = choices.item_count > 0 and clan_storage_actions.has(action) \
            and not clan_storage_busy and not clan_storage_pending \
            and (bool(clan_storage_state.get("canDeposit", false)) and stored.size() < 500 \
                if action == "put" else bag.size() < 100)
        var button := _button("ВНЕСТИ В КЛАН" if action == "put" else "ЗАБРАТЬ ИЗ КЛАНА", allowed)
        button.name = "PPARealClanStorage_" + action
        button.pressed.connect(_submit_selected_clan_storage_move.bind(action, version, revision))
        _body.add_child(button)

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
    if tab == "personal":
        _show_personal_storage_controls()
    elif tab == "clan":
        _show_clan_storage_controls()
    elif tab == "premium":
        _message("ПРЕМИУМ ДОСТУП", "Содержимое премиум-хранилища читается только с сервера PPA.")
        _locked_action("ПОЛОЖИТЬ / ЗАБРАТЬ")

func _auction_matches(item: Dictionary) -> bool:
    if _auction_category == "all":
        return true
    var slot_name := str(item.get("slot", ""))
    var kind := str(item.get("kind", ""))
    if _auction_category == "weapon":
        return slot_name == "weapon"
    if _auction_category == "armor":
        return slot_name in ["helmet","armor","gloves","legs","boots"]
    if _auction_category == "accessories":
        return slot_name in ["ring","necklace","artifact","cloak","wings","pet"]
    if _auction_category == "consumables":
        return kind in ["consumable","stone","feather"]
    if _auction_category == "materials":
        return kind == "material"
    if _auction_category == "books":
        return kind == "grimoire"
    if _auction_category == "quest":
        return kind == "quest"
    return true

func _auction_sell_uid_changed(index: int, chooser: OptionButton) -> void:
    if index >= 0 and index < chooser.item_count:
        _auction_sell_uid = str(chooser.get_item_metadata(index))

func _send_real_auction_action(action: String, fields: Dictionary) -> void:
    if not visible or service != "auction" or not _owns_verified_state(auction_state) \
        or auction_loading or auction_pending or not auction_actions.has(action) \
        or not bool(auction_state.get("settlementEnabled", false)):
        return
    var version := int(auction_state.get("version", 0))
    if version <= 0:
        return
    var valid := false
    if action == "place":
        var uid := str(fields.get("uid", ""))
        for entry in auction_state.get("bag", []):
            if entry is Dictionary and str(entry.get("uid", "")) == uid:
                valid = int(auction_state.get("maxSellSlots", 0)) > auction_state.get("mine", []).size()
                break
    elif action == "buy":
        for entry in auction_state.get("lots", []):
            if entry is Dictionary and bool(entry.get("canBuy", false)) \
                and str(entry.get("id", "")) == str(fields.get("lotId", "")) \
                and float(entry.get("price", -1)) == float(fields.get("expectedUnitPrice", -2)) \
                and str(entry.get("currency", "")) == str(fields.get("currency", "")):
                valid = true
                break
    elif action == "recover":
        for entry in auction_state.get("recoverable", []):
            if entry is Dictionary and bool(entry.get("canRecover", false)) \
                and str(entry.get("id", "")) == str(fields.get("lotId", "")):
                valid = true
                break
    elif action == "claim":
        if bool(auction_state.get("serverCreditClaimsEnabled", false)):
            for entry in auction_state.get("pendingCredits", []):
                if entry is Dictionary and bool(entry.get("canClaim", false)) \
                    and str(entry.get("id", "")) == str(fields.get("creditId", "")):
                    valid = true
                    break
    elif action == "cancel":
        for entry in auction_state.get("mine", []):
            if entry is Dictionary and bool(entry.get("canCancel", false)) \
                and str(entry.get("id", "")) == str(fields.get("lotId", "")):
                valid = true
                break
    if not valid:
        return
    var payload := fields.duplicate(true)
    payload["action"] = action
    payload["version"] = version
    auction_action_requested.emit(payload)

func _auction_buy_lot(lotId: String, price: float, currency: String) -> void:
    _send_real_auction_action("buy", {"lotId":lotId,"expectedUnitPrice":price,"currency":currency})

func _auction_cancel_lot(lotId: String) -> void:
    _send_real_auction_action("cancel", {"lotId":lotId})

func _auction_claim_credit(creditId: String) -> void:
    _send_real_auction_action("claim", {"creditId":creditId})

func _auction_recover_lot(lotId: String) -> void:
    _send_real_auction_action("recover", {"lotId":lotId})

func _auction_place_selected() -> void:
    _send_real_auction_action("place", {"uid":_auction_sell_uid,
        "price":_asking_price,"currency":_asking_currency.to_lower()})

func _show_auction_lots(rows: Array, own: bool) -> void:
    var count := 0
    for raw in rows:
        if not (raw is Dictionary):
            continue
        var entry: Dictionary = raw
        var item: Variant = entry.get("item", null)
        if not (item is Dictionary):
            continue
        if not own and not _auction_matches(item):
            continue
        var price: Variant = entry.get("price", null)
        var currency := str(entry.get("currency", "ppa")).to_upper()
        var desc := str(item.get("name", "Предмет PPA")).left(45)
        desc += "  +" + str(item.get("enh", 0))
        _mini_row(desc, str(entry.get("qty", 1)) + " шт. · " + str(price) + " " + currency)
        _body.add_child(_label("Продавец: " + str(entry.get("sellerName", "Игрок")).left(24), 11, SUB))
        var available := not auction_loading and not auction_pending and \
            bool(auction_state.get("settlementEnabled", false))
        if own and auction_actions.has("cancel") and bool(entry.get("canCancel", false)):
            var cancel := _button("СНЯТЬ С ПРОДАЖИ", available)
            cancel.name = "PPARealAuctionCancel_" + str(entry.get("id", ""))
            cancel.pressed.connect(_auction_cancel_lot.bind(str(entry.get("id", ""))))
            _body.add_child(cancel)
        elif not own and auction_actions.has("buy") and bool(entry.get("canBuy", false)):
            var buy := _button("КУПИТЬ · " + str(price) + " " + currency, available)
            buy.name = "PPARealAuctionBuy_" + str(entry.get("id", ""))
            buy.pressed.connect(_auction_buy_lot.bind(str(entry.get("id", "")),
                float(entry.get("price", 0)), str(entry.get("currency", ""))))
            _body.add_child(buy)
        count += 1
        if count >= 50:
            break
    if count == 0:
        _body.add_child(_label("Подходящих активных объявлений нет.", 12, SUB))
    elif count >= 50:
        _body.add_child(_label("Показаны первые 50 лотов из серверной выборки.", 11, SUB))

func _show_auction() -> void:
    var verified := _owns_verified_state(auction_state)
    _section("АУКЦИОН · PPA", "Реальные лоты и начисления из общего сервера Telegram PPA.")
    if not auction_notice.is_empty():
        _body.add_child(_label(auction_notice, 11, GOLD))
    if auction_pending:
        var retry := _button("ПРОВЕРИТЬ ТУ ЖЕ СДЕЛКУ", not auction_loading)
        retry.pressed.connect(func(): auction_retry_requested.emit())
        _body.add_child(retry)
    var refresh := _button("ОБНОВИТЬ АУКЦИОН", not auction_loading)
    refresh.pressed.connect(func(): authoritative_state_requested.emit("auction"))
    _body.add_child(refresh)
    if not verified:
        _message("ОЖИДАЕМ СЕРВЕРНЫЕ ЛОТЫ", "Без подтверждённого персонажа PPA аукцион недоступен.")
        _locked_action("КУПИТЬ / ПРОДАТЬ")
        return
    var wallet: Dictionary = auction_state.get("wallet", {})
    _mini_row("PPA", str(wallet.get("ppa", "—")))
    _mini_row("Gram", str(wallet.get("gram", "—")))
    _mini_row("Комиссия аукциона", "10% · начисление продавцу 90%")
    if tab != "mine":
        _choice_tiles([
            {"key":"all","label":"ВСЕ"}, {"key":"weapon","label":"ОРУЖИЕ"},
            {"key":"armor","label":"БРОНЯ"}, {"key":"accessories","label":"АКСЕССУАРЫ"},
            {"key":"consumables","label":"РАСХОДНИКИ"}, {"key":"materials","label":"МАТЕРИАЛЫ"},
            {"key":"books","label":"КНИГИ"}, {"key":"quest","label":"КВЕСТОВЫЕ"},
            {"key":"misc","label":"РАЗНОЕ"}], _auction_category, _auction_filter)
    if tab == "all":
        _section("АКТИВНЫЕ ЛОТЫ", "Общий рынок PPA · существующие объявления Telegram.")
        _show_auction_lots(auction_state.get("lots", []), false)
        _body.add_child(_label("Купить можно только защищённый лот PPA. Старые лоты пока только для просмотра.", 11, SUB))
    elif tab == "mine":
        _section("МОИ ЛОТЫ", "Только объявления этого персонажа на общем сервере.")
        _show_auction_lots(auction_state.get("mine", []), true)
        _section("ИСТЁКШИЕ ЛОТЫ · ВОЗВРАТ ВЕЩЕЙ",
            "Непроданная вещь хранится на сервере до безопасного возврата в сумку.")
        var recoverable: Array = auction_state.get("recoverable", [])
        if recoverable.is_empty():
            _body.add_child(_label("Вещей, ожидающих возврата, нет.", 12, SUB))
        for entry in recoverable.slice(0, 50):
            if not (entry is Dictionary):
                continue
            var lot: Dictionary = entry
            var item: Variant = lot.get("item", {})
            var item_name := str(item.get("name", "Вещь")) if item is Dictionary else "Вещь"
            _mini_row(item_name, "UID · " + str(lot.get("uid", "")).left(22))
            var enabled: bool = auction_actions.has("recover") and \
                bool(lot.get("canRecover", false)) and \
                not auction_pending and not auction_loading and \
                bool(auction_state.get("settlementEnabled", false)) and \
                (auction_state.get("bag", []) as Array).size() < 100
            var reclaim := _button("ВЕРНУТЬ ИЗ ИСТЁКШЕГО ЛОТА", enabled)
            reclaim.name = "PPARealAuctionRecover_" + str(lot.get("id", ""))
            reclaim.pressed.connect(_auction_recover_lot.bind(str(lot.get("id", ""))))
            _body.add_child(reclaim)
        _section("НАЧИСЛЕНИЯ ПРОДАВЦУ", "Подтверждённые Telegram PPA credits, пока без автоматического списания.")
        var credits: Array = auction_state.get("pendingCredits", [])
        if credits.is_empty():
            _body.add_child(_label("Ожидающих начислений нет.", 12, SUB))
        for credit in credits.slice(0, 30):
            if credit is Dictionary:
                _mini_row("Продажа · " + str(credit.get("lotId", "")).left(20),
                    str(credit.get("amount", 0)) + " " + str(credit.get("currency", "ppa")).to_upper())
                if auction_actions.has("claim") and bool(credit.get("canClaim", false)) \
                    and bool(auction_state.get("serverCreditClaimsEnabled", false)):
                    var claim := _button("ПОЛУЧИТЬ · " + str(credit.get("amount", 0)), \
                        not auction_pending and not auction_loading)
                    claim.name = "PPARealAuctionClaim_" + str(credit.get("id", ""))
                    claim.pressed.connect(_auction_claim_credit.bind(str(credit.get("id", ""))))
                    _body.add_child(claim)
        if not bool(auction_state.get("serverCreditClaimsEnabled", false)):
            _body.add_child(_label("Выплаты заблокированы, пока Telegram и Godot не используют единый серверный расчёт.", 11, SUB))
    elif tab == "sell":
        _section("ПРОДАЖА РЕАЛЬНОЙ ВЕЩИ", "Вещь будет изъята сервером из сумки и сохранена в лоте.")
        var items: Array = auction_state.get("bag", [])
        _mini_row("Открыто слотов", str(auction_state.get("maxSellSlots", 0)))
        _mini_row("Мои активные лоты", str(auction_state.get("mine", []).size()))
        var choose := OptionButton.new()
        choose.name = "PPARealAuctionGearPicker"
        var first_uid := ""
        var chosen := 0
        for item in items:
            if not (item is Dictionary) or str(item.get("uid", "")).is_empty():
                continue
            if str(item.get("slot", "")).is_empty():
                continue
            var index := choose.item_count
            choose.add_item(str(item.get("name", "Вещь")).left(25) + " · +" + str(item.get("enh", 0)))
            choose.set_item_metadata(index, str(item.get("uid", "")))
            if first_uid.is_empty():
                first_uid = str(item.get("uid", ""))
            if str(item.get("uid", "")) == _auction_sell_uid:
                chosen = index
        _body.add_child(choose)
        if choose.item_count > 0:
            choose.select(chosen)
            _auction_sell_uid = str(choose.get_item_metadata(chosen))
        else:
            _auction_sell_uid = ""
        choose.item_selected.connect(_auction_sell_uid_changed.bind(choose))
        var settings := GridContainer.new()
        settings.columns = 2
        settings.add_theme_constant_override("h_separation", 10)
        settings.add_theme_constant_override("v_separation", 8)
        _body.add_child(settings)
        settings.add_child(_label("Цена за вещь", 12, GOLD))
        var price := SpinBox.new()
        price.name = "PPARealAuctionPrice"
        price.min_value = 1
        price.max_value = 999999999
        price.step = 1
        price.value = _asking_price
        price.value_changed.connect(_set_asking_price)
        settings.add_child(price)
        settings.add_child(_label("Валюта", 12, GOLD))
        var currency := OptionButton.new()
        currency.name = "PPARealAuctionCurrency"
        currency.add_item("PPA")
        currency.add_item("Gram")
        currency.select(0 if _asking_currency == "PPA" else 1)
        currency.item_selected.connect(_set_currency)
        settings.add_child(currency)
        var enabled: bool = auction_actions.has("place") and \
            bool(auction_state.get("settlementEnabled", false)) and \
            not auction_loading and not auction_pending and not _auction_sell_uid.is_empty() \
            and int(auction_state.get("maxSellSlots", 0)) > auction_state.get("mine", []).size()
        var place := _button("ВЫСТАВИТЬ ВЕЩЬ НА АУКЦИОН", enabled)
        place.name = "PPARealAuctionPlace"
        place.pressed.connect(_auction_place_selected)
        _body.add_child(place)
        _body.add_child(_label("Комиссия при продаже: 10% · вещь не копируется.", 11, SUB))

func _show_clan() -> void:
    if not clan_state.is_empty():
        CLAN_CONTENT.render(self)
        return
    var captions := {"overview":"ОБЗОР КЛАНА", "clans":"КЛАНЫ И РЕЙТИНГ",
        "members":"УЧАСТНИКИ", "storage":"КЛАНОВЫЙ СКЛАД",
        "exchange":"ОБМЕН", "bosses":"КЛАНОВЫЕ БОССЫ",
        "bonuses":"БОНУСЫ КЛАНА", "wars":"ВОЙНЫ И ЦИТАДЕЛЬ", "journal":"ЖУРНАЛ"}
    _section(str(captions.get(tab, "МАГИСТР КЛАНОВ")), "Структура Telegram PPA · все операции через общий сервер")
    if not clan_notice.is_empty():
        _body.add_child(_label(clan_notice, 12, GOLD))
    var refresh := _button("ОБНОВИТЬ КЛАН", not clan_busy)
    refresh.pressed.connect(func(): authoritative_state_requested.emit("clan"))
    _body.add_child(refresh)
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

func set_online_presence(count: int, room_total: int) -> void:
    native_online_status = "Всего игроков %d · Мирный город %d" % [count, room_total]
    if service == "arena" and visible and _status != null:
        _status.text = "PPA · данные сервера · " + native_online_status

func set_online_failure(reason: String) -> void:
    native_online_status = reason
    if service == "arena" and visible and _status != null:
        _status.text = "PPA · " + native_online_status

func _show_arena() -> void:
    _section("МЕЧНИК АРЕНЫ", "Telegram PPA · испытания, PvP и рейтинг")
    var wallet: Dictionary = _player_view_readonly.get("money", {})
    var tokens: Variant = wallet.get("arenaTokens", null)
    # New trusted NPC snapshot may be fresher than the last full save.
    if has_verified_state and authoritative.get("arenaTokens", null) != null:
        tokens = authoritative["arenaTokens"]
    _mini_row("⚔ ЖЕТОНЫ АРЕНЫ · ЛИЧНЫЙ СЕЙВ D1",
        str(tokens) if tokens != null else "— · нет данных")
    # Match the backend arena projection from the same authenticated D1
    # save even if /api/game/npc/arena is disabled in Cloudflare. Never invent
    # player victories, rating, purchased limits or real matchmaking.
    var arena_record: Dictionary = VERIFIED_PLAYER.arena(_player_save_readonly)
    if has_verified_state and service == "arena":
        for field in ["rating", "wins", "losses", "attemptsRemaining"]:
            if authoritative.get(field, null) != null:
                arena_record[field] = authoritative[field]
    var rating: Variant = arena_record.get("rating", null)
    var wins: Variant = arena_record.get("wins", null)
    var losses: Variant = arena_record.get("losses", null)
    var tries_left: Variant = arena_record.get("attemptsRemaining", null)
    if rating != null or wins != null or losses != null or tries_left != null:
        _mini_row("РЕЙТИНГ · ПОДТВЕРЖДЁННЫЙ СЕЙВ", str(int(rating)) if rating != null else "—")
        _mini_row("ПОБЕДЫ / ПОРАЖЕНИЯ", (str(int(wins)) if wins != null else "—") + " / " + (str(int(losses)) if losses != null else "—"))
        _mini_row("ОСТАТОК ПОПЫТОК", str(int(tries_left)) if tries_left != null else "—")
    else:
        _mini_row("РЕЙТИНГ И ПОПЫТКИ", "— · нет подтверждённого статуса арены")
    match tab:
        "fights":
            _message("БЕСКОНЕЧНЫЕ ВОЛНЫ", "Бой с монстрами, прогресс волн и сезонные награды.")
            _message("ПРОТИВ ИИ", "Испытание против ботов. Состав и доступность определяет сервер.")
            _message("PVP АРЕНА", "Режимы 1×1 и 3×3 / 5×5 — где они доступны в живой PPA.")
            _message("СЕЗОННЫЙ РЕЙТИНГ", "Позиция и подбор на сервере.")
            var practice := _button("⚔ НАЧАТЬ ТРЕНИРОВКУ ПРОТИВ ИИ")
            practice.name = "NpcArenaAiPractice"
            practice.custom_minimum_size.y = 50.0
            practice.add_theme_stylebox_override("normal", _style(Color("#3A2917"), GOLD, 7, 2))
            practice.pressed.connect(func(): arena_training_requested.emit())
            _body.add_child(practice)
            _body.add_child(_label("Три движущихся ИИ-бота, атака, HP, победа и поражение. Тренировочный бой без сервера и наград.", 11, SUB))
            var online := _button("🌐 ОБЩИЙ ОНЛАЙН · ПРОВЕРИТЬ ИГРОКОВ")
            online.name = "NpcRealtimePresenceConnect"
            online.custom_minimum_size.y = 44.0
            online.pressed.connect(func(): native_realtime_requested.emit())
            _body.add_child(online)
            _body.add_child(_label("Это тот же сервер Telegram PPA. Вход заменит онлайн-соединение твоего героя в Telegram. Сетевые бои и награды здесь пока закрыты.", 11, SUB))
            _locked_action("БОЕВОЙ РЕЙТИНГ / СЕТЕВОЙ МАТЧ")
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
