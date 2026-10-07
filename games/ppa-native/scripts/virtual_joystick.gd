extends Control

signal vector_changed(value: Vector2)

@export var radius: float = 82.0
@export var knob_radius: float = 34.0

var _touch_id := -1
var _mouse_active := false
var _value := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    queue_redraw()

func value() -> Vector2:
    return _value

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if _touch_id == -1 and get_global_rect().has_point(event.position):
                _touch_id = event.index
                _set_from_global(event.position)
                get_viewport().set_input_as_handled()
        elif event.index == _touch_id:
            _touch_id = -1
            _set_value(Vector2.ZERO)
            get_viewport().set_input_as_handled()
        return

    if event is InputEventScreenDrag and event.index == _touch_id:
        _set_from_global(event.position)
        get_viewport().set_input_as_handled()
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and get_global_rect().has_point(event.position):
            _mouse_active = true
            _set_from_global(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and _mouse_active:
            _mouse_active = false
            _set_value(Vector2.ZERO)
            get_viewport().set_input_as_handled()
        return

    if event is InputEventMouseMotion and _mouse_active:
        _set_from_global(event.position)
        get_viewport().set_input_as_handled()

func _set_from_global(point: Vector2) -> void:
    var center := get_global_rect().position + size * 0.5
    var delta := point - center
    if delta.length() > radius:
        delta = delta.normalized() * radius
    _set_value(delta / radius)

func _set_value(next_value: Vector2) -> void:
    if next_value.length() < 0.08:
        next_value = Vector2.ZERO
    _value = next_value
    vector_changed.emit(_value)
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var ring := Color(1.0, 0.43, 0.11, 0.58)
    var fill := Color(0.03, 0.035, 0.045, 0.42)
    var knob := Color(1.0, 0.43, 0.11, 0.82)

    draw_circle(center, radius + 10.0, fill)
    draw_arc(center, radius, 0.0, TAU, 64, ring, 3.0, true)
    draw_circle(center + _value * radius, knob_radius, knob)
    draw_arc(center + _value * radius, knob_radius, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 2.0, true)
