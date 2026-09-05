extends Node


const LEVELS: Array[String] = [
	"res://Levels/Level_1.tscn",
	"res://Levels/Level_2.tscn",
	"res://Levels/Level_3.tscn",
	"res://Levels/Level_4.tscn",
]

const MAIN_MENU := "res://UI/Main_menu.tscn"
const LEVEL_SELECT := "res://UI/Level_SelectionUI.tscn"
const SETTINGS_MENU := preload("res://UI/Settings_Menu.tscn")
const LEVEL_SELECT_MENU := preload("res://UI/Level_SelectionUI.tscn")

var current_index: int = 0
var music_volume: float = 1.0
var sfx_volume: float = 1.0


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(linear) if linear > 0.0 else -80.0)


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


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func open_overlay(menu_scene: PackedScene, from_menu: CanvasLayer) -> void:
	from_menu.hide()
	var menu := menu_scene.instantiate()
	from_menu.add_sibling(menu)
	menu.closed.connect(from_menu.show)
