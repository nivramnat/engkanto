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
@onready var _bind_button: Button = %BindButton
@onready var _run_button: Button = %RunButton
@onready var _back_button: Button = %BackButton
@onready var _amulet: ColorRect = %Amulet

var _move_buttons: Array[Button] = []


func _ready() -> void:
	_move_buttons = [%Move0, %Move1, %Move2, %Move3]
	_fight_button.pressed.connect(_on_fight_pressed)
	_bind_button.pressed.connect(_on_bind_pressed)
	_run_button.pressed.connect(_on_run_pressed)
	_back_button.pressed.connect(_show_action_menu)
	for i in _move_buttons.size():
		_move_buttons[i].pressed.connect(_on_move_pressed.bind(i))
	_action_menu.hide()
	_move_menu.hide()
	_amulet.hide()


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
	var antings: int = GameState.item_count(GameState.ANTING_ANTING)
	_bind_button.text = "Bind (%d)" % antings
	_bind_button.disabled = antings <= 0
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


func _on_bind_pressed() -> void:
	if _busy or GameState.item_count(GameState.ANTING_ANTING) <= 0:
		return
	_busy = true
	_action_menu.hide()
	await _attempt_bind()
	_busy = false


func _attempt_bind() -> void:
	GameState.use_item(GameState.ANTING_ANTING)
	await _say("You hurl an anting-anting at %s!" % wild.display_name())

	# catch_rate is on a 0-255 scale; weaker targets are easier to bind.
	var ritual_bonus: float = 1.0  # folklore rituals will adjust this later
	var hp_ratio: float = float(wild.current_hp) / float(maxi(1, wild.max_hp()))
	var chance: float = clampf((wild.data.catch_rate / 255.0) * (1.0 - hp_ratio) * ritual_bonus, 0.0, 1.0)
	var success: bool = randf() < chance
	var shakes: int = 3 if success else randi_range(1, 3)
	await _play_bind_animation(shakes)

	if success:
		wild.full_heal()
		var where: String = GameState.capture(wild)
		await _say("Gotcha! %s was bound!" % wild.display_name())
		if where == "storage":
			await _say("Your party is full — %s was sent to the Albularyo's Hut." % wild.display_name())
		finished.emit("caught")
		return

	await _say("Aww! It broke free!")
	await _do_attack(wild, player, _enemy_move())
	if await _check_end():
		return
	_show_action_menu()


func _play_bind_animation(shakes: int) -> void:
	_amulet.pivot_offset = _amulet.size * 0.5
	_amulet.rotation = 0.0
	_amulet.show()
	for i in shakes:
		var t := create_tween()
		# Shake...
		t.tween_property(_amulet, "rotation", deg_to_rad(18.0), 0.08)
		t.tween_property(_amulet, "rotation", deg_to_rad(-18.0), 0.16)
		t.tween_property(_amulet, "rotation", 0.0, 0.08)
		# ...while glowing (runs alongside the shake).
		t.parallel().tween_property(_amulet, "modulate", Color(1.4, 1.3, 0.7), 0.16)
		t.parallel().tween_property(_amulet, "modulate", Color(1.0, 1.0, 1.0), 0.16).set_delay(0.16)
		await t.finished
		await get_tree().create_timer(0.12, true).timeout
	_amulet.hide()
	_amulet.rotation = 0.0


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
