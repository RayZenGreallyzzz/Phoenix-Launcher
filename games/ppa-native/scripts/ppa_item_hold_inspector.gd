extends Control

# One reusable PPA item inspector for ALL native NPC menus.
# Hold for 1 second: read-only mini card until finger/mouse release.
# Short tap: pinned mini card; permitted equip/unequip button lives here.
# Never changes player save, never infers owner permissions locally.
const ITEM_ATTRIBUTES = preload("res://scripts/ppa_item_attribute_view.gd")
const GOLD := Color("#F6C66F")
const SUB := Color("#A8B1B3")
const HOLD_SECONDS := 1.0
const DRAG_THRESHOLD := 22.0

var resolve_action: Callable
var _timer: Timer
var _popup_center: CenterContainer
var _panel: PanelContainer
var _popup_scroll: ScrollContainer
var _content: VBoxContainer
var _fit_revision := 0
var _dismiss_touch_start := Vector2.ZERO
var _dismiss_touch_pending := false
var _dismiss_touch_moved := false
var _held_source: Button
var _held_item: Dictionary = {}
var _held_origin := ""
var _tap_action: Callable
var _press_start := Vector2.ZERO
var _moved := false
var _temporary := false
var _open_item: Dictionary = {}
var _open_origin := ""
var _canvas_proxy: Button
var _last_pointer_down := Vector2.ZERO
var _touch_pointer_index := -1

func _ready() -> void:
    name = "PPAItemHoldInspector"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    _canvas_proxy = Button.new()
    _canvas_proxy.name = "PPAInspectorVirtualSlotProxy"
    _canvas_proxy.visible = false
    add_child(_canvas_proxy)
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.wait_time = HOLD_SECONDS
    _timer.timeout.connect(_hold_timeout)
    add_child(_timer)
    # Android video QA: a fixed 400px popup created a giant empty black
    # rectangle for stones and runes with only two or three detail lines.
    # CenterContainer gives the SAME common panel content-driven height.
    _popup_center = CenterContainer.new()
    _popup_center.name = "PPAItemInspectorCenter"
    _popup_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _popup_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_popup_center)
    _panel = PanelContainer.new()
    _panel.name = "PPAItemInspectorPopup"
    _panel.visible = false
    _panel.custom_minimum_size.x = 340.0
    _panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _panel.add_theme_stylebox_override("panel", _style(Color("#101719"), Color("#C18A42")))
    _popup_center.add_child(_panel)
    # One shared scrolling body: nested fixed-height stat containers clipped
    # wrapped lines beneath the close hint on narrow Android screens.
    _popup_scroll = ScrollContainer.new()
    _popup_scroll.name = "PPAInspectorBodyScroll"
    _popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _popup_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _popup_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    _popup_scroll.scroll_deadzone = 8
    _panel.add_child(_popup_scroll)
    _content = VBoxContainer.new()
    _content.name = "PPAItemInspectorContent"
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 6)
    _popup_scroll.add_child(_content)

# After Godot has laid out wrapped labels, cap the WHOLE card to the screen.
# The ScrollContainer owns vertical overflow and includes the final hint.
func _schedule_popup_fit() -> void:
    if _panel == null or _popup_scroll == null:
        return
    _fit_revision += 1
    _fit_popup_after_layout.call_deferred(_fit_revision)

func _fit_popup_after_layout(revision: int) -> void:
    if not is_open() or revision != _fit_revision:
        return
    var width_limit := maxf(180.0, size.x - 32.0)
    _panel.custom_minimum_size.x = minf(340.0, width_limit)
    _popup_scroll.custom_minimum_size.y = 0.0
    # Make room for the panel padding (10 each side) and its borders.
    _popup_scroll.custom_minimum_size.x = _panel.custom_minimum_size.x - 24.0
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_open() or revision != _fit_revision:
        return
    var body_height := maxf(_content.get_combined_minimum_size().y, _content.size.y)
    var height_limit := maxf(100.0, size.y - 56.0)
    _popup_scroll.custom_minimum_size.y = minf(body_height, height_limit - 24.0)
    _popup_scroll.scroll_vertical = 0

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and _panel != null and _panel.visible:
        _schedule_popup_fit()

