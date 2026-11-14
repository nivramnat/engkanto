extends Node
## Albularyo's Hut end-to-end test, run as two processes so save/load is real:
##   godot_console --path . res://tests/hut_test.tscn -- --phase=save
##   godot_console --path . res://tests/hut_test.tscn -- --phase=load
## Covers the Enter prompt, moving creatures both ways (Move button and a
## simulated mouse drag), the last-creature and full-party blocks, Heal All,
## and autosave on close. Uses its own save file, never the real one.

const WORLD: String = "res://scenes/world/world.tscn"
const SAVE: String = "user://test_hut_save.json"
const EXPECTED: String = "user://test_hut_expected.json"
const KAPRE: String = "res://data/creatures/kapre.tres"
const TIYANAK: String = "res://data/creatures/tiyanak.tres"

var _failures: int = 0


func _ready() -> void:
	SaveManager.save_path = SAVE
	var phase: String = "save"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.trim_prefix("--phase=")
	(_phase_save if phase == "save" else _phase_load).call_deferred()


func _phase_save() -> void:
	SaveManager.delete_save()
	GameState.new_game()
	var world: Node = (load(WORLD) as PackedScene).instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await _frames(120)

	var hut: Node3D = world.get_node("AlbularyoHut")
	var terrain: Node = world.get_node("Terrain")
	var ground: float = terrain.get_data().get_height(hut.global_position)
	_check(absf(hut.global_position.y - ground) < 1.5, "hut sits on the terrain (y %.2f, ground %.2f)" % [hut.global_position.y, ground])
	_check(BiomeMap.dominant(hut.global_position.x, hut.global_position.z) == BiomeMap.Biome.LOWLANDS, "hut is in the Baryo Lowlands")
	var balete: Node3D = world.get_node("BaleteTree")
	_check(hut.global_position.distance_to(balete.global_position) < 40.0, "hut is near the balete tree")
	var trees_inside: int = 0
	for n in world.get_node("ChunkScatter").find_children("*", "StaticBody3D", true, false):
		var p: Vector3 = (n as Node3D).global_position
		if Vector2(p.x, p.z).distance_to(Vector2(hut.global_position.x, hut.global_position.z)) < hut.clear_radius:
			trees_inside += 1
	_check(trees_inside == 0, "no scattered trees grow through the hut")

	# Walk up to the door: the Enter prompt appears.
	var hud: Node = world.get_node("HUD")
	var enter: Button = hud.get_node("%EnterButton")
	var screen: Control = hud.get_node("%HutScreen")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	_check(not enter.visible, "no Enter prompt away from the hut")
	var door: Vector3 = hut.global_transform * Vector3(0, 0, 4)
	player.global_position = Vector3(door.x, terrain.get_data().get_height(door) + 1.0, door.z)
	await _wait(func() -> bool: return enter.visible, 5.0)
	_check(enter.visible, "Enter prompt shows at the hut door")

	# Interact key opens the screen and pauses the world.
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)
	_check(screen.visible and get_tree().paused, "interact opens the hut screen and pauses")

	# Last party creature can't be stored (button, and drop).
	var starter: CreatureInstance = GameState.party[0]
	_check(screen.get_node("%MoveButton").disabled, "Move button disabled for the last creature")
	_check(screen.get_node("%MoveHint").text.contains("last"), "hint explains the last-creature rule")
	_check(not screen.try_move(starter), "try_move refuses the last party creature")
	screen._drop(Vector2.ZERO, {"hut_creature": starter}, "storage")
	_check(GameState.party.size() == 1 and GameState.storage.is_empty(), "drop of the last creature is refused")
	_check(screen.get_node("%Status").text.contains("last"), "status explains the refused drop")

	# Details panel shows the selected creature.
	_check(screen.get_node("%DetailName").text == starter.display_name(), "details show the name")
	_check(screen.get_node("%Element").text == GameTypes.element_name(starter.data.element_type), "details show the element")
	_check(screen.get_node("%Lore").text == starter.data.lore_text, "details show the lore")
	_check(screen.get_node("%Level").text == "Lv %d" % starter.level, "details show the level")

	# Party -> storage with the Move button.
	var kapre := CreatureInstance.create(load(KAPRE), 7)
	var tiyanak := CreatureInstance.create(load(TIYANAK), 6)
	GameState.capture(kapre)
	GameState.capture(tiyanak)
	screen.select(kapre)
	_check(not screen.get_node("%MoveButton").disabled, "Move enabled with 3 in party")
	screen.get_node("%MoveButton").pressed.emit()
	_check(kapre in GameState.storage and GameState.party.size() == 2, "Move button: party -> storage")
	_check(screen.get_node("%StorageGrid").get_child_count() == 1, "storage grid shows the stored creature")

	# Party -> storage with a real (simulated) mouse drag.
	await _mouse_drag(_slot_for(screen.get_node("%PartyList"), tiyanak), screen.get_node("%StorageBox"))
	_check(tiyanak in GameState.storage and GameState.party.size() == 1, "mouse drag: party -> storage")

	# Storage -> party: drag one back, Move the other back.
	if tiyanak in GameState.party:
		GameState.move_creature(tiyanak)  # keep going even if the drag above failed
		screen.select(tiyanak)
	await _mouse_drag(_slot_for(screen.get_node("%StorageGrid"), tiyanak), screen.get_node("%PartyBox"))
	_check(tiyanak in GameState.party and GameState.storage.size() == 1, "mouse drag: storage -> party")
	screen.select(kapre)
	screen.get_node("%MoveButton").pressed.emit()
	_check(kapre in GameState.party and GameState.storage.is_empty(), "Move button: storage -> party")

	# Touch input never starts a drag (it scrolls instead).
	screen._touch_input = true
	_check(screen._get_drag(Vector2.ZERO, _slot_for(screen.get_node("%PartyList"), kapre)) == null, "no drag from touch input")
	screen._touch_input = false

	# Full party blocks withdrawing.
	for i in 3:  # 3 in party + 3 = 6
		GameState.capture(CreatureInstance.create(load(KAPRE if i % 2 == 0 else TIYANAK), 3 + i))
	screen.select(kapre)
	screen.try_move(kapre)  # 6 in party -> 5, kapre into storage
	GameState.capture(CreatureInstance.create(load(TIYANAK), 9))  # back to 6
	_check(GameState.party.size() == 6 and GameState.storage.size() == 1, "6 in party, 1 stored")
	_check(not screen.try_move(kapre) and screen.get_node("%Status").text.contains("full"), "full party blocks withdrawing")
	_check(screen.get_node("%PartyList").get_child_count() == 6, "party panel always shows 6 slots")

	# Heal All.
	for c in GameState.party:
		c.take_damage(10)
	screen.get_node("%HealButton").pressed.emit()
	_check(GameState.party.all(func(c: CreatureInstance) -> bool: return c.current_hp == c.max_hp()), "Heal All restores the party")

	# Closing saves automatically.
	SaveManager.delete_save()
	screen.get_node("%CloseButton").pressed.emit()
	_check(not screen.visible and not get_tree().paused, "Close hides the screen and unpauses")
	_check(SaveManager.has_save(), "closing the hut autosaved")
	_write(EXPECTED, JSON.stringify(GameState.to_dict()))
	_finish()


