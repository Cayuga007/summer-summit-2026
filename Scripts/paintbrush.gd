class_name Paintbrush extends Node2D


@export var paint_prefab: Paint

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
		print("Paint")
