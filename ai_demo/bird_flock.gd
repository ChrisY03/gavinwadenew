extends Node3D

@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 3.0

var angle := 0.0
var birds_root: Node3D
var trigger_area: Area3D
var blackboard   # reference to the Blackboard singleton


func _ready():
	birds_root = $Birds
	trigger_area = $TriggerArea

	# Get the global Blackboard singleton
	blackboard = get_node("/root/Blackboard")


func _physics_process(delta):
	angle += orbit_speed * delta

	var center := global_position

	# Keep detection area centered on the flock
	trigger_area.global_position = center

	# Move each bird in orbit
	for bird in birds_root.get_children():
		var x = center.x + orbit_radius * cos(angle)
		var z = center.z + orbit_radius * sin(angle)
		var y = center.y + orbit_height

		bird.global_position = Vector3(x, y, z)
		bird.look_at(center, Vector3.UP)
		bird.rotate_y(deg_to_rad(90))


# ---------------------------------------------------------------
# Player ENTERS detection radius
# ---------------------------------------------------------------
func _on_trigger_area_body_entered(body):
	if body.name == "player":
		print("🐦 Bird flock detected the player!")

		# Birds create a noise alert in the blackboard
		if blackboard:
			blackboard.add_bird_alert(global_position)
			print("📡 Bird alert sent to guards.")


# ---------------------------------------------------------------
# Player LEAVES detection radius
# ---------------------------------------------------------------
func _on_trigger_area_body_exited(body):
	if body.name == "player":
		print("🐦 Player left the bird flock.")
