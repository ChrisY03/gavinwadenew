# PlayerNoise.gd  (attach to a Node3D; set player_body in the Inspector)
extends Node3D

@export var player_body: CharacterBody3D
@export var foot_ray: RayCast3D
@export var grass_audio: AudioStreamPlayer3D


var _grass_step_timer: float = 0.0
var grass_sounds: Array = []
var _was_on_floor: bool = false
var _sprint_heartbeat: float = 0.0

func _ready():
	grass_sounds = [
		load("res://assets/walking-on-grass-363353.mp3")
	]

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
		
	if not foot_ray:
		print("No foot_ray assigned")
		return
	
	if foot_ray.is_colliding():
		_grass_step_timer -= delta
		
		
	
			
		if _grass_step_timer <= 0.0 and player_body.velocity.length() > 1.0:
			_grass_step_timer = 0.45
			
			Director.push_event("noise", player_body.global_transform.origin, 0.15)
			
			if grass_sounds.size() > 0:
				grass_audio.stream = grass_sounds[randi() % grass_sounds.size()]
				grass_audio.play()		
		else:
			print("FootRay NOT colliding")		
	
