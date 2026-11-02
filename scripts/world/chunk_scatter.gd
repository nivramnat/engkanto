extends Node3D
## Streams biome-appropriate scenery in a grid of chunks around the player.
## Only chunks within `radius` are loaded; the rest are freed. Per-chunk density
## scales with the dominant biome weight and each item is additionally thinned by
## the biome weight at its own spot, so scatter fades out gradually at biome
## edges. Grass is drawn as one MultiMesh per chunk to stay cheap on mobile.

const B := BiomeMap.Biome

const TREES := {
	B.LOWLANDS: [preload("res://scenes/world/props/tree_common.tscn")],
	B.FOREST: [preload("res://scenes/world/props/pine.tscn"),
		preload("res://scenes/world/props/dead_tree.tscn"),
		preload("res://scenes/world/props/tree_common.tscn")],
	B.MYSTIC: [preload("res://scenes/world/props/twisted_tree.tscn"),
		preload("res://scenes/world/props/rock.tscn")],
	B.COAST: [preload("res://scenes/world/props/rock.tscn")],
}
const TREE_COUNT := {B.LOWLANDS: 3, B.FOREST: 9, B.MYSTIC: 5, B.COAST: 1}

const GRASS := {
	B.LOWLANDS: preload("res://assets/models/nature/glTF/Grass_Common_Short.gltf"),
	B.FOREST: preload("res://assets/models/nature/glTF/Grass_Wispy_Tall.gltf"),
	B.MYSTIC: preload("res://assets/models/nature/glTF/Grass_Wispy_Short.gltf"),
	B.COAST: preload("res://assets/models/nature/glTF/Grass_Common_Short.gltf"),
}
const GRASS_COUNT := {B.LOWLANDS: 70, B.FOREST: 45, B.MYSTIC: 45, B.COAST: 12}

@export var terrain_path: NodePath
@export var chunk_size: float = 96.0
@export var radius: int = 2

var _terrain: Node
var _player: Node3D
var _loaded: Dictionary = {}          # Vector2i -> Node3D
var _current := Vector2i(999999, 999999)


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var pc := _chunk_of(_player.global_position)
	if pc != _current:
		_current = pc
		_refresh(pc)


func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / chunk_size)), int(floor(pos.z / chunk_size)))


func _refresh(center: Vector2i) -> void:
	var needed := {}
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			needed[center + Vector2i(dx, dz)] = true
	for c in _loaded.keys():
		if not needed.has(c):
			_loaded[c].queue_free()
			_loaded.erase(c)
	for c in needed:
		if not _loaded.has(c):
			_loaded[c] = _build_chunk(c)


func _height(x: float, z: float) -> float:
	if _terrain != null:
		var h: float = _terrain.get_data().get_height(Vector3(x, 0.0, z))
		if is_finite(h):
			return h
	return 0.0


func _build_chunk(c: Vector2i) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	var x0: float = c.x * chunk_size
	var z0: float = c.y * chunk_size
	var cx: float = x0 + chunk_size * 0.5
	var cz: float = z0 + chunk_size * 0.5

	var w := BiomeMap.weights(cx, cz)
	var dom: int = 0
	for i in BiomeMap.COUNT:
		if w[i] > w[dom]:
			dom = i
	var dom_w: float = w[dom]

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)

	# Collidable props (trees/rocks), density scaled by the dominant weight.
	var scenes: Array = TREES[dom]
	var tcount: int = int(round(TREE_COUNT[dom] * dom_w))
	for i in tcount:
		if scenes.is_empty():
			break
		var px: float = x0 + rng.randf() * chunk_size
		var pz: float = z0 + rng.randf() * chunk_size
		# Edge fade: thin out where this biome's weight is low.
		var lw := BiomeMap.weights(px, pz)
		if rng.randf() > lw[dom]:
			continue
		var y: float = _height(px, pz)
		if y < 0.2:
			continue  # don't plant trees in the water/beach
		var inst: Node3D = (scenes[rng.randi() % scenes.size()] as PackedScene).instantiate()
		node.add_child(inst)
		var s: float = rng.randf_range(0.8, 1.25)
		inst.transform = Transform3D(
			Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(s, s, s)),
			Vector3(px, y, pz))

	_build_grass(node, dom, dom_w, x0, z0, rng)
	return node


func _build_grass(node: Node3D, dom: int, dom_w: float, x0: float, z0: float, rng: RandomNumberGenerator) -> void:
	var mesh := _mesh_of(GRASS[dom])
	if mesh == null:
		return
	var count: int = int(round(GRASS_COUNT[dom] * dom_w))
	var xforms: Array[Transform3D] = []
	for i in count:
		var px: float = x0 + rng.randf() * chunk_size
		var pz: float = z0 + rng.randf() * chunk_size
		var lw := BiomeMap.weights(px, pz)
		if rng.randf() > lw[dom]:
			continue
		var y: float = _height(px, pz)
		if y < 0.1:
			continue
		var s: float = rng.randf_range(0.6, 1.1)
		xforms.append(Transform3D(
			Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(s, s, s)),
			Vector3(px, y, pz)))
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	node.add_child(mmi)


func _mesh_of(scene: PackedScene) -> Mesh:
	var inst := scene.instantiate()
	var m := _find_mesh(inst)
	inst.free()
	return m


func _find_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return n.mesh
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null
