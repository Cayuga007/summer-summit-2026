extends CanvasLayer



func _on_level_1_button_pressed() -> void:
	LevelManager.current_index = 0
	get_tree().change_scene_to_file("res://Levels/Level_1.tscn")


func _on_level_2_button_pressed() -> void:
	LevelManager.current_index = 1
	get_tree().change_scene_to_file("res://Levels/Level_2.tscn")


func _on_level_3_button_pressed() -> void:
	LevelManager.current_index = 2
	get_tree().change_scene_to_file("res://Levels/Level_3.tscn")


func _on_level_4_button_pressed() -> void:
	LevelManager.current_index = 3
	get_tree().change_scene_to_file("res://Levels/Level_4.tscn")
