extends CharacterBody2D

var ice_contacts := 0
var bounce_contacts := 0
var gravity_flipped := false

var on_ice: bool:
	get:
		return ice_contacts > 0

var on_bounce: bool:
	get:
		return bounce_contacts > 0


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
	if not is_on_floor():
		var gravity := get_gravity()
		if gravity_flipped:
			gravity = -gravity
		velocity += gravity * delta

	if on_bounce and (is_on_floor() or _is_falling()):
		velocity.y = _oriented(PlayerVariables.bounce_velocity)
	elif Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = _oriented(PlayerVariables.jump_velocity)

	var direction := Input.get_axis("left", "right")
	var target_speed := PlayerVariables.speed
	var accel := PlayerVariables.acceleration
	var decel := PlayerVariables.friction

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
