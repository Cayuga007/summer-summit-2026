class_name Paintbrush extends Node2D


@export var paint_prefab: PackedScene
@export var paint_spacing := 5.0

var _is_holding := false
var _previous_paint_position := Vector2.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_is_holding = true
			_previous_paint_position = get_global_mouse_position()
			spawn_paint(_previous_paint_position)
		else:
			_is_holding = false
	elif event is InputEventMouseMotion and _is_holding:
		var current_position := get_global_mouse_position()
		paint_between(_previous_paint_position, current_position)
		_previous_paint_position = current_position


func paint_between(previous: Vector2, current: Vector2) -> void:
	var distance := previous.distance_to(current)
	var steps: int = max(1, int(ceil(distance / paint_spacing)))
	
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var position := previous.lerp(current, t)
		spawn_paint(position)


func spawn_paint(spawn_position: Vector2) -> void:
	var new_paint: StaticBody2D = paint_prefab.instantiate()
	add_child(new_paint)
	new_paint.global_position = spawn_position
