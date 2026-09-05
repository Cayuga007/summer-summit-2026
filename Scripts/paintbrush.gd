class_name Paintbrush extends Node2D


@export var paint_prefab: PackedScene

var _is_holding := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_is_holding = true
		elif event.is_released():
			_is_holding = false
	if event is InputEventMouseMotion and _is_holding:
		spawn_paint()


func spawn_paint() -> void:
	var new_paint: StaticBody2D = paint_prefab.instantiate()
	add_child(new_paint)
	new_paint.global_position = get_global_mouse_position()
