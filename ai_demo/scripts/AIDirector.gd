extends Node
class_name AIDirector

@export var heat_decay_per_sec: float = 0.2   # how fast heat cools per second
@export var hot_threshold: float = 0.5        # min heat to be “interesting”


func _ready() -> void:
	# At this point Sector autoload should also exist
	print("Director ready, Sector count at start: ", Sector.sector_count())
	print("Director exists? ", Director)
	print("Sector exists?   ", Sector)
	print("Sector count:    ", Sector.sector_count())



func _process(delta: float) -> void:
	# Cool all sectors each frame
	Sector.cool_all(heat_decay_per_sec, delta)


# Called from guards, player, heli, etc.
func push_event(kind: String, pos: Vector3, weight: float = 1.0) -> void:
	var sid := Sector.id_at(pos)
	if sid == -1:
		return

	var base := 0.5
	match kind:
		"heli":
			base = 1.0
		"lkp":
			base = 0.7      # last known player position
		"noise":
			base = 0.4      # footsteps, bushes, etc.
		_:
			base = 0.5

	Sector.bump_heat(sid, base * weight)


func init_for_current_map() -> void:
	print("Director: map initialized with ", Sector.sector_count(), " sectors")


func _get_hottest_sector() -> int:
	var best_sid := -1
	var best_heat := 0.0
	var count := Sector.sector_count()

	for sid in range(count):
		var h := Sector.heat_of(sid)
		if h >= hot_threshold and h > best_heat:
			best_heat = h
			best_sid = sid

	return best_sid


func get_patrol_point() -> Vector3:
	var sid := _get_hottest_sector()
	var count := Sector.sector_count()

	# No hot sector? pick a random walkable one.
	if sid == -1:
		if count <= 0:
			return Vector3.ZERO
		sid = randi() % count

	return Sector.random_point_in(sid)
