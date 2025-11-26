extends Node3D

@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 3.0

var angle := 0.0
var birds_root: Node3D
var trigger_area: Area3D

func _ready():
	birds_root = $Birds
	trigger_area = $TriggerArea


func _physics_process(delta):
	angle += orbit_speed * delta

	var center := global_position

	# Keep TriggerArea positioned on the flock center
	trigger_area.global_position = center

	# Move each bird in an orbit pattern
	for bird in birds_root.get_children():
		var x = center.x + orbit_radius * cos(angle)
		var z = center.z + orbit_radius * sin(angle)
		var y = center.y + orbit_height

		bird.global_position = Vector3(x, y, z)
		bird.look_at(center, Vector3.UP)
		bird.rotate_y(deg_to_rad(90))


# Called when something enters the flock's detection area
func _on_trigger_area_body_entered(body):
	if body.name == "Player":
		print("🐦 Bird flock detected the PLAYER!")


# Called when something exits the flock's detection area (optional)
func _on_trigger_area_body_exited(body):
	if body.name == "Player":
		print("🐦 Player LEFT the bird flock.")
