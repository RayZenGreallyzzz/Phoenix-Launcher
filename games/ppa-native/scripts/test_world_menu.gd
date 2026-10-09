extends Control

# Lightweight local beta UI. No production trading, forging, purchases or
# save mutations happen here. Menu/stash persists across all 8 visual classes.
const HERO_CATALOG = preload("res://scripts/test_hero_catalog.gd")
const SHARED_STASH = preload("res://scripts/test_shared_storage.gd")
const NPC_CATALOG = preload("res://scripts/test_city_npcs.gd")
const SHOP_CATALOG = preload("res://scripts/test_shop_catalog.gd")
const CANONICAL_CHARACTER = preload("res://scripts/ppa_character_screen.gd")
const NPC_SCREEN = preload("res://scripts/ppa_npc_screen.gd")
const GLOBAL_HUB = preload("res://scripts/ppa_global_hub.gd")
const SERVER_VIEW = preload("res://scripts/ppa_server_inventory_view.gd")

signal change_class_requested
# Future server adapter listens to this and returns a verified read-only NPC snapshot.
signal npc_snapshot_requested(service: String)
signal global_snapshot_requested(section: String)
signal dungeon_visual_test_requested
signal refresh_readonly_save_requested


var account: Dictionary = {}
var class_key := "gnome"
var stash: RefCounted
var nearby_npc: Dictionary = {}
var current_page := "character"
var _background: ColorRect
var _panel: PanelContainer
var _character_screen
var _npc_screen
var _global_hub
var _native_web_ui
var _web_open := false
var _use_original_web_ui := false
var _title: Label
var _list: VBoxContainer
var _interact_button: Button
var _notice: Label
var _tab_bar: HBoxContainer
var _merchant_tab := "potions"
var _merchant_selected := ""
var _shop_qty := 1
var _market_category := "all"
var _smith_tab := "enhance"
var _page_notice_default := "PPA · ТЕСТОВЫЙ КЛИЕНТ · СЕРВЕРНЫЕ ПОКУПКИ ОТКЛЮЧЕНЫ"
var _selected_item_index := -1
var _selected_item_source := "bag"
var _verified_save: Dictionary = {}
var _has_verified_save := false

func apply_readonly_snapshot(payload: Dictionary) -> void:
    if payload.get("readOnly", false) != true or not (payload.get("state") is Dictionary):
        return
    _verified_save = (payload["state"] as Dictionary).duplicate(true)
    _has_verified_save = true
    if _character_screen != null:
        _character_screen.apply_readonly_save(
            _verified_save, payload.get("version", null), payload.get("updatedAt", null)
        )
    if _panel != null and _panel.visible:
        _refresh()

func clear_readonly_snapshot() -> void:
    _verified_save.clear()
    _has_verified_save = false
    if _character_screen != null:
        _character_screen.clear_readonly_save()
    if _panel != null and _panel.visible:
        _refresh()


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
    # The native five-page PPA character UI is the default on Android and
    # desktop. The original HTML/WebView experiment remains opt-in, never
    # layered over a second Godot menu.
    _use_original_web_ui = OS.get_name() == "Android" and bool(ProjectSettings.get_setting("ppa/ui/use_original_webview", false))
    if not _use_original_web_ui:
        _character_screen = CANONICAL_CHARACTER.new()
        _character_screen.configure(account, class_key, stash)
        add_child(_character_screen)
        _character_screen.z_index = 95
        _character_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        _character_screen.close_requested.connect(close_menu)
        _character_screen.select_item_requested.connect(_open_item)
        _character_screen.unequip_requested.connect(_on_character_unequip)
        _character_screen.refresh_readonly_save_requested.connect(
            func(): refresh_readonly_save_requested.emit()
        )
        _character_screen.visible = false
    _panel.visible = false
    _background.visible = false
    # NPC windows are independent of BOTH the character UI and the old
    # general purpose test panel. Exactly one NPC screen is instantiated.
    _npc_screen = NPC_SCREEN.new()
    # Private local test bag is display-only. Do not pretend it is server PPA.
    _npc_screen.set_preview_stash(stash)
    _npc_screen.z_index = 105
    add_child(_npc_screen)
    _npc_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _npc_screen.close_requested.connect(close_menu)
    _npc_screen.authoritative_state_requested.connect(func(service: String): npc_snapshot_requested.emit(service))
    # Offline map preview uses the same scene route from the Keeper and Hub.
    # Never asks for a server entry ticket or records any rewards.
    _npc_screen.dungeon_visual_test_requested.connect(func(): dungeon_visual_test_requested.emit())
    _global_hub = GLOBAL_HUB.new()
    _global_hub.z_index = 110
    add_child(_global_hub)
    _global_hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _global_hub.close_requested.connect(close_menu)
    _global_hub.character_requested.connect(func(): open_page("character"))
    _global_hub.snapshot_requested.connect(func(section: String): global_snapshot_requested.emit(section))
    _global_hub.dungeon_visual_test_requested.connect(func(): dungeon_visual_test_requested.emit())
    # Optional A/B comparison of the untouched Telegram character iframe.
    # Keep it disabled for normal Android builds; never render both menus.
    if _use_original_web_ui and Engine.has_singleton("PPAOriginalWebUI"):
        _native_web_ui = Engine.get_singleton("PPAOriginalWebUI")
        _native_web_ui.connect("ppa_ui_event", _on_original_web_ui_event)

