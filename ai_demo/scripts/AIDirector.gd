extends Node
class_name AIDirector

@export var heat_decay: float = 0.85
@export var hot_threshold: float = 0.25
@export var sector_cooldown_sec: float = 5.0
@export var max_squads: int = 2
@export var squad_size: int = 2
@export var min_reassign_sec: float = 4.0

var sector_heat: PackedFloat32Array = PackedFloat32Array()
var sector_cooldown: PackedFloat32Array = PackedFloat32Array()
var _assignments: Dictionary = {}        # sector_id -> Array[Node]

# Call once after the Sectorizer has built its grid.
func init_for_current_map() -> void:
	var n: int = Sector.sector_count()   # swap to Sectors.* if that's your autoload name
	sector_heat.resize(n)
	sector_cooldown.resize(n)
	for i in range(n):
		sector_heat[i] = 0.0
		sector_cooldown[i] = 0.0
	_assignments.clear()

func push_event(kind: String, pos: Vector3, weight: float = 1.0) -> void:
	if Sector.sector_count() == 0:
		return
	var sid: int = Sector.sector_id_at(pos)
	if sid < 0:
		return

	var w: float = 0.5
	match kind:
		"heli":
			w = 1.0
		"lkp":
			w = 0.7
		"noise":
			w = 0.4
		_:
			w = 0.5

	sector_heat[sid] += w * weight

func tick_dispatch(_elapsed: float) -> void:
	var now: float = Time.get_unix_time_from_system()

	# Decay heat
	for i in range(sector_heat.size()):
		sector_heat[i] *= heat_decay
		if sector_heat[i] < 0.001:
			sector_heat[i] = 0.0

	# Hot sectors (not cooling)
	var hot: Array = []
	for i in range(sector_heat.size()):
		if sector_heat[i] >= hot_threshold and now >= sector_cooldown[i]:
			hot.append(i)

	# Clean assignments (remove deleted guards)
	var to_delete: Array = []
	for sid in _assignments.keys():
		var arr: Array = _assignments[sid]
		var kept: Array = []
		for g in arr:
			if is_instance_valid(g) and not g.is_queued_for_deletion():
				kept.append(g)
		if kept.is_empty():
			to_delete.append(sid)
		else:
			_assignments[sid] = kept
	for k in to_delete:
		_assignments.erase(k)

	var budget: int = max_squads - _assignments.size()
	if budget <= 0:
		return

	# Assign nearest idle guard to each hot sector until budget runs out
	var guards: Array = get_tree().get_nodes_in_group("guards")
	for sid in hot:
		if budget <= 0:
			break
		# pick up to squad_size nearest idle guards
		var c: Vector3 = Sector.center(sid)
		var candidates: Array = []
		for g in guards:
			if not is_instance_valid(g): continue
			if g.is_busy(): continue
			if now - g.get_last_task_time() < min_reassign_sec: continue
			candidates.append(g)
		# sort by distance
		candidates.sort_custom(func(a, b):
			var da: float = a.global_transform.origin.distance_squared_to(c)
			var db: float = b.global_transform.origin.distance_squared_to(c)
			return da < db
		)
		var assigned: Array = []
		for i in range(min(squad_size, candidates.size())):
			if budget <= 0: break
			var g = candidates[i]
			g.set_task_investigate_sector(sid)
			assigned.append(g)
			budget -= 1
		if assigned.size() > 0:
			_assignments[sid] = assigned


func mark_sector_cooldown(sid: int) -> void:
	sector_cooldown[sid] = Time.get_unix_time_from_system() + sector_cooldown_sec
