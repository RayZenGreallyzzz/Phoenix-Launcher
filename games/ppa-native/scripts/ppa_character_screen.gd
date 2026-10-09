extends Control

# Native port of the deployed PPA charFrame (2026-10-08).
# All geometry and navigation come from that iframe's CSS/DOM, not an invented
# tabbed window. Native controls replace the HTML elements; only this character
# screen is visible while the original web-style character menu is open.
# Real PPA equipment/stats/skills remain server-owned; local test stash is
# never represented as the authoritative character's server save.
signal close_requested
signal select_item_requested(source_name: String, index: int)
signal unequip_requested(slot: String)

const ORIGINAL_GRIMOIRES = preload("res://scripts/ppa_grimoire_catalog_generated.gd")
const CAPACITY = preload("res://scripts/ppa_storage_contract.gd")
const SERVER_VIEW = preload("res://scripts/ppa_server_inventory_view.gd")
const ITEM_ICONS = preload("res://scripts/ppa_item_icon_loader.gd")

const CAPTIONS := [
    "1. ИНВЕНТАРЬ",
    "2. ХАРАКТЕРИСТИКИ",
    "3. АКТИВНЫЕ НАВЫКИ",
    "4. ПАССИВНЫЕ НАВЫКИ",
    "5. РУНЫ"
]
const GEAR_LEFT := [["weapon", "Оружие"], ["helmet", "Шлем"], ["armor", "Броня"], ["gloves", "Перчатки"]]
const GEAR_RIGHT := [["ring", "Кольцо"], ["legs", "Поножи"], ["boots", "Сапоги"], ["necklace", "Ожерелье"]]
const COSMETICS := [["wings", "Крылья"], ["cloak", "Плащ"], ["pet", "Пет"], ["artifact", "Артефакт"]]
const RARITIES := {
    "common": Color("#5D431F"), "uncommon": Color("#42C868"),
    "rare": Color("#4B9CFF"), "epic": Color("#B565FF"),
    "legendary": Color("#F9B64C")
}
const GOLD := Color("#FFCF63")
const EDGE := Color("#87551F")
const MUTED := Color("#8F969D")
var account: Dictionary = {}
var class_key := "gnome"
var stash: RefCounted
var _page := 0
var _frame: PanelContainer
var _page_container: VBoxContainer
var _caption: Label
var _scroll: ScrollContainer
var _dots: Array[PanelContainer] = []
var _mono: SystemFont
# One gesture owner for content. Godot's native ScrollContainer touch
# inertia was racing with the old _input swipe code on Android (reversed and
# one-way scrolling). Explicit scroll uses one signed delta and no inertia.
var _touch_origin := Vector2.ZERO
var _touch_previous := Vector2.ZERO
var _touch_id := -1
var _gesture_axis := ""
var _mouse_origin := Vector2.ZERO
var _mouse_previous := Vector2.ZERO
var _mouse_scrolling := false
var _book_overlay: ColorRect
var _book_dialog: PanelContainer
var _book_container: VBoxContainer
var _book_scroll: ScrollContainer
var _gesture_scroll: ScrollContainer
var _original_skill_card_count := 0
# Mirrors the original iframe's renderSkills(sk): the absence of verified
# server skill data yields locked placeholders, never a fabricated learned
# skill selected from the global grimoire illustration catalog.
var _server_skills_received := false
var _server_skills: Dictionary = {}
var _server_inventory: Dictionary = {}
var _server_inventory_verified := false
var _icon_loader: Node

func apply_readonly_save(save: Dictionary) -> void:
    # This is a VIEW only. Never merge with the local test bag/equipment.
    _server_inventory = SERVER_VIEW.from_save(save)
    _server_inventory_verified = true
    var actual_class := str(save.get("classKey", save.get("cls", account.get("classKey", "")))).to_lower()
    if ["tank", "paladin", "barbarian", "assassin", "gnome", "archer", "mage", "priest"].has(actual_class):
        class_key = actual_class
    if is_node_ready() and visible:
        _draw_page()

func clear_readonly_save() -> void:
    _server_inventory.clear()
    _server_inventory_verified = false
    clear_authoritative_skill_snapshot()
    if is_node_ready() and visible:
        _draw_page()

func _real_bag() -> Array:
    return _server_inventory.get("bag", []) if _server_inventory_verified else []

func _real_equipment() -> Dictionary:
    return _server_inventory.get("equipped", {}) if _server_inventory_verified else {}

func _bind_item_icon(item: Dictionary, button: Button) -> void:
    if _icon_loader != null and not item.is_empty():
        _icon_loader.bind_button(item, class_key, button)

func apply_authoritative_skill_snapshot(snapshot: Dictionary) -> void:
    # Called ONLY by a future authenticated PPA player-state bridge.
    # Do not invoke this with catalog entries or native test stash values.
    if not snapshot.has("active") or not snapshot.has("passive"):
        return
    if not (snapshot["active"] is Array and snapshot["passive"] is Array):
        return
    _server_skills = snapshot.duplicate(true)
    _server_skills_received = true
    if is_node_ready() and visible and (_page == 2 or _page == 3):
        _draw_page()

func clear_authoritative_skill_snapshot() -> void:
    _server_skills_received = false
    _server_skills.clear()
    if is_node_ready() and visible and (_page == 2 or _page == 3):
        _draw_page()


func configure(profile: Dictionary, hero: String, shared_stash: RefCounted) -> void:
    account = profile.duplicate(true)
    class_key = hero
    stash = shared_stash
    if is_node_ready():
        _draw_page()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _icon_loader = ITEM_ICONS.new()
    _icon_loader.name = "PPAApprovedItemIcons"
    add_child(_icon_loader)
    _mono = SystemFont.new()
    _mono.font_names = PackedStringArray(["monospace", "Courier New"])
    _create_frame()
    _create_book_overlay()
    _fit_to_viewport()
    visible = false

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and is_node_ready():
        _fit_to_viewport()

