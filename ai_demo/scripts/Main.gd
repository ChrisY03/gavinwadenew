extends Node

@export var sector_bounds_path: NodePath
@export var nav_region_path: NodePath
@export var debug_mmi_path: NodePath

var _acc := 0.0

func _ready() -> void:
	if sector_bounds_path == NodePath("") or nav_region_path == NodePath(""):
		return
	call_deferred("_init_ai")

func _init_ai() -> void:
	var bounds := get_node(sector_bounds_path) as Area3D
	var navreg := get_node(nav_region_path) as NavigationRegion3D
	await get_tree().process_frame
	Sector.build_from_bounds(bounds, navreg, 20.0)
	Director.init_for_current_map()
	if debug_mmi_path != NodePath(""):
		var mmi := get_node(debug_mmi_path) as MultiMeshInstance3D
		Sector.debug_fill_multimesh(mmi)
	get_tree().create_timer(1.0).timeout.connect(func ():
		var guards := get_tree().get_nodes_in_group("guards")
		if guards.size() > 0:
			var pos := (guards[0] as Node3D).global_position + Vector3(8, 0, 0)
			Director.push_event("noise", pos, 1.0)
	)

func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0:
		Director.tick_dispatch(_acc)
		_acc = 0.0
