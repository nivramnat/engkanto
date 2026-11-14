extends Control
## Title screen (main scene). Continue appears only when a readable save
## exists; New Game asks for confirmation before erasing one. A corrupt or
## incompatible save hides Continue and shows a warning instead.

const WORLD_SCENE: String = "res://scenes/world/world.tscn"

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _warning: Label = %Warning
@onready var _confirm: Control = %Confirm
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	get_tree().paused = false  # in case we came from the pause menu
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_confirm_button.pressed.connect(_start_new_game)
	_cancel_button.pressed.connect(_confirm.hide)
	_refresh()


func _refresh() -> void:
	_warning.text = ""
	_continue_button.visible = false
	if not SaveManager.has_save():
		_new_game_button.grab_focus()
		return
	var summary: String = SaveManager.save_summary()
	if SaveManager.last_error != "":
		_show_bad_save(SaveManager.last_error)
		return
	_continue_button.visible = true
	_continue_button.text = "Continue — %s" % summary if summary != "" else "Continue"
	_continue_button.grab_focus()


func _show_bad_save(reason: String) -> void:
	push_warning("Title: save unusable: %s" % reason)
	SaveManager.backup_bad_save()  # kept as save_game.json.bak, not deleted
	_continue_button.visible = false
	_warning.text = "%s\nStart a New Game to continue playing." % reason
	_new_game_button.grab_focus()


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		# Became unreadable since the title opened: fall back to New Game.
		_show_bad_save(SaveManager.last_error)


func _on_new_game_pressed() -> void:
	# Only a usable save needs protecting; a corrupt one was already backed up.
	if _continue_button.visible:
		_confirm.show()
		_cancel_button.grab_focus()
	else:
		_start_new_game()


func _start_new_game() -> void:
	SaveManager.delete_save()
	GameState.new_game()
	TimeOfDay.set_time(8.0)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back at the title quits
		if _confirm.visible:
			_confirm.hide()
		else:
			get_tree().quit()
