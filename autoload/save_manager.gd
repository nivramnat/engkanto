extends Node
## Save/load singleton (autoload).
##
## Serialises GameState (party, Albularyo's Hut storage, inventory), the
## TimeOfDay clock and the player's position/biome to JSON at user://, which maps
## to a writable app-data folder on both PC and Android.
##
## Every save carries a "version". Loading runs older saves through _migrate()
## one version at a time, so bump SAVE_VERSION and add a migration step whenever
## the format changes. Missing fields fall back to defaults.
##
## Autosaves whenever a battle ends (win, lose, run or successful bind).

signal saved(ok: bool)

const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://save_game.json"

var save_path: String = DEFAULT_PATH  ## overridable so tests never touch the real save
var autosave_enabled: bool = true
var last_error: String = ""           ## why the last load failed, for UI warnings

## Player state read from a save, applied by the player when the world spawns.
var _pending_player: Dictionary = {}


func _ready() -> void:
	GameState.battle_finished.connect(_on_battle_finished)


# --- Queries ---

func has_save() -> bool:
	# A crash between removing the old save and renaming the new one leaves
	# only the .tmp (which was fully written); recover it.
	if not FileAccess.file_exists(save_path) and FileAccess.file_exists(save_path + ".tmp"):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"),
			ProjectSettings.globalize_path(save_path))
	return FileAccess.file_exists(save_path)


## Parse and validate the save without applying it. Returns {} (and sets
## last_error) when the file is missing, unreadable, corrupt or too new.
func read_save() -> Dictionary:
	last_error = ""
	if not has_save():
		last_error = "No save file found."
		return {}
	var text: String = FileAccess.get_file_as_string(save_path)
	if text.is_empty():
		last_error = "Save file is empty or unreadable (%s)." % error_string(FileAccess.get_open_error())
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		last_error = "Save file is corrupted (not valid JSON)."
		return {}
	var data: Dictionary = parsed
	if not data.has("version") or typeof(data["version"]) != TYPE_FLOAT:
		last_error = "Save file is corrupted (no version)."
		return {}
	var version: int = int(data["version"])
	if version > SAVE_VERSION:
		last_error = "Save file is from a newer version of the game (v%d)." % version
		return {}
	return _migrate(data, version)


## Short description for the title screen's Continue button, e.g. the biome.
func save_summary() -> String:
	var player: Variant = read_save().get("player", {})
	return str(player.get("biome", "")) if player is Dictionary else ""


# --- Save ---

func save_game() -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"game": GameState.to_dict(),
		"time_of_day": TimeOfDay.to_dict(),
	}
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		data["player"] = _player_to_dict(player)
	elif not _pending_player.is_empty():
		data["player"] = _pending_player  # world not loaded yet: keep the old spot
	var ok: bool = _write_atomic(JSON.stringify(data, "\t"))
	saved.emit(ok)
	return ok


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_pending_player = {}


# --- Load ---

## Read the save and apply it to GameState/TimeOfDay. The player position is
## held until the player spawns (take_pending_player). Returns false, leaving
## the current state untouched, if the save can't be used.
func load_game() -> bool:
	var data: Dictionary = read_save()
	if data.is_empty():
		push_warning("SaveManager: %s Starting a new game instead." % last_error)
		backup_bad_save()
		return false
	var game: Variant = data.get("game", {})
	GameState.from_dict(game if game is Dictionary else {})
	if GameState.party.is_empty() and GameState.storage.is_empty():
		push_warning("SaveManager: save had no valid creatures; giving the starter back.")
		var inventory: Dictionary = GameState.inventory
		GameState.new_game()
		GameState.inventory = inventory
	var tod: Variant = data.get("time_of_day", {})
	TimeOfDay.from_dict(tod if tod is Dictionary else {})
	var player: Variant = data.get("player", {})
	_pending_player = player if player is Dictionary else {}
	return true


## Called by the player on spawn: returns the saved position/camera (or {}) once.
func take_pending_player() -> Dictionary:
	var p: Dictionary = _pending_player
	_pending_player = {}
	return p


# --- Internals ---

func _player_to_dict(player: Node3D) -> Dictionary:
	var pos: Vector3 = player.global_position
	var biome: int = BiomeMap.dominant(pos.x, pos.z)
	var d: Dictionary = {
		"position": [pos.x, pos.y, pos.z],
		"biome": BiomeMap.NAMES[biome],
		"biome_id": biome,
	}
	if player.has_method("get_camera_yaw"):
		d["camera_yaw"] = player.get_camera_yaw()
	return d


## Upgrade older save formats step by step. Add a `match` arm per version bump.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var v: int = from_version
	while v < SAVE_VERSION:
		match v:
			# 1: data = upgraded_v1_to_v2(data)
			_:
				pass
		v += 1
	data["version"] = SAVE_VERSION
	return data


## Write to a temp file then swap it in, so a crash or the Android app being
## killed mid-write can't leave a half-written save.
func _write_atomic(text: String) -> bool:
	var tmp_path: String = save_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: can't write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	var target: String = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(target)
	var err: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), target)
	if err != OK:
		push_error("SaveManager: can't replace save file (%s)" % error_string(err))
		return false
	return true


## Keep an unreadable save around as .bak (for debugging) instead of silently
## overwriting it on the next save.
func backup_bad_save() -> void:
	if not has_save():
		return
	var src: String = ProjectSettings.globalize_path(save_path)
	DirAccess.remove_absolute(src + ".bak")
	DirAccess.rename_absolute(src, src + ".bak")


func _on_battle_finished(_result: String, _wild: CreatureInstance) -> void:
	if autosave_enabled:
		save_game()
