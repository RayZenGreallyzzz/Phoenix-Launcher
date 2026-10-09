extends Control

# Cheap continuous scrolling for inventories up to 500 slots.
# Exactly ONE canvas node represents the whole grid; only visible rows draw.
# Grid data is a display-only server snapshot, never a mutation source.
const STORAGE = preload("res://scripts/ppa_storage_contract.gd")
const ORIGINAL_ITEM_ART = preload("res://scripts/ppa_item_icon_loader.gd")
const FILL := Color("#10161B")
const EDGE := Color("#695239")
const SHINE := Color("#342A22")
const PAD := 4.0
const GAP := 5.0

var storage_kind := "inventory"
var columns := 4
var capacity := 0
var _cell_size := 48.0
var _stride := 53.0
var _host: ScrollContainer
var _last_visible := Vector2i.ZERO
var _verified_items: Array = []
var _icon_cache: Dictionary = {}
var _missing_icon_cache: Dictionary = {}

func configure(kind: String, host: ScrollContainer, desired_columns: int = 4) -> void:
    storage_kind = kind
    capacity = STORAGE.capacity(kind)
    columns = maxi(1, desired_columns)
    _host = host
    name = "NpcStorageGrid_" + kind
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if not resized.is_connected(_fit_cells):
        resized.connect(_fit_cells)
    if _host != null and not _host.get_v_scroll_bar().value_changed.is_connected(_on_scroll):
        _host.get_v_scroll_bar().value_changed.connect(_on_scroll)
    _fit_cells()

func apply_items_readonly(items: Array) -> void:
    # This grid has no item actions. It only paints already authenticated
    # save data, and only the visible rows, so even 500 slots stay cheap.
    _verified_items = items.duplicate(true)
    # Only the icons of visible slots are loaded, not all 500 storage cells.
    # Cache across scrolls; discard when a new authoritative save is read.
    _icon_cache.clear()
    _missing_icon_cache.clear()
    queue_redraw()

func _approved_texture(item: Dictionary) -> Texture2D:
    # Same original PPA source as the inventory picker. Original art is
    # bundled by the Android build and never scraped from another user's data.
    var path: String = ORIGINAL_ITEM_ART.art_path(item, str(item.get("classKey", "")))
    if path.is_empty():
        return null
    var file: String = path.get_slice("?", 0)
    if not file.begins_with("/assets/") or file.contains("..") or file.contains("\\"):
        return null
    if _icon_cache.has(file):
        return _icon_cache[file] as Texture2D
    if _missing_icon_cache.has(file):
        return null
    var resource: String = "res://assets/ppa_item_icons/" + file.trim_prefix("/assets/")
    if ResourceLoader.exists(resource):
        var texture: Texture2D = load(resource) as Texture2D
        if texture != null:
            _icon_cache[file] = texture
            return texture
    _missing_icon_cache[file] = true
    return null

func _fit_cells() -> void:
    if capacity <= 0 or columns <= 0:
        return
    # No forced 500 Control nodes: the scroll container holds just this
    # custom canvas with content height proportional to total row count.
    var available := maxf(120.0, size.x if size.x > 10.0 else custom_minimum_size.x)
    var actual := clampf(floorf((available - PAD * 2.0 - float(columns - 1) * GAP) / float(columns)), 24.0, 70.0)
    if absf(actual - _cell_size) < 0.5:
        queue_redraw()
        return
    _cell_size = actual
    _stride = _cell_size + GAP
    var rows := ceili(float(capacity) / float(columns))
    var needed_h := float(rows) * _stride + PAD * 2.0
    if absf(custom_minimum_size.y - needed_h) > 0.5:
        custom_minimum_size.y = needed_h
    queue_redraw()

func _on_scroll(_value: float) -> void:
    # Redraw only the visible slice while finger-scrolling.
    queue_redraw()

func range_at(offset_y: float, viewport_height: float) -> Vector2i:
    # Exclusive end slot. A little overscan ensures no gaps at cell edges.
    if capacity <= 0:
        return Vector2i.ZERO
    var pitch := maxf(1.0, _stride)
    var first_row := maxi(0, int(floorf(offset_y / pitch)) - 1)
    var last_row := mini(ceili(float(capacity) / float(columns)),
        int(ceilf((offset_y + maxf(1.0, viewport_height)) / pitch)) + 1)
    return Vector2i(mini(capacity, first_row * columns),
        mini(capacity, maxi(first_row, last_row) * columns))

func _draw() -> void:
    if _host == null or capacity <= 0:
        return
    var visible := range_at(float(_host.scroll_vertical), _host.size.y)
    _last_visible = visible
    for index in range(visible.x, visible.y):
        var row := index / columns
        var col := index % columns
        var top_left := Vector2(PAD + float(col) * _stride, PAD + float(row) * _stride)
        var rect := Rect2(top_left, Vector2(_cell_size, _cell_size))
        draw_rect(rect, FILL, true)
        draw_rect(rect, EDGE, false, 1.2, true)
        draw_line(top_left + Vector2(3, 3),
            top_left + Vector2(_cell_size - 3, 3), SHINE, 1.0, true)
        if index < _verified_items.size() and _verified_items[index] is Dictionary:
            var item: Dictionary = _verified_items[index]
            if not item.is_empty():
                var texture: Texture2D = _approved_texture(item)
                var qty := int(item.get("qty", item.get("count", 1)))
                if texture != null:
                    var inset := maxf(3.0, _cell_size * 0.07)
                    var img_rect := Rect2(top_left + Vector2(inset, inset),
                        Vector2(_cell_size - inset * 2.0, _cell_size - inset * 2.0))
                    draw_texture_rect(texture, img_rect, false, Color.WHITE)
                else:
                    # Unknown/new original items still have a real name,
                    # never a fake image or an invisible empty black square.
                    var name_text := str(item.get("name", "Предмет")).left(8)
                    draw_string(ThemeDB.fallback_font, top_left + Vector2(4, _cell_size * 0.47),
                        name_text, HORIZONTAL_ALIGNMENT_LEFT, _cell_size - 8.0, 9, Color("#E0C68C"))
                if qty > 1:
                    var count_text := "×" + str(qty)
                    draw_string(ThemeDB.fallback_font, top_left + Vector2(4, _cell_size - 5),
                        count_text, HORIZONTAL_ALIGNMENT_RIGHT, _cell_size - 8.0, 10,
                        Color("#FFF0CB"))

func rendered_slot_count() -> int:
    return _last_visible.y - _last_visible.x
