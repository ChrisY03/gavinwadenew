extends Node3D

# ===========================
# ORBIT SETTINGS
# ===========================
@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 3.0

var angle := 0.0

# ===========================
# FLEE SETTINGS
# ===========================
@export var flee_distance: float = 20.0
@export var flee_speed: float = 8.0
@export var flee_height: float = 7.0     # how high they rise when fleeing
@export var flee_duration: float = 4.0   # how long fleeing lasts

var flee_timer := 0.0
var is_fleeing := false
var flee_target := Vector3.ZERO
var base_height: float = 0.0

# ===========================
# TERRAIN LIMITS
# ===========================
@export var min_x: float = -80
@export var max_x: float = 80
@export var min_z: float = -80
@export var max_z: float = 80

# ===========================
# INTERNAL NODES
# ===========================
var birds_root: Node3D
var trigger_area: Area3D


# ===========================
# READY
# ===========================
func _ready():
	birds_root = $Birds
	trigger_area = $TriggerArea

	base_height = global_position.y  # remember starting height

	# Connect signals
	trigger_area.body_entered.connect(_on_player_enter)
	trigger_area.body_exited.connect(_on_player_exit)


# ===========================
# PHYSICS
# ===========================
func _physics_process(delta):
	# Always follow flock center
	trigger_area.global_position = global_position

	if is_fleeing:
		_process_flee(delta)
	else:
		_process_orbit(delta)


# ===========================
# ORBIT MOVEMENT
# ===========================
func _process_orbit(delta):
	angle += orbit_speed * delta
	var center := global_position

	for bird in birds_root.get_children():
		var x = center.x + orbit_radius * cos(angle)
		var z = center.z + orbit_radius * sin(angle)
		var y = center.y + orbit_height

		bird.global_position = Vector3(x, y, z)
		bird.look_at(center, Vector3.UP)


# ===========================
# START FLEE
# ===========================
func _start_flee_from(_player_pos: Vector3):
	if is_fleeing:
		return

	is_fleeing = true
	flee_timer = flee_duration

	var angle := randf() * TAU

	# Random direction on the ground
	flee_target = global_position + Vector3(
		cos(angle) * flee_distance,
		0,
		sin(angle) * flee_distance
	)

	# Clamp to terrain
	flee_target.x = clamp(flee_target.x, min_x, max_x)
	flee_target.z = clamp(flee_target.z, min_z, max_z)

	print("🕊 Birds fleeing toward:", flee_target)


# ===========================
# FLEE MOVEMENT
# ===========================
func _process_flee(delta):
	flee_timer -= delta

	# ----------------------
	# END OF FLEE → LOWER FLOCK TO GROUND
	# ----------------------
	if flee_timer <= 0.0:
		is_fleeing = false

		print("🕊 Birds calming down. Returning to normal height.")

		# ⭐ FIX: Restore original height
		global_position.y = base_height

		return

	# Flee movement target (slightly above flee target)
	var target := flee_target + Vector3(0, flee_height, 0)

	var dir: Vector3 = target - global_position

	if dir.length() > 0.1:
		dir = dir.normalized()
		global_position += dir * flee_speed * delta

	# Clamp to terrain
	global_position.x = clamp(global_position.x, min_x, max_x)
	global_position.z = clamp(global_position.z, min_z, max_z)


# ===========================
# PLAYER ENTER
# ===========================
func _on_player_enter(body: Node3D):
	if body.is_in_group("player"):
		print("🟥 Bird flock detected the player!")

		# Blackboard alert
		var bb = get_node("/root/Blackboard")
		bb.add_noise(global_position, 50.0, 5.0)

		print("📣 Bird alert sent to guards.")

		_start_flee_from(body.global_position)


# ===========================
# PLAYER EXIT
# ===========================
func _on_player_exit(body: Node3D):
	if body.is_in_group("player"):
		print("🟦 Player left the bird flock.")
