extends Button

# Ambient hover settings
@export_range(0.0, 1.0) var max_hover_amount: float = 0.4
@export var hover_in_duration: float = 0.2
@export var hover_out_duration: float = 0.3

# Slime fluid impact settings
@export_range(0.05, 0.25) var impact_depth: float = 0.12        # Scale indentation depth
@export_range(2.0, 15.0) var push_distance: float = 6.0         # How many pixels the dent pushes inwards
@export var fluid_viscosity: float = 7.5                        # Damping rate (controls wave dissipation)
@export var fluid_frequency: float = 11.0                       # Oscillation speed (lower = heavier slime)

@onready var background: NinePatchRect = $Background
var shader_material: ShaderMaterial
var hover_tween: Tween

# Physical state variables
var is_impact_active: bool = false
var impact_time: float = 0.0
var impact_direction: Vector2 = Vector2.ZERO                    # Normalized direction from hit point to center
var initial_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	initial_position = position
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)

	if background and background.material:
		background.material = background.material.duplicate()
		shader_material = background.material as ShaderMaterial

	if shader_material:
		shader_material.set_shader_parameter("hover_amount", 0.0)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(delta: float) -> void:
	if not is_impact_active:
		return

	impact_time += delta

	# Viscous fluid exponential decay
	var decay: float = exp(-fluid_viscosity * impact_time)

	# Primary wave: Starts with strong inward compression
	var primary_wave: float = -cos(fluid_frequency * impact_time) * decay

	# Secondary wave: Propagates to the opposite side with a quarter-cycle phase lag (0.5 * PI)
	var distal_wave: float = -sin(fluid_frequency * impact_time) * decay

	# 1. Asymmetric scale deformation along the impact axis
	var compression: float = primary_wave * impact_depth
	var lateral_expansion: float = -primary_wave * (impact_depth * 0.6) # Slime volume conservation

	# Project compression onto the 2D axes based on impact angle
	var dir_sqr = Vector2(impact_direction.x * impact_direction.x, impact_direction.y * impact_direction.y)
	scale.x = 1.0 + dir_sqr.x * compression + dir_sqr.y * lateral_expansion
	scale.y = 1.0 + dir_sqr.y * compression + dir_sqr.x * lateral_expansion

	# 2. Positional displacement: Shifts inwards initially, then overshoots towards the far side
	var wave_offset = (primary_wave * 0.6 + distal_wave * 0.4) * push_distance * decay
	position = initial_position + impact_direction * wave_offset

	# Terminate motion when energy has completely dissipated
	if decay < 0.005 or impact_time > 0.85:
		is_impact_active = false
		scale = Vector2.ONE
		position = initial_position

func _on_mouse_entered() -> void:
	_trigger_directional_impact()
	_animate_hover(max_hover_amount, hover_in_duration)

func _on_mouse_exited() -> void:
	_animate_hover(0.0, hover_out_duration)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_trigger_directional_impact(1.4) # Stronger impact poke on click

func _trigger_directional_impact(force_mult: float = 1.0) -> void:
	var local_mouse = get_local_mouse_position()
	var center = size * 0.5
	var raw_dir = center - local_mouse

	# Ensure we have a valid entry direction even if mouse lands near center
	if raw_dir.length() > 2.0:
		impact_direction = raw_dir.normalized()
	else:
		impact_direction = Vector2(0.0, 1.0)

	# Record base position in case of layout shifts
	initial_position = position
	impact_time = 0.0
	is_impact_active = true

func _animate_hover(target_value: float, duration: float) -> void:
	if not shader_material:
		return

	if hover_tween and hover_tween.is_running():
		hover_tween.kill()

	hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(shader_material, "shader_parameter/hover_amount", target_value, duration)
