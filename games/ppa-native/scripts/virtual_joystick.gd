extends Control

# Passive visual for the PPA floating joystick.
# Input ownership lives in native_world.gd so Android touch delivery cannot be
# blocked by Control mouse filters or GUI routing.
const BASE_RADIUS_PX := 65.0
const MAX_RADIUS_PX := 50.0
const KNOB_RADIUS_PX := 25.0

var _active := false
var _center := Vector2.ZERO
var _offset := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = false
    queue_redraw()

func begin_at(screen_position: Vector2) -> void:
    _active = true
    _center = screen_position
    _offset = Vector2.ZERO
    queue_redraw()

func set_offset(screen_offset: Vector2) -> void:
    _offset = screen_offset.limit_length(MAX_RADIUS_PX)
    queue_redraw()

func end() -> void:
    _active = false
    _center = Vector2.ZERO
    _offset = Vector2.ZERO
    queue_redraw()

func _draw() -> void:
    if not _active:
        return

    var local_center := _center - global_position
    var fill := Color(0.025, 0.03, 0.04, 0.42)
    var ring := Color(1.0, 0.43, 0.11, 0.62)
    var knob := Color(1.0, 0.43, 0.11, 0.86)

    draw_circle(local_center, BASE_RADIUS_PX, fill)
    draw_arc(local_center, MAX_RADIUS_PX, 0.0, TAU, 48, ring, 3.0, true)

    var knob_center := local_center + _offset
    draw_circle(knob_center, KNOB_RADIUS_PX, knob)
    draw_arc(knob_center, KNOB_RADIUS_PX, 0.0, TAU, 32, Color(1, 1, 1, 0.30), 2.0, true)
