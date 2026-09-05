extends Node


const LEVELS: Array[String] = [
	"res://Levels/Level_1.tscn",
	"res://Levels/Level_2.tscn",
	"res://Levels/Level_3.tscn",
	"res://Levels/Level_4.tscn",
]

const LEVEL_SELECT := "res://UI/Level_SelectionUI.tscn"

var current_index: int = 0

func load_level(index: int) -> void:
	current_index = clampi(index, 0, LEVELS.size() - 1)
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVELS[current_index])

func retry() -> void:
	load_level(current_index)

func next() -> void:
	if has_next_level():
		load_level(current_index + 1)
	else:
		go_to_level_select()  

func has_next_level() -> bool:
	return current_index < LEVELS.size() - 1

func go_to_level_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SELECT)
