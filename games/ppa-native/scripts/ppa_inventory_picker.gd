extends VBoxContainer
signal item_chosen(key: String)

const SLOT_COUNT := 100
const PPA_ITEM_ICONS = preload("res://scripts/ppa_item_icon_loader.gd")
var _icon_loader: Node
const GEAR := ["weapon", "helmet", "armor", "gloves", "legs", "boots", "ring", "necklace", "pants", "shield", "amulet"]
const MATERIAL := ["stone", "sharpening", "upgrade_stone", "enhancement", "sharpening_stone"]
var entries: Dictionary = {}
var equipment: Dictionary = {}
var mode := "all"
var selected := ""
var grid: GridContainer
var scroller: ScrollContainer

func _ready() -> void:
    if _icon_loader == null:
        _icon_loader = PPA_ITEM_ICONS.new()
        _icon_loader.name = "PPAOriginalNpcPickerIconLoader"
        add_child(_icon_loader)

func configure(items: Array, worn: Dictionary, category: String, selected_key: String) -> void:
    entries.clear()
    equipment = worn.duplicate(true)
    mode = category
    selected = selected_key
    for i in range(items.size()):
        var item = items[i]
        if not (item is Dictionary) or str(item.get("id", "")).is_empty():
            continue
        var slot := int(item.get("slot", i))
        if slot >= 0 and slot < SLOT_COUNT:
            entries[slot] = item
    _draw_content()

func eligible(item: Dictionary) -> bool:
    if item.is_empty():
        return false
    var kind := str(item.get("kind", "")).to_lower()
    match mode:
        "sell": return not bool(item.get("bound", false)) and bool(item.get("tradeable", true))
        "equipment": return GEAR.has(kind)
        "stone": return MATERIAL.has(kind) or "заточ" in str(item.get("name", "")).to_lower()
        "rune": return kind == "rune"
        _: return true

func item_for(key: String) -> Dictionary:
    if key.begins_with("bag:"):
        return entries.get(int(key.trim_prefix("bag:")), {})
    if key.begins_with("equip:"):
        return equipment.get(key.trim_prefix("equip:"), {})
    return {}

func _slot(item: Dictionary, key: String, index_label: String) -> Button:
    var b := Button.new()
    b.name = "PickSlot_" + key.replace(":", "_")
    var valid := eligible(item)
    b.disabled = not valid
    b.text = index_label if item.is_empty() else str(item.get("short", "◆")).substr(0, 3) + ("\n×" + str(item.get("qty", 1)) if int(item.get("qty", 1)) > 1 else "")
    b.tooltip_text = str(item.get("name", "Пустая ячейка"))
    b.custom_minimum_size = Vector2(50, 50)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size", 10)
    var box := StyleBoxFlat.new()
    box.bg_color = Color("#2D2A1E") if key == selected else Color("#11181F")
    box.border_color = Color("#EAB65F") if key == selected else Color("#735438")
    box.set_border_width_all(1)
    box.set_corner_radius_all(5)
    b.add_theme_stylebox_override("normal", box)
    b.add_theme_stylebox_override("disabled", box)
    b.add_theme_color_override("font_disabled_color", Color("#777C7C"))
    if valid:
        b.pressed.connect(func(): item_chosen.emit(key))
    # Reuse the exact same approved asset resolver as the hero's bag.
    # No screenshots, demo inventory or extra per-slot network service.
    if _icon_loader != null and not item.is_empty():
        _icon_loader.bind_button(item, str(item.get("classKey", "")), b)
    return b

func _draw_content() -> void:
    for old in get_children():
        remove_child(old)
        old.queue_free()
    name = "NpcInventoryPicker"
    add_theme_constant_override("separation", 7)
    scroller = ScrollContainer.new()
    scroller.name = "NpcItemChoiceScroll"
    scroller.custom_minimum_size.y = 255
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(scroller)
    grid = GridContainer.new()
    grid.name = "NpcItemChoiceGrid"
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    scroller.add_child(grid)
    for i in range(SLOT_COUNT):
        var item: Dictionary = entries.get(i, {})
        grid.add_child(_slot(item, "bag:" + str(i), "%02d" % (i + 1)))
    if mode == "equipment":
        var row := HFlowContainer.new()
        row.name = "NpcEquippedItemChoices"
        add_child(row)
        for key in GEAR:
            var item: Dictionary = equipment.get(key, {})
            if not item.is_empty():
                row.add_child(_slot(item, "equip:" + key, str(item.get("short", "◆"))))