func _style_box(bg: Color, border: Color, radius: int = 5, border_size: int = 1) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(border_size)
    s.set_corner_radius_all(radius)
    return s

func _text(content: String, font_size: int, color: Color = MUTED) -> Label:
    var l := Label.new()
    l.text = content
    l.add_theme_font_override("font", _mono)
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _button(content: String, font_size: int = 11) -> Button:
    var b := Button.new()
    b.text = content
    b.add_theme_font_override("font", _mono)
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_color_override("font_color", GOLD)
    b.add_theme_stylebox_override("normal", _style_box(Color("#201B16"), Color("#815020"), 5))
    b.add_theme_stylebox_override("hover", _style_box(Color("#352517"), Color("#D5943B"), 5))
    b.add_theme_stylebox_override("pressed", _style_box(Color("#100D0C"), Color("#F2B049"), 5))
    return b

func _create_frame() -> void:
    _frame = PanelContainer.new()
    _frame.name = "OriginalPPACharacterFrame"
    _frame.anchor_left = 0.5
    _frame.anchor_right = 0.5
    _frame.anchor_top = 0.5
    _frame.anchor_bottom = 0.5
    _frame.mouse_filter = Control.MOUSE_FILTER_STOP
    _frame.add_theme_stylebox_override("panel", _style_box(Color("#101418"), EDGE, 13, 2))
    add_child(_frame)

    # Original #box CSS: dual vertical/radial gradients in the INSIDE of
    # the same original PPA frame. No second menu, canvas or WebView layer.
    var fill := ColorRect.new()
    fill.name = "OriginalPPABackgroundGradient"
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var fill_shader := Shader.new()
    fill_shader.code = "shader_type canvas_item; void fragment() { vec3 topc = vec3(0.0941, 0.1098, 0.1216); vec3 bottomc = vec3(0.0314,0.0431,0.0510); vec3 bg = mix(topc,bottomc,UV.y); float d = length(vec2((UV.x-0.5)*1.2,UV.y*2.2)); float glow = (1.0 - smoothstep(0.0,0.36,d))*0.16; bg = mix(bg,vec3(0.678,0.255,0.094),glow); COLOR=vec4(bg,1.0); }"
    var bg_material := ShaderMaterial.new()
    bg_material.shader = fill_shader
    fill.material = bg_material
    _frame.add_child(fill)

    var padding := MarginContainer.new()
    padding.add_theme_constant_override("margin_left", 5)
    padding.add_theme_constant_override("margin_right", 5)
    padding.add_theme_constant_override("margin_top", 5)
    padding.add_theme_constant_override("margin_bottom", 5)
    _frame.add_child(padding)
    # Exact 1px decorative bands from #box:before / #box:after.
    # They are passive decoration within this ONE window.
    for top_line in [true, false]:
        var line := ColorRect.new()
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        line.color = Color("#C87927")
        line.z_index = 3
        line.anchor_right = 1.0
        line.offset_left = 12.0
        line.offset_right = -12.0
        if top_line:
            line.offset_top = 43.0
            line.offset_bottom = 44.0
        else:
            line.anchor_top = 1.0
            line.anchor_bottom = 1.0
            line.offset_top = -8.0
            line.offset_bottom = -7.0
        # Lines belong to the plain ColorRect, NOT to PanelContainer:
        # the latter would stretch any direct child to the entire panel.
        fill.add_child(line)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 0)
    padding.add_child(content)

    # Exact original header structure: title, close button, arrows+five dots
    # and bottom pageCaption. Header = 82 CSS pixels.
    var header := Control.new()
    header.custom_minimum_size = Vector2(0.0, 82.0)
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(header)
    var title := _text("ПЕРСОНАЖ", 17, GOLD)
    title.add_theme_font_size_override("font_size", 17)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_shadow_color", Color("#49240C"))
    title.add_theme_constant_override("shadow_offset_x", 1)
    title.add_theme_constant_override("shadow_offset_y", 1)
    title.anchor_left = 0
    title.anchor_right = 1
    title.offset_top = 2
    title.offset_bottom = 27
    header.add_child(title)

    var close := _button("✕", 16)
    close.anchor_left = 1
    close.anchor_right = 1
    close.offset_left = -36
    close.offset_right = -9
    close.offset_top = 2
    close.offset_bottom = 29
    close.add_theme_color_override("font_color", Color("#FFD0A0"))
    close.add_theme_stylebox_override("normal", _style_box(Color("#4A130F"), Color("#A4472A"), 5))
    close.pressed.connect(func(): close_requested.emit())
    header.add_child(close)

    # Original PPA navRow: 31×27 arrows, 11px gaps, 7×7 dots with 7px
    # separation. The old port drew oversized 17×27 bullet buttons.
    var nav := HBoxContainer.new()
    nav.anchor_left = 0.5
    nav.anchor_right = 0.5
    nav.offset_left = -80
    nav.offset_right = 80
    nav.offset_top = 30
    nav.offset_bottom = 57
    nav.alignment = BoxContainer.ALIGNMENT_CENTER
    nav.add_theme_constant_override("separation", 11)
    header.add_child(nav)
    var left := _button("‹", 20)
    left.custom_minimum_size = Vector2(31, 27)
    left.add_theme_stylebox_override("normal", _style_box(Color("#171410"), Color("#815020"), 14))
    left.pressed.connect(func(): open_index(_page - 1))
    nav.add_child(left)
    var dot_row := HBoxContainer.new()
    dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
    dot_row.add_theme_constant_override("separation", 7)
    nav.add_child(dot_row)
    for i in range(5):
        # Godot Button has a built-in font minimum height; using Button for
        # the tiny HTML .dot stretched it into a 27px pill on Android.
        # A 7x7 Panel inside a 15x27 input hit-area stays exactly circular.
        var target := CenterContainer.new()
        target.custom_minimum_size = Vector2(15.0, 27.0)
        target.mouse_filter = Control.MOUSE_FILTER_STOP
        target.gui_input.connect(_dot_input.bind(i))
        dot_row.add_child(target)
        var dot := PanelContainer.new()
        dot.name = "OriginalPPAPageDot"
        dot.custom_minimum_size = Vector2(7.0, 7.0)
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dot.add_theme_stylebox_override("panel", _style_box(Color("#5A5B5C"), Color("#252525"), 4))
        target.add_child(dot)
        _dots.append(dot)
    var right := _button("›", 20)
    right.custom_minimum_size = Vector2(31, 27)
    right.add_theme_stylebox_override("normal", _style_box(Color("#171410"), Color("#815020"), 14))
    right.pressed.connect(func(): open_index(_page + 1))
    nav.add_child(right)

    _caption = _text(CAPTIONS[0], 10, Color("#F0BA4D"))
    _caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _caption.anchor_left = 0.0
    _caption.anchor_right = 1.0
    _caption.offset_left = 7
    _caption.offset_right = -7
    _caption.offset_top = 59
    _caption.offset_bottom = 82
    header.add_child(_caption)

    _scroll = ScrollContainer.new()
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _scroll.scroll_deadzone = 100000
    _scroll.follow_focus = false
    content.add_child(_scroll)
    # The web PPA uses a thin amber 5px scroll thumb, not Godot's default
    # wide grey mobile scrollbar.
    var vbar := _scroll.get_v_scroll_bar()
    vbar.custom_minimum_size.x = 5.0
    vbar.add_theme_stylebox_override("scroll", _style_box(Color("#101214"), Color.TRANSPARENT, 0, 0))
    for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
        vbar.add_theme_stylebox_override(state, _style_box(Color("#8B5A24"), Color.TRANSPARENT, 4, 0))
    var inner := MarginContainer.new()
    inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for side in ["margin_left", "margin_right"]:
        inner.add_theme_constant_override(side, 10)
    inner.add_theme_constant_override("margin_top", 10)
    inner.add_theme_constant_override("margin_bottom", 18)
    _scroll.add_child(inner)
    _page_container = VBoxContainer.new()
    _page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _page_container.add_theme_constant_override("separation", 7)
    inner.add_child(_page_container)

