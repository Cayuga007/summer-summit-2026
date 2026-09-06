extends CanvasLayer


func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	LevelManager.load_level(0)
