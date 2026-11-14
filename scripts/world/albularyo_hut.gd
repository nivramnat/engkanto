extends StaticBody3D
## The Albularyo's Hut: a nipa hut on bamboo stilts where the player manages
## party and storage. Built from primitives in the scene.
##
## Emits player_in_range_changed when the player walks up to or away from the
## door. The world scene wires that signal to the HUD, which shows the Enter
## prompt and opens the hut screen. On spawn the hut settles onto the terrain
## and joins the "scatter_clear" group so streamed trees don't grow through it.

signal player_in_range_changed(in_range: bool)

@export var terrain_path: NodePath
@export var clear_radius: float = 8.0  ## no scattered trees within this distance

var _player_in_range: bool = false

@onready var _enter_area: Area3D = $EnterArea


func _ready() -> void:
	add_to_group("scatter_clear")
	_enter_area.body_entered.connect(_on_body_entered)
	_enter_area.body_exited.connect(_on_body_exited)
	_snap_to_terrain.call_deferred()


func is_player_in_range() -> bool:
	return _player_in_range


## Sit on the lowest ground under the footprint, so stilts never float on a slope.
func _snap_to_terrain() -> void:
	var terrain: Node = get_node_or_null(terrain_path)
	if terrain == null or not terrain.has_method("get_data") or terrain.get_data() == null:
		return
	var lowest: float = INF
	for offset in [Vector3.ZERO, Vector3(2, 0, 2), Vector3(-2, 0, 2), Vector3(2, 0, -2), Vector3(-2, 0, -2)]:
		var p: Vector3 = global_transform * offset
		var h: float = terrain.get_data().get_height(Vector3(p.x, 0.0, p.z))
		if is_finite(h):
			lowest = minf(lowest, h)
	if is_finite(lowest):
		global_position.y = lowest


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _player_in_range:
		_player_in_range = true
		player_in_range_changed.emit(true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and _player_in_range:
		_player_in_range = false
		player_in_range_changed.emit(false)
