extends CanvasLayer



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func _on_retry_button_pressed() -> void:
	print("level retry")
	LevelManager.retry()

func _on_next_button_pressed() -> void:
	LevelManager.next()


func _on_level_select_button_pressed() -> void:
	LevelManager.go_to_level_select()
