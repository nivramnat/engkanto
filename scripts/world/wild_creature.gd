extends CharacterBody3D
class_name WildCreature
## A visible wild engkanto in the overworld.
##
## Placeholder capsule tinted by element type with a billboarded name label.
## Wanders randomly around its spawn point, pausing between hops, and holds
## still when the player comes close. Touching the player fires `touched`.

signal touched(creature: Creature)

@export var wander_speed: float = 1.5
@export var wander_radius: float = 4.0
@export var stop_distance: float = 3.0
@export var turn_speed: float = 8.0

var creature_data: Creature
var _home: Vector3
var _target: Vector3
var _idle_timer: float = 0.0
var _player: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _label: Label3D = $NameLabel
@onready var _touch_area: Area3D = $TouchArea


func _ready() -> void:
	_touch_area.body_entered.connect(_on_body_entered)


## Assign the creature this instance represents. Call right after adding the
## node to the tree and positioning it.
func setup(data: Creature) -> void:
	creature_data = data
	_home = global_position
	_target = global_position
	_label.text = data.name
	var material := StandardMaterial3D.new()
	material.albedo_color = GameTypes.element_color(data.element_type)
	_mesh.set_surface_override_material(0, material)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if _player != null and _flat_distance_to(_player.global_position) < stop_distance:
		# Freeze and watch the player.
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var to_target: Vector3 = _target - global_position
		to_target.y = 0.0
		if to_target.length() < 0.4:
			_idle_timer = randf_range(0.5, 2.0)
			_pick_target()
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var dir: Vector3 = to_target.normalized()
			velocity.x = dir.x * wander_speed
			velocity.z = dir.z * wander_speed
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), turn_speed * delta)

	move_and_slide()


func _pick_target() -> void:
	var angle: float = randf() * TAU
	var r: float = sqrt(randf()) * wander_radius
	_target = _home + Vector3(cos(angle) * r, 0.0, sin(angle) * r)


func _flat_distance_to(point: Vector3) -> float:
	var a: Vector3 = Vector3(global_position.x, 0.0, global_position.z)
	var b: Vector3 = Vector3(point.x, 0.0, point.z)
	return a.distance_to(b)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and creature_data != null:
		print("Encountered wild %s!" % creature_data.name)
		touched.emit(creature_data)
		var wild := CreatureInstance.create(creature_data, randi_range(3, 6))
		GameState.start_battle(wild, self)
