extends Node2D

const PAUSE_MENU := preload("res://UI/Pause_Menu.tscn")
const PAINTBRUSH = preload("res://paintbrush.tscn")

var pause_menu: CanvasLayer


func _ready() -> void:
	add_child(PAINTBRUSH.instantiate())
	$VictoryDoor.level_completed.connect(_on_level_completed)
	pause_menu = PAUSE_MENU.instantiate()
	add_child(pause_menu)


func _on_level_completed() -> void:
	pause_menu.hide()
	$LevelCompleted.show()
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused:
		if $LevelCompleted.visible:
			return
		pause_menu.open()
