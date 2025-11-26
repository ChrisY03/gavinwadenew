# AIDirector.gd
extends Node
class_name AIDirector

@export var heat_decay_per_sec: float = 0.2   # how fast heat cools per second
@export var hot_threshold: float = 0.5        # sectors with >= this are “interesting”

func _process(delta: float) -> void:
	# Cool all sectors every frame
	Sector.cool_all(heat_decay_per_sec, delta)

func init_for_current_map() -> void:
	# If your Sector grid is already built elsewhere, you might not
	# need to do anything here. This just satisfies older calls.
	# You can expand this later if you want Director to do extra setup.
	pass

# Called when something happens (noise, last known pos, heli, etc.)
func push_event(kind: String, pos: Vector3, weight: float = 1.0) -> void:
	var sid := Sector.id_at(pos)
	if sid == -1:
		return

	var base := 0.5
	match kind:
		"heli":  base = 1.0
		"lkp":   base = 0.7
		"noise": base = 0.4
		_:       base = 0.5

	Sector.bump_heat(sid, base * weight)


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


# What sector should a guard investigate/patrol now?
func get_patrol_sector() -> int:
	var sid := _get_hottest_sector()
	if sid != -1:
		return sid

	var count := Sector.sector_count()
	if count <= 0:
		return -1

	return randi() % count


# Give a concrete world position for the guard to walk to
func get_patrol_point() -> Vector3:
	var sid := get_patrol_sector()
	if sid == -1:
		return Vector3.ZERO
	return Sector.random_point_in(sid)

	
