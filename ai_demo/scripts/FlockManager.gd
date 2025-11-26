extends Node

var flocks: Array = []                # List of all bird flocks in the scene
var reserved_positions: Array = []    # Active flee targets
var min_distance_between_targets := 20.0


# -----------------------
# Called by each BirdFlock when it loads
# -----------------------
func register_flock(flock):
	flocks.append(flock)


# -----------------------
# Suggests a NEW flee target that is NOT near another flock’s target
# -----------------------
func request_valid_target(desired: Vector3) -> Vector3:
	for other_target in reserved_positions:
		if desired.distance_to(other_target) < min_distance_between_targets:
			# Too close — push it away randomly
			desired.x += randf_range(-20, 20)
			desired.z += randf_range(-20, 20)
	return desired


# -----------------------
# Called when a flock starts fleeing
# -----------------------
func reserve_target(pos: Vector3):
	reserved_positions.append(pos)


# -----------------------
# Called when flock finishes fleeing
# -----------------------
func release_target(pos: Vector3):
	reserved_positions.erase(pos)
