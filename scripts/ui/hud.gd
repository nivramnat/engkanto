extends CanvasLayer
## Overworld HUD: Party and Pause buttons (touch and mouse), plus Tab (party)
## and Esc (`pause` action) on PC and the back button on Android. Inert during
## battle (the tree is paused); the pause menu handles its own closing.

@onready var _menu_button: Button = %MenuButton
@onready var _pause_button: Button = %PauseButton
@onready var _party_screen: Control = %PartyScreen
@onready var _pause_menu: Control = %PauseMenu


func _ready() -> void:
	_menu_button.pressed.connect(_toggle)
	_pause_button.pressed.connect(_pause_menu.open)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_toggle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause_menu.open()


func _notification(what: int) -> void:
	# Android back button (quit_on_go_back is off): toggle the pause menu.
	# Delivered even while paused, so this node handles both directions.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _pause_menu.visible:
			_pause_menu.close()
		else:
			_pause_menu.open()


func _toggle() -> void:
	if _party_screen.visible:
		_party_screen.close()
	else:
		_party_screen.open()
