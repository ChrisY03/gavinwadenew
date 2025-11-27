extends Node

@export var sector_bounds_path: NodePath
@export var nav_region_path: NodePath
@export var debug_mmi_path: NodePath

var _debug_mmi: MultiMeshInstance3D
var _accum_debug: float = 0.0

func _ready() -> void:
	if sector_bounds_path == NodePath("") or nav_region_path == NodePath(""):
		push_warning("AIBootstrap: sector_bounds_path or nav_region_path not set in inspector")
		return

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

	await get_tree().process_frame

	Sector.build_from_bounds(bounds, navreg, 20.0)
	print("AIBootstrap: Sector count after build = ", Sector.sector_count())
	Director.init_for_current_map()

	if debug_mmi_path != NodePath(""):
		var mmi := get_node_or_null(debug_mmi_path) as MultiMeshInstance3D
		if mmi and Sector.has_method("debug_fill_multimesh"):
			Sector.debug_fill_multimesh(mmi)
			_debug_mmi = mmi
			_setup_sector_debug_material(_debug_mmi)
			_debug_mmi.visible = false 
			print("AIBootstrap: filled debug multimesh")


func _setup_sector_debug_material(mmi: MultiMeshInstance3D) -> void:
	if mmi == null:
		return

	var mat := StandardMaterial3D.new()
	mat.flags_unshaded = true                # ignore scene lighting so colours are clear
	mat.vertex_color_use_as_albedo = true    # THIS is the important bit
	mat.albedo_color = Color(1, 1, 1, .5)     # don't tint

	mmi.material_override = mat


func _process(delta: float) -> void:
	_accum_debug += delta
	if _accum_debug >= 0.2:
		_accum_debug = 0.0
		if _debug_mmi and Sector.has_method("debug_update_multimesh"):
			Sector.debug_update_multimesh(_debug_mmi)
			
			
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_sector_debug"):
		_toggle_sector_debug()
	
func _toggle_sector_debug() -> void:
	if _debug_mmi == null:
		return
	_debug_mmi.visible = not _debug_mmi.visible
	print("Sector debug visible:", _debug_mmi.visible)
