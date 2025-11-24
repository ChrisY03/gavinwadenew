extends Node3D

signal player_spotted(player_position: Vector3)

#
# MOVEMENT SETTINGS
#
@export var speed: float = 10.0
@export var rotation_speed: float = 3.0

@export var use_random_patrol: bool = true
@export var patrol_points: Array[NodePath] = []

@export var min_x: float = -50.0
@export var max_x: float = 50.0
@export var min_z: float = -50.0
@export var max_z: float = 50.0
@export var flight_height: float = 40.0

#
# SPOTLIGHT SETTINGS
#
@export var spotlight_path: NodePath
@export var debug_print_detection: bool = true
@export var use_noisy_reports: bool = true
@export var sighting_noise_radius: float = 5.0

var spotlight: SpotLight3D
var player: Node3D
var rng := RandomNumberGenerator.new()

var current_target_index: int = 0
var random_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	rng.randomize()
	set_physics_process(true)

	# --- Load Player ---
	player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("No node in group 'player' found!")

	# --- Load Spotlight ---
	if spotlight_path != NodePath():
		spotlight = get_node_or_null(spotlight_path) as SpotLight3D
		if spotlight == null:
			push_warning("Invalid spotlight_path assignment!")
	else:
		push_warning("spotlight_path is EMPTY in the Inspector!")

	# Start patrol system
	if use_random_patrol:
		_pick_new_random_target()
	else:
		current_target_index = 0


func _physics_process(delta: float) -> void:
	if use_random_patrol:
		_move_random(delta)
	else:
		_move_waypoints(delta)

	_check_spotlight_detection()


# -------------------------------------------------------
# RANDOM MOVEMENT
# -------------------------------------------------------
func _pick_new_random_target() -> void:
	var x: float = rng.randf_range(min_x, max_x)
	var z: float = rng.randf_range(min_z, max_z)
	random_target = Vector3(x, flight_height, z)


func _move_random(delta: float) -> void:
	var dir: Vector3 = random_target - global_position
	var dist: float = dir.length()

	if dist > 0.2:
		dir = dir.normalized()
		global_position += dir * speed * delta

		var flat: Vector3 = Vector3(dir.x, 0, dir.z)
		if flat.length() > 0.001:
			var yaw: float = atan2(flat.x, flat.z)
			rotation.y = lerp_angle(rotation.y, yaw, rotation_speed * delta)
	else:
		_pick_new_random_target()


# -------------------------------------------------------
# WAYPOINT MOVEMENT
# -------------------------------------------------------
func _move_waypoints(delta: float) -> void:
	if patrol_points.is_empty(): return

	var t: Node3D = get_node_or_null(patrol_points[current_target_index]) as Node3D
	if t == null: return

	var dir: Vector3 = t.global_position - global_position
	var dist: float = dir.length()

	if dist > 0.2:
		dir = dir.normalized()
		global_position += dir * speed * delta

		var flat: Vector3 = Vector3(dir.x, 0, dir.z)
		if flat.length() > 0.001:
			var yaw: float = atan2(flat.x, flat.z)
			rotation.y = lerp_angle(rotation.y, yaw, rotation_speed * delta)
	else:
		current_target_index = (current_target_index + 1) % patrol_points.size()


# -------------------------------------------------------
# SPOTLIGHT DETECTION
# -------------------------------------------------------
func _check_spotlight_detection() -> void:
	if spotlight == null or player == null:
		return

	var to_player: Vector3 = player.global_position - spotlight.global_position
	var dist: float = to_player.length()

	# Distance check
	if dist > spotlight.spot_range:
		return

	# Spotlight forward vector (spotlight looks DOWN its -Z direction normally)
	var forward: Vector3 = -spotlight.global_transform.basis.z.normalized()
	var angle_rad: float = forward.angle_to(to_player.normalized())
	var half_angle: float = deg_to_rad(spotlight.spot_angle * 0.5)

	# Cone check
	if angle_rad > half_angle:
		return

	# Detection SUCCESS
	if debug_print_detection:
		print("🚨 Helicopter sees player at:", player.global_position)

	emit_signal("player_spotted", player.global_position)
	_notify_guards(player.global_position)


# -------------------------------------------------------
# GUARD ALERTING + BLACKBOARD
# -------------------------------------------------------
func _notify_guards(player_pos: Vector3) -> void:
	var reported: Vector3 = player_pos

	if use_noisy_reports:
		reported.x += rng.randf_range(-sighting_noise_radius, sighting_noise_radius)
		reported.z += rng.randf_range(-sighting_noise_radius, sighting_noise_radius)

	# Blackboard (if used by your AI system)
	if Engine.has_singleton("Blackboard"):
		Blackboard.add_noise(player_pos, sighting_noise_radius, 5.0)

	# Notify guards with on_player_spotted()
	for g in get_tree().get_nodes_in_group("guards"):
		if g.has_method("on_player_spotted"):
			g.on_player_spotted(reported)
