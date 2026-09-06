extends RigidBody2D

@onready var color_rect: ColorRect = $ColorRect

func setup(col: Color, initial_vel: Vector2) -> void:
	color_rect.color = col
	linear_velocity = initial_vel
	
	
	await get_tree().create_timer(10.0).timeout
	queue_free()
