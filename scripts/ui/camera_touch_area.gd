extends Control
## Swipe-to-rotate region for touch devices (right half of the screen).
## Emits the per-event drag delta; the player turns it into camera rotation.
## Hidden and inactive when no touchscreen is present.

signal swiped(relative: Vector2)

var _touch_index: int = -1


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		hide()
		set_process_input(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		swiped.emit(event.relative)
		accept_event()