func _fit_to_viewport() -> void:
    if _frame == null or size.x < 1 or size.y < 1:
        return
    # PPA production index: charFrame width:min(46vw,430px) and
    # height:min(91vh,680px) on landscape; portrait min(88vw,400px)
    # and min(88vh,760px). Short landscape <=620px goes full viewport.
    var portrait := size.y > size.x
    var width := minf(size.x * (0.88 if portrait else 0.46), (400.0 if portrait else 430.0))
    var height := minf(size.y * (0.88 if portrait else 0.91), (760.0 if portrait else 680.0))
    if not portrait and size.y <= 620.0:
        width = size.x
        height = size.y
    width = maxf(255.0, minf(width, size.x - 8.0))
    height = maxf(260.0, minf(height, size.y - 8.0))
    _frame.offset_left = -width * 0.5
    _frame.offset_right = width * 0.5
    _frame.offset_top = -height * 0.5
    _frame.offset_bottom = height * 0.5

func open_index(index: int) -> void:
    _page = posmod(index, 5)
    if _book_overlay != null:
        _book_overlay.visible = false
    visible = true
    _fit_to_viewport()
    _draw_page()
    if _scroll != null:
        _scroll.set_deferred("scroll_vertical", 0)

func is_open() -> bool:
    return visible

# PPA production gesture rules:
#   vertical up   => content moves up (scroll_vertical increases)
#   vertical down => content moves down (scroll_vertical decreases)
#   horizontal    => previous / next of five pages
# Godot's native touch scroll deadzone is set high to avoid *double* scrolling.
func _input(event: InputEvent) -> void:
    if not visible or _frame == null:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if _touch_id < 0:
                var target: ScrollContainer = _book_scroll if _book_overlay != null and _book_overlay.visible else _scroll
                var bounds: Rect2 = _book_dialog.get_global_rect() if target == _book_scroll else _scroll.get_global_rect()
                if target != null and bounds.has_point(touch.position):
                    _gesture_scroll = target
                    _touch_id = touch.index
                    _touch_origin = touch.position
                    _touch_previous = touch.position
                    _gesture_axis = ""
        elif touch.index == _touch_id:
            _touch_id = -1
            _gesture_axis = ""
            _gesture_scroll = null
        return
    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _touch_id:
            _move_gesture(drag.position, _touch_origin, _touch_previous, true)
            _touch_previous = drag.position
        return
    # Desktop mouse and stylus fallback. Android touch also emits synthetic
    # mouse events, so ignore those while the real ScreenTouch owns the drag.
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index != MOUSE_BUTTON_LEFT or _touch_id >= 0:
            return
        if mb.pressed:
            var mouse_target: ScrollContainer = _book_scroll if _book_overlay != null and _book_overlay.visible else _scroll
            var mouse_bounds: Rect2 = _book_dialog.get_global_rect() if mouse_target == _book_scroll else _scroll.get_global_rect()
            _mouse_scrolling = mouse_target != null and mouse_bounds.has_point(mb.position)
            _gesture_scroll = mouse_target if _mouse_scrolling else null
            _mouse_origin = mb.position
            _mouse_previous = mb.position
            _gesture_axis = ""
        else:
            _mouse_scrolling = false
            _gesture_axis = ""
            _gesture_scroll = null
    elif event is InputEventMouseMotion and _mouse_scrolling and _touch_id < 0:
        var motion := event as InputEventMouseMotion
        _move_gesture(motion.position, _mouse_origin, _mouse_previous, false)
        _mouse_previous = motion.position

