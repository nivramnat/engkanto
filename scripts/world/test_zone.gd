extends Node3D
## Test zone. Reflects the TimeOfDay phase in the lighting so the day/night
## toggle (T) is visible while playing.

@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _world_env: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	TimeOfDay.phase_changed.connect(_on_phase_changed)
	_apply(TimeOfDay.is_night())


func _on_phase_changed(is_night: bool) -> void:
	_apply(is_night)


func _apply(is_night: bool) -> void:
	_sun.light_energy = 0.15 if is_night else 1.0
	var env: Environment = _world_env.environment
	if env != null:
		env.background_color = Color(0.05, 0.06, 0.12) if is_night else Color(0.46, 0.58, 0.69)
		env.ambient_light_energy = 0.2 if is_night else 0.6
