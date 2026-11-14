extends CanvasLayer
## Overworld HUD: Party and Pause buttons (touch and mouse), plus Tab (party)
## and Esc (`pause` action) on PC and the back button on Android. Inert during
## battle (the tree is paused); the pause menu and hut screen handle their own
## closing.
##
## Near the Albularyo's Hut (set_hut_in_range, wired from the hut's signal in
## the world scene) an Enter button appears: tap/click it, or press `interact`.

@onready var _menu_button: Button = %MenuButton
@onready var _pause_button: Button = %PauseButton
@onready var _enter_button: Button = %EnterButton
@onready var _party_screen: Control = %PartyScreen
@onready var _hut_screen: Control = %HutScreen
@onready var _pause_menu: Control = %PauseMenu


func _ready() -> void:
	_menu_button.pressed.connect(_toggle)
	_pause_button.pressed.connect(_pause_menu.open)
	_enter_button.pressed.connect(enter_hut)
	if not OS.has_feature("mobile"):
		_enter_button.text += "  [E]"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_toggle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause_menu.open()
	elif event.is_action_pressed("interact") and _enter_button.visible:
		get_viewport().set_input_as_handled()
		enter_hut()


func _notification(what: int) -> void:
	# Android back button (quit_on_go_back is off): close the hut screen, or
	# toggle the pause menu. Delivered even while paused.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _hut_screen.visible:
			_hut_screen.close()
		elif _pause_menu.visible:
			_pause_menu.close()
		else:
			_pause_menu.open()


## Show or hide the Enter prompt as the player nears or leaves the hut door.
func set_hut_in_range(in_range: bool) -> void:
	_enter_button.visible = in_range


func enter_hut() -> void:
	if not _enter_button.visible or GameState.is_in_battle() or get_tree().paused:
		return
	if _party_screen.visible:
		_party_screen.close()
	_hut_screen.open()


func _toggle() -> void:
	if _party_screen.visible:
		_party_screen.close()
	else:
		_party_screen.open()