func _move_gesture(point: Vector2, origin: Vector2, previous: Vector2, touch: bool) -> void:
    if _gesture_scroll == null:
        return
    var total := point - origin
    if _gesture_axis.is_empty() and total.length() >= 12.0:
        _gesture_axis = "vertical" if absf(total.y) >= absf(total.x) * 1.05 else "horizontal"
    if _gesture_axis == "vertical":
        var dy := point.y - previous.y
        # A finger moving UP has negative dy, thus increases vertical scroll.
        var max_scroll := maxi(0, int(ceilf(_gesture_scroll.get_v_scroll_bar().max_value - _gesture_scroll.get_v_scroll_bar().page)))
        _gesture_scroll.scroll_vertical = clampi(_gesture_scroll.scroll_vertical - int(roundf(dy)), 0, max_scroll)
        get_viewport().set_input_as_handled()
    elif _gesture_axis == "horizontal" and _gesture_scroll == _scroll and absf(total.x) >= 42.0 and absf(total.x) >= absf(total.y) * 1.15:
        var step := 1 if total.x < 0.0 else -1
        _touch_id = -1
        _mouse_scrolling = false
        _gesture_axis = ""
        _gesture_scroll = null
        open_index(_page + step)
        get_viewport().set_input_as_handled()

func _dot_input(event: InputEvent, index: int) -> void:
    if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
        open_index(index)
        accept_event()
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
            open_index(index)
            accept_event()

func _clear_page() -> void:
    for child in _page_container.get_children():
        _page_container.remove_child(child)
        child.queue_free()

func _draw_page() -> void:
    if _page_container == null or stash == null:
        return
    _clear_page()
    _caption.text = CAPTIONS[_page]
    for i in range(_dots.size()):
        var active := i == _page
        _dots[i].add_theme_stylebox_override("panel", _style_box(
            Color("#FFB843") if active else Color("#5A5B5C"),
            Color("#FFCF63") if active else Color("#252525"), 4
        ))
    _original_skill_card_count = 0
    match _page:
        0: _draw_inventory()
        1: _draw_stats()
        2: _draw_skills(false)
        3: _draw_skills(true)
        4: _draw_runes()

func _section(title: String) -> void:
    var bar := PanelContainer.new()
    bar.custom_minimum_size.y = 25
    bar.add_theme_stylebox_override("panel", _style_box(Color("#251A10"), Color("#5A371B"), 0))
    _page_container.add_child(bar)
    var caption := _text(title, 10, Color("#E5B44A"))
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    bar.add_child(caption)

func _slot(name: String, kind: String, w: float = 54.0, h: float = 54.0) -> Button:
    var equipped: Dictionary = _real_equipment().get(kind, {})
    var filled := not equipped.is_empty()
    var b := _button(name + "\n" + (str(equipped.get("name", "")) if filled else "свободно"), 7)
    b.custom_minimum_size = Vector2(w, h)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_color_override("font_color", Color("#C9A565"))
    b.add_theme_stylebox_override("normal", _style_box(
        Color("#0C0F12"), RARITIES.get(str(equipped.get("rarity", "common")), Color("#A26620")) if filled else Color("#A26620"), 6, 1
    ))
    # These server-owned items are inspect-only until authoritative
    # equipment operations are connected to the original PPA backend.
    b.disabled = true
    _bind_item_icon(equipped, b)
    return b

