extends Node

@export var use_vision_cone: bool = true
@export var cone_path: NodePath = ^"../Facing/VisionCone3D"

signal player_seen(pos: Vector3)
signal player_visible(pos: Vector3)
signal player_lost(pos: Vector3)

@onready var facing: Node3D = $"../Facing"
@onready var cone: Node = get_node_or_null(cone_path)

var _visible: bool = false
var _cone_visible: bool = false
var _last_known: Vector3 = Vector3.ZERO
var _player_ref: Node3D = null


func _ready() -> void:
	if use_vision_cone and is_instance_valid(cone):
		# VisionCone3D addon usually exposes these signals:
		# body_sighted(body: Node3D), body_hidden(body: Node3D)
		if cone.has_signal("body_sighted"):
			cone.connect("body_sighted", Callable(self, "_on_cone_sighted"))
		if cone.has_signal("body_hidden"):
			cone.connect("body_hidden", Callable(self, "_on_cone_hidden"))

	print("[Perception] ready. use_vision_cone=", use_vision_cone, " cone=", cone)


func tick(delta: float, player: Node3D, owner_body: Node3D) -> void:
	_player_ref = player

	if player == null or owner_body == null:
		_emit_lost_if_needed(_last_known)
		return

	if not use_vision_cone or not is_instance_valid(cone):
		# If cone is disabled/missing, we just treat as no visibility
		_emit_lost_if_needed(_last_known)
		return

	# With VisionCone3D, we mostly rely on its signals.
	# Here we just keep the "visible" state alive & emit continuous player_visible.
	if _cone_visible and _player_ref:
		_last_known = _player_ref.global_transform.origin
		player_visible.emit(_last_known)
	else:
		_emit_lost_if_needed(_last_known)


func _on_cone_sighted(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	_player_ref = body

	# --- Concealment check: if player is in cover, ignore cone hits ---
	if _is_player_concealed(body):
		# If we were previously seeing them, mark as lost
		_cone_visible = false
		_emit_lost_if_needed(_last_known)
		print("[Perception] player in cover, ignoring cone sight")
		return

	_cone_visible = true
	_visible = true
	_last_known = body.global_transform.origin

	player_seen.emit(_last_known)
	player_visible.emit(_last_known)
	#print("[Perception] SEEN via cone at ", _last_known)


func _on_cone_hidden(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	_cone_visible = false
	_emit_lost_if_needed(_last_known)
	#print("[Perception] LOST via cone at ", _last_known)


func _emit_lost_if_needed(pos: Vector3) -> void:
	if _visible or _cone_visible:
		_visible = false
		_cone_visible = false
		player_lost.emit(pos)
		print("[Perception] LOST at ", pos)


func _is_player_concealed(player: Node3D) -> bool:
	if not player.has_meta("cover_count"):
		return false
	var c: int = int(player.get_meta("cover_count"))
	return c > 0


func is_visible() -> bool:
	return _visible or _cone_visible


func last_known() -> Vector3:
	return _last_known