func _on_original_web_ui_event(event_name: String) -> void:
    if event_name == "closeChar":
        _web_open = false
        _background.visible = false
    elif event_name.begins_with("error:"):
        _web_open = false
        _background.visible = false
        push_warning("PPA ORIGINAL UI: " + event_name)
        # Fail visibly instead of pretending that a broken iframe is 1:1.
    elif event_name == "charReady":
        # This is the REAL notification from the original PPA iframe,
        # not a synthetic one emitted during WebView load.
        print("PPA_ORIGINAL_WEBVIEW_CHARFRAME_READY")
    elif event_name == "stateRequested":
        # Godot has no authenticated full character snapshot yet; do not
        # invent inventory, books, ranks or server purchases in response.
        print("PPA_ORIGINAL_UI_AWAITING_AUTHENTICATED_STATE")

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
    # The player model already opens the canonical five-page character UI.
    # A second top-right "ГЕРОЙ" button duplicated that action and covered
    # valuable mobile screen space. Keep only global "РАЗДЕЛЫ" navigation.

    # Permanent top-level navigation, NOT a child of character or NPC UI.
    var hub_button := Button.new()
    hub_button.name = "OpenGlobalPpaHub"
    hub_button.text = "РАЗДЕЛЫ"
    hub_button.anchor_left = 1.0
    hub_button.anchor_right = 1.0
    hub_button.offset_left = -310.0
    hub_button.offset_right = -160.0
    hub_button.offset_top = 142.0
    hub_button.offset_bottom = 185.0
    hub_button.z_index = 65
    hub_button.add_theme_stylebox_override("normal", _button_style(Color("#32221D")))
    hub_button.add_theme_color_override("font_color", Color("#F2CC89"))
    hub_button.pressed.connect(func(): open_global_section("events"))
    add_child(hub_button)

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

    _tab_bar = HBoxContainer.new()
    _tab_bar.add_theme_constant_override("separation", 4)
    column.add_child(_tab_bar)
    for spec in [
        ["character", "ГЕРОЙ"],
        ["bag", "СУМКА"],
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
        _tab_bar.add_child(b)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)

    _list = VBoxContainer.new()
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.add_theme_constant_override("separation", 8)
    scroll.add_child(_list)

    _notice = Label.new()
    _notice.text = _page_notice_default
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
    return _web_open or (_panel != null and _panel.visible) or (_character_screen != null and _character_screen.visible) or (_npc_screen != null and _npc_screen.is_open()) or (_global_hub != null and _global_hub.is_open())

