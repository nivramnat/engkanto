extends Control
## Dynamic on-screen virtual joystick for touch devices.
##
## Appears where the player first touches within this control's rect and
## emits a direction in roughly [-1, 1] per axis (screen-up is -Y, matching
## the move input convention). Hidden and inactive when no touchscreen.

signal direction_changed(direction: Vector2)

@export var radius: float = 120.0
@export var knob_radius: float = 48.0

var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		hide()
		set_process_input(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_active = true
			_touch_index = event.index
			_center = event.position
			_knob = event.position
			_emit()
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_knob = event.position
		_emit()
		accept_event()


func _emit() -> void:
	var offset: Vector2 = (_knob - _center).limit_length(radius)
	_knob = _center + offset
	direction_changed.emit(offset / radius)
	queue_redraw()


func _release() -> void:
	_active = false
	_touch_index = -1
	direction_changed.emit(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	draw_circle(_center, radius, Color(1.0, 1.0, 1.0, 0.15))
	draw_circle(_knob, knob_radius, Color(1.0, 1.0, 1.0, 0.35))
