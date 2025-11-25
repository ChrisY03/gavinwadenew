# Perception.gd
extends Node

@export var fov: float = 120.0
@export var losRange: float = 20.0
@export var use_vision_cone: bool = true
@export var cone_path: NodePath = ^"../Facing/VisionCone3D"  # drag your VisionCone3D here if different

signal player_seen(pos: Vector3)
signal player_visible(pos: Vector3)
signal player_lost(pos: Vector3)

@onready var facing: Node3D = $"../Facing"
@onready var los: RayCast3D = $"../Facing/RayCast3D"
@onready var cone: Node = get_node_or_null(cone_path)

var _visible: bool = false
var _cone_visible: bool = false
var _last_known: Vector3 = Vector3.ZERO

func _ready() -> void:
	if use_vision_cone and is_instance_valid(cone):
		# Ensure the cone is monitoring and hook signals if they exist
		if "monitoring" in cone:
			cone.monitoring = true
		if cone.has_signal("body_sighted"):
			cone.connect("body_sighted", Callable(self, "_on_cone_sighted"))
		if cone.has_signal("body_hidden"):
			cone.connect("body_hidden", Callable(self, "_on_cone_hidden"))

func tick(delta: float, player: Node3D, owner_body: Node3D) -> void:
	if player == null or owner_body == null:
		_emit_lost_if_needed(_last_known)
		return

	# Preferred path: VisionCone addon handles FOV + occlusion
	if use_vision_cone and is_instance_valid(cone):
		if _cone_visible:
			_last_known = player.global_transform.origin
			# cone signal handlers already emitted seen/visible
			return
		_emit_lost_if_needed(_last_known)
		return

	# Fallback: manual FOV + RayCast3D
	var to_p := player.global_transform.origin - owner_body.global_transform.origin
	if to_p.length() > losRange:
		_emit_lost_if_needed(_last_known)
		return

	var forward := -facing.global_transform.basis.z
	var ang_deg := rad_to_deg(acos(clampf(forward.dot(to_p.normalized()), -1.0, 1.0)))

	if ang_deg <= fov * 0.5:
		# RayCast3D is local to Facing; cast forward
		los.target_position = Vector3(0.0, 0.0, -losRange)
		los.force_raycast_update()
		var seen := los.is_colliding() and los.get_collider() == player
		if seen:
			_last_known = player.global_transform.origin
			if not _visible:
				_visible = true
				player_seen.emit(_last_known)
			player_visible.emit(_last_known)
		else:
			_emit_lost_if_needed(_last_known)
	else:
		_emit_lost_if_needed(_last_known)

func _on_cone_sighted(body: Node3D) -> void:
	if body.is_in_group("player"):
		_cone_visible = true
		_last_known = body.global_transform.origin
		if not _visible:
			_visible = true
			player_seen.emit(_last_known)
		player_visible.emit(_last_known)

func _on_cone_hidden(body: Node3D) -> void:
	if body.is_in_group("player"):
		_cone_visible = false
		_emit_lost_if_needed(_last_known)

func _emit_lost_if_needed(pos: Vector3) -> void:
	if _visible:
		_visible = false
		player_lost.emit(pos)

func is_visible() -> bool:
	return _visible or _cone_visible

func last_known() -> Vector3:
	return _last_known
