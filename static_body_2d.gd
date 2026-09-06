extends StaticBody2D

@onready var shape_cast: ShapeCast2D = $ShapeCast2D


func _ready() -> void:
	# Add to group for safety identification
	add_to_group("hazard")


func _physics_process(_delta: float) -> void:
	if not shape_cast.is_colliding():
		return

	for i in shape_cast.get_collision_count():
		var collider = shape_cast.get_collider(i)
		if collider is Player and not collider.is_dead:
			collider.die()
			break
