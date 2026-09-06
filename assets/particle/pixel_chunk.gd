extends RigidBody2D

@onready var color_rect: ColorRect = $ColorRect

var target_position: Vector2 = Vector2.ZERO
var is_homing: bool = false
var homing_time: float = 0.0
var total_homing_duration: float = 0.85
var current_vel: Vector2 = Vector2.ZERO
var start_rot: float = 0.0

# Unique frequency and phase offset for organic floating turbulence
var hover_seed: float = 0.0
var hover_amplitude: float = 0.0


func setup(col: Color, initial_vel: Vector2) -> void:
	color_rect.color = col
	linear_velocity = initial_vel
	# Generate independent floating traits per chunk
	hover_seed = randf_range(0.0, TAU)
	hover_amplitude = randf_range(1.5, 4.0)


func recall_to(target_pos: Vector2, delay: float, duration: float) -> void:
	if is_homing:
		return

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	collision_layer = 0
	collision_mask = 0
	gravity_scale = 0.0

	current_vel = linear_velocity
	rotation = wrapf(rotation, -PI, PI)
	start_rot = rotation
	target_position = target_pos.round()
	total_homing_duration = maxf(duration, 0.1)
	homing_time = 0.0

	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	is_homing = true


func _physics_process(delta: float) -> void:
	if not is_homing:
		return

	homing_time += delta
	var t: float = clampf(homing_time / total_homing_duration, 0.0, 1.0)

	# 1. Base translation: Smooth quintic curve (acceleration to cruise)
	var ease_blend: float = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

	var to_target: Vector2 = target_position - global_position
	var distance: float = to_target.length()

	# 2. Overdamped arrival (critically damped - no bounce or spring overshoot)
	# Approaching the end (t > 0.7), deceleration ramps up heavily to clamp velocity
	var arrival_damping: float = 1.0 - smoothstep(0.7, 1.0, t)
	var pull_factor: float = ease_blend * (12.0 * arrival_damping + 4.0)
	var desired_vel: Vector2 = to_target * pull_factor

	# Steer toward target; high dampening near target eliminates oscillation
	var steer_weight: float = lerpf(3.0, 28.0, ease_blend)
	current_vel = current_vel.lerp(desired_vel, steer_weight * delta)

	# 3. Subtle floating / hover envelope
	# Active primarily during the mid-flight to near-docking phase (peaks between 0.4 and 0.85)
	var hover_envelope: float = sin(t * PI)
	var hover_offset: Vector2 = Vector2.ZERO
	if hover_envelope > 0.01:
		var time_scale: float = homing_time * 7.0 + hover_seed
		# Gentle vertical bobbing with a slight horizontal drift
		hover_offset = Vector2(
			cos(time_scale * 0.7) * (hover_amplitude * 0.4),
			sin(time_scale) * hover_amplitude
		) * hover_envelope

	# Apply position update
	global_position += (current_vel * delta) + (hover_offset * delta * 4.0)

	# Smooth rotation back to 0 without wobble
	rotation = lerp_angle(start_rot, 0.0, ease_blend)

	# Strict snap and clean freeze when time runs out or distance is negligible
	if t >= 1.0 or (distance < 0.4 and current_vel.length() < 5.0):
		global_position = target_position
		rotation = 0.0
		is_homing = false
