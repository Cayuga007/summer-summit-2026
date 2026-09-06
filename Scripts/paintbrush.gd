class_name Paintbrush extends Node2D

@export var paint_prefab: PackedScene
@export var paint_ui: CanvasLayer
@export var paint_spacing := 5.0

var colors = [
	preload("res://platforms/platform.tscn"),
	preload("res://platforms/IcePlatform.tscn"),
	preload("res://platforms/JumpPlatform.tscn"),
	preload("res://platforms/GravityPlatform.tscn"),
	preload("res://platforms/PortalPlatform.tscn"),
]

var _is_holding := false
var _previous_paint_position := Vector2.ZERO
var _meter_amount := PlayerVariables.max_meter_amount
var _current_color = 0
var can_swap := true
var num_colors: int = 1

# Controls whether painting is permitted during death and reassembly
var painting_enabled: bool = true

# Level baseline snapshots for respawn restoration
var _initial_paint_amount: float = -1.0
var _initial_num_colors: int = 1

# Dedicated container node to isolate painted strokes from other children
var _stroke_container: Node2D


func _ready() -> void:
	# Add to group so player can locate the brush regardless of scene structure
	add_to_group("paintbrush")

	# Create dedicated container for painted stroke instances
	_stroke_container = Node2D.new()
	_stroke_container.name = "StrokeContainer"
	add_child(_stroke_container)

	# Snapshot initial unlocks configured by the level script
	_initial_num_colors = num_colors

	_sync_selected_color()


func _sync_selected_color() -> void:
	if num_colors > 1:
		paint_ui.get_child(2).visible = true
		paint_ui.get_child(3).visible = true
	else:
		paint_ui.get_child(2).visible = false
		paint_ui.get_child(3).visible = false

	_current_color = clampi(_current_color, 0, num_colors - 1)
	paint_prefab = colors[_current_color]

	# Sync slot visibility and active selection alphas
	for i in range(colors.size()):
		var slot_node = paint_ui.get_child(1).get_child(0).get_child(i)
		slot_node.visible = (i < num_colors)
		slot_node.modulate.a = 1.0 if i == _current_color else 0.25


func _unhandled_input(event: InputEvent) -> void:
	if not painting_enabled:
		return

	if Input.is_action_just_pressed("swap_left") and can_swap:
		can_swap = false
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 0.25
		_current_color = posmod(_current_color - 1, num_colors)
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 1
		paint_prefab = colors[_current_color]
		await get_tree().create_timer(0.1).timeout
		can_swap = true
	if Input.is_action_just_pressed("swap_right") and can_swap:
		can_swap = false
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 0.25
		_current_color = (_current_color + 1) % num_colors
		paint_ui.get_child(1).get_child(0).get_child(_current_color).modulate.a = 1
		paint_prefab = colors[_current_color]
		await get_tree().create_timer(0.1).timeout
		can_swap = true


func _input(event: InputEvent) -> void:
	if not painting_enabled:
		_is_holding = false
		return

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
	if "is_exit" in new_paint:
		new_paint.is_exit = false

	_stroke_container.add_child(new_paint)
	new_paint.global_position = spawn_position

	_resize_circle_shape(new_paint.get_node_or_null("CollisionShape2D"), PlayerVariables.paint_radius)

	var mesh_instance: MeshInstance2D = new_paint.get_node_or_null("MeshInstance2D")
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.mesh = mesh_instance.mesh.duplicate()
		mesh_instance.mesh.radius = PlayerVariables.paint_radius
		mesh_instance.mesh.height = PlayerVariables.paint_radius * 2

	var area := new_paint.get_node_or_null("Area2D")
	if area:
		_resize_circle_shape(area.get_node_or_null("CollisionShape2D"), PlayerVariables.paint_radius + 4)

	_meter_amount -= PlayerVariables.meter_spill_amount
	var progress_bar: ProgressBar = paint_ui.get_child(0)
	progress_bar.value = (_meter_amount / PlayerVariables.max_meter_amount) * 100.0


func set_paint_amount(amount: float) -> void:
	_meter_amount = clampf(amount, 0.0, PlayerVariables.max_meter_amount)

	# Lock the first assigned amount as this level's starting baseline
	if _initial_paint_amount < 0.0:
		_initial_paint_amount = _meter_amount

	var progress_bar: ProgressBar = paint_ui.get_child(0)
	progress_bar.value = (_meter_amount / PlayerVariables.max_meter_amount) * 100.0


func add_paint_amount(amount: float) -> void:
	_meter_amount = clampf(_meter_amount + amount, 0.0, PlayerVariables.max_meter_amount)
	var progress_bar: ProgressBar = paint_ui.get_child(0)
	progress_bar.value = (_meter_amount / PlayerVariables.max_meter_amount) * 100.0


func _resize_circle_shape(shape_node: CollisionShape2D, radius: float) -> void:
	if shape_node == null or shape_node.shape == null:
		return
	shape_node.shape = shape_node.shape.duplicate()
	if shape_node.shape is CircleShape2D:
		shape_node.shape.radius = radius


# Resets drawn strokes, restores the exact initial level paint amount, and synchronizes unlocks
func clear_paint() -> void:
	_is_holding = false

	# 1. Batch remove all painted stroke bodies
	for stroke in _stroke_container.get_children():
		stroke.queue_free()

	# 2. Reset meter to the specific starting quota provided by the level
	var target_amount: float = _initial_paint_amount if _initial_paint_amount >= 0.0 else PlayerVariables.max_meter_amount
	set_paint_amount(target_amount)

	# 3. Restore unlocks and color selection to the level baseline
	num_colors = _initial_num_colors
	_current_color = 0
	_sync_selected_color()