func open_global_section(which: String) -> void:
    if _global_hub == null:
        return
    # Strictly one modal: global navigation cannot coexist with an NPC,
    # the five-page hero screen, or optional original HTML/WebView.
    if _npc_screen != null:
        _npc_screen.close_npc()
    if _native_web_ui != null and _web_open:
        _native_web_ui.hideUi()
    _web_open = false
    if _character_screen != null:
        _character_screen.visible = false
    _panel.visible = false
    _background.visible = false
    current_page = "global_" + which
    _global_hub.open_section(which)

func _on_character_unequip(slot: String) -> void:
    var result: String = stash.unequip_test_item(slot)
    if _character_screen != null:
        _character_screen.open_index(0)
    print("[PPA-CHARACTER] Local test equipment action: ", result)

func open_npc(npc: Dictionary) -> void:
    if npc.is_empty() or _npc_screen == null:
        return
    var valid_service := str(npc.get("service", ""))
    if not NPC_SCREEN.SERVICES.has(valid_service):
        return
    nearby_npc = npc.duplicate(true)
    _merchant_tab = "potions"
    _merchant_selected = ""
    _shop_qty = 1
    _market_category = "all"
    _smith_tab = "enhance"
    # NEVER route an NPC through open_page("character"/"warehouse").
    # Prevents the five-page hero interface from opening behind a shop.
    if _native_web_ui != null and _web_open:
        _native_web_ui.hideUi()
    _web_open = false
    if _character_screen != null:
        _character_screen.visible = false
    _panel.visible = false
    _background.visible = false
    if _global_hub != null:
        _global_hub.close_global()
    current_page = "npc_" + valid_service
    _npc_screen.open_npc(npc)

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
    if _global_hub != null and _global_hub.is_open():
        _global_hub.close_global()
    if _npc_screen != null and _npc_screen.is_open():
        _npc_screen.close_npc()
    current_page = page
    if ["character", "bag", "runes", "skills"].has(page):
        _panel.visible = false
        if _character_screen != null:
            _character_screen.visible = false
        var source_page := 4 if page == "runes" else (2 if page == "skills" else 0)
        if _use_original_web_ui:
            if _native_web_ui == null:
                _background.visible = false
                push_error("PPA_ORIGINAL_WEBVIEW_REQUIRED: opt-in Android plugin missing")
                OS.alert("Тестовый WebView не загрузился. Отключи ppa/ui/use_original_webview.", "PPA · WebView")
                return
            # Optional original PPA HTML; not a second game engine.
            _background.visible = false
            _web_open = true
            _native_web_ui.showCharacter(class_key, source_page)
            return
        if _character_screen == null:
            _background.visible = false
            push_error("PPA_NATIVE_CHARACTER_MISSING: five-page Godot screen unavailable")
            return
        # Native Godot owns touch, page navigation and scroll on all devices.
        _background.visible = true
        _character_screen.open_index(source_page)
        return
    if _native_web_ui != null and _web_open:
        _native_web_ui.hideUi()
        _web_open = false
    if _character_screen != null:
        _character_screen.visible = false
    _background.visible = true
    _panel.visible = true
    _notice.text = _page_notice_default
    _resize_active_panel()
    _refresh()

func _resize_active_panel() -> void:
    if _panel == null:
        return
    var hero_page := ["character", "bag", "runes", "skills", "item"].has(current_page)
    var warehouse_page := current_page == "warehouse"
    var width := 464.0 if hero_page else (1000.0 if warehouse_page else 1110.0)
    var height := 620.0 if hero_page else 632.0
    var max_width := maxf(340.0, size.x - 30.0)
    var max_height := maxf(320.0, size.y - 28.0)
    width = minf(width, max_width)
    height = minf(height, max_height)
    _panel.offset_left = -width * 0.5
    _panel.offset_right = width * 0.5
    _panel.offset_top = -height * 0.5
    _panel.offset_bottom = height * 0.5
    if _tab_bar != null:
        _tab_bar.visible = hero_page or warehouse_page

