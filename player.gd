class_name Player extends CharacterBody2D

const pixel_chunk_scene = preload("res://assets/particle/PixelChunk.tscn")
@export var pixel_step: int = 4

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
var started_falling := false
# Horizontal speed to keep after leaving ice / jumping.
var _air_carry_speed := 0.0
# Gravity pads currently overlapping. Painted strokes are many pads at once.
var _gravity_pads: Array[Node2D] = []
var _gravity_flip_armed := true
var _gravity_cooldown := 0.0
var _portal_cooldown := 0.0
var _jumped_this_airtime := false



# Base Y-offset applied during jumping animation.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@onready var sand_particles: GPUParticles2D = $SandParticles

const JUMP_Y_OFFSET: float = -109.0
const JUMP_COOLDOWN = 0.5
const JUMP_BUFFER_WINDOW = 0.10
const FALL_JUMP_BUFFER_WINDOW = 0.25

var jump_buffer_t := 0.0
var fall_jump_buffer_t := FALL_JUMP_BUFFER_WINDOW
var jump_t := 0.0

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	




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
	# If dead, perform one final slide to transfer momentum to the particle server, then halt.
	if is_dead:
		move_and_slide()
		velocity = Vector2.ZERO
		return
	
	if jump_buffer_t > 0.0:
		jump_buffer_t -= delta
	jump_t -= delta

	if Input.is_action_just_pressed("teleport debug"):
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO
	if Input.is_action_just_pressed("teleport debug"):
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO

	if _gravity_cooldown > 0.0:
		_gravity_cooldown = maxf(_gravity_cooldown - delta, 0.0)
	if _portal_cooldown > 0.0:
		_portal_cooldown = maxf(_portal_cooldown - delta, 0.0)

	_try_gravity_flip()

	# Apply gravity when airborne, or when gravity just flipped and we are still on the old floor.
	if not is_on_floor():
		if not started_falling:
			started_falling = true
			fall_jump_buffer_t = FALL_JUMP_BUFFER_WINDOW
		var gravity := get_gravity() * PlayerVariables.gravity_multiplier
		if gravity_flipped:
			gravity = -gravity
		velocity += gravity * delta
		fall_jump_buffer_t -= delta
	else:
		started_falling = false

	var just_jumped := false
	if on_bounce:
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
	if Input.is_action_just_pressed("jump"):
		jump_buffer_t = JUMP_BUFFER_WINDOW
		if fall_jump_buffer_t > 0.0 and jump_t <= 0.0:
			jump()
			just_jumped = true
	
	if is_on_floor() and jump_buffer_t > 0.0 and jump_t <= 0.0:
		jump()
		just_jumped = true

	var direction := Input.get_axis("left", "right")
	var target_speed: float = PlayerVariables.speed
	var accel: float = PlayerVariables.acceleration
	var decel: float = PlayerVariables.friction

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


func jump() -> void:
	jump_t = JUMP_COOLDOWN
	velocity.y = _oriented(PlayerVariables.jump_velocity)
	_air_carry_speed = maxf(_air_carry_speed, abs(velocity.x))
	jump_buffer_t = 0.0
	is_landing = false

func update_animation() -> void:
	# Skip ground/jump animation updates while dead.
	if is_dead:
		return

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
			
			
			return

	# If landing sequence (frames 6 -> 7 -> 8) is still playing, keep waiting until frame 8 finishes.
	if is_landing:
		
		
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
		
func die() -> void:
	if is_dead:
		return
	is_dead = true

	# Capture velocity at the moment of impact for the sand shader.
	var impact_velocity: Vector2 = velocity

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	sprite.offset.y = 0.0

	# Original clean approach for native death particles.
	if death_particles:
		death_particles.restart()
		death_particles.emitting = true

	# Trigger the pixel sand dissolve effect.
	trigger_sand_dissolve(impact_velocity)
	spawn_pixel_sand(impact_velocity)

	# 5. Handle reload or respawn after the death animation finishes
	await sprite.animation_finished
	LevelManager.retry()

func trigger_sand_dissolve(impact_vel: Vector2 = Vector2.ZERO) -> void:
	if not sand_particles:
		return

	var cur_anim: String = sprite.animation
	var cur_frame: int = sprite.frame
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(cur_anim, cur_frame)

	if not frame_texture:
		return

	var mat := sand_particles.process_material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("sprite_texture", frame_texture)
		mat.set_shader_parameter("sprite_size", frame_texture.get_size())
		mat.set_shader_parameter("emitter_velocity", impact_vel)
		mat.set_shader_parameter("inherit_ratio", 1.0)

	sprite.visible = false
	sand_particles.restart()
	sand_particles.emitting = true
	
	
func spawn_pixel_sand(impact_vel: Vector2) -> void:
	if not pixel_chunk_scene:
		print("Error: PixelChunkScene not assigned in player Inspector!")
		return

	var cur_anim: String = sprite.animation
	var cur_frame: int = sprite.frame
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(cur_anim, cur_frame)
	
	if not frame_texture:
		return

	var img: Image = frame_texture.get_image()
	if not img:
		return

	var img_size: Vector2i = img.get_size()
	var sprite_center: Vector2 = Vector2(img_size) * 0.5

	for y in range(0, img_size.y, pixel_step):
		for x in range(0, img_size.x, pixel_step):
			var col: Color = img.get_pixel(x, y)
			
			if col.a < 0.1:
				continue
	
			var chunk = pixel_chunk_scene.instantiate() as RigidBody2D
			get_parent().add_child(chunk)
		
			var local_offset = Vector2(float(x), float(y)) - sprite_center
			chunk.global_position = sprite.global_position + local_offset

			var scatter = Vector2(randf_range(-50.0, 50.0), randf_range(-80.0, -20.0))
			var final_vel = (impact_vel * 0.4) + scatter
			
			chunk.setup(col, final_vel)
