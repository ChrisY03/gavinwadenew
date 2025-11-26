extends CharacterBody3D

# --- Movement / nav params ---
@export var move_speed: float = 4.0
@export var turn_speed: float = 8.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

# --- Patrol params ---
@export var patrol_reached_radius: float = 1.5
@export var patrol_idle_time: float = 2.0

# --- Alert params ---
@export var alert_reached_radius: float = 2.0      # how close to LKP counts as "arrived"
@export var alert_scan_time: float = 3.0           # how long to stand & scan
@export var alert_scan_speed_deg: float = 30.0     # degrees/sec while scanning

@export var alert_max_time: float = 12.0        # total time to stay in ALERT
@export var alert_points_per_sector: int = 4    # how many extra points in that sector

var _alert_search_points: Array[Vector3] = []
var _alert_search_idx: int = 0
var _alert_total_timer: float = 0.0
var _alert_scanning: bool = false
var _alert_scan_timer: float = 0.0

# --- Chase retarget params ---
@export var chase_retarget_interval: float = 0.2   # seconds
@export var chase_retarget_dist: float = 1.0       # meters

# --- State machine ---
enum State { PATROL, ALERT, CHASE }
var state: State = State.PATROL

# --- References ---
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var perception = $Perception
@onready var label: Label3D = $Facing/Label3D

var player: Node3D
var last_known: Vector3 = Vector3.ZERO

# Patrol state
var patrol_target: Vector3 = Vector3.ZERO
var patrol_has_target: bool = false
var patrol_idle_timer: float = 0.0

# Alert state
var _alert_target: Vector3 = Vector3.ZERO



# Nav bookkeeping
var _nav_ready: bool = false
var _last_target_set: Vector3 = Vector3.INF
var _last_set_time: float = 0.0


func _ready() -> void:
	add_to_group("guards")

	player = get_tree().get_first_node_in_group("player")

	perception.player_seen.connect(_on_player_seen)
	perception.player_lost.connect(_on_player_lost)

	# Basic nav agent tuning
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.5
	agent.avoidance_enabled = false

	# Wait until navigation map is ready
	call_deferred("_await_nav_ready")


func _await_nav_ready() -> void:
	var rid := agent.get_navigation_map()
	while not (rid.is_valid() and NavigationServer3D.map_get_iteration_id(rid) > 0):
		await get_tree().process_frame
		rid = agent.get_navigation_map()

	_nav_ready = true
	# Start with a valid target (current position)
	agent.target_position = global_transform.origin


func _physics_process(delta: float) -> void:
	if not _nav_ready:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	_update_state(delta)
	_update_targets(delta)
	_move_along_path(delta)

	if label:
		label.text = ["PATROL", "ALERT", "CHASE"][state]


# --- Perception callbacks ----------------------------------------------------

func _on_player_seen(pos: Vector3) -> void:
	last_known = pos
	state = State.CHASE
	_alert_scanning = false
	Director.push_event("lkp", pos)


func _on_player_lost(pos: Vector3) -> void:
	last_known = pos
	_alert_target = pos
	_alert_scanning = false
	Director.push_event("lkp", pos)
	# State change handled in _update_state


# --- State machine -----------------------------------------------------------

func _update_state(delta: float) -> void:
	if perception.is_visible():
		state = State.CHASE
		return

	match state:
		State.CHASE:
			# Just lost LOS → go into ALERT and head to last known position
			state = State.ALERT
			_alert_target = last_known
			_alert_scanning = false
			_alert_scan_timer = alert_scan_time
			_start_alert_search()

		State.ALERT:
			# Transitions (back to PATROL) handled in alert logic
			pass

		State.PATROL:
			# Pure patrol; transitions only from CHASE/ALERT
			pass


# --- Target selection per state ---------------------------------------------

func _update_targets(delta: float) -> void:
	match state:
		State.PATROL:
			_update_patrol_target(delta)

		State.ALERT:
			_update_alert_target(delta)

		State.CHASE:
			_update_chase_target(delta)

func _start_alert_search() -> void:
	_alert_search_points.clear()
	_alert_search_idx = 0
	_alert_total_timer = alert_max_time
	_alert_scanning = false
	_alert_scan_timer = 0.0

	var sid := Sector.id_at(last_known)
	if sid != -1:
		# Always start at last known position
		_alert_search_points.append(last_known)

		# Then add a few random points in that same sector
		for i in range(alert_points_per_sector):
			_alert_search_points.append(Sector.random_point_in(sid))
	else:
		# Fallback: just search around last_known even if sector failed
		_alert_search_points.append(last_known)



