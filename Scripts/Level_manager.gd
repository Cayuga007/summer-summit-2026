extends Node


const LEVELS: Array[String] = [
	"res://Levels/Level_1.tscn",
	"res://Levels/Level_2.tscn",
	"res://Levels/Level_3.tscn",
	"res://Levels/Level_4.tscn",
	"res://Levels/Level_5.tscn",
	"res://Levels/Level_6.tscn",
	"res://Levels/Level_7.tscn",
	"res://Levels/Level_8.tscn",
	"res://Levels/Level_9.tscn",
	"res://Levels/Level_10.tscn",
	"res://Levels/Level_11.tscn",
	"res://Levels/Level_12.tscn",
	"res://Levels/Level_13.tscn",
	"res://Levels/Level_14.tscn",
	"res://Levels/Level_15.tscn",
	
	
]

const MAIN_MENU := preload("res://UI/Main_menu.tscn")
const LEVEL_SELECT := preload("res://UI/Level_SelectionUI.tscn")
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


func sync_current_index_from_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var idx := LEVELS.find(scene.scene_file_path)
	if idx >= 0:
		current_index = idx


func retry() -> void:
	sync_current_index_from_scene()
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
	get_tree().change_scene_to_file("res://UI/Level_SelectionUI.tscn")


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/Main_menu.tscn")


func open_overlay(menu_scene: PackedScene, from_menu: CanvasLayer) -> void:
	from_menu.hide()
	var menu := menu_scene.instantiate()
	from_menu.add_sibling(menu)
	menu.closed.connect(from_menu.show)