func _draw_inventory() -> void:
    var equipment := HBoxContainer.new()
    equipment.add_theme_constant_override("separation", 7)
    _page_container.add_child(equipment)
    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 7)
    left.custom_minimum_size.x = 54
    equipment.add_child(left)
    for e in GEAR_LEFT:
        left.add_child(_slot(str(e[1]), str(e[0])))

    var portrait := PanelContainer.new()
    portrait.name = "OriginalPPAPortrait"
    portrait.custom_minimum_size = Vector2(100, 237)
    portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    portrait.add_theme_stylebox_override("panel", _style_box(Color("#111417"), Color("#59401E"), 8))
    equipment.add_child(portrait)
    var mark := _text("МОДЕЛЬ\nПЕРСОНАЖА", 9, Color("#5E6266"))
    mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    portrait.add_child(mark)

    var right := VBoxContainer.new()
    right.add_theme_constant_override("separation", 7)
    right.custom_minimum_size.x = 54
    equipment.add_child(right)
    for e in GEAR_RIGHT:
        right.add_child(_slot(str(e[1]), str(e[0])))

    var cosmetics := HBoxContainer.new()
    cosmetics.name = "OriginalPPACosmeticSlots"
    cosmetics.alignment = BoxContainer.ALIGNMENT_CENTER
    cosmetics.add_theme_constant_override("separation", 4)
    _page_container.add_child(cosmetics)
    # Four truly SQUARE cosmetic slots. Do not let HBox expand the width
    # without also increasing height, which made them stretched rectangles.
    var cosmetic_width := _frame.offset_right - _frame.offset_left - 36.0
    var cosmetic_side := clampf(floorf((cosmetic_width - 12.0) / 4.0), 44.0, 72.0)
    for e in COSMETICS:
        var cosmetic_slot := _slot(str(e[1]), str(e[0]), cosmetic_side, cosmetic_side)
        cosmetic_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        cosmetics.add_child(cosmetic_slot)

    # Original profession ribbon max-width:260px, centered, not full width.
    var ribbon_holder := CenterContainer.new()
    ribbon_holder.custom_minimum_size.y = 30
    _page_container.add_child(ribbon_holder)
    var profession := PanelContainer.new()
    profession.custom_minimum_size = Vector2(260, 30)
    profession.add_theme_stylebox_override("panel", _style_box(Color("#25190F"), Color("#8C5925"), 5))
    ribbon_holder.add_child(profession)
    var cls := _text("ПРОФЕССИЯ · " + class_key.to_upper(), 9, Color("#EFBD55"))
    cls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    profession.add_child(cls)

    _section("ИНВЕНТАРЬ")
    var bag_line := HBoxContainer.new()
    bag_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _page_container.add_child(bag_line)
    var bag_label := _text("СУМКА", 9, Color("#DCAE4C"))
    bag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    bag_line.add_child(bag_label)
    var real_bag := _real_bag()
    var occupied := 0
    for candidate in real_bag:
        if candidate is Dictionary and not (candidate as Dictionary).is_empty():
            occupied += 1
    var count := _text((str(occupied) if _server_inventory_verified else "—") + " / " + str(CAPACITY.INVENTORY), 7, MUTED)
    count.name = "OriginalPPABagCount"
    count.autowrap_mode = TextServer.AUTOWRAP_OFF
    count.custom_minimum_size.x = 66.0
    count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    count.size_flags_horizontal = Control.SIZE_SHRINK_END
    bag_line.add_child(count)

    var grid := GridContainer.new()
    grid.name = "OriginalPPABagGrid"
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    _page_container.add_child(grid)
    # Production CSS: 5 equal SQUARE columns, gap 4px, not 93×41
    # rectangles. Effective page interior = iframe width - 36px margins.
    var page_width := _frame.offset_right - _frame.offset_left - 36.0
    var cell_side := floorf((page_width - 16.0) / 5.0)
    cell_side = maxf(34.0, cell_side)
    for i in range(CAPACITY.INVENTORY):
        var slot := _button("", 8)
        slot.custom_minimum_size = Vector2(cell_side, cell_side)
        slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var unlocked := i < 50
        var item: Dictionary = SERVER_VIEW.item_at(real_bag, i)
        var locked := not unlocked and item.is_empty()
        slot.disabled = locked
        slot.modulate.a = 1.0 if not locked else 0.40
        var edge := Color("#5D431F") if unlocked else Color("#282A2B")
        if not item.is_empty():
            edge = RARITIES.get(SERVER_VIEW.rarity(item), edge)
            slot.text = SERVER_VIEW.symbol(item) + "\n×" + str(SERVER_VIEW.item_count(item))
            slot.tooltip_text = SERVER_VIEW.title(item)
        var slot_style := _style_box(Color("#0B0E11"), edge, 4)
        slot.add_theme_stylebox_override("normal", slot_style)
        # Without this override, Godot draws the 50 disabled, locked
        # inventory slots as fully transparent. The entire bottom half
        # looks like an empty broken scroll page in the user's 0.1.60 video.
        slot.add_theme_stylebox_override("disabled", slot_style)
        slot.disabled = true
        grid.add_child(slot)
        _bind_item_icon(item, slot)
    var info := PanelContainer.new()
    info.custom_minimum_size.y = 35
    info.add_theme_stylebox_override("panel", _style_box(Color("#0D1013"), Color("#303238"), 5))
    _page_container.add_child(info)
    var hint := _text("ПРЕДМЕТЫ PPA · ТОЛЬКО ПРОСМОТР" if _server_inventory_verified else "ОЖИДАЕМ НАСТОЯЩИЙ ИНВЕНТАРЬ PPA", 8, MUTED)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    info.add_child(hint)
    var delete_notice := _text("УДАЛЕНИЕ АККАУНТА: доступно только через действующий клиент PPA.", 8, Color("#9F817C"))
    _page_container.add_child(delete_notice)

func _draw_stats() -> void:
    var level := PanelContainer.new()
    level.custom_minimum_size.y = 61
    level.add_theme_stylebox_override("panel", _style_box(Color("#0C0F11"), Color("#4B3822"), 5))
    _page_container.add_child(level)
    var block := VBoxContainer.new()
    block.add_theme_constant_override("separation", 7)
    level.add_child(block)
    var original_save: Dictionary = _server_inventory.get("save", {}) if _server_inventory_verified else {}
    var saved_level := str(original_save.get("lvl", original_save.get("level", "—")))
    var saved_xp := str(original_save.get("xp", "—"))
    block.add_child(_text("Уровень " + saved_level + "              XP " + saved_xp, 9, Color("#A9AFB4")))
    var xp := ProgressBar.new()
    xp.custom_minimum_size.y = 9
    xp.show_percentage = false
    xp.value = 0
    block.add_child(xp)
    _page_container.add_child(_text("Перерождений: " + str(original_save.get("rebirths", "—")) + "             доступно с 30 ур.", 9, Color("#A9AFB4")))
    var actions := HBoxContainer.new()
    _page_container.add_child(actions)
    for label in ["СБРОС ХАРАКТЕРИСТИК", "ПЕРЕРОЖДЕНИЕ · 30 УР."]:
        var b := _button(label, 8)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.custom_minimum_size.y = 34
        b.disabled = true
        actions.add_child(b)
    _page_container.add_child(_text("Очки характеристик: " + str(original_save.get("statPts", "—")), 9, Color("#F0BB51")))
    for entry in [
        ["❤", "HP"], ["◉", "Мана"], ["⚔", "Атака"],
        ["◆", "Защита"], ["➤", "Скорость"], ["≋", "Скорость атаки"],
        ["✹", "Крит. урон"], ["✦", "Крит. шанс"], ["◌", "Уворот"]
    ]:
        var row := PanelContainer.new()
        row.custom_minimum_size.y = 34
        row.add_theme_stylebox_override("panel", _style_box(Color("#121619"), Color("#34373B"), 5))
        _page_container.add_child(row)
        var line := HBoxContainer.new()
        line.add_theme_constant_override("separation", 5)
        row.add_child(line)
        var ico := _text(str(entry[0]), 12, GOLD)
        ico.custom_minimum_size.x = 25
        line.add_child(ico)
        var name := _text(str(entry[1]), 8, Color("#B8BDC1"))
        name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(name)
        var source_keys := {
            "HP":["hp"], "Мана":["mp"], "Атака":["atk", "attack"],
            "Защита":["def", "defense"], "Скорость":["speed", "spd"],
            "Скорость атаки":["attackSpeed", "atkSpeed"], "Крит. урон":["critDamage", "critDmg"],
            "Крит. шанс":["critChance", "crit"], "Уворот":["dodge", "evasion"]
        }
        var server_value: Variant = "—"
        for field in source_keys.get(str(entry[1]), []):
            if original_save.has(field):
                server_value = original_save[field]
                break
        var value := _text(str(server_value), 10, Color("#E6E6E6"))
        value.custom_minimum_size.x = 55
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        line.add_child(value)
        var add := _button("+", 17)
        add.custom_minimum_size = Vector2(29, 29)
        add.disabled = true
        line.add_child(add)
    _section("РАСПРЕДЕЛЕНИЕ ХАРАКТЕРИСТИК")
    _page_container.add_child(_text(
        "Старт: 10 очков · до первого перерождения +3 за уровень · с 30 ур. можно переродиться и получить +15 · после перерождения уровни 1–30 повторных очков не дают, с 31 ур. снова +3 · HP / Мана / Атака — максимум 200 очков · остальные — 100 · Уворот — максимум 60%.",
        8, MUTED
    ))