func _style(bg: Color, stroke: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = stroke
    s.set_border_width_all(2)
    s.set_corner_radius_all(7)
    s.set_content_margin_all(10)
    return s

func _text(text_value: String, tint: Color = GOLD, size: int = 12) -> Label:
    var label := Label.new()
    label.text = text_value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", tint)
    return label

# Shared original PPA rarity palette. These are ONLY UI colors, not stats.
const RARITY_COLORS := {
    "common": Color("#C5CDD7"),
    "uncommon": Color("#5FEC99"),
    "rare": Color("#73B2FF"),
    "epic": Color("#D18FFF"),
    "legendary": Color("#FFD170")
}
const RARITY_CAPTIONS := {
    "common":"Обычный", "uncommon":"Необычный",
    "rare":"Редкий", "epic":"Эпический",
    "legendary":"Легендарный"
}

static func rarity_key(item: Dictionary) -> String:
    var raw := str(item.get("rarity", "common")).to_lower().strip_edges()
    var synonyms := {
        "обычный":"common", "необычный":"uncommon",
        "редкий":"rare", "эпический":"epic", "легендарный":"legendary"
    }
    raw = str(synonyms.get(raw, raw))
    return raw if RARITY_COLORS.has(raw) else "common"

static func rarity_tint(item: Dictionary) -> Color:
    return RARITY_COLORS[rarity_key(item)]

static func _type_name(item: Dictionary) -> String:
    var official := str(item.get("typeName", "")).strip_edges()
    if not official.is_empty():
        return official
    var category := str(item.get("kind", ""))
    return str({
        "gear":"Снаряжение", "material":"Материал",
        "stone":"Камень заточки", "rune":"Руна",
        "pet":"Питомец", "accessory":"Аксессуар",
        "grimoire":"Гримуар", "consumable":"Расходуемый предмет"
    }.get(category, "Предмет"))


func bind_button(button: Button, item: Dictionary, origin: String = "catalog",
        tap_action: Callable = Callable()) -> void:
    if item.is_empty():
        return
    # An item icon is a viewer, not a purchase/spend button. It must receive
    # pointer-down even if its surrounding inventory slot is read-only.
    button.disabled = false
    button.tooltip_text = ""
    button.set_meta("ppa_inspect_name", str(item.get("name", "")))
    button.set_meta("ppa_inspect_origin", origin)
    button.button_down.connect(_begin_press.bind(button, item.duplicate(true), origin, tap_action))
    # GLOBAL input release is necessary: the finger may lift outside a slot.
    # It also prevents opening a tap card after scrolling a grid.
    # The controller is shared instead of allocating 100 timers per slot.

func begin_canvas_hold(item: Dictionary, origin: String, global_pos: Vector2) -> void:
    # Virtual 100/200/500-cell storage grids are drawn by one Control, not
    # hundreds of Buttons. Reuse this single invisible proxy per inspector.
    if _canvas_proxy == null or item.is_empty():
        return
    _begin_press(_canvas_proxy, item, origin, Callable())
    _press_start = global_pos


func _begin_press(button: Button, item: Dictionary, origin: String,
        tap_action: Callable) -> void:
    _timer.stop()
    _held_source = button
    _held_item = item.duplicate(true)
    _held_origin = origin
    _tap_action = tap_action
    _press_start = _last_pointer_down
    _moved = false
    _temporary = false
    _timer.start()

func _input(event: InputEvent) -> void:
    # A pinned details card is dismissed by the next touch ANYWHERE, without
    # adding a large close button. The equip/unequip button is the one
    # exception: allow it to receive a real tap and perform the verified action.
    if is_open() and not _temporary:
        if event is InputEventScreenTouch:
            var touch := event as InputEventScreenTouch
            if touch.pressed:
                if not _is_equipment_button_at(touch.position):
                    # Wait until release for an INSIDE tap. A swipe must be
                    # passed to the scroll body, not mistaken for dismissal.
                    if _panel.get_global_rect().has_point(touch.position):
                        _dismiss_touch_start = touch.position
                        _dismiss_touch_pending = true
                        _dismiss_touch_moved = false
                    else:
                        dismiss()
                        get_viewport().set_input_as_handled()
                        return
            elif _dismiss_touch_pending:
                var close_on_release := not _dismiss_touch_moved
                _dismiss_touch_pending = false
                if close_on_release:
                    dismiss()
                    get_viewport().set_input_as_handled()
                return
        elif event is InputEventScreenDrag and _dismiss_touch_pending:
            if (event.position - _dismiss_touch_start).length() > DRAG_THRESHOLD:
                _dismiss_touch_moved = true
            # Never mark a real swipe handled: let the scroll container scroll.
            return
        elif event is InputEventMouseButton:
            var mouse := event as InputEventMouseButton
            if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed \
                    and not _is_equipment_button_at(mouse.position):
                # Mouse-wheel and drag scrolls are not blanket dismiss clicks.
                dismiss()
                get_viewport().set_input_as_handled()
                return
    # Input is delivered before Button GUI signals on real Android, so record
    # the true screen-touch origin rather than stale emulated mouse position.
    if event is InputEventScreenTouch and event.pressed:
        _last_pointer_down = event.position
        _touch_pointer_index = event.index
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed             and _touch_pointer_index < 0:
        _last_pointer_down = event.position
    if _held_source == null:
        return
    if event is InputEventScreenDrag:
        if (event.position - _press_start).length() > DRAG_THRESHOLD:
            _cancel_press()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        if (event.position - _press_start).length() > DRAG_THRESHOLD:
            _cancel_press()
    elif event is InputEventScreenTouch and not event.pressed and (
            _touch_pointer_index < 0 or event.index == _touch_pointer_index):
        _touch_pointer_index = -1
        _finish_press()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT             and not event.pressed and _touch_pointer_index < 0:
        _finish_press()

func _is_equipment_button_at(point: Vector2) -> bool:
    if _content == null:
        return false
    var gear_button := _content.find_child("PPAInspectorEquipmentAction", true, false) as Button
    return gear_button != null and gear_button.is_visible_in_tree() \
        and not gear_button.disabled and gear_button.get_global_rect().has_point(point)


func _hold_timeout() -> void:
    if _held_source == null or not is_instance_valid(_held_source) or _moved:
        return
    _temporary = true
    _show_item(_held_item, _held_origin, true)

func _cancel_press() -> void:
    _moved = true
    _timer.stop()
    if _temporary:
        dismiss()
    _held_source = null

func _finish_press() -> void:
    if _held_source == null:
        return
    _timer.stop()
    var show_menu := not _temporary and not _moved
    var item := _held_item.duplicate(true)
    var origin := _held_origin
    var tap_action := _tap_action
    _held_source = null
    if _temporary:
        dismiss()
    elif show_menu:
        if tap_action.is_valid():
            tap_action.call()
        _show_item(item, origin, false)

func _show_item(item: Dictionary, origin: String, preview_only: bool) -> void:
    _open_item = item.duplicate(true)
    _open_origin = origin
    var tier := rarity_key(item)
    var tint := rarity_tint(item)
    var surface := Color("#172026").lerp(tint, 0.065)
    _panel.add_theme_stylebox_override("panel", _style(surface, tint))
    _panel.visible = true
    for child in _content.get_children():
        _content.remove_child(child)
        child.queue_free()
    var title := _text(str(item.get("name", "Предмет PPA")).left(70), tint, 16)
    title.name = "PPAInspectorName"
    _content.add_child(title)
    var rarity_line := _text(
        str(RARITY_CAPTIONS.get(tier, "Обычный")) + " · " + _type_name(item),
        tint, 11)
    rarity_line.name = "PPAInspectorRarity"
    _content.add_child(rarity_line)

    var separator := ColorRect.new()
    separator.name = "PPAInspectorRarityDivider"
    separator.color = tint.darkened(0.24)
    separator.custom_minimum_size.y = 2
    separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _content.add_child(separator)

    var qty: Variant = item.get("count", item.get("qty", null))
    if qty != null:
        _content.add_child(_text("Количество: " + str(qty), Color("#E6EBED")))

    var descriptions := ITEM_ATTRIBUTES.description_lines_for_item(item)
    var description_heading := _text("ОПИСАНИЕ", tint, 11)
    description_heading.name = "PPAInspectorDescriptionHeading"
    _content.add_child(description_heading)
    if descriptions.is_empty():
        var missing := _text("Описание не указано в данных PPA.", SUB, 11)
        missing.name = "PPAInspectorMissingDescription"
        _content.add_child(missing)
    else:
        for source_line in descriptions:
            var description := _text(str(source_line), Color("#EEF0ED"), 12)
            description.name = "PPAInspectorDescription"
            _content.add_child(description)

    var details: Array = ITEM_ATTRIBUTES.stat_lines_for_item(item)
    if not details.is_empty():
        _content.add_child(_text("ХАРАКТЕРИСТИКИ", tint, 11))
        # Do not trap wrapped attributes inside a 168px inner scroller
        # with scrolling disabled: it hid the bottom lines on real phones.
        var rows := VBoxContainer.new()
        rows.name = "PPAInspectorAttributeRows"
        rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _content.add_child(rows)
        for line in details:
            rows.add_child(_text(str(line), Color("#E6EBED"), 11))
    elif origin == "catalog" and item.get("materials") is Array:
        # Some official legendary recipes only name a tier. Their exact
        # bonuses are absent from the public recipe; never fabricate stats.
        var missing_stats := _text(
            "Точные характеристики в каталоге этого рецепта не указаны.",
            SUB, 11)
        missing_stats.name = "PPAInspectorUnspecifiedRecipeStats"
        _content.add_child(missing_stats)

    if preview_only:
        # This panel may only be read while holding, never used to spend.
        var hint := _text("Отпусти палец, чтобы закрыть", SUB, 10)
        hint.name = "PPAInspectorHoldToDismiss"
        _content.add_child(hint)
        _schedule_popup_fit()
        return
    var action: Dictionary = {}
    if resolve_action.is_valid():
        var result: Variant = resolve_action.call(item, origin)
        if result is Dictionary:
            action = result
    if not action.is_empty():
        var button := Button.new()
        button.name = "PPAInspectorEquipmentAction"
        button.text = str(action.get("label", ""))
        button.disabled = not bool(action.get("allowed", false))
        button.add_theme_color_override("font_color", GOLD)
        button.add_theme_stylebox_override("normal", _style(Color("#322418"), Color("#AE762F")))
        _content.add_child(button)
        var callback: Variant = action.get("callback")
        if callback is Callable:
            button.pressed.connect(func():
                if (callback as Callable).is_valid() and not button.disabled:
                    (callback as Callable).call()
                dismiss())
        if button.disabled:
            _content.add_child(_text("Действие доступно после подтверждения сервера.", SUB, 10))
    var hint := _text("Коснись экрана, чтобы закрыть", SUB, 10)
    hint.name = "PPAInspectorTapToDismiss"
    _content.add_child(hint)
    _schedule_popup_fit()

func dismiss() -> void:
    if _timer != null:
        _timer.stop()
    if _panel != null:
        _panel.visible = false
    _open_item.clear()
    _open_origin = ""
    _temporary = false
    _held_source = null
    _dismiss_touch_pending = false
    _dismiss_touch_moved = false
    _fit_revision += 1

func is_open() -> bool:
    return _panel != null and _panel.visible
