class_name Paintbrush extends Node2D


@export var paint_prefab: PackedScene
@export var paint_ui: CanvasLayer
@export var max_meter_amount: float = 100
@export var meter_spill_amount: float = 0.1
@export var paint_radius := 30
@export var paint_spacing := 5.0

var _is_holding := false
var _previous_paint_position := Vector2.ZERO
var _meter_amount := max_meter_amount


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if _meter_amount <= 0: return
	
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
		var paint_spawn_position := previous.lerp(current, t)
		spawn_paint(paint_spawn_position)


func spawn_paint(spawn_position: Vector2) -> void:
	var new_paint: StaticBody2D = paint_prefab.instantiate()
	add_child(new_paint)
	new_paint.global_position = spawn_position
	
	var collision_shape: CollisionShape2D = new_paint.get_child(0)
	collision_shape.shape.radius = paint_radius
	var mesh_instance: MeshInstance2D = new_paint.get_child(1)
	mesh_instance.mesh.radius = paint_radius
	mesh_instance.mesh.height = paint_radius * 2
	
	_meter_amount -= meter_spill_amount
	var progress_bar: ProgressBar = paint_ui.get_child(0)
	progress_bar.value = _meter_amount / max_meter_amount * 100
