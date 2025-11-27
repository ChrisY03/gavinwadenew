extends Node

@export var sector_bounds_path: NodePath      # Area3D with BoxShape3D
@export var nav_region_path: NodePath         # NavigationRegion3D with baked navmesh
@export var debug_mmi_path: NodePath          # Optional MultiMeshInstance3D for debug

func _ready() -> void:
	if sector_bounds_path == NodePath("") or nav_region_path == NodePath(""):
		push_warning("AIBootstrap: sector_bounds_path or nav_region_path not set in inspector")
		return

	print("AIBootstrap: deferring AI init")
	call_deferred("_init_ai")


func _init_ai() -> void:
	var bounds := get_node_or_null(sector_bounds_path) as Area3D
	var navreg := get_node_or_null(nav_region_path) as NavigationRegion3D

	if bounds == null:
		push_error("AIBootstrap: bounds node not found at " + str(sector_bounds_path))
		return
	if navreg == null:
		push_error("AIBootstrap: nav_region node not found at " + str(nav_region_path))
		return

	# Wait one frame so the nav map is registered
	await get_tree().process_frame

	print("AIBootstrap: building sectors from ", bounds.name, " and nav region ", navreg.name)
	Sector.build_from_bounds(bounds, navreg, 20.0)
	print("AIBootstrap: Sector count after build = ", Sector.sector_count())

	Director.init_for_current_map()

	if debug_mmi_path != NodePath(""):
		var mmi := get_node_or_null(debug_mmi_path) as MultiMeshInstance3D
		if mmi:
			if Sector.has_method("debug_fill_multimesh"):
				Sector.debug_fill_multimesh(mmi)
				print("AIBootstrap: filled debug multimesh")
			else:
				print("AIBootstrap: Sector.debug_fill_multimesh missing")
