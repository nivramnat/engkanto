extends CanvasLayer
## Overworld HUD: a menu button (works for touch and mouse) and the Tab key on
## PC both toggle the party screen. Inert during battle (the tree is paused).

@onready var _menu_button: Button = %MenuButton
@onready var _party_screen: Control = %PartyScreen


func _ready() -> void:
	_menu_button.pressed.connect(_toggle)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_toggle()


func _toggle() -> void:
	if _party_screen.visible:
		_party_screen.close()
	else:
		_party_screen.open()
