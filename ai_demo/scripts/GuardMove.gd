extends Node

@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var floor_snap: float = 1.0
@export var max_slope_deg: float = 50.0
@export var move_speed: float = 3.0
@export var turn_speed: float = 8.0
@export var lookahead_m: float = 2.5
@export var chase_turn_boost: float = 1.6
@export var susp_turn_boost: float = 1.2

@onready var body: CharacterBody3D = get_parent()
@onready var agent: NavigationAgent3D = $"../NavigationAgent3D"
@onready var facing: Node3D = $"../Facing"

var _nav_ok := false
var _state := 0
var _player_pos := Vector3.ZERO

func _ready() -> void:
	body.floor_snap_length = floor_snap
	body.floor_max_angle = deg_to_rad(max_slope_deg)
	agent.max_speed = move_speed
	agent.path_max_distance = 2.5
	call_deferred("_wait_navmap")

func ready_for_nav() -> bool:
	return _nav_ok

func _wait_navmap() -> void:
	var rid := agent.get_navigation_map()
	while not (rid.is_valid() and NavigationServer3D.map_get_iteration_id(rid) > 0):
		await get_tree().process_frame
		rid = agent.get_navigation_map()
	_nav_ok = true

func set_target(p: Vector3) -> void:
	if not _nav_ok: return
	var rid := agent.get_navigation_map()
	if not (rid.is_valid() and NavigationServer3D.map_get_iteration_id(rid) > 0):
		return
	var cp := NavigationServer3D.map_get_closest_point(rid, p)
	print("Requested:", p, " snapped to:", cp)
	if agent.target_position.distance_to(cp) > 0.75:
		agent.target_position = cp

func clear_target() -> void:
	agent.target_position = body.global_transform.origin

func is_navigation_finished() -> bool:
	return agent.is_navigation_finished()

func get_next_path_position() -> Vector3:
	return agent.get_next_path_position()

func get_random_nav_point(radius: float) -> Vector3:
	if not _nav_ok:
		return body.global_transform.origin
	var rid := agent.get_navigation_map()
	if not (rid.is_valid() and NavigationServer3D.map_get_iteration_id(rid) > 0):
		return body.global_transform.origin
	var origin := body.global_transform.origin
	var dir := Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0)).normalized() * randf_range(5.0, radius)
	var p := NavigationServer3D.map_get_closest_point(rid, origin + dir)
	return p if p != Vector3.INF else origin

func tick(delta: float, state: int, player: Node3D) -> void:
	_state = state
	if player:
		_player_pos = player.global_transform.origin
	agent.velocity = Vector3(body.velocity.x, 0.0, body.velocity.z)

	var next_pos := agent.get_next_path_position()
	var to_next := next_pos - body.global_transform.origin
	to_next.y = 0.0

	if to_next.length() > 0.05:
		var dir := to_next.normalized()
		body.velocity.x = dir.x * move_speed
		body.velocity.z = dir.z * move_speed
	else:
		body.velocity.x = lerpf(body.velocity.x, 0.0, 0.2)
		body.velocity.z = lerpf(body.velocity.z, 0.0, 0.2)

	if not body.is_on_floor():
		body.velocity.y -= gravity * delta
	else:
		if body.velocity.y > 0.0:
			body.velocity.y = 0.0
		body.velocity.y -= gravity * delta * 0.1

	body.move_and_slide()
	_face_update(delta)

func _face_update(delta: float) -> void:
	var cand: Vector3 = Vector3.ZERO

	if _state == 2 and _player_pos != Vector3.ZERO:
		cand = _player_pos - body.global_transform.origin

	if cand.length() < 0.01:
		var vel2d: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
		if vel2d.length() > 0.05:
			cand = vel2d

	if cand.length() < 0.01:
		var np: Vector3 = agent.get_next_path_position()
		var to_np: Vector3 = np - body.global_transform.origin
		if to_np.length() > 0.01:
			var step: float = min(lookahead_m, to_np.length())
			cand = to_np.normalized() * step

	if cand.length() < 0.01:
		cand = agent.target_position - body.global_transform.origin
	if cand.length() < 0.01:
		cand = -facing.global_transform.basis.z

	cand.y = 0.0
	if cand.length() > 0.001:
		cand = cand.normalized()
		var yaw: float = atan2(-cand.x, -cand.z)
		var mul: float = 1.0
		if _state == 2:
			mul = chase_turn_boost
		elif _state == 1:
			mul = susp_turn_boost
		facing.rotation.y = lerp_angle(facing.rotation.y, yaw, (turn_speed * mul) * delta)
