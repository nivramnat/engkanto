extends Node
## Day/night clock (autoload).
##
## Runs a sped-up clock for testing, exposes the current phase, and lets the
## spawning system ask whether a creature may appear now. Emits phase_changed
## when it crosses dawn/dusk. Press T to toggle day/night while playing.

signal phase_changed(is_night: bool)

const DAY_START: float = 6.0
const NIGHT_START: float = 18.0

@export var day_length_seconds: float = 60.0  ## real seconds for one in-game day (sped up for testing)

var time_hours: float = 8.0  ## current in-game hour in [0, 24)
var _was_night: bool = false


func _ready() -> void:
	_was_night = is_night()


func _process(delta: float) -> void:
	if day_length_seconds <= 0.0:
		return
	time_hours = fmod(time_hours + (24.0 / day_length_seconds) * delta, 24.0)
	_check_phase()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		toggle_phase()


func is_night() -> bool:
	return time_hours < DAY_START or time_hours >= NIGHT_START


func is_day() -> bool:
	return not is_night()


## Jump straight to midday or midnight to flip the phase immediately (debug).
func toggle_phase() -> void:
	time_hours = 0.0 if is_day() else 12.0
	_check_phase()


func allows_spawn(spawn_time: GameTypes.SpawnTime) -> bool:
	match spawn_time:
		GameTypes.SpawnTime.DAY:
			return is_day()
		GameTypes.SpawnTime.NIGHT:
			return is_night()
		_:
			return true


func _check_phase() -> void:
	var night: bool = is_night()
	if night != _was_night:
		_was_night = night
		phase_changed.emit(night)
		print("[TimeOfDay] now %s (%.1fh)" % ["night" if night else "day", time_hours])
