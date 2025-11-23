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
# SPOTLIGHT DETECTION SETTINGS
#
@export var spotlight_path: NodePath
@export var debug_print_detection: bool = true
@export var use_noisy_reports: bool = true
@export var sighting_noise_radius: float = 5.0

var spotlight: SpotLight3D
var player: Node3D = null
var rng := RandomNumberGenerator.new()
var current_target_index := 0
var random_target := Vector3.ZERO
var debug_timer := 0.0


func _ready() -> void:
	rng.randomize()
	set_physics_process(true)

	player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("No node in group 'player' found!")

	# Load spotlight
	if spotlight_path != NodePath():
		spotlight = get_node_or_null(spotlight_path)
		if spotlight == null:
			push_warning("Spotlight path is invalid!")
	else:
		push_warning("You must assign spotlight_path in the inspector!")

	# Setup first patrol target
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


# ===============================
# MOVEMENT — RANDOM
# ===============================
func _pick_new_random_target() -> void:
	var x := rng.randf_range(min_x, max_x)
	var z := rng.randf_range(min_z, max_z)
	random_target = Vector3(x, flight_height, z)


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


# ===============================
# MOVEMENT — WAYPOINTS
# ===============================
func _move_waypoints(delta: float) -> void:
	if patrol_points.is_empty(): return

	var t: Node3D = get_node_or_null(patrol_points[current_target_index])
	if t == null: return

	var dir := t.global_position - global_position
	var dist := dir.length()

	if dist > 0.2:
		dir = dir.normalized()
		global_position += dir * speed * delta

		var flat := Vector3(dir.x, 0, dir.z)
		if flat.length() > 0.001:
			var target_yaw := atan2(flat.x, flat.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
	else:
		current_target_index = (current_target_index + 1) % patrol_points.size()


# ===============================
# SPOTLIGHT DETECTION
# ===============================
func _check_spotlight_detection() -> void:
	if spotlight == null or player == null:
		return

	var to_player := player.global_position - spotlight.global_position
	var dist := to_player.length()

	if dist > spotlight.spot_range:
		return

	var forward := -spotlight.global_transform.basis.z.normalized()
	var angle_rad := forward.angle_to(to_player.normalized())
	var half_angle := deg_to_rad(spotlight.spot_angle * 0.5)

	if angle_rad > half_angle:
		return

	if debug_print_detection:
		print("🚨 Helicopter sees player at:", player.global_position)

	emit_signal("player_spotted", player.global_position)
	_notify_guards(player.global_position)


# ===============================
# NOTIFY GUARDS & BLACKBOARD
# ===============================
func _notify_guards(player_pos: Vector3) -> void:
	var reported := player_pos

	if use_noisy_reports:
		reported.x += rng.randf_range(-sighting_noise_radius, sighting_noise_radius)
		reported.z += rng.randf_range(-sighting_noise_radius, sighting_noise_radius)

	# Blackboard alert
	if Engine.has_singleton("Blackboard"):
		Blackboard.add_noise(player_pos, sighting_noise_radius, 5.0)

	# Notify guards
	for g in get_tree().get_nodes_in_group("guards"):
		if g.has_method("on_player_spotted"):
			g.on_player_spotted(reported)
