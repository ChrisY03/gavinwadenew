extends CharacterBody3D

# --- Simple movement params ---
@export var move_speed: float = 4.0
@export var turn_speed: float = 8.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

@export var patrol_reached_radius: float = 1.5
@export var patrol_idle_time: float = 2.0

var patrol_target: Vector3 = Vector3.ZERO
var patrol_has_target: bool = false
var patrol_idle_timer: float = 0.0

# --- Simple state machine ---
enum State { PATROL, ALERT, CHASE }
var state: State = State.PATROL

@export var alert_duration: float = 3.0  # how long we stay ALERT after losing sight
var _alert_timer: float = 0.0

# --- References ---
@onready var perception = $Perception
@onready var label: Label3D = $Facing/Label3D

var player: Node3D
var last_known: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("guards")

	player = get_tree().get_first_node_in_group("player")

	# Hook seen/lost from perception
	perception.player_seen.connect(_on_player_seen)
	perception.player_lost.connect(_on_player_lost)


func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	_update_state(delta)
	_update_movement(delta)

	if label:
		label.text = ["PATROL", "ALERT", "CHASE"][state]


# --- Perception callbacks ----------------------------------------------------

func _on_player_seen(pos: Vector3) -> void:
	last_known = pos
	state = State.CHASE
	
	if Engine.has_singleton("Director"):
		Director.push_event("lkp", pos)

func _on_player_lost(pos: Vector3) -> void:
	last_known = pos
	# _update_state will transition to ALERT
	last_known = pos
	if Engine.has_singleton("Director"):
		Director.push_event("lkp", pos)
	# _update_state will transition to ALERT


# --- State machine -----------------------------------------------------------

func _update_state(delta: float) -> void:
	if perception.is_visible():
		# If we see the player at all, we chase.
		state = State.CHASE
		_alert_timer = 0.0
	else:
		match state:
			State.CHASE:
				# Just lost sight -> go into ALERT
				state = State.ALERT
				_alert_timer = alert_duration

			State.ALERT:
				_alert_timer -= delta
				if _alert_timer <= 0.0:
					state = State.PATROL

			State.PATROL:
				# idle / patrol logic handled in movement
				pass


# --- Movement / facing -------------------------------------------------------

func _update_movement(delta: float) -> void:
	var vel := velocity

	match state:
		State.PATROL, State.ALERT:
			_ensure_patrol_target(delta)

			if patrol_has_target:
				var target := patrol_target
				var to_target := target - global_transform.origin
				to_target.y = 0.0

				if to_target.length() > 0.05:
					var dir := to_target.normalized()
					vel.x = dir.x * move_speed
					vel.z = dir.z * move_speed

					# Face patrol target
					var look_target := Vector3(target.x, global_transform.origin.y, target.z)
					look_at(look_target, Vector3.UP)
				else:
					vel.x = lerp(vel.x, 0.0, 0.25)
					vel.z = lerp(vel.z, 0.0, 0.25)
			else:
				vel.x = lerp(vel.x, 0.0, 0.25)
				vel.z = lerp(vel.z, 0.0, 0.25)

		State.CHASE:
			if player:
				var to_player := player.global_transform.origin - global_transform.origin
				to_player.y = 0.0
				var dist := to_player.length()

				if dist > 0.1:
					var dir := to_player.normalized()
					vel.x = dir.x * move_speed
					vel.z = dir.z * move_speed

					# Face movement direction
					var target_yaw := atan2(-dir.x, -dir.z)
					rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
				else:
					vel.x = 0.0
					vel.z = 0.0
			else:
				vel.x = 0.0
				vel.z = 0.0

	# Gravity
	if not is_on_floor():
		vel.y -= gravity * delta
	else:
		if vel.y > 0.0:
			vel.y = 0.0
		# tiny downward bias to stay snapped
		vel.y -= gravity * delta * 0.1

	velocity = vel
	move_and_slide()


func _ensure_patrol_target(delta: float) -> void:
	# Already have a target and not there yet -> keep it
	if patrol_has_target and global_transform.origin.distance_to(patrol_target) > patrol_reached_radius:
		return

	# Reached target: idle a bit, then pick a new sector
	if patrol_has_target:
		patrol_idle_timer -= delta
		if patrol_idle_timer > 0.0:
			return
		patrol_has_target = false

	# Ask the Director singleton (autoload) for a new patrol point
	if not Engine.has_singleton("Director"):
	
		return

	var p: Vector3 = Director.get_patrol_point()
	if p == Vector3.ZERO:
		print("Guard: Director.get_patrol_point() returned ZERO - no patrol sectors/points?")
		return

	patrol_target = p
	patrol_has_target = true
	patrol_idle_timer = patrol_idle_time
	print("Guard: new patrol target from Director = ", p)
