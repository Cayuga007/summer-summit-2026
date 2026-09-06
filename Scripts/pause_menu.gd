extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func open() -> void:
	show()
	get_tree().paused = true


func _on_resume_button_pressed() -> void:
	hide()
	get_tree().paused = false


func _on_settings_button_pressed() -> void:
	LevelManager.open_overlay(LevelManager.SETTINGS_MENU, self)

func _on_level_retry_button_pressed() -> void:
	LevelManager.retry()


func _on_main_menu_button_pressed() -> void:
	LevelManager.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_resume_button_pressed()
		get_viewport().set_input_as_handled()
