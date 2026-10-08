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
var _touch_origin := Vector2.ZERO
var _touch_tracking := false

func configure(profile: Dictionary, hero: String, shared_stash: RefCounted) -> void:
    account = profile.duplicate(true)
    class_key = hero
    stash = shared_stash
    if is_node_ready():
        _draw_page()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mono = SystemFont.new()
    _mono.font_names = PackedStringArray(["monospace", "Courier New"])
    _create_frame()
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
        _frame.add_child(line)
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
    visible = true
    _fit_to_viewport()
    _draw_page()
    if _scroll != null:
        _scroll.set_deferred("scroll_vertical", 0)

func is_open() -> bool:
    return visible

func _input(event: InputEvent) -> void:
    if not visible or _frame == null:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _touch_origin = touch.position
            _touch_tracking = _frame.get_global_rect().has_point(touch.position)
        elif _touch_tracking:
            _swipe(touch.position)
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT:
            if mouse.pressed:
                _touch_origin = mouse.position
                _touch_tracking = _frame.get_global_rect().has_point(mouse.position)
            elif _touch_tracking:
                _swipe(mouse.position)

func _dot_input(event: InputEvent, index: int) -> void:
    if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
        open_index(index)
        accept_event()
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
            open_index(index)
            accept_event()

func _swipe(finish: Vector2) -> void:
    _touch_tracking = false
    var delta := finish - _touch_origin
    if absf(delta.x) > 38.0 and absf(delta.x) > absf(delta.y) * 1.15:
        open_index(_page + (1 if delta.x < 0.0 else -1))

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
    var equipped: Dictionary = stash.equipment.get(kind, {})
    var filled := not equipped.is_empty()
    var b := _button(name + "\n" + (str(equipped.get("name", "")) if filled else "свободно"), 7)
    b.custom_minimum_size = Vector2(w, h)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_color_override("font_color", Color("#C9A565"))
    b.add_theme_stylebox_override("normal", _style_box(
        Color("#0C0F12"), RARITIES.get(str(equipped.get("rarity", "common")), Color("#A26620")) if filled else Color("#A26620"), 6, 1
    ))
    b.pressed.connect(func(): unequip_requested.emit(kind))
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
    cosmetics.add_theme_constant_override("separation", 4)
    _page_container.add_child(cosmetics)
    for e in COSMETICS:
        cosmetics.add_child(_slot(str(e[1]), str(e[0]), 72, 48))

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
    var count := _text(str(stash.bag.size()) + " предм.", 7, MUTED)
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
    for i in range(100):
        var slot := _button("", 8)
        slot.custom_minimum_size = Vector2(cell_side, cell_side)
        slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var unlocked := i < 50
        var item: Dictionary = stash.bag[i] if i < stash.bag.size() else {}
        var locked := not unlocked and item.is_empty()
        slot.disabled = locked
        slot.modulate.a = 1.0 if not locked else 0.40
        var edge := Color("#5D431F") if unlocked else Color("#282A2B")
        if not item.is_empty():
            edge = RARITIES.get(str(item.get("rarity", "common")), edge)
            slot.text = str(item.get("short", "◆")) + "\n×" + str(item.get("qty", 1))
        var slot_style := _style_box(Color("#0B0E11"), edge, 4)
        slot.add_theme_stylebox_override("normal", slot_style)
        # Without this override, Godot draws the 50 disabled, locked
        # inventory slots as fully transparent. The entire bottom half
        # looks like an empty broken scroll page in the user's 0.1.60 video.
        slot.add_theme_stylebox_override("disabled", slot_style)
        slot.pressed.connect(func(): select_item_requested.emit("bag", i))
        grid.add_child(slot)
    var info := PanelContainer.new()
    info.custom_minimum_size.y = 35
    info.add_theme_stylebox_override("panel", _style_box(Color("#0D1013"), Color("#303238"), 5))
    _page_container.add_child(info)
    var hint := _text("Тапни предмет, чтобы посмотреть или надеть.", 8, MUTED)
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
    block.add_child(_text("Уровень —                                    — / — XP", 9, Color("#A9AFB4")))
    var xp := ProgressBar.new()
    xp.custom_minimum_size.y = 9
    xp.show_percentage = false
    xp.value = 0
    block.add_child(xp)
    _page_container.add_child(_text("Перерождений: —             доступно с 30 ур.", 9, Color("#A9AFB4")))
    var actions := HBoxContainer.new()
    _page_container.add_child(actions)
    for label in ["СБРОС ХАРАКТЕРИСТИК", "ПЕРЕРОЖДЕНИЕ · 30 УР."]:
        var b := _button(label, 8)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.custom_minimum_size.y = 34
        b.disabled = true
        actions.add_child(b)
    _page_container.add_child(_text("Очки характеристик: —", 9, Color("#F0BB51")))
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
        var value := _text("—", 10, Color("#E6E6E6"))
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

func _draw_skills(passive: bool) -> void:
    # From actual PPA charFrame.makeSkillPlaceholder()/renderSkills:
    # Four active + five passive cards, 58×76 icons and their exact empty texts.
    # A single explanation line is NOT equivalent to the real menu.
    _section("ПАССИВНЫЕ НАВЫКИ" if passive else "АКТИВНЫЕ НАВЫКИ")
    var count := 5 if passive else 4
    for index in range(count):
        var card := PanelContainer.new()
        card.custom_minimum_size.y = 82
        card.add_theme_stylebox_override("panel", _style_box(Color("#17191B"), Color("#685235"), 7))
        _page_container.add_child(card)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        card.add_child(row)

        var icon := PanelContainer.new()
        icon.custom_minimum_size = Vector2(58, 76)
        icon.add_theme_stylebox_override("panel", _style_box(Color("#121416"), Color("#715936"), 6))
        row.add_child(icon)
        var lock := _text("🔒", 17, Color("#918476"))
        lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        icon.add_child(lock)

        var content := VBoxContainer.new()
        content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.add_theme_constant_override("separation", 4)
        row.add_child(content)
        content.add_child(_text("ПАССИВНЫЙ НАВЫК" if passive else "АКТИВНЫЙ НАВЫК", 9, Color("#8D8377")))
        content.add_child(_text("Ожидание данных выбранного класса", 8, Color("#686D72")))
        var meta := HBoxContainer.new()
        meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content.add_child(meta)
        var pips := HBoxContainer.new()
        pips.add_theme_constant_override("separation", 3)
        meta.add_child(pips)
        for rank in range(5):
            var pip := PanelContainer.new()
            pip.custom_minimum_size = Vector2(9, 9)
            pip.add_theme_stylebox_override("panel", _style_box(Color("#151515"), Color("#655135"), 0))
            pips.add_child(pip)
        var flex := Control.new()
        flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        meta.add_child(flex)
        meta.add_child(_text("закрыто", 7, Color("#777777")))
        var upgrade := _button("НУЖЕН ГРИМУАР", 8)
        upgrade.disabled = true
        upgrade.custom_minimum_size.y = 24
        upgrade.add_theme_stylebox_override("disabled", _style_box(Color("#111315"), Color("#3C4145"), 4))
        content.add_child(upgrade)

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
    for i in range(stash.bag.size()):
        var item: Dictionary = stash.bag[i]
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