func _phase_load() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	_check(GameState.party.size() == 1, "fresh process starts with just the starter")
	_check(SaveManager.load_game(), "save loads")
	_check(_norm(GameState.to_dict()) == _norm(expected), "party and storage survive save + load exactly")
	_check(GameState.party.size() == 6 and GameState.storage.size() == 1, "6 in party, 1 in storage after load")
	_check(GameState.storage[0].display_name() == "Kapre" and GameState.storage[0].level == 7, "the stored Kapre (Lv 7) is in storage")
	for f in [SAVE, EXPECTED]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	_finish()


# --- Helpers ---

func _slot_for(container: Node, creature: CreatureInstance) -> Control:
	for s in container.get_children():
		if s.creature == creature:
			return s
	return null


## Press on `from`, move past the drag threshold, release over `to`.
func _mouse_drag(from: Control, to: Control) -> void:
	if from == null:
		_check(false, "drag source slot exists")
		return
	await _frames(2)  # slots rebuilt this frame aren't laid out yet
	var a: Vector2 = from.get_global_rect().get_center()
	var b: Vector2 = to.get_global_rect().get_center()
	_mouse(InputEventMouseButton.new(), a, true)
	await _frames(2)
	for i in range(1, 11):
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.relative = (b - a) / 10.0  # the viewport measures drag distance from this
		_push(m, a.lerp(b, i / 10.0))
		await _frames(1)
	_mouse(InputEventMouseButton.new(), b, false)
	await _frames(3)


func _mouse(e: InputEventMouseButton, pos: Vector2, pressed: bool) -> void:
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_push(e, pos)


func _push(e: InputEventMouse, pos: Vector2) -> void:
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func _wait(cond: Callable, timeout: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_failures += 1
		push_error("FAIL: " + what)


func _finish() -> void:
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