func close_menu() -> void:
    if _global_hub != null:
        _global_hub.close_global()
    if _npc_screen != null:
        _npc_screen.close_npc()
    if _native_web_ui != null and _web_open:
        _native_web_ui.hideUi()
        _web_open = false
    _panel.visible = false
    if _character_screen != null:
        _character_screen.visible = false
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
        button.custom_minimum_size = Vector2(128, 58)
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
    grid.columns = 3
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
    if _has_verified_save:
        var server_inventory := SERVER_VIEW.from_save(_verified_save)
        var server_bag: Array = server_inventory.get("bag", [])
        var resource_stacks: Array = server_inventory.get("resource_items", [])
        var source_items: Array = resource_stacks if _selected_item_source == "resource" else server_bag
        var real_item: Dictionary = SERVER_VIEW.item_at(source_items, _selected_item_index)
        if real_item.is_empty():
            open_page("bag")
            return
        _line(SERVER_VIEW.title(real_item), false, true)
        _line("Количество: " + str(SERVER_VIEW.item_count(real_item)))
        _line("Редкость: " + SERVER_VIEW.rarity(real_item), true)
        _line("Настоящий предмет PPA. Действия будут доступны после серверного подключения.", true)
        var back_to_bag := Button.new()
        back_to_bag.text = "НАЗАД"
        back_to_bag.pressed.connect(open_page.bind("bag"))
        _list.add_child(back_to_bag)
        return
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
    # Real PPA selling is intentionally unavailable until server inventory is
    # connected. No imaginary payout or local pseudo-economy.
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

# Reuses the SAME native window as character, warehouse and every NPC;
# never spawns a secondary shop or translucent overlay over another one.
func _show_shop() -> void:
    var service := str(nearby_npc.get("service", ""))
    if service == "merchant":
        _show_canonical_merchant()
    elif service == "blackmarket":
        _show_canonical_black_market()
    else:
        _line("Это не магазин PPA.", true)

func _set_merchant_tab(tab: String) -> void:
    if _npc_screen != null and _npc_screen.is_open() and _npc_screen.service == "merchant":
        _npc_screen._select_tab(tab)
    _merchant_tab = tab
    _merchant_selected = ""
    _shop_qty = 1
    _refresh()

func _select_merchant_item(id: String) -> void:
    if _npc_screen != null and _npc_screen.is_open() and _npc_screen.service == "merchant":
        _npc_screen._select_item(id)
    _merchant_selected = id
    _shop_qty = 1
    _refresh()

func _adjust_merchant_quantity(change: int) -> void:
    if _npc_screen != null and _npc_screen.is_open() and _npc_screen.service == "merchant":
        _npc_screen._change_quantity(change)
    _shop_qty = clampi(_shop_qty + change, 1, 999)
    _refresh()

func _catalog_picture(path: String, size_px: float) -> TextureRect:
    var picture := TextureRect.new()
    picture.custom_minimum_size = Vector2(size_px, size_px)
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if ResourceLoader.exists(path):
        picture.texture = load(path) as Texture2D
    return picture

