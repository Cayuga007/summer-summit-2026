extends CanvasLayer


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/intro_cutscene.tscn")


func _on_level_select_button_pressed() -> void:
	LevelManager.open_overlay(LevelManager.LEVEL_SELECT_MENU, self)


func _on_settings_button_pressed() -> void:
	LevelManager.open_overlay(LevelManager.SETTINGS_MENU, self)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
