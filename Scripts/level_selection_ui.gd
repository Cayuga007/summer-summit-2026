extends CanvasLayer

signal closed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_level_1_button_pressed() -> void:
	LevelManager.load_level(0)


func _on_level_2_button_pressed() -> void:
	LevelManager.load_level(1)


func _on_level_3_button_pressed() -> void:
	LevelManager.load_level(2)


func _on_level_4_button_pressed() -> void:
	LevelManager.load_level(3)


func _on_back_button_pressed() -> void:
	if get_tree().current_scene == self:
		LevelManager.go_to_main_menu()
	else:
		closed.emit()
		queue_free()
