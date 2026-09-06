class_name Player extends CharacterBody2D

var ice_contacts := 0
var bounce_contacts := 0
var gravity_flipped := false
var is_dead := false

@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var on_ice: bool:
	get:
		return ice_contacts > 0

var on_bounce: bool:
	get:
		return bounce_contacts > 0

# Landing recovery lock state.
var is_landing := false
# Horizontal speed to keep after leaving ice / jumping.
var _air_carry_speed := 0.0

# Base Y-offset applied during jumping animation.
const JUMP_Y_OFFSET: float = -109.0


func _ready() -> void:
	# Listen for animation finish to automatically exit the landing state.
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)


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
	# If dead, stop processing input or animation changes
	if is_dead:
		move_and_slide()
		return

	if Input.is_action_just_pressed("teleport debug"):
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO
		
	if not is_on_floor():
		var gravity := get_gravity()
		if gravity_flipped:
			gravity = -gravity
		velocity += gravity * delta

	var just_jumped := false
	if on_bounce and (is_on_floor() or _is_falling()):
		velocity.y = _oriented(PlayerVariables.bounce_velocity)
		_air_carry_speed = maxf(_air_carry_speed, abs(velocity.x))
		just_jumped = true
		is_landing = false
	elif Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _oriented(PlayerVariables.jump_velocity)
		_air_carry_speed = maxf(_air_carry_speed, abs(velocity.x))
		just_jumped = true
		is_landing = false

	var direction := Input.get_axis("left", "right")
	var target_speed := PlayerVariables.speed
	var accel := PlayerVariables.acceleration
	var decel := PlayerVariables.friction

	if on_ice and is_on_floor() and not just_jumped:
		target_speed = PlayerVariables.ice_speed
		accel = PlayerVariables.ice_acceleration
		decel = PlayerVariables.ice_friction
		_air_carry_speed = abs(velocity.x)
	elif not is_on_floor() or just_jumped:
		accel = PlayerVariables.air_acceleration
		decel = PlayerVariables.air_friction
		target_speed = maxf(PlayerVariables.speed, maxf(_air_carry_speed, abs(velocity.x)))
	else:
		_air_carry_speed = 0.0

	if direction:
		var desired := direction * target_speed
		# Holding the travel direction must not bleed ice/jump momentum.
		if signf(velocity.x) == signf(direction) and abs(velocity.x) > abs(desired):
			desired = velocity.x
		velocity.x = move_toward(velocity.x, desired, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, decel * delta)

	move_and_slide()
	update_animation()


func update_animation() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D

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
	if $AnimatedSprite2D.animation == "Jumping":
		is_landing = false
		$AnimatedSprite2D.offset.y = 0.0
		
		
func die() -> void:
	# Prevent triggering death multiple times
	if is_dead:
		return
	is_dead = true

	# 1. Stop horizontal movement and interactions
	velocity = Vector2.ZERO

	# 2. Trigger the death animation
	sprite.play("Death")

	# 3. Emit the particle effect
	if death_particles:
		death_particles.restart()
		death_particles.emitting = true

	# 4. Optional: Disable collision so the corpse doesn't block hazards/triggers
	$CollisionShape2D.set_deferred("disabled", true)

	# 5. Handle reload or respawn after the death animation finishes
	await sprite.animation_finished
	LevelManager.retry()