func _update_patrol_target(delta: float) -> void:
	# If we already have a target and path, keep going
	if patrol_has_target and not agent.is_navigation_finished():
		return

	# Reached patrol target → idle a bit before new one
	if patrol_has_target and agent.is_navigation_finished():
		patrol_idle_timer -= delta
		if patrol_idle_timer > 0.0:
			return
		patrol_has_target = false

	# Ask Director for a new patrol point on the sector grid
	var p: Vector3 = Director.get_patrol_point()
	if p == Vector3.ZERO:
		return

	patrol_target = p
	patrol_has_target = true
	patrol_idle_timer = patrol_idle_time
	_set_agent_target(p)


func _update_alert_target(delta: float) -> void:
	# If we magically see the player again, CHASE logic will take over
	if perception.is_visible():
		return

	# Global timeout on ALERT
	_alert_total_timer -= delta
	if _alert_total_timer <= 0.0:
		_alert_scanning = false
		state = State.PATROL
		patrol_has_target = false
		return

	# No points? Just bail back to patrol
	if _alert_search_points.is_empty():
		state = State.PATROL
		patrol_has_target = false
		return

	# If currently scanning in place at a point
	if _alert_scanning:
		_alert_scan_timer -= delta
		if _alert_scan_timer <= 0.0:
			_alert_scanning = false
			_alert_search_idx += 1
			if _alert_search_idx >= _alert_search_points.size():
				# Finished all waypoints
				state = State.PATROL
				patrol_has_target = false
			# Next frame we'll move toward the next point if any
		return

	# Not scanning → move toward the current search point
	var target := _alert_search_points[_alert_search_idx]
	var to_target := target - global_transform.origin
	to_target.y = 0.0

	if to_target.length() > alert_reached_radius:
		_set_agent_target(target)
	else:
		# Arrived at this search point → start scanning here
		_alert_scanning = true
		_alert_scan_timer = alert_scan_time
		_set_agent_target(global_transform.origin) # stop at this spot



func _update_chase_target(delta: float) -> void:
	if player == null:
		return

	var p := player.global_transform.origin
	var now := Time.get_unix_time_from_system()

	var need_time := (now - _last_set_time) >= chase_retarget_interval
	var need_dist := (_last_target_set == Vector3.INF) or (p.distance_to(_last_target_set) >= chase_retarget_dist)

	if need_time or need_dist:
		_set_agent_target(p)


func _set_agent_target(p: Vector3) -> void:
	_last_set_time = Time.get_unix_time_from_system()
	_last_target_set = p

	var rid := agent.get_navigation_map()
	if not rid.is_valid():
		return

	# Snap to closest point on nav to avoid edge weirdness
	var closest := NavigationServer3D.map_get_closest_point(rid, p)
	if closest == Vector3.INF:
		return

	# Avoid thrashing if basically same target
	if agent.target_position.distance_to(closest) > 0.1:
		agent.target_position = closest


# --- Movement along nav path + alert scanning --------------------------------

func _move_along_path(delta: float) -> void:
	var vel := velocity

	if agent.is_navigation_finished():
		# Special case: ALERT scanning in place
		if state == State.ALERT and _alert_scanning:
			# Slow spin while scanning
			rotation.y += deg_to_rad(alert_scan_speed_deg) * delta

			vel.x = lerp(vel.x, 0.0, 0.2)
			vel.z = lerp(vel.z, 0.0, 0.2)
		else:
			# No path / reached target → slow to stop
			vel.x = lerp(vel.x, 0.0, 0.2)
			vel.z = lerp(vel.z, 0.0, 0.2)
	else:
		var next_pos := agent.get_next_path_position()
		var to_next := next_pos - global_transform.origin
		to_next.y = 0.0

		if to_next.length() > 0.05:
			var dir := to_next.normalized()
			vel.x = dir.x * move_speed
			vel.z = dir.z * move_speed

			# Rotate towards path direction
			var target_yaw := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
		else:
			vel.x = lerp(vel.x, 0.0, 0.2)
			vel.z = lerp(vel.z, 0.0, 0.2)

	# Gravity
	if not is_on_floor():
		vel.y -= gravity * delta
	else:
		if vel.y > 0.0:
			vel.y = 0.0
		vel.y -= gravity * delta * 0.1

	velocity = vel
	move_and_slide()
