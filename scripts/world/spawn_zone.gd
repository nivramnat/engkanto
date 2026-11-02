extends Node3D
class_name SpawnZone
## Spawns wild creatures around this node.
##
## Picks from `creatures`, respecting each creature's spawn_time against the
## TimeOfDay autoload, keeps at most `max_alive` instances, and despawns any
## that no longer belong when the phase flips.

@export var creatures: Array[Creature] = []
@export var wild_creature_scene: PackedScene
@export var max_alive: int = 5
@export var spawn_radius: float = 12.0
@export var spawn_interval: float = 1.5
@export var active_radius: float = 0.0  ## only spawn when the player is within this (0 = always)

var _alive: Array[Node] = []
var _timer: float = 0.0


func _ready() -> void:
	TimeOfDay.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	_prune()
	if not _player_in_range():
		# Unload this biome's creatures while the player is away (streaming).
		for n in _alive:
			if is_instance_valid(n):
				n.queue_free()
		_alive.clear()
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_try_spawn()


func _player_in_range() -> bool:
	if active_radius <= 0.0:
		return true
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	# Horizontal distance only — biomes are laid out in XZ and the player's Y
	# follows the terrain.
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(p.global_position.x, p.global_position.z)
	return a.distance_to(b) <= active_radius


func _try_spawn() -> void:
	if wild_creature_scene == null or creatures.is_empty() or _alive.size() >= max_alive:
		return

	var candidates: Array[Creature] = creatures.filter(
		func(c: Creature) -> bool: return c != null and TimeOfDay.allows_spawn(c.spawn_time)
	)
	if candidates.is_empty():
		return

	var data: Creature = candidates[randi() % candidates.size()]
	var instance: WildCreature = wild_creature_scene.instantiate()
	add_child(instance)
	instance.global_position = _random_point()
	instance.setup(data)
	_alive.append(instance)


func _random_point() -> Vector3:
	var angle: float = randf() * TAU
	var r: float = sqrt(randf()) * spawn_radius
	return global_position + Vector3(cos(angle) * r, 1.0, sin(angle) * r)


func _prune() -> void:
	_alive = _alive.filter(func(n: Node) -> bool: return is_instance_valid(n))


func _on_phase_changed(_is_night: bool) -> void:
	for n in _alive:
		var wild := n as WildCreature
		if is_instance_valid(wild) and wild.creature_data != null:
			if not TimeOfDay.allows_spawn(wild.creature_data.spawn_time):
				wild.queue_free()
	_prune()