func _show_canonical_merchant() -> void:
    _title.text = "ЛАВКА ТОРГОВЦА"
    _line("ЛАВКА ТОРГОВЦА", false, true)
    _line("ВСЕ ПОКУПКИ · ТОЛЬКО ЗА GOLD", true)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    _list.add_child(tabs)
    for entry in SHOP_CATALOG.MERCHANT_TABS:
        var key := str(entry.get("key", ""))
        var button := _action(tabs, str(entry.get("label", "")), _set_merchant_tab.bind(key))
        button.modulate = Color("#FFD395") if key == _merchant_tab else Color("#A7B0B7")
    _spacer()

    var contents := HBoxContainer.new()
    contents.add_theme_constant_override("separation", 16)
    _list.add_child(contents)
    var items_left := VBoxContainer.new()
    items_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    contents.add_child(items_left)
    var products: Array = []
    for raw in SHOP_CATALOG.MERCHANT:
        if str(raw.get("tab", "")) == _merchant_tab:
            products.append(raw)
    var count_label := Label.new()
    count_label.text = str(products.size()) + " товаров"
    count_label.add_theme_color_override("font_color", Color("#BEAA8A"))
    items_left.add_child(count_label)
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    items_left.add_child(grid)
    for raw in products:
        var product: Dictionary = raw
        var tile := PanelContainer.new()
        tile.custom_minimum_size = Vector2(154.0, 146.0)
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tile.add_theme_stylebox_override("panel", _button_style(Color("#10171B")))
        grid.add_child(tile)
        var stack := VBoxContainer.new()
        stack.add_theme_constant_override("separation", 3)
        tile.add_child(stack)
        stack.add_child(_catalog_picture(str(product.get("img", "")), 63.0))
        var name := Label.new()
        name.text = str(product.get("name", ""))
        name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name.add_theme_font_size_override("font_size", 11)
        stack.add_child(name)
        var price := str(product.get("price", 0)) + (" PPA" if str(product.get("currency", "gold")) == "ppa" else " Gold")
        var select := Button.new()
        select.text = price
        select.custom_minimum_size = Vector2(0, 30)
        select.add_theme_font_size_override("font_size", 12)
        select.pressed.connect(_select_merchant_item.bind(str(product.get("id", ""))))
        stack.add_child(select)

    var detail := PanelContainer.new()
    detail.custom_minimum_size = Vector2(337.0, 360.0)
    detail.add_theme_stylebox_override("panel", _button_style(Color("#0C1013")))
    contents.add_child(detail)
    var detail_col := VBoxContainer.new()
    detail_col.add_theme_constant_override("separation", 9)
    detail.add_child(detail_col)
    var selected: Dictionary = {}
    for product in SHOP_CATALOG.MERCHANT:
        if str(product.get("id", "")) == _merchant_selected:
            selected = product
            break
    if selected.is_empty():
        var label := Label.new()
        label.text = "ВЫБЕРИТЕ ТОВАР"
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 18)
        label.add_theme_color_override("font_color", Color("#F0C166"))
        detail_col.add_child(label)
        detail_col.add_child(_catalog_picture("", 118.0))
        var message := Label.new()
        message.text = "Нажми на товар слева, чтобы узнать его настоящую цену и описание PPA."
        message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        detail_col.add_child(message)
    else:
        detail_col.add_child(_catalog_picture(str(selected.get("img", "")), 108.0))
        var item_title := Label.new()
        item_title.text = str(selected.get("name", ""))
        item_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        item_title.add_theme_color_override("font_color", Color("#F0C166"))
        item_title.add_theme_font_size_override("font_size", 16)
        detail_col.add_child(item_title)
        var text_desc := Label.new()
        text_desc.text = str(selected.get("desc", ""))
        text_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        text_desc.add_theme_font_size_override("font_size", 12)
        detail_col.add_child(text_desc)
        var currency := " PPA" if str(selected.get("currency", "gold")) == "ppa" else " Gold"
        var unit_price := int(selected.get("price", 0))
        var price_label := Label.new()
        price_label.text = "Цена: " + str(unit_price) + currency + " / шт."
        price_label.add_theme_color_override("font_color", Color("#F0C166"))
        detail_col.add_child(price_label)
        var own := Label.new()
        own.text = "У вас: — (серверный инвентарь не загружен)"
        own.add_theme_font_size_override("font_size", 11)
        detail_col.add_child(own)
        var qty_row := HBoxContainer.new()
        detail_col.add_child(qty_row)
        _action(qty_row, "−", _adjust_merchant_quantity.bind(-1))
        var qty := Label.new()
        qty.text = "×" + str(_shop_qty)
        qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        qty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        qty_row.add_child(qty)
        _action(qty_row, "+", _adjust_merchant_quantity.bind(1))
        var total := Label.new()
        total.text = "Итого: " + str(unit_price * _shop_qty) + currency
        detail_col.add_child(total)
        var buy := Button.new()
        buy.text = "КУПИТЬ · ТРЕБУЕТСЯ СИНХРОНИЗАЦИЯ PPA"
        buy.disabled = true
        buy.custom_minimum_size = Vector2(0, 45)
        detail_col.add_child(buy)
    _spacer()
    _line("🪙 Gold: —        ◆ Gram: —        ◉ PPA: —", true)
    _notice.text = "ОРИГИНАЛЬНЫЕ 12 ТОВАРОВ И ЦЕНЫ PPA · ПОКУПКИ ВРЕМЕННО ЗАБЛОКИРОВАНЫ"