# Unlike the old placeholders, this uses the ACTUAL GRIMOIRE_CATALOG
# and GRIMOIRE_ART extracted from the live PPA on every build.
# The selected hero class is only a visual native test, not a real server
# class change. Never invent book counts, ranks, or upgrades.
# The original PPA uses renderSkills(server_skills), not GRIMOIRE_CATALOG
# for the player's acquired skills. If the authentic save is unavailable,
# show the exact 4+5 empty cards: lock icon, 5x 9px rank pips, grey 24px
# "НУЖЕН ГРИМУАР" button. The catalog remains the source for book art
# only after the server confirms a matching skill ID.
func _draw_skills(passive: bool) -> void:
    _section("ПАССИВНЫЕ НАВЫКИ" if passive else "АКТИВНЫЕ НАВЫКИ")
    var category := "passive" if passive else "active"
    var slot_count := 5 if passive else 4
    var verified: Array = _server_skills.get(category, []) if _server_skills_received else []
    for slot_idx in range(slot_count):
        var skill: Dictionary = {}
        if slot_idx < verified.size() and verified[slot_idx] is Dictionary:
            skill = (verified[slot_idx] as Dictionary).duplicate(true)
        _draw_source_skill_card(skill, passive)

func _source_skill_label(value: String, y: float, h: float, font_size: int, tint: Color) -> Label:
    var label := _text(value, font_size, tint)
    label.anchor_right = 1.0
    label.offset_top = y
    label.offset_bottom = y + h
    label.offset_left = 0.0
    label.offset_right = 0.0
    label.clip_text = true
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _source_skill_pip(parent: Control, rank_index: int, current_rank: int) -> void:
    # The PPA .rankPips span is exactly 9x9. A VBox/HBox child with
    # SIZE_FILL was stretching to 250px in Native 0.1.69; explicit
    # geometry avoids that completely.
    var pip := PanelContainer.new()
    pip.name = "OriginalPPARankPip"
    pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pip.position = Vector2(rank_index * 12.0, 0.0)
    pip.size = Vector2(9.0, 9.0)
    pip.custom_minimum_size = Vector2(9.0, 9.0)
    pip.add_theme_stylebox_override("panel", _style_box(
        Color("#F0A933") if rank_index < current_rank else Color("#151515"),
        Color("#F7CC6B") if rank_index < current_rank else Color("#655135"), 0, 1
    ))
    parent.add_child(pip)

func _find_canonical_skill(skill_id: String, passive: bool) -> Dictionary:
    var category := "passive" if passive else "active"
    var definition: Dictionary = ORIGINAL_GRIMOIRES.class_info(class_key)
    for raw in definition.get(category, []):
        if raw is Dictionary and str(raw.get("id", "")) == skill_id:
            return raw
    return {}

