extends Node
## Repro/regression harness for returning from battle to the overworld.
## Runs the real world scene, then plays three encounters back to back:
## a battle win, a run, and a guaranteed successful bind. After each it checks
## the world is still loaded, the player didn't move, and only the encountered
## creature was removed.
##   godot_console --path . res://tests/battle_flow_test.tscn

const WORLD: String = "res://scenes/world/world.tscn"
const SCENARIOS: Array[String] = ["win", "run", "caught"]

var _failures: int = 0
var _world: Node
var _last_result: String = ""


func _ready() -> void:
	# Sibling of this node (not a child) so the world pauses normally.
	_world = (load(WORLD) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_world)
	_run.call_deferred()


func _run() -> void:
	get_node("/root/TimeOfDay").day_length_seconds = 0.0  # no phase flips mid-test
	_gs().battle_finished.connect(func(r: String, _w: CreatureInstance) -> void: _last_result = r)
	await _frames(120)  # let terrain, scatter and spawners settle
	for scenario in SCENARIOS:
		await _encounter(scenario)
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _encounter(scenario: String) -> void:
	print("--- scenario: %s ---" % scenario)
	var world: Node = _world
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var wild_node: WildCreature = await _find_wild()
	if wild_node == null:
		_fail("no wild creature spawned")
		return
	var others: Array[WildCreature] = _wilds().filter(func(w: WildCreature) -> bool: return w != wild_node)
	var player_pos: Vector3 = player.global_position
	var party_before: int = _gs().party.size()

	_last_result = ""
	# Start the encounter exactly as touching the creature does.
	wild_node._on_body_entered(player)
	var battle: Node = await _find_battle()
	if battle == null:
		_fail("battle did not open")
		return
	var menu: Control = battle._action_menu
	await _wait_until(func() -> bool: return menu.visible, 10.0)

	match scenario:
		"win":
			battle.wild.current_hp = 1
			battle.player.current_hp = battle.player.max_hp()
			battle._on_fight_pressed()
			battle._on_move_pressed(0)
		"run":
			battle._on_run_pressed()
		"caught":
			# Guarantee success: full catch rate, wild at 1 HP.
			var data: Creature = battle.wild.data.duplicate()
			data.catch_rate = 255
			battle.wild.data = data
			battle.wild.current_hp = 0  # hp_ratio 0 -> chance = 1.0
			battle._on_bind_pressed()

	var battle_ref: WeakRef = weakref(battle)
	battle = null
	var closed: bool = await _wait_until(func() -> bool: return battle_ref.get_ref() == null and not get_tree().paused, 20.0)
	if not closed:
		_fail("battle never closed")
		return
	var return_pos: Vector3 = player.global_position
	await _frames(30)

	if _last_result != scenario:
		_fail("expected result %s, got '%s'" % [scenario, _last_result])
	if not is_instance_valid(world) or not world.is_inside_tree():
		_fail("overworld scene was lost")
		return
	if not is_instance_valid(player):
		_fail("player was freed")
		return
	if return_pos.distance_to(player_pos) > 0.05:
		_fail("player moved from %s to %s" % [player_pos, return_pos])
	if scenario == "run":
		if not is_instance_valid(wild_node):
			_fail("creature was removed after running away")
		else:
			wild_node._on_body_entered(player)  # still touching: cooldown must block it
			if _gs().is_in_battle():
				_fail("creature re-triggered a battle immediately after running")
				return
			await _frames(180)  # let the cooldown expire before the next scenario
	elif is_instance_valid(wild_node):
		_fail("defeated/caught creature is still in the world")
	for o in others:
		if not is_instance_valid(o):
			_fail("an unrelated wild creature was removed")
			break
	if scenario == "caught" and _gs().party.size() + _gs().storage.size() != party_before + 1:
		_fail("caught creature was not added to party/storage")
	if _gs().is_in_battle():
		_fail("GameState still thinks a battle is running")
	print("scenario %s finished" % scenario)


func _wilds() -> Array[WildCreature]:
	var out: Array[WildCreature] = []
	for n in _all(get_tree().root):
		if n is WildCreature:
			out.append(n)
	return out


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _find_wild() -> WildCreature:
	for i in 600:
		var w: Array[WildCreature] = _wilds()
		if not w.is_empty():
			return w[0]
		await get_tree().process_frame
	return null


func _find_battle() -> Node:
	for i in 60:
		for c in get_tree().root.get_children():
			if c.has_signal("finished") and c.has_method("setup"):
				return c
		await get_tree().process_frame
	return null


func _wait_until(cond: Callable, timeout: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fail(msg: String) -> void:
	_failures += 1
	push_error("FAIL: " + msg)


func _gs() -> Node:
	return get_node("/root/GameState")