func _set_market_category(key: String) -> void:
    if _npc_screen != null and _npc_screen.is_open() and _npc_screen.service == "blackmarket":
        _npc_screen._select_tab(key)
    _market_category = key
    _refresh()

func _show_canonical_black_market() -> void:
    _title.text = "БЛЕК МАРКЕТ"
    _line("БЛЕК МАРКЕТ     ·     редкие товары · закрытые сделки", false, true)
    _line("Оригинальный рынок PPA · ассортимент и лимиты зависят от серверного сохранения, обновление каждые 24 часа.", true)
    _spacer()
    var tabs := HBoxContainer.new()
    _list.add_child(tabs)
    var shop_label := _action(tabs, "ТОВАРЫ", _set_market_category.bind("all"))
    shop_label.modulate = Color("#F2BAB5")
    var buyback := Button.new()
    buyback.text = "СКУПКА · ДАННЫЕ СЕРВЕРА"
    buyback.disabled = true
    buyback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.add_child(buyback)

    var categories := GridContainer.new()
    categories.columns = 4
    categories.add_theme_constant_override("h_separation", 6)
    categories.add_theme_constant_override("v_separation", 6)
    _list.add_child(categories)
    for entry in SHOP_CATALOG.BM_CATEGORIES:
        var key := str(entry.get("key", ""))
        var button := _action(categories, str(entry.get("label", "")), _set_market_category.bind(key))
        button.modulate = Color("#FFD2D2") if key == _market_category else Color("#9E8D91")
    _spacer()
    _line("БАЗОВЫЕ ПРЕДЛОЖЕНИЯ ИЗ PPA", false, true)
    _line("Ниже показаны только постоянные позиции из исходного алгоритма. Случайные лоты и состояние «куплено» без сохранения игрока не подменяем.", true)
    var grid := GridContainer.new()
    grid.columns = 3
    _list.add_child(grid)
    var found := 0
    for raw in SHOP_CATALOG.BLACK_MARKET_REFERENCE:
        var item: Dictionary = raw
        if _market_category != "all" and str(item.get("category", "")) != _market_category:
            continue
        found += 1
        var tile := PanelContainer.new()
        tile.custom_minimum_size = Vector2(230, 146)
        var style := _button_style(Color("#160D12"))
        style.border_color = Color("#71363C")
        tile.add_theme_stylebox_override("panel", style)
        grid.add_child(tile)
        var stack := VBoxContainer.new()
        stack.add_theme_constant_override("separation", 5)
        tile.add_child(stack)
        var title := Label.new()
        title.text = str(item.get("name", ""))
        title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        title.add_theme_font_size_override("font_size", 15)
        title.add_theme_color_override("font_color", Color("#F0C0B6"))
        stack.add_child(title)
        var desc := Label.new()
        desc.text = str(item.get("desc", ""))
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.add_theme_font_size_override("font_size", 11)
        stack.add_child(desc)
        var price := Label.new()
        price.text = str(item.get("price", 0)) + " PPA  ·  лимит " + str(item.get("limit", 1))
        price.add_theme_font_size_override("font_size", 12)
        price.add_theme_color_override("font_color", Color("#F0A79B"))
        stack.add_child(price)
    if found == 0:
        _line("Предложения этого раздела генерируются PPA индивидуально при обновлении рынка.", true)
    _spacer()
    _line("☠ ТОВАР ИЗ-ПОД ПРИЛАВКА · 500 PPA · содержимое скрыто до покупки", false, true)
    _line("Реальные случайные товары, лимиты, ежедневная скупка и таймер появятся после подключения того же состояния, что использует веб-PPA.", true)
    _line("◉ PPA: —      ◆ Gram: —", true)
    _notice.text = "ОРИГИНАЛЬНАЯ СТРУКТУРА РЫНКА · НЕТ ФАЛЬШИВЫХ ЛОТОВ И ПОКУПОК"

