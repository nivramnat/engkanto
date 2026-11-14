extends Control
## Pause menu: Resume, Save (manual save) and Quit to Title. Pauses the tree
## while open and keeps processing itself (process_mode ALWAYS). Opened by the
## HUD's Pause button (touch/mouse), the `pause` action (Esc on PC) or the
## Android back button.

signal closed

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %SaveButton
@onready var _title_button: Button = %TitleButton
@onready var _status: Label = %Status


func _ready() -> void:
	_resume_button.pressed.connect(close)
	_save_button.pressed.connect(_on_save_pressed)
	_title_button.pressed.connect(_on_title_pressed)
	hide()


func open() -> void:
	if GameState.is_in_battle():
		return
	_status.text = ""
	show()
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _on_save_pressed() -> void:
	if SaveManager.save_game():
		_status.text = "Game saved."
	else:
		_status.text = "Couldn't save the game!"


func _on_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
