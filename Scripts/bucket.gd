class_name Bucket extends Area2D

signal collected(amount: float)

@export var paint_amount: float = 25.0
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	if body is Player:
		is_collected = true
		collected.emit(paint_amount)
		# Defer disabling collisions to prevent physics locks
		collision_shape.set_deferred("disabled", true)
		visible = false


# Restores the bucket to its active, collectible state upon player respawn
func reset_bucket() -> void:
	is_collected = false
	visible = true
	collision_shape.set_deferred("disabled", false)
