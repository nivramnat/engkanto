extends Button
## On-screen jump button for touch devices (bottom-right, above where future
## action buttons will sit). Hidden when there's no touchscreen; the player
## connects to the built-in `pressed` signal.


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		hide()
