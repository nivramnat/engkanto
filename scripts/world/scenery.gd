extends Node3D
## Scatters collidable props (trees, rocks, bushes) around the edges of the map
## and in a few clusters, keeping the middle clear for the SpawnZone and player.
## Each tree/rock prop scene carries its own collision, so the player can't walk
## through them; bushes are decorative (no collision).

@export var tree_scenes: Array[PackedScene] = []
@export var rock_scenes: Array[PackedScene] = []
@export var bush_scenes: Array[PackedScene] = []
@export var area_extent: float = 38.0
@export var clear_radius: float = 15.0
@export var tree_count: int = 20
@export var rock_count: int = 14
@export var bush_count: int = 18
@export var cluster_count: int = 4
@export var rng_seed: int = 1337

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = rng_seed
	var clusters: Array[Vector2] = []
	for i in cluster_count:
		clusters.append(_ring_point(clear_radius + 4.0, area_extent - 6.0))
	_scatter(tree_scenes, tree_count, clusters, 0.8, 1.25)
	_scatter(rock_scenes, rock_count, clusters, 0.7, 1.4)
	_scatter(bush_scenes, bush_count, clusters, 0.8, 1.3)


func _scatter(scenes: Array[PackedScene], n: int, clusters: Array[Vector2], smin: float, smax: float) -> void:
	if scenes.is_empty():
		return
	for i in n:
		var p: Vector2
		# ~60% gathered into clusters, the rest loose around the edges.
		if not clusters.is_empty() and _rng.randf() < 0.6:
			var c: Vector2 = clusters[_rng.randi() % clusters.size()]
			p = c + Vector2(_rng.randfn(0.0, 3.0), _rng.randfn(0.0, 3.0))
		else:
			p = _ring_point(clear_radius, area_extent)
		p.x = clampf(p.x, -area_extent, area_extent)
		p.y = clampf(p.y, -area_extent, area_extent)
		if p.length() < clear_radius:
			continue
		var scene: PackedScene = scenes[_rng.randi() % scenes.size()]
		var inst: Node3D = scene.instantiate()
		add_child(inst)
		var s: float = _rng.randf_range(smin, smax)
		inst.transform = Transform3D(
			Basis(Vector3.UP, _rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(s, s, s)),
			Vector3(p.x, 0.0, p.y))


func _ring_point(r_min: float, r_max: float) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	var r: float = sqrt(_rng.randf_range(r_min * r_min, r_max * r_max))
	return Vector2(cos(angle) * r, sin(angle) * r)
