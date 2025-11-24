extends Node

@export var fov: float = 120.0
@export var losRange: float = 20.0

signal player_seen(pos: Vector3)
signal player_visible(pos: Vector3)
signal player_lost(pos: Vector3)

@onready var facing: Node3D = $"../Facing"
@onready var los: RayCast3D = $"../Facing/RayCast3D"

var _visible := false
var _last_known := Vector3.ZERO

func tick(delta: float, player: Node3D, owner_body: Node3D) -> void:
	if player == null:
		_emit_lost_if_needed(owner_body.global_transform.origin)
		return

	var to_p := player.global_transform.origin - owner_body.global_transform.origin
	if to_p.length() > losRange:
		_emit_lost_if_needed(_last_known)
		return

	var forward := -facing.global_transform.basis.z
	var to_dir := to_p.normalized()
	var ang_deg := rad_to_deg(acos(clampf(forward.dot(to_dir), -1.0, 1.0)))
	if ang_deg <= fov * 0.5:
		los.target_position = Vector3(0, 0, -losRange)
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

func _emit_lost_if_needed(pos: Vector3) -> void:
	if _visible:
		_visible = false
		player_lost.emit(pos)

func is_visible() -> bool:
	return _visible

func last_known() -> Vector3:
	return _last_known
