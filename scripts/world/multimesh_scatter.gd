extends MultiMeshInstance3D
## Scatters many copies of a small model (grass, flowers) as a single MultiMesh
## so the whole patch costs one draw call per surface — cheap on mobile. Keeps
## the middle of the map clear for gameplay.

@export var source_scene: PackedScene
@export var count: int = 400
@export var area_extent: float = 38.0    ## half-size of the square scatter area
@export var clear_radius: float = 15.0   ## keep this radius around the origin empty
@export var min_scale: float = 0.7
@export var max_scale: float = 1.1
@export var rng_seed: int = 0


func _ready() -> void:
	if source_scene == null:
		return
	var baked: Dictionary = _extract(source_scene)
	var mesh: Mesh = baked["mesh"]
	if mesh == null:
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var placements: Array[Transform3D] = []
	for i in count:
		var x: float = rng.randf_range(-area_extent, area_extent)
		var z: float = rng.randf_range(-area_extent, area_extent)
		if Vector2(x, z).length() < clear_radius:
			continue
		var s: float = rng.randf_range(min_scale, max_scale)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(s, s, s))
		placements.append(Transform3D(basis, Vector3(x, 0.0, z)) * baked["offset"])

	mm.instance_count = placements.size()
	for i in placements.size():
		mm.set_instance_transform(i, placements[i])
	multimesh = mm


## Pull the mesh out of an imported model plus the transform of its mesh node
## (so any scale/rotation baked into the glTF is preserved).
func _extract(scene: PackedScene) -> Dictionary:
	var root_inst: Node = scene.instantiate()
	var mi: MeshInstance3D = _find_mesh_instance(root_inst)
	var offset := Transform3D.IDENTITY
	var mesh: Mesh = null
	if mi != null:
		mesh = mi.mesh
		var n: Node = mi
		while n != null and n != root_inst:
			if n is Node3D:
				offset = (n as Node3D).transform * offset
			n = n.get_parent()
		if root_inst is Node3D:
			offset = (root_inst as Node3D).transform * offset
	root_inst.queue_free()
	return {"mesh": mesh, "offset": offset}


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var r: MeshInstance3D = _find_mesh_instance(c)
		if r != null:
			return r
	return null
