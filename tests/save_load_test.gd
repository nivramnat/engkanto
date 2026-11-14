extends Node
## Save/load end-to-end test, run as two separate processes so "quit" is real:
##   godot_console --path . res://tests/save_load_test.tscn -- --phase=save
##   godot_console --path . res://tests/save_load_test.tscn -- --phase=load
## Uses its own save file; the player's real save is never touched.

const WORLD: String = "res://scenes/world/world.tscn"
const TITLE: String = "res://scenes/ui/title_screen.tscn"
const SAVE: String = "user://test_save_game.json"
const EXPECTED: String = "user://test_save_expected.json"
const KAPRE: String = "res://data/creatures/kapre.tres"
const TIYANAK: String = "res://data/creatures/tiyanak.tres"

var _failures: int = 0


func _ready() -> void:
	SaveManager.save_path = SAVE
	TimeOfDay.day_length_seconds = 0.0  # freeze the clock so it can be compared
	var phase: String = "save"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.trim_prefix("--phase=")
	(_phase_save if phase == "save" else _phase_load).call_deferred()


# --- Phase 1: new game, play, autosave + manual save, quit ---

func _phase_save() -> void:
	SaveManager.delete_save()
	var title: Node = await _open_title()
	_check(not _btn(title, "ContinueButton").visible, "Continue hidden with no save")
	_btn(title, "NewGameButton").pressed.emit()  # no save -> starts immediately
	_check(not title.get_node("%Confirm").visible, "no confirmation without a save")
	var world: Node = await _wait_world()
	if world == null:
		return _finish()
	await _frames(120)

	# Build a distinctive state: travel to the forest, fill party + hut, etc.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var c: Vector2 = BiomeMap.CENTERS[BiomeMap.Biome.FOREST]
	var ground: float = world.get_node("Terrain").get_data().get_height(Vector3(c.x, 0.0, c.y))
	player.global_position = Vector3(c.x, ground + 3.0, c.y)
	player.get_node("CameraYaw").rotation.y = 1.25
	await _frames(240)  # settle onto the streamed terrain collision

	var kapre: Creature = load(KAPRE)
	var tiyanak: Creature = load(TIYANAK)
	for i in 7:  # 1 starter + 7 -> 6 in party, 2 in the hut
		var inst := CreatureInstance.create(kapre if i % 2 == 0 else tiyanak, 4 + i)
		inst.current_hp = maxi(1, inst.max_hp() - 3 - i)
		GameState.capture(inst)
	GameState.inventory = {GameState.ANTING_ANTING: 4, "herb": 2}
	TimeOfDay.set_time(21.5)

	# Autosave: run from a wild creature.
	var wild: WildCreature = await _find_wild()
	if wild == null:
		_check(false, "a wild creature spawned for the autosave check")
	else:
		var saves: Array[bool] = []
		SaveManager.saved.connect(func(ok: bool) -> void: saves.append(ok))
		wild._on_body_entered(player)
		var battle: Node = await _find_battle()
		await _wait(func() -> bool: return battle._action_menu.visible, 10.0)
		battle._on_run_pressed()
		await _wait(func() -> bool: return not get_tree().paused, 10.0)
		_check(saves == [true], "autosave fired once after the battle ended")
		_check(SaveManager.has_save(), "save file exists after autosave")

	# Manual save through the pause menu.
	var pause: Control = world.get_node("HUD/PauseMenu")
	world.get_node("HUD/PauseButton").pressed.emit()
	_check(pause.visible and get_tree().paused, "pause menu opens and pauses")
	pause.get_node("%SaveButton").pressed.emit()
	_check(pause.get_node("%Status").text == "Game saved.", "manual save reports success")
	var text: String = FileAccess.get_file_as_string(SAVE)
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary and int(parsed.get("version", 0)) == SaveManager.SAVE_VERSION, "file has a version")

	_write_json(EXPECTED, {
		"game": GameState.to_dict(),
		"time": TimeOfDay.time_hours,
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"yaw": player.get_camera_yaw(),
		"biome": BiomeMap.NAMES[BiomeMap.dominant(player.global_position.x, player.global_position.z)],
	})
	print("saved file:\n", text)
	_finish()


# --- Phase 2: fresh process, Continue from the title, verify, edge cases ---

