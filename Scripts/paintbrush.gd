class_name Paintbrush extends Node2D


@export var paint_prefab: PackedScene
@export var paint_ui: CanvasLayer
@export var paint_spacing := 5.0

var _is_holding := false
var _previous_paint_position := Vector2.ZERO
var _meter_amount := PlayerVariables.max_meter_amount
var _current_color = 0
var can_swap := true


func _ready() -> void:
	PlayerVariables.unlocks_changed.connect(_sync_selected_color)
	_sync_selected_color()


func _sync_selected_color() -> void:
	var num_colors: int = PlayerVariables.unlocked_colors.size()
	if num_colors <= 0:
		return
	if num_colors > 1:
		paint_ui.get_child(2).visible = true
		paint_ui.get_child(3).visible = true
	else:
		paint_ui.get_child(2).visible = false
		paint_ui.get_child(3).visible = false
	_current_color = clampi(_current_color, 0, num_colors - 1)
	paint_prefab = PlayerVariables.unlocked_colors[_current_color]
	for i in range(num_colors):
		paint_ui.get_child(1).get_child(0).get_child(i).visible = true


func _unhandled_input(event: InputEvent) -> void:
	var num_colors = PlayerVariables.unlocked_colors.size()
	if Input.is_action_just_pressed("swap_left") and can_swap:
		can_swap = false
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 0.25
		_current_color = posmod(_current_color - 1, num_colors)
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 1
		paint_prefab = PlayerVariables.unlocked_colors[_current_color]
		await get_tree().create_timer(0.1).timeout
		can_swap = true
	if Input.is_action_just_pressed("swap_right") and can_swap:
		can_swap = false
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 0.25
		_current_color = (_current_color + 1) % num_colors
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 1
		paint_prefab = PlayerVariables.unlocked_colors[_current_color]
		await get_tree().create_timer(0.1).timeout
		can_swap = true


func _input(event: InputEvent) -> void:
	if _meter_amount <= 0:
		_is_holding = false
		return
	
	if event is InputEventMouseButton:
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
	# Painted portal dabs are entries; level-placed PortalPlatform nodes stay exits.
	if "is_exit" in new_paint:
		new_paint.is_exit = false
	add_child(new_paint)
	new_paint.global_position = spawn_position

	_resize_circle_shape(new_paint.get_node_or_null("CollisionShape2D"), PlayerVariables.paint_radius)

	var mesh_instance: MeshInstance2D = new_paint.get_node_or_null("MeshInstance2D")
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.mesh = mesh_instance.mesh.duplicate()
		mesh_instance.mesh.radius = PlayerVariables.paint_radius
		mesh_instance.mesh.height = PlayerVariables.paint_radius * 2

	# Mechanic triggers stay ~11px unless resized; keep them a bit larger than the solid body.
	var area := new_paint.get_node_or_null("Area2D")
	if area:
		_resize_circle_shape(area.get_node_or_null("CollisionShape2D"), PlayerVariables.paint_radius + 4)

	_meter_amount -= PlayerVariables.meter_spill_amount
	var progress_bar: ProgressBar = paint_ui.get_child(0)
	progress_bar.value = _meter_amount / PlayerVariables.max_meter_amount * 100


func set_paint_amount(amount: float) -> void:
	_meter_amount = amount
	var progress_bar: ProgressBar = paint_ui.get_child(0)
	progress_bar.value = _meter_amount / PlayerVariables.max_meter_amount * 100


func add_paint_amount(amount: float) -> void:
	_meter_amount = clamp(_meter_amount + amount, 0, PlayerVariables.max_meter_amount)
	var progress_bar: ProgressBar = paint_ui.get_child(0)
	progress_bar.value = _meter_amount / PlayerVariables.max_meter_amount * 100


func _resize_circle_shape(shape_node: CollisionShape2D, radius: float) -> void:
	if shape_node == null or shape_node.shape == null:
		return
	shape_node.shape = shape_node.shape.duplicate()
	if shape_node.shape is CircleShape2D:
		shape_node.shape.radius = radius
