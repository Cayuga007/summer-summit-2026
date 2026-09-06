class_name Player extends CharacterBody2D

var ice_contacts := 0
var bounce_contacts := 0
var gravity_flipped := false

var on_ice: bool:
	get:
		return ice_contacts > 0

var on_bounce: bool:
	get:
		return bounce_contacts > 0

# Landing recovery lock state.
var is_landing := false
var is_dead := false

# Base Y-offset applied during jumping animation.
const JUMP_Y_OFFSET: float = -109.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@onready var sand_particles: GPUParticles2D = $SandParticles


func _ready() -> void:
	# Listen for animation finish to automatically exit the landing state.
	sprite.animation_finished.connect(_on_animation_finished)


func enter_ice() -> void:
	ice_contacts += 1


func exit_ice() -> void:
	ice_contacts = maxi(ice_contacts - 1, 0)


func enter_bounce() -> void:
	bounce_contacts += 1


func exit_bounce() -> void:
	bounce_contacts = maxi(bounce_contacts - 1, 0)


func toggle_gravity() -> void:
	gravity_flipped = not gravity_flipped
	up_direction = Vector2.DOWN if gravity_flipped else Vector2.UP
	$Icon.flip_v = gravity_flipped
	# Launch into the new "down" so we leave the pad instead of sticking to it.
	velocity.y = abs(PlayerVariables.jump_velocity) * (-1.0 if gravity_flipped else 1.0)


func _oriented(upward: float) -> float:
	return -upward if gravity_flipped else upward


func _is_falling() -> bool:
	return velocity.y <= 0.0 if gravity_flipped else velocity.y >= 0.0


func _physics_process(delta: float) -> void:
	# If dead, perform one final slide to transfer momentum to the particle server, then halt.
	if is_dead:
		move_and_slide()
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		var gravity := get_gravity()
		if gravity_flipped:
			gravity = -gravity
		velocity += gravity * delta

	if on_bounce and (is_on_floor() or _is_falling()):
		velocity.y = _oriented(PlayerVariables.bounce_velocity)
		is_landing = false
	elif Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _oriented(PlayerVariables.jump_velocity)
		is_landing = false

	var direction := Input.get_axis("left", "right")
	var target_speed: float = PlayerVariables.speed
	var accel: float = PlayerVariables.acceleration
	var decel: float = PlayerVariables.friction

	if on_ice and is_on_floor():
		target_speed = PlayerVariables.ice_speed
		accel = PlayerVariables.ice_acceleration
		decel = PlayerVariables.ice_friction
	elif not is_on_floor():
		accel = PlayerVariables.air_acceleration
		decel = PlayerVariables.air_friction

	if direction:
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, decel * delta)

	move_and_slide()
	update_animation()


func die() -> void:
	if is_dead:
		return
	is_dead = true

	# Capture velocity at the moment of impact before zeroing movement.
	var impact_velocity: Vector2 = velocity

	# Disable collision immediately so hazards do not re-trigger.
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Reset visual vertical offset.
	sprite.offset.y = 0.0

	# Trigger simultaneous pixel sand collapse with inherited momentum.
	trigger_sand_dissolve(impact_velocity)

	# Halt player body movement.
	velocity = Vector2.ZERO

func update_animation() -> void:
	# Skip ground/jump animation updates while dead.
	if is_dead:
		return

	# Handle horizontal facing direction.
	if velocity.x > 0.0:
		sprite.flip_h = false
	elif velocity.x < 0.0:
		sprite.flip_h = true

	# Case 1: In the air.
	if not is_on_floor():
		is_landing = false

		if sprite.animation != "Jumping":
			sprite.play("Jumping")

		# Apply vertical jumping offset.
		sprite.offset.y = -JUMP_Y_OFFSET if gravity_flipped else JUMP_Y_OFFSET

		# Pause default playback so physics manually steers the frames.
		sprite.pause()

		# Determine upward and downward motion relative to inverted gravity.
		var upward_velocity: float = -velocity.y if gravity_flipped else velocity.y
		var max_jump_speed: float = abs(PlayerVariables.jump_velocity)

		# Map the mid-air portion (frames 1 to 5) across the vertical velocity curve.
		# progress: 0.0 = moving upward fastest -> 0.5 = peak/apex -> 1.0 = falling down
		var progress: float = remap(upward_velocity, -max_jump_speed, max_jump_speed, 0.0, 1.0)
		progress = clampf(progress, 0.0, 1.0)

		var target_frame: int = int(round(remap(progress, 0.0, 1.0, 1.0, 5.0)))
		sprite.set_frame_and_progress(target_frame, 0.0)
		return

	# Case 2: Just landed on the ground, trigger frames 6 -> 7 -> 8.
	if sprite.animation == "Jumping" and not is_landing:
		# If the sprite was still in air frames (1 to 5), start the landing sequence.
		if sprite.frame < 6:
			is_landing = true
			sprite.set_frame_and_progress(6, 0.0)
			sprite.play()
			sprite.offset.y = -JUMP_Y_OFFSET if gravity_flipped else JUMP_Y_OFFSET
			return

	# If landing sequence (frames 6 -> 7 -> 8) is still playing, keep waiting until frame 8 finishes.
	if is_landing:
		sprite.offset.y = -JUMP_Y_OFFSET if gravity_flipped else JUMP_Y_OFFSET
		return

	# Reset Y offset for standard ground animations.
	sprite.offset.y = 0.0

	# Case 3: Standard ground states (Idle / Walking).
	if not is_zero_approx(velocity.x):
		sprite.play("Walking")
	else:
		sprite.play("Idle")


func _on_animation_finished() -> void:
	# Once the Jumping animation finishes playing through frame 8, release the landing lock and reset offset.
	if sprite.animation == "Jumping":
		is_landing = false
		sprite.offset.y = 0.0

func trigger_sand_dissolve(impact_vel: Vector2 = Vector2.ZERO) -> void:
	if not sand_particles:
		return

	# Retrieve the exact texture of the currently active animation frame.
	var cur_anim: String = sprite.animation
	var cur_frame: int = sprite.frame
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(cur_anim, cur_frame)

	if not frame_texture:
		return

	# Detach the particle system from the player node tree into world space.
	sand_particles.top_level = true
	sand_particles.global_position = sprite.global_position

	# Pass texture, dimensions, and player velocity parameters to the custom shader.
	var mat := sand_particles.process_material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("sprite_texture", frame_texture)
		mat.set_shader_parameter("sprite_size", frame_texture.get_size())
		mat.set_shader_parameter("emitter_velocity", impact_vel)
		mat.set_shader_parameter("inherit_ratio", 1.0)

	# Hide the source character sprite and emit the pixel sand burst.
	sprite.visible = false
	sand_particles.restart()
	sand_particles.emitting = true
