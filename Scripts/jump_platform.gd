extends StaticBody2D


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("enter_bounce"):
		if body.bounce_contacts == 0:
			$JumpPlatformSFX.play()
		body.enter_bounce()


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("exit_bounce"):
		body.exit_bounce()
