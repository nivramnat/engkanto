extends CharacterBody3D
## Third-person player controller.
##
## Movement uses the project input map (move_forward/back/left/right, run),
## resolved relative to the camera yaw. The SpringArm3D camera orbits the
## player: right-mouse drag on PC, swipe on the right half of the screen on
## touch. On touch devices movement also comes from the on-screen joystick.

@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var turn_speed: float = 12.0          ## how fast the body faces its movement direction
@export var mouse_sensitivity: float = 0.005  ## radians of camera rotation per pixel of mouse motion
@export var touch_sensitivity: float = 0.004  ## radians of camera rotation per pixel of swipe
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = 20.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _joystick_input: Vector2 = Vector2.ZERO
var _pending_swipe: Vector2 = Vector2.ZERO    ## touch rotation accumulated between physics frames

@onready var _camera_yaw: Node3D = $CameraYaw
@onready var _spring_arm: SpringArm3D = $CameraYaw/SpringArm3D
@onready var _mesh: Node3D = $Mesh


func _ready() -> void:
	# Keep the spring arm from colliding with the player's own body.
	_spring_arm.add_excluded_object(get_rid())

	var joystick := get_node_or_null("TouchControls/VirtualJoystick")
	if joystick != null:
		joystick.direction_changed.connect(_on_joystick_direction_changed)
	var swipe_area := get_node_or_null("TouchControls/CameraTouchArea")
	if swipe_area != null:
		swipe_area.swiped.connect(_on_camera_swiped)


func _on_joystick_direction_changed(direction: Vector2) -> void:
	_joystick_input = direction


func _on_camera_swiped(relative: Vector2) -> void:
	_pending_swipe += relative * touch_sensitivity


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("camera_rotate"):
		_rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)


func _rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
	_camera_yaw.rotate_y(yaw_delta)
	var pitch: float = _spring_arm.rotation.x + pitch_delta
	_spring_arm.rotation.x = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func _physics_process(delta: float) -> void:
	if _pending_swipe != Vector2.ZERO:
		_rotate_camera(-_pending_swipe.x, -_pending_swipe.y)
		_pending_swipe = Vector2.ZERO

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Keyboard/gamepad plus the touch joystick, clamped to a unit length.
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_input += _joystick_input
	move_input = move_input.limit_length(1.0)

	var direction: Vector3 = _camera_yaw.global_transform.basis * Vector3(move_input.x, 0.0, move_input.y)
	direction.y = 0.0
	if direction.length() > 0.001:
		direction = direction.normalized()
	else:
		direction = Vector3.ZERO

	var speed: float = run_speed if Input.is_action_pressed("run") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if direction.length() > 0.001:
		var target_yaw: float = atan2(direction.x, direction.z)
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, target_yaw, turn_speed * delta)

	move_and_slide()
