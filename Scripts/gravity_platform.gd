extends StaticBody2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("enter_gravity_pad"):
		body.enter_gravity_pad(self)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("exit_gravity_pad"):
		body.exit_gravity_pad(self)
