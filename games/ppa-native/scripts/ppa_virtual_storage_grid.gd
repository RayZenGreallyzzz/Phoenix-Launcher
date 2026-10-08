extends Control

# Cheap continuous scrolling for inventories up to 500 slots.
# Exactly ONE canvas node represents the whole grid; only visible rows draw.
# Grid data is a display-only server snapshot, never a mutation source.
const STORAGE = preload("res://scripts/ppa_storage_contract.gd")
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

func rendered_slot_count() -> int:
    return _last_visible.y - _last_visible.x
