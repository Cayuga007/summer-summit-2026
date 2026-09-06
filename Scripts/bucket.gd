class_name Bucket extends Area2D


signal collected(amount)
@export var fill_amount: int = 50
var touched := false


func _ready() -> void:
	body_entered.connect(func(body: Node2D):
		if body is Player and not touched:
			touched = true
			collected.emit(fill_amount)
			queue_free())