func _set_smith_tab(tab: String) -> void:
    if _npc_screen != null and _npc_screen.is_open() and _npc_screen.service == "forge":
        _npc_screen._select_tab(tab)
    _smith_tab = tab
    _refresh()

func _show_forge() -> void:
    _title.text = "КУЗНЕЦ"
    _line("КУЗНЕЦ", false, true)
    _line("ЗАТОЧКА · СНАРЯЖЕНИЕ · АКСЕССУАРЫ · ПЕТЫ", true)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 6)
    _list.add_child(tabs)
    for entry in SHOP_CATALOG.SMITH_TABS:
        var key := str(entry.get("key", ""))
        var button := _action(tabs, str(entry.get("label", "")), _set_smith_tab.bind(key))
        button.modulate = Color("#F0C166") if key == _smith_tab else Color("#AFA091")
    _spacer()
    match _smith_tab:
        "enhance":
            _line("ЗАТОЧКА СНАРЯЖЕНИЯ / АКСЕССУАРОВ / ПЕТОВ", false, true)
            _line("Обычные камни — до +5. Премиум камни — до +7, сохраняют предмет и заточку при провале.", true)
            _line("Премиум руна: +12–16 п.п. к шансу попытки.", true)
            _spacer()
            var chances := GridContainer.new()
            chances.columns = 4
            chances.add_theme_constant_override("h_separation", 8)
            chances.add_theme_constant_override("v_separation", 8)
            _list.add_child(chances)
            for spec in [
                ["+1","43%"],["+2","35%"],["+3","27%"],["+4","19%"],
                ["+5","12%"],["+6","7%"],["+7","3%"]
            ]:
                var label := Label.new()
                label.text = str(spec[0]) + "  ·  " + str(spec[1])
                label.add_theme_color_override("font_color", Color("#F0C166"))
                chances.add_child(label)
            _spacer()
            _line("При обычной неудаче редкости до редкой могут сгореть; эпический предмет теряет 1 уровень заточки.", true)
        "equipment":
            _line("ЭПИЧЕСКОЕ СНАРЯЖЕНИЕ", false, true)
            _line("Эпик-доспехи доступны всем 8 классам. Оружие и шмот: только крафт, 12 000–15 000 PPA + ресурсы + Перо Феникса.", true)
        "legendary":
            _line("ЛЕГЕНДАРНОЕ СНАРЯЖЕНИЕ · ФАРТ ЗОНА", false, true)
            _line("Базовые характеристики ×3 от эпических +0.", true)
            _line("Оружие: 14 000 PPA + 1000 Адской руды.", true)
            _line("Остальное: 12 000 PPA + 1000 легендарных кристаллов.", true)
        "accessories":
            _line("АКСЕССУАРЫ", false, true)
            _line("КОЛЬЦО · ПЛАЩ · ОЖЕРЕЛЬЕ · АРТЕФАКТ · КРЫЛЬЯ", true)
            _line("Редкости: обычный · необычный · редкий · эпический · легендарный.", true)
        "pets":
            _line("8 БАЗОВЫХ ПИТОМЦЕВ", false, true)
            _line("Выбор питомца и редкости; эпические петы не крафтятся — только события и особые условия.", true)
    _spacer()
    _line("ИНВЕНТАРЬ СЕРВЕРА: —       Gold: —       Gram: —       PPA: —", true)
    var safe_button := Button.new()
    safe_button.text = "ЗАТОЧИТЬ / СОЗДАТЬ · ДОСТУПНО ПОСЛЕ СИНХРОНИЗАЦИИ"
    safe_button.disabled = true
    safe_button.custom_minimum_size = Vector2(0, 46)
    _list.add_child(safe_button)
    _notice.text = "КУЗНЕЦ ИЗ PPA · ТЕКУЩЕЕ СНАРЯЖЕНИЕ И РЕЦЕПТЫ НЕ ПОДМЕНЯЕМ"

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
