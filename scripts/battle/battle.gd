extends CanvasLayer
## Turn-based battle. Shown as an overlay over the paused overworld. Player
## chooses Fight (one of up to 4 moves) or Run; the wild creature picks a random
## move. Turn order is by speed. Ends when a side faints or the player runs.

signal finished(result: String)  # "win", "lose", or "run"

const MESSAGE_TIME: float = 0.7

var player: CreatureInstance
var wild: CreatureInstance
var _busy: bool = false

@onready var _wild_name: Label = %WildName
@onready var _wild_hp: ProgressBar = %WildHP
@onready var _wild_hp_label: Label = %WildHPLabel
@onready var _wild_token: ColorRect = %WildToken
@onready var _player_name: Label = %PlayerName
@onready var _player_hp: ProgressBar = %PlayerHP
@onready var _player_hp_label: Label = %PlayerHPLabel
@onready var _player_token: ColorRect = %PlayerToken
@onready var _message: Label = %Message
@onready var _action_menu: Control = %ActionMenu
@onready var _move_menu: Control = %MoveMenu
@onready var _fight_button: Button = %FightButton
@onready var _run_button: Button = %RunButton
@onready var _back_button: Button = %BackButton

var _move_buttons: Array[Button] = []


func _ready() -> void:
	_move_buttons = [%Move0, %Move1, %Move2, %Move3]
	_fight_button.pressed.connect(_on_fight_pressed)
	_run_button.pressed.connect(_on_run_pressed)
	_back_button.pressed.connect(_show_action_menu)
	for i in _move_buttons.size():
		_move_buttons[i].pressed.connect(_on_move_pressed.bind(i))
	_action_menu.hide()
	_move_menu.hide()


func setup(p_player: CreatureInstance, p_wild: CreatureInstance) -> void:
	player = p_player
	wild = p_wild
	_wild_token.color = GameTypes.element_color(wild.data.element_type)
	_player_token.color = GameTypes.element_color(player.data.element_type)
	_refresh()
	_start()


func _start() -> void:
	_busy = true
	await _say("A wild %s (Lv %d) appeared!" % [wild.display_name(), wild.level])
	await _say("Go, %s!" % player.display_name())
	_busy = false
	_show_action_menu()


func _refresh() -> void:
	_wild_name.text = "%s  Lv %d" % [wild.display_name(), wild.level]
	_wild_hp.max_value = wild.max_hp()
	_wild_hp.value = wild.current_hp
	_wild_hp_label.text = "%d / %d" % [wild.current_hp, wild.max_hp()]
	_player_name.text = "%s  Lv %d" % [player.display_name(), player.level]
	_player_hp.max_value = player.max_hp()
	_player_hp.value = player.current_hp
	_player_hp_label.text = "%d / %d" % [player.current_hp, player.max_hp()]


func _show_action_menu() -> void:
	_move_menu.hide()
	_action_menu.show()
	_message.text = "What will %s do?" % player.display_name()


func _show_move_menu() -> void:
	_action_menu.hide()
	var moves: Array[Move] = player.data.moves
	for i in _move_buttons.size():
		var b: Button = _move_buttons[i]
		if i < moves.size() and moves[i] != null:
			b.text = moves[i].name
			b.visible = true
		else:
			b.visible = false
	_move_menu.show()


func _on_fight_pressed() -> void:
	if _busy:
		return
	_show_move_menu()


func _on_run_pressed() -> void:
	if _busy:
		return
	_busy = true
	_action_menu.hide()
	await _say("Got away safely!")
	finished.emit("run")


func _on_move_pressed(index: int) -> void:
	if _busy:
		return
	var moves: Array[Move] = player.data.moves
	if index >= moves.size() or moves[index] == null:
		return
	_busy = true
	_move_menu.hide()
	await _run_round(moves[index])
	_busy = false


func _run_round(player_move: Move) -> void:
	var enemy_move: Move = _enemy_move()
	# Turn order by speed; player wins ties.
	if player.speed() >= wild.speed():
		await _do_attack(player, wild, player_move)
		if await _check_end():
			return
		await _do_attack(wild, player, enemy_move)
	else:
		await _do_attack(wild, player, enemy_move)
		if await _check_end():
			return
		await _do_attack(player, wild, player_move)
	if await _check_end():
		return
	_show_action_menu()


func _do_attack(attacker: CreatureInstance, defender: CreatureInstance, move: Move) -> void:
	if move == null:
		return
	await _say("%s used %s!" % [attacker.display_name(), move.name])
	if randi_range(1, 100) > move.accuracy:
		await _say("%s's attack missed!" % attacker.display_name())
		return
	var mult: float = GameTypes.type_multiplier(move.element_type, defender.data.element_type)
	defender.take_damage(_damage(attacker, defender, move, mult))
	_refresh()
	if mult > 1.0:
		await _say("It's super effective!")
	elif mult < 1.0:
		await _say("It's not very effective...")
	else:
		await _pause()


func _damage(attacker: CreatureInstance, defender: CreatureInstance, move: Move, mult: float) -> int:
	var raw: float = float(move.power) * float(attacker.attack()) / float(maxi(1, defender.defense()))
	var dmg: float = raw * 0.5 * mult * randf_range(0.85, 1.0)
	return maxi(1, int(round(dmg)))


func _check_end() -> bool:
	if wild.is_fainted():
		await _say("%s fainted!" % wild.display_name())
		await _say("You won the battle!")
		finished.emit("win")
		return true
	if player.is_fainted():
		await _say("%s fainted!" % player.display_name())
		await _say("You have no creatures left...")
		finished.emit("lose")
		return true
	return false


func _enemy_move() -> Move:
	var moves: Array = wild.data.moves.filter(func(m: Move) -> bool: return m != null)
	if moves.is_empty():
		return null
	return moves[randi() % moves.size()]


func _say(text: String) -> void:
	_message.text = text
	await get_tree().create_timer(MESSAGE_TIME, true).timeout


func _pause() -> void:
	await get_tree().create_timer(MESSAGE_TIME * 0.5, true).timeout
