extends Node2D

func _ready() -> void:
	$VictoryDoor.level_completed.connect(_on_level_completed)

func _on_level_completed() -> void:
	$LevelCompleted.show()
	get_tree().paused = true  # optional, stops the player behind the menu
