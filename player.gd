class_name Player extends CharacterBody2D

const pixel_chunk_scene = preload("res://assets/particle/PixelChunk.tscn")
@export var pixel_step: int = 4

# Time in seconds sand chunks simulate physics on the ground before recalling
@export var death_settle_time: float = 1.0

# Flight duration for chunks to travel back to the spawn coordinate
@export var chunk_recall_duration: float = 0.6

# Staggered launch delay to make chunks lift off asynchronously
@export var chunk_recall_max_delay: float = 0.2

var ice_contacts := 0
var bounce_contacts := 0
var gravity_flipped := false

# Stores references to active sand chunks and their relative sprite offsets
# Format: { "chunk": RigidBody2D, "offset": Vector2 }
var active_chunks: Array[Dictionary] = []

var on_ice: bool:
	get:
		return ice_contacts > 0

var on_bounce: bool:
	get:
		return bounce_contacts > 0

# Landing recovery lock state.
var is_landing := false
var is_dead := false

# Horizontal speed to keep after leaving ice / jumping.
var _air_carry_speed := 0.0


# Base Y-offset applied during jumping animation.


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@onready var sand_particles: GPUParticles2D = $SandParticles

# Stores the default spawn/checkpoint coordinate
var spawn_point: Vector2 = Vector2.ZERO

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	# Record current starting coordinate as the initial spawn point
	spawn_point = global_position



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

	if Input.is_action_just_pressed("teleport debug"):
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO
		

	if not is_on_floor():
		var gravity = get_gravity() * PlayerVariables.gravity_multiplier
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
	var target_speed: float = PlayerVariables.speed
	var accel: float = PlayerVariables.acceleration
	var decel: float = PlayerVariables.friction

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

	var impact_velocity: Vector2 = velocity

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	sprite.offset.y = 0.0

	if death_particles:
		death_particles.restart()
		death_particles.emitting = true

	call_deferred("spawn_pixel_sand", impact_velocity)
	sprite.visible = false

	# Wait for chunks to hit the floor, scatter, and settle
	await get_tree().create_timer(death_settle_time).timeout

	# Trigger the sand reassembly back to the spawn point
	respawn(spawn_point)

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
	active_chunks.clear()

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
			
			# Prevent one-frame flash to (0,0) from engine interpolation
			chunk.reset_physics_interpolation()

			var scatter = Vector2(randf_range(-50.0, 50.0), randf_range(-80.0, -20.0))
			var final_vel = (impact_vel * 0.4) + scatter
			chunk.setup(col, final_vel)

			# Record chunk instance and its relative sprite offset
			active_chunks.append({
				"chunk": chunk,
				"offset": local_offset
			})
			
func respawn(respawn_position: Vector2) -> void:
	global_position = respawn_position.round()
	velocity = Vector2.ZERO
	sprite.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	sprite.play("Idle")
	sprite.set_frame_and_progress(0, 0.0)

	var total_max_delay: float = 0.0

	for item in active_chunks:
		var chunk = item["chunk"]
		if is_instance_valid(chunk):
			var target_pos: Vector2 = (global_position + item["offset"]).round()

			# Calculate staggered delay based on distance + slight randomness
			# Chunks closer to the respawn point start returning slightly earlier
			var distance_ratio: float = clampf(chunk.global_position.distance_to(target_pos) / 500.0, 0.0, 1.0)
			var delay: float = (distance_ratio * chunk_recall_max_delay) + randf_range(0.0, 0.1)
			total_max_delay = maxf(total_max_delay, delay)

			chunk.recall_to(target_pos, delay, chunk_recall_duration)

	# Wait until the longest flight path finishes
	await get_tree().create_timer(chunk_recall_duration + total_max_delay).timeout
	await get_tree().process_frame

	# Reveal player and destroy pixel chunks
	sprite.visible = true
	is_dead = false
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	for item in active_chunks:
		var chunk = item["chunk"]
		if is_instance_valid(chunk):
			chunk.queue_free()

	active_chunks.clear()