func _draw_source_skill_card(skill: Dictionary, passive: bool) -> void:
    var has_skill := not skill.is_empty() and not str(skill.get("id", "")).is_empty()
    var skill_def: Dictionary = _find_canonical_skill(str(skill.get("id", "")), passive) if has_skill else {}
    # Never show a generic catalog item as acquired. The ID must be
    # present in authenticated server data AND in the canonical class.
    has_skill = has_skill and not skill_def.is_empty()
    var rank := clampi(int(skill.get("rank", 0)), 0, 5) if has_skill else 0
    var card := PanelContainer.new()
    card.name = "OriginalPPARealSkillCard" if has_skill else "OriginalPPASkillPlaceholder"
    # Godot may auto-rename repeated siblings (@PanelContainer@N). CI and
    # runtime must identify source skill slots by metadata, not node names.
    card.set_meta("ppa_skill_slot", true)
    card.set_meta("ppa_skill_verified", has_skill)
    card.custom_minimum_size.y = 90.0
    card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    var bg := _style_box(Color("#17191B"), Color("#685235"), 7, 1)
    bg.set_content_margin_all(7.0)
    card.add_theme_stylebox_override("panel", bg)
    _page_container.add_child(card)

    var row := HBoxContainer.new()
    row.name = "OriginalPPASkillRow"
    row.custom_minimum_size.y = 76.0
    row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    row.add_theme_constant_override("separation", 8)
    card.add_child(row)

    var icon := PanelContainer.new()
    icon.name = "OriginalPPASkillIcon"
    icon.custom_minimum_size = Vector2(58.0, 76.0)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.add_theme_stylebox_override("panel", _style_box(Color("#090B0D"), Color("#715936"), 6, 1))
    row.add_child(icon)
    if has_skill:
        var image := _book_picture(str(skill_def.get("cardArt", "")), Vector2(58.0, 76.0))
        image.mouse_filter = Control.MOUSE_FILTER_IGNORE
        icon.add_child(image)
        image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        image.modulate = Color(0.74, 0.73, 0.75, 0.83) if rank == 0 else Color.WHITE
    else:
        var padlock := _text("🔒", 26, Color("#918476"))
        padlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        padlock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        icon.add_child(padlock)

    # The original .skillMain is a 76px-height grid on the right.
    # Absolute offsets prevent Godot Containers from vertically expanding
    # rank pips, text and action buttons beyond their source CSS sizes.
    var main := Control.new()
    main.name = "OriginalPPASkillMain"
    main.custom_minimum_size = Vector2(100.0, 76.0)
    main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    row.add_child(main)
    var title_text := "ПАССИВНЫЙ НАВЫК" if passive else "АКТИВНЫЙ НАВЫК"
    var subtitle := "Ожидание данных выбранного класса"
    if has_skill:
        title_text = str(skill.get("n", skill_def.get("n", title_text)))
        var preview: Array = skill.get("preview", skill_def.get("preview", []))
        var fallback_desc := str(skill_def.get("d", ""))
        var description := str(preview[mini(2, maxi(0, rank - 1))]) if not preview.is_empty() else fallback_desc
        subtitle = ("Пассивный" if passive else "Активный") + " навык"
        subtitle += (" · ранг " + ["", "I", "II", "III", "IV", "V"][rank]) if rank > 0 else " не изучен"
        subtitle += " · " + description
        subtitle += " · книги I×" + str(skill.get("book1", 0)) + " II×" + str(skill.get("book2", 0)) + " III×" + str(skill.get("book3", 0))
    main.add_child(_source_skill_label(title_text, 0.0, 13.0, 9, Color("#E4B650") if has_skill else Color("#8D8377")))
    var desc := _source_skill_label(subtitle, 14.0, 14.0, 8, Color("#9CA1A5") if has_skill else Color("#686D72"))
    main.add_child(desc)
    var rank_row := Control.new()
    rank_row.name = "OriginalPPARankPips"
    rank_row.position = Vector2(0.0, 31.0)
    rank_row.size = Vector2(57.0, 9.0)
    rank_row.custom_minimum_size = Vector2(57.0, 9.0)
    main.add_child(rank_row)
    for pip_index in range(5):
        _source_skill_pip(rank_row, pip_index, rank)

    var status := _text("закрыто", 7, Color("#777777"))
    if has_skill:
        status.text = "MAX" if rank >= 5 else ("до " + ["I","II","III","IV","V"][maxi(0, rank - 1)] + " → " + ["I","II","III","IV","V"][mini(4,rank)] + " · выбери книгу")
    status.anchor_left = 1.0
    status.anchor_right = 1.0
    status.offset_left = -132.0
    status.offset_right = 0.0
    status.offset_top = 29.0
    status.offset_bottom = 42.0
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status.autowrap_mode = TextServer.AUTOWRAP_OFF
    status.clip_text = true
    main.add_child(status)
    if has_skill:
        var rank_actions := HBoxContainer.new()
        rank_actions.name = "OriginalPPASkillRankChoices"
        rank_actions.anchor_right = 1.0
        rank_actions.offset_top = 44.0
        rank_actions.offset_bottom = 76.0
        rank_actions.add_theme_constant_override("separation", 3)
        main.add_child(rank_actions)
        for book_rank in range(1,4):
            var book_count := int(skill.get("book" + str(book_rank),0))
            var book := _button(["I","II","III"][book_rank-1] + " ×" + str(book_count) + "\n—%", 8)
            book.name = "OriginalPPABookRankChoice"
            book.custom_minimum_size.y = 30.0
            book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            # Display only; real upgrades must go through authoritative PPA.
            book.disabled = true
            book.add_theme_stylebox_override("disabled", _style_box(Color("#211A13"), Color("#89551C"), 4))
            book.add_theme_color_override("font_disabled_color", Color("#A68D69"))
            rank_actions.add_child(book)
        var click_area := Button.new()
        click_area.name = "OriginalPPASkillInspect"
        click_area.flat = true
        click_area.anchor_right = 1.0
        click_area.offset_bottom = 42.0
        click_area.mouse_filter = Control.MOUSE_FILTER_PASS
        click_area.pressed.connect(_open_grimoire_popup.bind(skill_def, passive, str(ORIGINAL_GRIMOIRES.class_info(class_key).get("name", class_key))))
        main.add_child(click_area)
    else:
        var need_book := _button("НУЖЕН ГРИМУАР", 8)
        need_book.name = "OriginalPPAEmptySkillUpgrade"
        need_book.anchor_right = 1.0
        need_book.offset_top = 44.0
        need_book.offset_bottom = 68.0
        need_book.disabled = true
        need_book.add_theme_color_override("font_disabled_color", Color("#62676B"))
        need_book.add_theme_stylebox_override("disabled", _style_box(Color("#111315"), Color("#3C4145"), 4))
        main.add_child(need_book)
    _original_skill_card_count += 1

func _book_picture(path: String, dimensions: Vector2) -> TextureRect:
    var picture := TextureRect.new()
    picture.custom_minimum_size = dimensions
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    if ResourceLoader.exists(path):
        picture.texture = load(path) as Texture2D
    return picture

func _create_book_overlay() -> void:
    _book_overlay = ColorRect.new()
    _book_overlay.name = "OriginalPPAGrimoirePopup"
    _book_overlay.color = Color(0, 0, 0, 0.73)
    _book_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _book_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _book_overlay.z_index = 20
    _book_overlay.visible = false
    _frame.add_child(_book_overlay)

    _book_dialog = PanelContainer.new()
    _book_dialog.anchor_left = 0.5
    _book_dialog.anchor_right = 0.5
    _book_dialog.anchor_top = 0.5
    _book_dialog.anchor_bottom = 0.5
    _book_dialog.offset_left = -142.5
    _book_dialog.offset_right = 142.5
    _book_dialog.offset_top = -250
    _book_dialog.offset_bottom = 250
    _book_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
    _book_dialog.add_theme_stylebox_override("panel", _style_box(Color("#1B1F22"), Color("#9A6424"), 10, 2))
    _book_overlay.add_child(_book_dialog)
    var book_margin := MarginContainer.new()
    for side in ["margin_left", "margin_right"]:
        book_margin.add_theme_constant_override(side, 9)
    for side in ["margin_top", "margin_bottom"]:
        book_margin.add_theme_constant_override(side, 9)
    _book_dialog.add_child(book_margin)
    _book_scroll = ScrollContainer.new()
    _book_scroll.name = "OriginalPPABookDetailsScroll"
    _book_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _book_scroll.scroll_deadzone = 100000
    _book_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    book_margin.add_child(_book_scroll)
    _book_container = VBoxContainer.new()
    _book_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _book_container.add_theme_constant_override("separation", 7)
    _book_scroll.add_child(_book_container)

