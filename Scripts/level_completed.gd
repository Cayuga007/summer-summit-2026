extends CanvasLayer


@onready var gradient: TextureRect = $Gradient


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gradient.global_position = Vector2(1250, 0)
	hide()


func _on_retry_button_pressed() -> void:
	LevelManager.retry()

func _on_next_button_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(gradient, "global_position:x", -450, 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	await get_tree().create_timer(1).timeout
	LevelManager.next()


func _on_level_select_button_pressed() -> void:
	LevelManager.go_to_level_select()
