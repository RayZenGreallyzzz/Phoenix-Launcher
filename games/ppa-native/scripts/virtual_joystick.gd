extends Control

signal vector_changed(value: Vector2)
signal active_changed(active: bool)

# Native port of PPA_FLOATING_JOYSTICK_20261004.
# Gameplay input is updated at full touch rate. Only redraws are capped to ~30 Hz.
const DEAD_ZONE_PX := 8.0
const MAX_RADIUS_PX := 50.0
const BASE_RADIUS_PX := 65.0
const KNOB_RADIUS_PX := 25.0
const VISUAL_INTERVAL_MS := 33

var _touch_id := -1
var _mouse_active := false
var _active := false
var _center := Vector2.ZERO
var _value := Vector2.ZERO
var _visual_offset := Vector2.ZERO
var _last_visual_ms := 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    set_process_unhandled_input(false)
    queue_redraw()

func value() -> Vector2:
    return _value

func is_active() -> bool:
    return _active

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if _touch_id == -1 and _eligible_point(event.position):
                _touch_id = event.index
                _begin(event.position)
                get_viewport().set_input_as_handled()
        elif event.index == _touch_id:
            _touch_id = -1
            _reset()
            get_viewport().set_input_as_handled()
        return

    if event is InputEventScreenDrag:
        if event.index == _touch_id and _active:
            _update_from_point(event.position)
            get_viewport().set_input_as_handled()
        return

    # Desktop debugging keeps the same floating behavior.
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if not _mouse_active and _touch_id == -1 and _eligible_point(event.position):
                _mouse_active = true
                _begin(event.position)
                get_viewport().set_input_as_handled()
        elif _mouse_active:
            _mouse_active = false
            _reset()
            get_viewport().set_input_as_handled()
        return

    if event is InputEventMouseMotion and _mouse_active and _active:
        _update_from_point(event.position)
        get_viewport().set_input_as_handled()

func _eligible_point(point: Vector2) -> bool:
    var viewport_size := get_viewport_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return false
    # Same rule as the current PPA: movement owns one touch on the left half.
    return point.x <= viewport_size.x * 0.5

func _begin(point: Vector2) -> void:
    _active = true
    _center = point
    _value = Vector2.ZERO
    _visual_offset = Vector2.ZERO
    _last_visual_ms = 0
    active_changed.emit(true)
    vector_changed.emit(_value)
    queue_redraw()

func _update_from_point(point: Vector2) -> void:
    var raw := point - _center
    var distance := raw.length()

    if distance <= DEAD_ZONE_PX:
        _value = Vector2.ZERO
    else:
        var magnitude := (min(distance, MAX_RADIUS_PX) - DEAD_ZONE_PX) / (MAX_RADIUS_PX - DEAD_ZONE_PX)
        _value = raw / max(distance, 0.001) * magnitude

    # Input above stays full-rate. Decorative movement is limited to ~30 Hz,
    # matching the optimized web joystick.
    var now := Time.get_ticks_msec()
    if _last_visual_ms == 0 or now - _last_visual_ms >= VISUAL_INTERVAL_MS:
        _last_visual_ms = now
        _visual_offset = raw.limit_length(MAX_RADIUS_PX)
        queue_redraw()

    vector_changed.emit(_value)

func _reset() -> void:
    if not _active and _value == Vector2.ZERO:
        return
    _active = false
    _touch_id = -1
    _mouse_active = false
    _center = Vector2.ZERO
    _value = Vector2.ZERO
    _visual_offset = Vector2.ZERO
    _last_visual_ms = 0
    vector_changed.emit(_value)
    active_changed.emit(false)
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _reset()

func _draw() -> void:
    if not _active:
        return

    var local_center := _center - global_position
    var fill := Color(0.025, 0.03, 0.04, 0.42)
    var ring := Color(1.0, 0.43, 0.11, 0.58)
    var knob := Color(1.0, 0.43, 0.11, 0.84)

    draw_circle(local_center, BASE_RADIUS_PX, fill)
    draw_arc(local_center, MAX_RADIUS_PX, 0.0, TAU, 48, ring, 3.0, true)

    var knob_center := local_center + _visual_offset
    draw_circle(knob_center, KNOB_RADIUS_PX, knob)
    draw_arc(knob_center, KNOB_RADIUS_PX, 0.0, TAU, 32, Color(1, 1, 1, 0.28), 2.0, true)
