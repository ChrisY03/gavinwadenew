extends Node3D

# ===========================
# ORBIT SETTINGS
# ===========================
@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 3.0

var angle: float = 0.0

# ===========================
# FLEE SETTINGS
# ===========================
@export var flee_distance: float = 20.0
@export var flee_speed: float = 8.0
@export var flee_height: float = 7.0
@export var flee_duration: float = 4.0

var flee_timer: float = 0.0
var is_fleeing: bool = false
var flee_target: Vector3 = Vector3.ZERO

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
var ground_check: RayCast3D
var alert_sound: AudioStreamPlayer3D

# ===========================
# READY
# ===========================
func _ready():
	birds_root = $Birds
	trigger_area = $TriggerArea
	ground_check = $GroundCheck
	alert_sound = $BirdAlertSound

	# Connect signals
	trigger_area.body_entered.connect(_on_player_enter)
	trigger_area.body_exited.connect(_on_player_exit)

	# Register with FlockManager autoload
	if Engine.has_singleton("FlockManager"):
		FlockManager.register_flock(self)
	else:
		push_warning("⚠ FlockManager autoload not found!")

	# Safety checks
	if ground_check == null:
		push_error("❌ Missing GroundCheck RayCast3D!")
	if alert_sound == null:
		push_error("❌ Missing BirdAlertSound node!")

# ===========================
# PHYSICS PROCESS
# ===========================
func _physics_process(delta):
	trigger_area.global_position = global_position
	_update_ground_height()

	if is_fleeing:
		_process_flee(delta)
	else:
		_process_orbit(delta)

# ===========================
# TERRAIN HEIGHT ADJUSTMENT
# ===========================
func _update_ground_height():
	ground_check.global_position = global_position + Vector3(0, 50, 0)

	if ground_check.is_colliding():
		var terrain_y := ground_check.get_collision_point().y
		global_position.y = terrain_y + orbit_height

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
# START FLEEING
# ===========================
func _start_flee_from(player_pos: Vector3):
	if is_fleeing:
		return

	is_fleeing = true
	flee_timer = flee_duration

	var away := (global_position - player_pos).normalized()
	var flee_strength := randf_range(flee_distance, flee_distance * 3.0)
	var desired_target := global_position + away * flee_strength

	# Request SAFE target
	var safe_target := FlockManager.request_valid_target(desired_target)
	flee_target = safe_target

	# Reserve this target
	FlockManager.reserve_target(flee_target)

	print("🕊 Birds fleeing to:", flee_target)

# ===========================
# FLEE MOVEMENT
# ===========================
func _process_flee(delta):
	flee_timer -= delta

	if flee_timer <= 0.0:
		is_fleeing = false
		print("🕊 Birds calm — returning to orbit.")

		# Release reserved target
		FlockManager.release_target(flee_target)
		return

	var target := flee_target + Vector3(0, flee_height, 0)
	var dir := target - global_position

	if dir.length() > 0.1:
		dir = dir.normalized()
		global_position += dir * flee_speed * delta

	global_position.x = clamp(global_position.x, min_x, max_x)
	global_position.z = clamp(global_position.z, min_z, max_z)

# ===========================
# SIGNAL: PLAYER ENTER AREA
# ===========================
func _on_player_enter(body: Node3D):
	if not body.is_in_group("player"):
		return

	print("🟥 Bird flock detected the player!")

	if alert_sound:
		alert_sound.play()

	var bb = get_node("/root/Blackboard")
	bb.add_noise(global_position, 50.0, 5.0)
	print("📣 Bird alert sent to guards.")

	_start_flee_from(body.global_position)

# ===========================
# SIGNAL: PLAYER EXIT AREA
# ===========================
func _on_player_exit(body: Node3D):
	if body.is_in_group("player"):
		print("🟦 Player left the bird flock.")
