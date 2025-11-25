extends CharacterBody3D

@export var susDecay: float = 0.35
@export var susRise: float = 0.8
@export var losLoseGrace: float = 1.0
@export var wander_interval: float = 3.0
@export var wander_radius: float = 20.0

# Soft/Hard alert tuning
@export var soft_alert_time: float = 6.0
@export var soft_thresh: float = 0.35
@export var hard_thresh: float = 0.80

enum State { PATROL, ALERT, CHASE }

@onready var mover = $move
@onready var perception = $Perception
@onready var tasks = $TaskRunner
@onready var overhead = $Facing/Overhead
@onready var label: Label3D = $Facing/Label3D
@onready var sign_node: Label3D = $Facing/Overhead/Sign

var patrol_points: Array[Vector3] = []
var patrol_idx := 0
var state: State = State.PATROL
var suspicion := 0.1
var lastKnown := Vector3.ZERO
var lostLosTimer := 0.0
var investigateTarget := Vector3.ZERO
var player: Node3D
var wander_timer := 0.0
var _sign_timer: float = 0.0
var _last_sign_state: int = -1
var alert_ttl := 0.0
var player_in_cone: bool = false

func _ready() -> void:
	add_to_group("guards")
	for c in get_children():
		if c is Marker3D and c.name.begins_with("WP"):
			patrol_points.append(c.global_transform.origin)

	player = get_tree().get_first_node_in_group("player") # ensure your Player is in group "player"

	perception.player_seen.connect(_on_player_seen)
	perception.player_visible.connect(_on_player_visible)
	perception.player_lost.connect(_on_player_lost)

	if patrol_points.is_empty():
		wander_timer = 0.0

func _physics_process(delta: float) -> void:
	if not mover.ready_for_nav():
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	perception.tick(delta, player, self)

	_update_state(delta)
	_drive_behavior(delta)
	_run_tasks(delta)

	mover.tick(delta, state, player)

	var state_text : String = ["PATROL","ALERT","CHASE"][state]
	var susp_text : String = "  S:" + str(snappedf(suspicion, 0.01))
	
	if player_in_cone:
		label.text = state_text + susp_text + "  [VC]"
	else:
		label.text = state_text + susp_text

# --- Perception events raise/maintain suspicion (hard alert comes from threshold) ---
func _on_player_seen(pos: Vector3) -> void:
	suspicion = 1.0
	lastKnown = pos
	lostLosTimer = 0.0
	state = State.CHASE

func _on_player_visible(pos: Vector3) -> void:
	suspicion = clampf(suspicion + susRise * get_physics_process_delta_time(), 0.0, 1.0)
	lastKnown = pos
	lostLosTimer = 0.0

func _on_player_lost(pos: Vector3) -> void:
	lastKnown = pos

# --- FSM (3 states: PATROL, ALERT, CHASE). Soft vs hard alert = suspicion thresholds ---
func _update_state(delta: float) -> void:
	if not perception.is_visible():
		suspicion = clampf(suspicion - susDecay * delta, 0.0, 1.0)
		lostLosTimer += delta

	# Any time we clearly see the player → CHASE immediately
	if perception.is_visible():
		state = State.CHASE
		suspicion = 1.0
		lostLosTimer = 0.0
		return

	match state:
		State.PATROL:
			# Soft alert triggers: rising suspicion or a clue to check
			if suspicion > soft_thresh or investigateTarget != Vector3.ZERO:
				state = State.ALERT
				alert_ttl = soft_alert_time

		State.ALERT:
			alert_ttl -= delta
			# Escalate to hard alert (CHASE) if suspicion crosses hard threshold
			if suspicion > hard_thresh:
				state = State.CHASE
				suspicion = 1.0
				return
			# Lost track long enough? keep alerting but decay to PATROL when TTL ends
			if alert_ttl <= 0.0:
				state = State.PATROL
				investigateTarget = Vector3.ZERO

		State.CHASE:
			# If we’ve lost LoS for a while, drop to soft alert at LKP
			if lostLosTimer > losLoseGrace:
				state = State.ALERT
				alert_ttl = soft_alert_time

# --- Behavior driving per state ---
func _drive_behavior(delta: float) -> void:
	match state:
		State.PATROL:
			# If a task is active (e.g., director route) let it drive movement
			if tasks.is_busy():
				return
			# Simple: cycle WPs if present; (swap to your dynamic patrol when ready)
			if patrol_points.is_empty():
				return
			if mover.is_navigation_finished():
				patrol_idx = (patrol_idx + 1) % patrol_points.size()
				mover.set_target(patrol_points[patrol_idx])
			_hide_sign()

		State.ALERT:
			# Follow a clue (investigateTarget) or last known position; tasks can also feed points
			if tasks.is_busy():
				return
			var tgt := Vector3.ZERO
			if investigateTarget != Vector3.ZERO:
				tgt = investigateTarget
			elif lastKnown != Vector3.ZERO:
				tgt = lastKnown
			if tgt != Vector3.ZERO:
				mover.set_target(tgt)
			if _last_sign_state != State.ALERT:
				_show_sign("?", Color(1.0, 0.9, 0.2), 1.0)
				_last_sign_state = State.ALERT

		State.CHASE:
			if player:
				mover.set_target(player.global_transform.origin)
			if _last_sign_state != State.CHASE:
				_show_sign("!", Color(1.0, 0.25, 0.25), 0.8)
				_last_sign_state = State.CHASE

# --- Tasks (sector routes / points) ---
func _run_tasks(delta: float) -> void:
	if not tasks.is_busy():
		return
	tasks.tick(delta, global_transform.origin)
	var t: Variant = tasks.current_target()
	if t is Vector3:
		mover.set_target(t as Vector3)

func is_busy() -> bool:
	return state == State.CHASE or tasks.is_busy()

func get_last_task_time() -> float:
	return tasks.get_last_task_time()

func set_task_investigate_sector_points(points: Array[Vector3]) -> void:
	tasks.set_sector_route(points)
	if state == State.PATROL:
		state = State.ALERT
		alert_ttl = soft_alert_time

func set_task_investigate_point(pos: Vector3, dwell_sec: float = 3.0) -> void:
	tasks.set_point_task(pos, dwell_sec)
	if state == State.PATROL:
		state = State.ALERT
		alert_ttl = soft_alert_time

func clear_task_and_return_to_beat() -> void:
	tasks.clear()

# --- Signs (! / ?) ---
func _show_sign(txt: String, col: Color, dur: float, pop: bool = true) -> void:
	sign_node.text = txt
	sign_node.modulate = col
	sign_node.visible = true
	_sign_timer = dur

	var tw = create_tween()
	if pop:
		overhead.scale = Vector3.ONE * 0.6
		tw.tween_property(overhead, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur)
	tw.tween_property(sign_node, "modulate:a", 0.0, 0.25)
	tw.tween_callback(Callable(self, "_hide_sign"))

func _hide_sign() -> void:
	sign_node.visible = false
	sign_node.modulate.a = 1.0
	overhead.scale = Vector3.ONE
	_sign_timer = 0.0
	_last_sign_state = -1


func _on_vision_cone_3d_body_hidden(body: Node3D) -> void:
	if body == player:
		player_in_cone = false
	pass # Replace with function body.


func _on_vision_cone_3d_body_sighted(body: Node3D) -> void:
	if body == player:
		player_in_cone = true
		state = State.CHASE
		print("PLAYER IN VISION CONE")
	pass # Replace with function body.
