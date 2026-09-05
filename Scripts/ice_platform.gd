extends StaticBody2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("enter_ice"):
		body.enter_ice()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("exit_ice"):
		body.exit_ice()
