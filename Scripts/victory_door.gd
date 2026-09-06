extends Area2D

signal level_completed

var _completed := false


func _on_body_entered(body: Node2D) -> void:
	if _completed:
		return
	if body.is_in_group("Player"):
		_completed = true
		$VictorySFX.play()
		level_completed.emit()
