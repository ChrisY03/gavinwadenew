extends Area3D

@onready var first_arm = $"First Arm"
@onready var second_arm = $"First Arm2"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		print("Found the player!" + body.name, "Is " + body.name + " inside of the cone")
		
		var my_blue_arrow = global_transform.basis.z
		var first_arm_blue_arrow = first_arm.global_transform.basis.z
		var second_arm_blue_arrow = second_arm.global_transform.basis.z
		
		var minimum_dot = my_blue_arrow.dot(first_arm_blue_arrow)
		var maximum_dot = my_blue_arrow.dot(second_arm.global_transform.basis.z)
		print(maximum_dot)
	
	
	pass # Replace with function body.
		
# func _process(delta):
	#var player = get_tree().get_first_node_in_group("Player")
	#var angle = global_transform.origin.signed_angle_to(player.global_tra)
