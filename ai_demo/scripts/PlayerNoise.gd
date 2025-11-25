# PlayerNoise.gd  (attach to a Node3D; set player_body in the Inspector)
extends Node3D

@export var player_body: CharacterBody3D

var _was_on_floor: bool = false
var _sprint_heartbeat: float = 0.0

func _physics_process(delta: float) -> void:
	if player_body == null:
		return

	var on_floor: bool = player_body.is_on_floor()
	if (not _was_on_floor) and on_floor:
		Director.push_event("noise", player_body.global_transform.origin, 0.8)
	_was_on_floor = on_floor

	var sprinting: bool = Input.is_action_pressed("sprint")
	if sprinting:
		_sprint_heartbeat -= delta
		if _sprint_heartbeat <= 0.0:
			Director.push_event("noise", player_body.global_transform.origin, 0.25)
			_sprint_heartbeat = 0.4
			print("Player sprinting")

	if Input.is_action_just_pressed("whistle"):
		Director.push_event("noise", player_body.global_transform.origin, 1.0)
		print("Player whistled")