func _phase_load() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	_check(GameState.party.size() == 1, "fresh process starts with just the starter")

	var title: Node = await _open_title()
	var cont: Button = _btn(title, "ContinueButton")
	_check(cont.visible, "Continue shown when a save exists")
	_check(cont.text.contains(str(expected["biome"])), "Continue shows saved biome (%s)" % cont.text)
	cont.pressed.emit()

	# State is applied synchronously, before the world even loads.
	_check(_norm(GameState.to_dict()) == _norm(expected["game"]),
		"party, hut storage and inventory restored exactly")
	_check(GameState.party.size() == 6 and GameState.storage.size() == 2, "6 in party, 2 in hut")
	_check(is_equal_approx(TimeOfDay.time_hours, float(expected["time"])), "clock restored (%.2f)" % TimeOfDay.time_hours)
	_check(TimeOfDay.is_night(), "restored as night")

	var world: Node = await _wait_world()
	if world == null:
		return _finish()
	await _frames(240)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var want := Vector3(expected["position"][0], expected["position"][1], expected["position"][2])
	var got: Vector3 = player.global_position
	_check(Vector2(got.x, got.z).distance_to(Vector2(want.x, want.z)) < 0.5, "player XZ restored (%s vs %s)" % [got, want])
	_check(absf(got.y - want.y) < 1.0, "player standing on the ground, not fallen through (y %.2f vs %.2f)" % [got.y, want.y])
	_check(absf(player.get_camera_yaw() - float(expected["yaw"])) < 0.001, "camera yaw restored (%.4f vs %.4f)" % [player.get_camera_yaw(), float(expected["yaw"])])

	# Quit to title -> New Game asks first; Cancel keeps the save.
	world.get_node("HUD/PauseButton").pressed.emit()
	world.get_node("HUD/PauseMenu/%TitleButton").pressed.emit()
	title = await _wait_scene(TITLE)
	_check(not get_tree().paused, "title screen is not paused")
	_btn(title, "NewGameButton").pressed.emit()
	_check(title.get_node("%Confirm").visible, "New Game asks for confirmation when a save exists")
	_btn(title, "CancelButton").pressed.emit()
	_check(SaveManager.has_save() and not title.get_node("%Confirm").visible, "Cancel keeps the save")

	# Bad creature path is skipped, rest of the save still loads.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data["game"]["storage"].append({"resource": "res://data/creatures/nope.tres", "level": 3, "current_hp": 5})  # path-case: ignore (missing on purpose)
	_write_json(SAVE, data)
	_check(SaveManager.load_game() and GameState.storage.size() == 2, "unknown creature skipped, save still loads")

	# Newer version is refused, current state untouched.
	data["version"] = SaveManager.SAVE_VERSION + 1
	_write_json(SAVE, data)
	_check(not SaveManager.load_game() and SaveManager.last_error.contains("newer"), "newer save version refused")
	_check(GameState.party.size() == 6, "failed load leaves state untouched")

	# Corrupt file: title hides Continue, warns, keeps a .bak.
	_write_text(SAVE, "{ this is not json")
	title.queue_free()
	title = await _open_title()
	_check(not _btn(title, "ContinueButton").visible, "corrupt save hides Continue")
	_check(title.get_node("%Warning").text.contains("corrupted"), "corrupt save shows a warning")
	_check(FileAccess.file_exists(SAVE + ".bak") and not SaveManager.has_save(), "corrupt save moved to .bak")
	_check(not SaveManager.load_game() and SaveManager.last_error != "", "missing save fails gracefully")

	# Confirmed New Game erases the save and resets state.
	SaveManager.save_game()
	title.queue_free()
	title = await _open_title()
	_btn(title, "NewGameButton").pressed.emit()
	_btn(title, "ConfirmButton").pressed.emit()
	_check(not SaveManager.has_save(), "confirmed New Game erased the save")
	_check(GameState.party.size() == 1 and GameState.storage.is_empty(), "New Game reset party and hut")
	_check(await _wait_world() != null, "New Game enters the world")

	for f in [SAVE, SAVE + ".bak", EXPECTED]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	_finish()


# --- Helpers ---

func _open_title() -> Node:
	var title: Node = (load(TITLE) as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title  # so change_scene replaces it, not this node
	await get_tree().process_frame
	return title


func _btn(title: Node, name: String) -> Button:
	return title.get_node("%" + name) as Button


func _wait_world() -> Node:
	return await _wait_scene(WORLD)


func _wait_scene(path: String) -> Node:
	var ok: bool = await _wait(func() -> bool:
		var cs: Node = get_tree().current_scene
		return cs != null and cs.scene_file_path == path, 10.0)
	_check(ok, "scene %s loaded" % path)
	return get_tree().current_scene if ok else null


func _find_wild() -> WildCreature:
	for i in 600:
		var found: Array[Node] = get_tree().current_scene.find_children("*", "WildCreature", true, false)
		if not found.is_empty():
			return found[0] as WildCreature
		await get_tree().process_frame
	return null


func _find_battle() -> Node:
	for i in 60:
		for c in get_tree().root.get_children():
			if c.has_signal("finished") and c.has_method("setup"):
				return c
		await get_tree().process_frame
	return null


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


## JSON round-trip with sorted keys, so ints vs floats and key order don't matter.
func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


func _write_json(path: String, d: Dictionary) -> void:
	_write_text(path, JSON.stringify(d, "\t"))


func _write_text(path: String, text: String) -> void:
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
