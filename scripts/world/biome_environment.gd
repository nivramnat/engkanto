extends Node
## Interpolates fog colour/density and sun colour/energy from the blended biome
## weights at the player's position, so moving between biomes shifts the mood
## gradually. Night (TimeOfDay) dims the sun on top of the biome tint.

@export var environment_path: NodePath
@export var sun_path: NodePath
@export var lerp_speed: float = 1.5

var _env: Environment
var _sun: DirectionalLight3D
var _player: Node3D


func _ready() -> void:
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we != null:
		_env = we.environment
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _env != null:
		_env.fog_enabled = true


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	var p: Vector3 = _player.global_position
	var w := BiomeMap.weights(p.x, p.z)

	var target_fog := BiomeMap.blended_color(BiomeMap.FOG_COLOR, w)
	var target_light := BiomeMap.blended_color(BiomeMap.LIGHT_COLOR, w)
	var target_density := BiomeMap.blended_float(BiomeMap.FOG_DENSITY, w)
	var target_energy := BiomeMap.blended_float(BiomeMap.LIGHT_ENERGY, w)

	if TimeOfDay.is_night():
		target_energy *= 0.3
		target_fog = target_fog.darkened(0.6)

	var t: float = clampf(lerp_speed * delta, 0.0, 1.0)
	if _env != null:
		_env.fog_light_color = _env.fog_light_color.lerp(target_fog, t)
		_env.fog_density = lerpf(_env.fog_density, target_density, t)
		_env.ambient_light_color = _env.ambient_light_color.lerp(target_fog, t)
	if _sun != null:
		_sun.light_color = _sun.light_color.lerp(target_light, t)
		_sun.light_energy = lerpf(_sun.light_energy, target_energy, t)
