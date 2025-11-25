# PlayerNoise.gd  (attach to a Node3D; set player_body in the Inspector)
extends Node3D

@export var player_body: CharacterBody3D
@export var grass_audio: AudioStreamPlayer
@export var whistle_audio: AudioStreamPlayer


var _grass_step_timer: float = 0.0
var grass_sounds: Array = []
var _was_on_floor: bool = false
var _sprint_heartbeat: float = 0.0
var whistle_sound: AudioStream

func _ready():
	grass_sounds = [
		load("res://assets/walking-on-grass-363353.mp3")
	]
	
	whistle_sound = load("res://assets/black-ops-prop-hunt-whistle.mp3")

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
		
		if whistle_audio and whistle_sound:
			whistle_audio.stream = whistle_sound
			whistle_audio.play()
			
	
	_grass_step_timer -= delta
		
	var vel := player_body.velocity
	vel.y = 0.0
	var speed := vel.length()
	
	if speed > 0.1 and _grass_step_timer <= 0.0:
		var step_interval := 0.30 if sprinting else 0.45
		_grass_step_timer = step_interval
							
		Director.push_event("noise", player_body.global_transform.origin, 0.15)
			
		if grass_sounds.size() > 0:
			grass_audio.stream = grass_sounds[randi() % grass_sounds.size()]
			grass_audio.play()		
			
	
