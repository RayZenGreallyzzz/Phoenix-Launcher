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
var _panel: PanelContainer
var _content: VBoxContainer
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
    _panel = PanelContainer.new()
    _panel.name = "PPAItemInspectorPopup"
    _panel.visible = false
    _panel.anchor_left = 0.5
    _panel.anchor_right = 0.5
    _panel.anchor_top = 0.5
    _panel.anchor_bottom = 0.5
    _panel.offset_left = -170
    _panel.offset_right = 170
    _panel.offset_top = -200
    _panel.offset_bottom = 200
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _panel.add_theme_stylebox_override("panel", _style(Color("#101719"), Color("#C18A42")))
    add_child(_panel)
    _content = VBoxContainer.new()
    _content.name = "PPAItemInspectorContent"
    _content.add_theme_constant_override("separation", 6)
    _panel.add_child(_content)

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
    _press_start = get_viewport().get_mouse_position()
    _moved = false
    _temporary = false
    _timer.start()

func _input(event: InputEvent) -> void:
    if _held_source == null:
        return
    if event is InputEventScreenDrag:
        if (event.position - _press_start).length() > DRAG_THRESHOLD:
            _cancel_press()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        if (event.position - _press_start).length() > DRAG_THRESHOLD:
            _cancel_press()
    elif event is InputEventScreenTouch and not event.pressed:
        _finish_press()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        _finish_press()

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
    _panel.visible = true
    for child in _content.get_children():
        _content.remove_child(child)
        child.queue_free()
    var title := _text(str(item.get("name", "Предмет PPA")).left(70), GOLD, 16)
    title.name = "PPAInspectorName"
    _content.add_child(title)
    var rarity := str(item.get("rarity", "—"))
    var kind := str(item.get("typeName", item.get("kind", "Предмет")))
    _content.add_child(_text("Редкость: " + rarity + " · " + kind, SUB))
    var qty: Variant = item.get("count", item.get("qty", null))
    if qty != null:
        _content.add_child(_text("Количество: " + str(qty), GOLD))
    var details: Array = ITEM_ATTRIBUTES.lines_for_item(item)
    if details.is_empty():
        _content.add_child(_text("Дополнительных характеристик в сохранении нет.", SUB))
    else:
        var scroll := ScrollContainer.new()
        scroll.name = "PPAInspectorAttributeScroll"
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
        scroll.custom_minimum_size.y = minf(190.0, float(details.size()) * 25.0 + 12.0)
        _content.add_child(scroll)
        var rows := VBoxContainer.new()
        scroll.add_child(rows)
        for line in details:
            rows.add_child(_text(str(line), SUB))
    if preview_only:
        # Hold inspection never performs an action; releasing hides the card.
        _content.add_child(_text("Отпусти палец, чтобы закрыть", SUB, 10))
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
    var close := Button.new()
    close.name = "PPAInspectorClose"
    close.text = "✕ ЗАКРЫТЬ"
    close.pressed.connect(dismiss)
    _content.add_child(close)

func dismiss() -> void:
    if _timer != null:
        _timer.stop()
    if _panel != null:
        _panel.visible = false
    _open_item.clear()
    _open_origin = ""
    _temporary = false
    _held_source = null

func is_open() -> bool:
    return _panel != null and _panel.visible
