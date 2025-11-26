extends Node3D

@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 3.0
@export var flee_distance: float = 20.0
@export var flee_speed: float = 10.0

var birds_root: Node3D
var trigger_area: Area3D

var current_angle: float = 0.0
var is_fleeing: bool = false
var flee_target: Vector3
var flee_done: bool = false

func _ready() -> void:
	birds_root = $Birds
	trigger_area = $TriggerArea

	if birds_root.get_child_count() == 0:
		push_warning("❌ No birds found under BirdFlock/Birds!")
	else:
		print("🕊 Bird flock initialized with ", birds_root.get_child_count(), " birds.")

	# Connect detection signals
	trigger_area.body_entered.connect(_on_player_enter)
	trigger_area.body_exited.connect(_on_player_exit)


func _physics_process(delta: float) -> void:
	# ALWAYS move the trigger area with the flock center
	trigger_area.global_position = global_position

	if is_fleeing:
		_process_flee(delta)
	else:
		_process_idle_orbit(delta)


# ---------------------------------------------------------
# 🟢 IDLE ORBITING
# ---------------------------------------------------------
func _process_idle_orbit(delta: float) -> void:
	current_angle += orbit_speed * delta
	var center := global_position

	for bird in birds_root.get_children():
		var bx = center.x + orbit_radius * cos(current_angle)
		var bz = center.z + orbit_radius * sin(current_angle)
		var by = center.y + orbit_height
		bird.global_position = Vector3(bx, by, bz)

		bird.look_at(center, Vector3.UP)
		bird.rotate_y(deg_to_rad(90))  # Model alignment fix


# ---------------------------------------------------------
# 🔴 FLEE LOGIC
# ---------------------------------------------------------
func _start_flee_from(player_pos: Vector3) -> void:
	if is_fleeing:
		return

	is_fleeing = true
	flee_done = false

	# Pick a random horizontal flee direction
	var random_angle: float = randf() * TAU
	flee_target = global_position + Vector3(
		cos(random_angle) * flee_distance,
		0,
		sin(random_angle) * flee_distance
	)

	print("🕊 Birds fleeing toward:", flee_target)


func _process_flee(delta: float) -> void:
	if not flee_done:
		# -----------------------------
		# Move the FLOCK CENTER first!
		# -----------------------------
		var dir: Vector3 = flee_target - global_position
		var horiz := Vector3(dir.x, 0, dir.z)
		var dist := horiz.length()

		if dist > 0.1:
			horiz = horiz.normalized()
			global_position += horiz * flee_speed * delta
		else:
			# We reached the new location → switch to orbit mode
			flee_done = true
			is_fleeing = false
			print("🕊 Birds arrived. Resuming idle orbit.")

	# Birds now orbit around updated global_position as usual
	_process_idle_orbit(delta)


# ---------------------------------------------------------
# 🟠 DETECTION
# ---------------------------------------------------------
func _on_player_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	print("🟥 Bird flock detected the player!")

	# Send alert to guards via blackboard
	var bb = get_node("/root/Blackboard")
	bb.add_noise(
		body.global_position,
		100.0,   # Alert radius
		5.0      # Alert duration
	)

	print("🟦 Bird alert sent to guards.")

	_start_flee_from(body.global_position)


func _on_player_exit(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	print("⬜ Player left the bird flock.")