func _open_grimoire_popup(skill: Dictionary, passive: bool, class_title: String) -> void:
    if _book_overlay == null:
        return
    for child in _book_container.get_children():
        _book_container.remove_child(child)
        child.queue_free()

    var header := HBoxContainer.new()
    _book_container.add_child(header)
    var title := _text("ГРИМУАР · " + str(skill.get("n", "")), 11, Color("#C990FF"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close := _button("✕", 15)
    close.custom_minimum_size = Vector2(26, 26)
    close.pressed.connect(func(): _book_overlay.visible = false)
    header.add_child(close)

    var hero := HBoxContainer.new()
    hero.add_theme_constant_override("separation", 8)
    _book_container.add_child(hero)
    hero.add_child(_book_picture(str(skill.get("cardArt", "")), Vector2(64, 86)))
    var textcol := VBoxContainer.new()
    textcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hero.add_child(textcol)
    textcol.add_child(_text(str(skill.get("n", "")), 11, Color("#C990FF")))
    textcol.add_child(_text(
        ("Пассивный" if passive else "Активный") + " навык · " + class_title,
        8, Color("#C990FF")
    ))
    textcol.add_child(_text("Ранг: —  / V", 8, Color("#A8A9AF")))
    textcol.add_child(_text("Гримуары: — (сервер PPA)", 8, Color("#A8A9AF")))

    var effect := PanelContainer.new()
    effect.add_theme_stylebox_override("panel", _style_box(Color("#0D0A11"), Color("#493459"), 7))
    _book_container.add_child(effect)
    var effect_col := VBoxContainer.new()
    effect.add_child(effect_col)
    effect_col.add_child(_text("РОСТ НАВЫКА ПО РАНГАМ", 9, Color("#D9B86D")))
    var previews: Array = skill.get("preview", [])
    for idx in range(mini(3, previews.size())):
        var label := PanelContainer.new()
        label.add_theme_stylebox_override("panel", _style_box(Color("#0B0C0F"), Color("#343038"), 5))
        effect_col.add_child(label)
        var name := _text("Ранг " + ["I", "II", "III"][idx] + " · " + str(previews[idx]), 8, Color("#BFB2C9"))
        label.add_child(name)
    _book_container.add_child(_text("Книга I / II / III: шанс определяется текущим рангом навыка PPA.", 8, Color("#D8C28F")))
    _book_container.add_child(_text("Ранги навыка и число книг будут показаны после синхронизации сохранения.", 8, Color("#A8A9AF")))

    var act := _button("ИЗУЧИТЬ / УЛУЧШИТЬ · НУЖНЫ ДАННЫЕ PPA", 8)
    act.disabled = true
    act.custom_minimum_size.y = 32
    act.add_theme_stylebox_override("disabled", _style_box(Color("#151219"), Color("#493459"), 5))
    _book_container.add_child(act)
    _book_overlay.visible = true
    _book_scroll.scroll_vertical = 0

func _draw_runes() -> void:
    _section("РУНЫ")
    _page_container.add_child(_text(
        "Слоты открываются каждые 10 уровней · +1 слот за перерождение",
        8, Color("#9AA0A4")
    ))
    var sockets := GridContainer.new()
    sockets.columns = 5
    sockets.add_theme_constant_override("h_separation", 6)
    sockets.add_theme_constant_override("v_separation", 6)
    _page_container.add_child(sockets)
    for i in range(10):
        var slot := _button("◇\n" + str(i + 1), 10)
        slot.custom_minimum_size = Vector2(53, 62)
        slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        slot.disabled = true
        slot.add_theme_stylebox_override("disabled", _style_box(Color("#15100D"), Color("#8B632A"), 7, 2))
        sockets.add_child(slot)
    _section("ДОСТУПНЫЕ РУНЫ")
    var inv := GridContainer.new()
    inv.columns = 4
    inv.add_theme_constant_override("h_separation", 6)
    inv.add_theme_constant_override("v_separation", 6)
    _page_container.add_child(inv)
    var rune_count := 0
    var rune_bag := _real_bag()
    for i in range(rune_bag.size()):
        var item: Dictionary = SERVER_VIEW.item_at(rune_bag, i)
        if str(item.get("kind", "")) != "rune" and str(item.get("id", "")) != "test_rune":
            continue
        rune_count += 1
        var button := _button(str(item.get("short", "ᚱ")) + "\n" + str(item.get("name", "Руна")), 10)
        button.custom_minimum_size = Vector2(58, 66)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(func(): select_item_requested.emit("bag", i))
        inv.add_child(button)
    if rune_count == 0:
        _page_container.add_child(_text("Рун пока нет. Обычные–эпические можно выбить, легендарные продаются только в Black Market.", 8))
    var info := PanelContainer.new()
    info.custom_minimum_size.y = 38
    info.add_theme_stylebox_override("panel", _style_box(Color("#13110E"), Color("#65421F"), 5))
    _page_container.add_child(info)
    var label := _text("Нажми на руну, чтобы вставить её в первый свободный слот.", 8, Color("#B48B45"))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    info.add_child(label)
