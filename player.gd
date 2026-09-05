extends CharacterBody2D

var ice_contacts := 0
var bounce_contacts := 0
var gravity_contacts := 0

var on_ice: bool:
	get:
		return ice_contacts > 0

var on_bounce: bool:
	get:
		return bounce_contacts > 0
		
var on_gravity: bool:
	get:
		return gravity_contacts > 0


func enter_ice() -> void:
	ice_contacts += 1


func exit_ice() -> void:
	ice_contacts = maxi(ice_contacts - 1, 0)


func enter_bounce() -> void:
	bounce_contacts += 1


func exit_bounce() -> void:
	bounce_contacts = maxi(bounce_contacts - 1, 0)

func enter_gravity() -> void:
	gravity_contacts += 1

func exit_gravity() -> void:
	gravity_contacts = maxi(gravity_contacts - 1, 0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if on_gravity and is_on_floor():
		velocity.y *= PlayerVariables.flip_gravity
	if on_bounce and (is_on_floor() or velocity.y >= 0.0):
		velocity.y = PlayerVariables.bounce_velocity
	elif Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = PlayerVariables.jump_velocity

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
