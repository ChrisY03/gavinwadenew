extends Node3D

@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 3.0

var angle: float = 0.0

@export var flee_distance: float = 20.0
@export var flee_speed: float = 20.0
@export var flee_height: float = 20.0
@export var flee_duration: float = 4.0

var flee_timer: float = 0.0
var is_fleeing: bool = false
var flee_target: Vector3 = Vector3.ZERO

@export var min_x: float = -80
@export var max_x: float = 80
@export var min_z: float = -80
@export var max_z: float = 80

var birds_root: Node3D
var trigger_area: Area3D
var ground_check: RayCast3D
var alert_sound: AudioStreamPlayer3D

func _ready():
	birds_root = $Birds
	trigger_area = $TriggerArea
	ground_check = $GroundCheck
	alert_sound = $BirdAlertSound

	trigger_area.body_entered.connect(_on_player_enter)
	trigger_area.body_exited.connect(_on_player_exit)

	if Engine.has_singleton("FlockManager"):
		FlockManager.register_flock(self)
	else:
		push_warning("FlockManager autoload not found!")

	if ground_check == null:
		push_error("Missing GroundCheck RayCast3D!")
	if alert_sound == null:
		push_error("Missing BirdAlertSound node!")

func _physics_process(delta):
	trigger_area.global_position = global_position
	_update_ground_height()

	if is_fleeing:
		_process_flee(delta)
	else:
		_process_orbit(delta)

func _update_ground_height():
	ground_check.global_position = global_position + Vector3(0, 50, 0)

	if ground_check.is_colliding():
		var terrain_y := ground_check.get_collision_point().y
		global_position.y = terrain_y + orbit_height

func _process_orbit(delta):
	angle += orbit_speed * delta
	var center := global_position

	for bird in birds_root.get_children():
		var x = center.x + orbit_radius * cos(angle)
		var z = center.z + orbit_radius * sin(angle)
		var y = center.y + orbit_height

		bird.global_position = Vector3(x, y, z)

		bird.look_at(center, Vector3.UP)

		bird.rotate_y(deg_to_rad(90))

func _start_flee_from(player_pos: Vector3):
	if is_fleeing:
		return

	is_fleeing = true
	flee_timer = flee_duration

	var away := (global_position - player_pos).normalized()
	var flee_strength := randf_range(flee_distance, flee_distance * 3.0)
	var desired_target := global_position + away * flee_strength

	var safe_target := FlockManager.request_valid_target(desired_target)
	flee_target = safe_target

	FlockManager.reserve_target(flee_target)

	print("Birds fleeing to:", flee_target)

func _process_flee(delta):
	flee_timer -= delta

	if flee_timer <= 0.0:
		is_fleeing = false
		print("Birds calm — returning to orbit.")
		FlockManager.release_target(flee_target)
		return

	var target := flee_target + Vector3(0, flee_height, 0)
	var dir := target - global_position

	if dir.length() > 0.1:
		dir = dir.normalized()
		global_position += dir * flee_speed * delta

	global_position.x = clamp(global_position.x, min_x, max_x)
	global_position.z = clamp(global_position.z, min_z, max_z)

func _on_player_enter(body: Node3D):
	if not body.is_in_group("player"):
		return

	print("Bird flock detected the player!")

	if alert_sound:
		alert_sound.play()

	var bb = get_node("/root/Blackboard")
	bb.add_noise(global_position, 50.0, 5.0)
	Director._alert_nearby_guards_noise(global_position, 1)
	print("Bird alert sent to guards.")

	_start_flee_from(body.global_position)

func _on_player_exit(body: Node3D):
	if body.is_in_group("player"):
		print("Player left the bird flock.")
