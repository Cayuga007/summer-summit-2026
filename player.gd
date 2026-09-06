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
# Gravity pads currently overlapping. Painted strokes are many pads at once.
var _gravity_pads: Array[Node2D] = []
var _gravity_flip_armed := true
var _gravity_cooldown := 0.0
var _portal_cooldown := 0.0
var _jumped_this_airtime := false

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


func enter_gravity_pad(pad: Node2D) -> void:
	if _gravity_pads.has(pad):
		return
	_gravity_pads.append(pad)


func exit_gravity_pad(pad: Node2D) -> void:
	_gravity_pads.erase(pad)
	if _gravity_pads.is_empty():
		_gravity_flip_armed = true


func toggle_gravity() -> void:
	_gravity_flip_armed = false
	_gravity_cooldown = PlayerVariables.gravity_flip_cooldown
	gravity_flipped = not gravity_flipped
	$Icon.flip_v = gravity_flipped
	sprite.flip_v = gravity_flipped


func _desired_up() -> Vector2:
	return Vector2.DOWN if gravity_flipped else Vector2.UP


func _gravity_is_flipping() -> bool:
	return up_direction != _desired_up()


func is_portal_cooling() -> bool:
	return _portal_cooldown > 0.0


func teleport_via_portal(destination: Vector2) -> void:
	global_position = destination
	_portal_cooldown = PlayerVariables.portal_cooldown


func _try_gravity_flip() -> void:
	if not _gravity_flip_armed or _gravity_cooldown > 0.0:
		return
	if _gravity_pads.is_empty() or not is_on_floor():
		return
	toggle_gravity()


func _oriented(upward: float) -> float:
	return -upward if up_direction == Vector2.DOWN else upward


func _is_falling() -> bool:
	return velocity.y <= 0.0 if up_direction == Vector2.DOWN else velocity.y >= 0.0


func _physics_process(delta: float) -> void:
	# If dead, stop processing input or animation changes
	if is_dead:
		move_and_slide()
		return

	if Input.is_action_just_pressed("teleport debug"):
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO

	if _gravity_cooldown > 0.0:
		_gravity_cooldown = maxf(_gravity_cooldown - delta, 0.0)
	if _portal_cooldown > 0.0:
		_portal_cooldown = maxf(_portal_cooldown - delta, 0.0)

	_try_gravity_flip()

	# Apply gravity when airborne, or when gravity just flipped and we are still on the old floor.
	if not is_on_floor() or _gravity_is_flipping():
		var gravity := get_gravity() * PlayerVariables.gravity_multiplier
		if gravity_flipped:
			gravity = -gravity
		velocity += gravity * delta

	var just_jumped := false
	if on_bounce and (is_on_floor() or _is_falling()):
		velocity.y = _oriented(PlayerVariables.bounce_velocity)
		_air_carry_speed = maxf(_air_carry_speed, abs(velocity.x))
		just_jumped = true
		is_landing = false
		_jumped_this_airtime = true
	elif Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _oriented(PlayerVariables.jump_velocity)
		_air_carry_speed = maxf(_air_carry_speed, abs(velocity.x))
		just_jumped = true
		is_landing = false
		_jumped_this_airtime = true

	var direction := Input.get_axis("left", "right")
	var target_speed := PlayerVariables.speed
	var accel := PlayerVariables.acceleration
	var decel := PlayerVariables.friction

	if on_ice and is_on_floor() and not just_jumped and not _gravity_is_flipping():
		target_speed = PlayerVariables.ice_speed
		accel = PlayerVariables.ice_acceleration
		decel = PlayerVariables.ice_friction
		_air_carry_speed = abs(velocity.x)
	elif not is_on_floor() or just_jumped or _gravity_is_flipping():
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
	if is_on_floor():
		_jumped_this_airtime = false
	elif _gravity_is_flipping():
		up_direction = _desired_up()
	update_animation()


func update_animation() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.flip_v = gravity_flipped

	# Handle horizontal facing direction.
	if velocity.x > 0.0:
		sprite.flip_h = false
	elif velocity.x < 0.0:
		sprite.flip_h = true

	# Case 1: In the air.
	if not is_on_floor():
		is_landing = false

		# Gravity lift-off is not a jump — keep the grounded sprite so it does not pop.
		if not _jumped_this_airtime:
			sprite.offset.y = 0.0
			if not is_zero_approx(velocity.x):
				sprite.play("Walking")
			else:
				sprite.play("Idle")
			return

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
