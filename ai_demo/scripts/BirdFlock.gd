extends Node3D

@export var orbit_radius: float = 6.0
@export var orbit_speed: float = 1.0
@export var orbit_height: float = 3.0

var angle := 0.0
var birds_root: Node3D

func _ready():
	birds_root = $Birds

	if birds_root.get_child_count() == 0:
		push_error("❌ No birds found under BirdFlock/Birds!")
	else:
		print("🕊 BirdFlock initialized with ", birds_root.get_child_count(), " birds.")

func _physics_process(delta):
	angle += orbit_speed * delta

	var center := global_position

	for bird in birds_root.get_children():
		# --- Orbit position ---
		var x = center.x + orbit_radius * cos(angle)
		var z = center.z + orbit_radius * sin(angle)
		var y = center.y + orbit_height

		bird.global_position = Vector3(x, y, z)

		# --- Make bird face toward movement direction ---
		bird.look_at(center, Vector3.UP)

		# --- FIX: rotate so the bird model's forward direction is correct ---
		# If still sideways, try 180 or -90 instead
		bird.rotate_y(deg_to_rad(90))
