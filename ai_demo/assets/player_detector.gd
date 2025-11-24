extends Area3D


func _on_body_entered(body: Node3D) -> void:
	print("Found the player!" + body.name)
	pass # Replace with function body.
