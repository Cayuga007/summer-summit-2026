extends Area2D

func _ready() -> void:
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Duck-typing check: trigger death if the touching body has a die() method
	if body.has_method("die"):
		body.die()
