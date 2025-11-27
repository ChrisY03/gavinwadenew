# CoverArea.gd
extends Area3D

@export var cover_strength: float = 1.0   # for future use (partial cover), unused for now

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var current: int = 0
	if body.has_meta("cover_count"):
		current = int(body.get_meta("cover_count"))

	body.set_meta("cover_count", current + 1)
	#print("CoverArea: player entered, cover_count=", current + 1)


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_meta("cover_count"):
		return

	var current: int = int(body.get_meta("cover_count"))
	current -= 1
	if current < 0:
		current = 0

	body.set_meta("cover_count", current)
	#print("CoverArea: player exited, cover_count=", current)
