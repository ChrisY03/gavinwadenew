extends Node3D

signal player_spotted(player_position: Vector3)

# ===========================
# MOVEMENT SETTINGS
# ===========================
@export var speed: float = 10.0
@export var rotation_speed: float = 3.0
@export var use_random_patrol: bool = true
@export var patrol_points: Array[NodePath] = []

@export var min_x: float = -50.0
@export var max_x: float = 50.0
@export var min_z: float = -50.0
@export var max_z: float = 50.0
@export var flight_height: float = 40.0

# ===========================
# RAYCAST DETECTION
# ===========================
@export var detector_pivot_path: NodePath
var detector_pivot: Node3D
var raycast: RayCast3D
var player: Node3D

var rng := RandomNumberGenerator.new()
var random_target := Vector3.ZERO

func _ready() -> void:
	rng.randomize()

	# Get player
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("No player found in group 'player'!")

	# Load detector pivot
	if detector_pivot_path == NodePath(""):
		push_error("You MUST assign detector_pivot_path!")
	else:
		detector_pivot = get_node_or_null(detector_pivot_path)
		if detector_pivot == null:
			push_error("DetectorPivot node NOT found!")
		else:
			raycast = detector_pivot.get_node_or_null("RayCast3D")
			if raycast == null:
				push_error("RayCast3D is missing as a child of DetectorPivot!")

	if use_random_patrol:
		_pick_new_random_target()

	set_physics_process(true)


# ===========================
# MOVEMENT — RANDOM
# ===========================
func _pick_new_random_target() -> void:
	random_target = Vector3(
		rng.randf_range(min_x, max_x),
		flight_height,
		rng.randf_range(min_z, max_z)
	)

func _move_random(delta: float) -> void:
	var dir := random_target - global_position
	var dist := dir.length()

	if dist > 0.2:
		dir = dir.normalized()
		global_position += dir * speed * delta

		var flat := Vector3(dir.x, 0, dir.z)
		if flat.length() > 0.001:
			var target_yaw := atan2(flat.x, flat.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	else:
		_pick_new_random_target()


# ===========================
# MAIN LOOP
# ===========================
func _physics_process(delta: float) -> void:
	if use_random_patrol:
		_move_random(delta)

	_raycast_detect_player()


# ===========================
# DETECTION VIA RAYCAST
# ===========================
func _raycast_detect_player() -> void:
	if raycast == null:
		return

	if raycast.is_colliding():
		var collider = raycast.get_collider()

		if collider == player:
			print("🚨 Helicopter sees player at:", player.global_position)
			emit_signal("player_spotted", player.global_position)
			return
