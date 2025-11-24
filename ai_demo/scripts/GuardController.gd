extends CharacterBody3D

@export var susDecay: float = 0.35
@export var susRise: float = 0.8
@export var losLoseGrace: float = 1.0
@export var wander_interval: float = 3.0
@export var wander_radius: float = 20.0

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH, WANDER }

@onready var mover = $move
@onready var perception = $Perception
@onready var tasks = $TaskRunner
@onready var label: Label3D = $Facing/Label3D
@onready var sign_node: Label3D = $Facing/Sign


var patrol_points: Array[Vector3] = []
var patrol_idx := 0
var state: State = State.PATROL
var suspicion := 0.1
var lastKnown := Vector3.ZERO
var lostLosTimer := 0.0
var searchTtl := 0.0
var investigateTarget := Vector3.ZERO
var player: Node3D
var wander_timer := 0.0

func _ready() -> void:
	add_to_group("guards")
	for c in get_children():
		if c is Marker3D and c.name.begins_with("WP"):
			patrol_points.append(c.global_transform.origin)
	player = get_tree().get_first_node_in_group("player")
	perception.player_seen.connect(_on_player_seen)
	perception.player_visible.connect(_on_player_visible)
	perception.player_lost.connect(_on_player_lost)
	if patrol_points.is_empty():
		state = State.WANDER
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

	label.text = ["PATROL","SUSPICIOUS","CHASE","SEARCH","WANDER"][state] + "  S:" + str(snappedf(suspicion, 0.01))

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

func _update_state(delta: float) -> void:
	if not perception.is_visible():
		suspicion = clampf(suspicion - susDecay * delta, 0.0, 1.0)
		lostLosTimer += delta

	match state:
		State.PATROL:
			if perception.is_visible():
				state = State.CHASE
			elif suspicion > 0.35:
				state = State.SUSPICIOUS
		State.SUSPICIOUS:
			if perception.is_visible() or suspicion > 0.8 or (suspicion > 0.7 and lostLosTimer < 0.5):
				state = State.CHASE
				suspicion = 1.0
			elif suspicion <= 0.0:
				state = State.WANDER
		State.CHASE:
			if not perception.is_visible() and lostLosTimer > losLoseGrace:
				state = State.SEARCH
				searchTtl = 8.0
		State.SEARCH:
			searchTtl -= delta
			if perception.is_visible() or (lostLosTimer < 0.2 and suspicion > 0.35):
				state = State.CHASE
				suspicion = 1.0
			elif searchTtl <= 0.0:
				state = State.WANDER
		State.WANDER:
			if perception.is_visible():
				state = State.CHASE
				suspicion = 1.0
			elif suspicion > 0.35:
				state = State.SUSPICIOUS

func _drive_behavior(delta: float) -> void:
	match state:
		State.PATROL:
			if patrol_points.is_empty():
				return
			if mover.is_navigation_finished():
				patrol_idx = (patrol_idx + 1) % patrol_points.size()
				mover.set_target(patrol_points[patrol_idx])
		State.SUSPICIOUS:
			var tgt := Vector3.ZERO
			if investigateTarget != Vector3.ZERO:
				tgt = investigateTarget
			elif player:
				tgt = player.global_transform.origin
			if tgt != Vector3.ZERO:
				mover.set_target(tgt)
		State.CHASE:
			if player:
				mover.set_target(player.global_transform.origin)
		State.SEARCH:
			if tasks.is_busy():
				return
			var pts := []
			for i in range(5):
				var dir := Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0)).normalized() * randf_range(4.0, 10.0)
				pts.append(lastKnown + dir)
			tasks.set_sector_route(pts)
		State.WANDER:
			wander_timer -= delta
			if wander_timer <= 0.0 or mover.is_navigation_finished():
				var p: Vector3 = mover.get_random_nav_point(wander_radius)
				mover.set_target(p)
				wander_timer = wander_interval

func _run_tasks(delta: float) -> void:
	if tasks.is_busy():
		tasks.tick(delta, global_transform.origin)
		var t: Variant = tasks.current_target()
		if t is Vector3:
			mover.set_target(t as Vector3)


func is_busy() -> bool:
	return state == State.CHASE or state == State.SEARCH or tasks.is_busy()

func get_last_task_time() -> float:
	return tasks.get_last_task_time()

func set_task_investigate_sector_points(points: Array[Vector3]) -> void:
	tasks.set_sector_route(points)
	if state == State.PATROL or state == State.WANDER:
		state = State.SUSPICIOUS

func set_task_investigate_point(pos: Vector3, dwell_sec: float = 3.0) -> void:
	tasks.set_point_task(pos, dwell_sec)
	if state == State.PATROL or state == State.WANDER:
		state = State.SUSPICIOUS

func clear_task_and_return_to_beat() -> void:
	tasks.clear()
