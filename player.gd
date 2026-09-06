class_name Player extends CharacterBody2D

# Pixel sand configuration and resource binding
const PIXEL_CHUNK_SCENE = preload("res://assets/particle/PixelChunk.tscn")
@export var pixel_step: int = 4
@export var death_settle_time: float = 1.0
@export var chunk_recall_duration: float = 0.85
@export var chunk_recall_max_delay: float = 0.1

# Stores active pixel chunk references and their sprite offsets
# Format: { "chunk": RigidBody2D, "offset": Vector2 }
var active_chunks: Array[Dictionary] = []
var spawn_point: Vector2 = Vector2.ZERO

var ice_contacts := 0
var bounce_contacts := 0
var gravity_flipped := false
var is_dead := false

@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var walking_sfx: AudioStreamPlayer = $WalkingSFX
@onready var ice_sfx: AudioStreamPlayer = $IceSFX
@onready var jump_sfx: AudioStreamPlayer = $JumpSFX
@onready var death_sfx: AudioStreamPlayer = $DeathSFX

var on_ice: bool:
	get:
		return ice_contacts > 0

var on_bounce: bool:
	get:
		return bounce_contacts > 0

# Landing recovery lock state.
var is_landing := false
var started_falling := false
# Horizontal speed to keep after leaving ice / jumping.
var _air_carry_speed := 0.0
# Gravity pads currently overlapping. Painted dabs from one drag share a stroke id.
var _gravity_pads: Array[Node2D] = []
var _gravity_stroke_id := 0
var _last_gravity_stroke_id := 0
var _gravity_cooldown := 0.0
var _portal_cooldown := 0.0
# After a portal warp, leftover is_on_floor() must not snap or apply ground friction.
var _portal_exit_air := false
var _saved_floor_snap := -1.0
var _jumped_this_airtime := false


const JUMP_COOLDOWN = 0.5
const JUMP_BUFFER_WINDOW = 0.10
const FALL_JUMP_BUFFER_WINDOW = 0.25

var jump_buffer_t := 0.0
var fall_jump_buffer_t := FALL_JUMP_BUFFER_WINDOW
var jump_t := 0.0


func _ready() -> void:
	# Listen for animation finish to automatically exit the landing state.
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	# Record initial coordinates as default spawn point
	spawn_point = global_position
	
	if walking_sfx.stream is AudioStreamMP3:
		var walk_stream: AudioStreamMP3 = walking_sfx.stream.duplicate()
		walk_stream.loop = true
		walking_sfx.stream = walk_stream
	if ice_sfx.stream is AudioStreamMP3:
		var ice_stream: AudioStreamMP3 = ice_sfx.stream.duplicate()
		ice_stream.loop = true
		ice_sfx.stream = ice_stream

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
	_try_gravity_flip()


func exit_gravity_pad(pad: Node2D) -> void:
	_gravity_pads.erase(pad)
	if _gravity_pads.is_empty():
		_gravity_stroke_id = 0
		return
	if not _overlaps_gravity_stroke(_gravity_stroke_id):
		_gravity_stroke_id = _pad_stroke_id(_gravity_pads[0])


func toggle_gravity() -> void:
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


func _is_grounded() -> bool:
	return is_on_floor() and not _portal_exit_air


func teleport_via_portal(destination: Vector2) -> void:
	_air_carry_speed = maxf(_air_carry_speed, abs(velocity.x))
	global_position = destination
	_portal_cooldown = PlayerVariables.portal_cooldown
	_portal_exit_air = true
	started_falling = true
	is_landing = false
	ice_contacts = 0
	bounce_contacts = 0
	_gravity_pads.clear()
	_gravity_stroke_id = 0
	_last_gravity_stroke_id = 0
	if _saved_floor_snap < 0.0:
		_saved_floor_snap = floor_snap_length
	floor_snap_length = 0.0
	reset_physics_interpolation()


func _pad_stroke_id(pad: Node2D) -> int:
	if pad.has_method("get_stroke_id"):
		return pad.get_stroke_id()
	return pad.get_instance_id()


func _overlaps_gravity_stroke(stroke_id: int) -> bool:
	if stroke_id == 0:
		return false
	for pad in _gravity_pads:
		if _pad_stroke_id(pad) == stroke_id:
			return true
	return false


func _try_gravity_flip() -> void:
	if _gravity_pads.is_empty():
		return
	var sid := _pad_stroke_id(_gravity_pads[_gravity_pads.size() - 1])
	if sid == _gravity_stroke_id:
		return
	# Ignore a physics jitter re-entry into the same stroke, but always
	# honor a different stroke (airborne or grounded).
	if sid == _last_gravity_stroke_id and _gravity_cooldown > 0.0:
		return
	toggle_gravity()
	_gravity_stroke_id = sid
	_last_gravity_stroke_id = sid
	if _gravity_pads[_gravity_pads.size() - 1].has_method("play_flip_sfx"):
		_gravity_pads[_gravity_pads.size() - 1].play_flip_sfx()


func _oriented(upward: float) -> float:
	return -upward if up_direction == Vector2.DOWN else upward


func _is_falling() -> bool:
	return velocity.y <= 0.0 if up_direction == Vector2.DOWN else velocity.y >= 0.0


func _physics_process(delta: float) -> void:
	# If dead, stop processing input or animation changes
	if is_dead:
		move_and_slide()
		_update_walking_sfx()
		return

	# Teleport may fire during move_and_slide; only end air-carry after a full step at the exit.
	var finish_portal_air := _portal_exit_air
	
	if jump_buffer_t > 0.0:
		jump_buffer_t -= delta
	jump_t -= delta

	if Input.is_action_just_pressed("teleport debug"):
		global_position = get_global_mouse_position()
		velocity = Vector2.ZERO

	if _gravity_cooldown > 0.0:
		_gravity_cooldown = maxf(_gravity_cooldown - delta, 0.0)
	if _portal_cooldown > 0.0:
		_portal_cooldown = maxf(_portal_cooldown - delta, 0.0)

	_try_gravity_flip()

	# Apply gravity when airborne, or when gravity just flipped and we are still on the old floor.		
	if not _is_grounded() or _gravity_is_flipping():
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
	elif Input.is_action_just_pressed("jump") and _is_grounded():
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
	
	if _is_grounded() and jump_buffer_t > 0.0 and jump_t <= 0.0:
		jump()
		just_jumped = true

	var direction := Input.get_axis("left", "right")
	var target_speed := PlayerVariables.speed
	var accel := PlayerVariables.acceleration
	var decel := PlayerVariables.friction

	if on_ice and _is_grounded() and not just_jumped and not _gravity_is_flipping():
		target_speed = PlayerVariables.ice_speed
		accel = PlayerVariables.ice_acceleration
		decel = PlayerVariables.ice_friction
		_air_carry_speed = abs(velocity.x)
	elif not _is_grounded() or just_jumped or _gravity_is_flipping():
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
	if finish_portal_air:
		_portal_exit_air = false
		if _saved_floor_snap >= 0.0:
			floor_snap_length = _saved_floor_snap
			_saved_floor_snap = -1.0
	if is_on_floor():
		_jumped_this_airtime = false
	elif _gravity_is_flipping():
		up_direction = _desired_up()
	update_animation()
	_update_walking_sfx()


func jump() -> void:
	jump_sfx.play()
	jump_t = JUMP_COOLDOWN
	velocity.y = _oriented(PlayerVariables.jump_velocity)
	_air_carry_speed = maxf(_air_carry_speed, abs(velocity.x))
	jump_buffer_t = 0.0
	is_landing = false


func update_animation() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.flip_v = gravity_flipped

	# Handle horizontal facing direction.
	if velocity.x > 0.0:
		sprite.flip_h = false
	elif velocity.x < 0.0:
		sprite.flip_h = true

	# Case 1: In the air.
	if not _is_grounded():
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
		
func reset_gravity_state() -> void:
	if gravity_flipped:
		gravity_flipped = false
		$Icon.flip_v = false
		sprite.flip_v = false
		up_direction = Vector2.UP
	
	# Clear pad overlaps and reset cooldowns so it's ready for the next life
	_gravity_pads.clear()
	_gravity_stroke_id = 0
	_last_gravity_stroke_id = 0
	_gravity_cooldown = 0.0

func die() -> void:
	if is_dead:
		return
	is_dead = true
	_update_walking_sfx()
	death_sfx.play()

	var impact_velocity: Vector2 = velocity

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	sprite.offset.y = 0.0

	if death_particles:
		death_particles.restart()
		death_particles.emitting = true

	# 1. Reset paintbrush strokes and ink quota
	get_tree().call_group("paintbrush", "set", "painting_enabled", false)
	get_tree().call_group("paintbrush", "clear_paint")

	# 2. Reset level pickups (buckets, coins, switches, etc.)
	get_tree().call_group("level", "reset_level_state")

	call_deferred("spawn_pixel_sand", impact_velocity)
	sprite.visible = false
	velocity = Vector2.ZERO

	await get_tree().create_timer(death_settle_time).timeout
	respawn(spawn_point)

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

			var chunk = PIXEL_CHUNK_SCENE.instantiate() as RigidBody2D
			get_parent().add_child(chunk)

			var raw_offset = Vector2(float(x), float(y)) - sprite_center
			
			var spawn_offset = raw_offset
			if sprite.flip_h:
				spawn_offset.x = -spawn_offset.x
			if sprite.flip_v:
				spawn_offset.y = -spawn_offset.y

			chunk.global_position = sprite.global_position + spawn_offset
			chunk.reset_physics_interpolation()

			var scatter_y: float = randf_range(20.0, 80.0) if gravity_flipped else randf_range(-80.0, -20.0)
			var scatter = Vector2(randf_range(-50.0, 50.0), scatter_y)
			var final_vel = (impact_vel * 0.4) + scatter
			chunk.setup(col, final_vel)
			chunk.gravity_scale = -1.0 if gravity_flipped else 1.0

		
			active_chunks.append({
				"chunk": chunk,
				"offset": raw_offset
			})

func respawn(respawn_position: Vector2) -> void:
	
	global_position = respawn_position.round()
	velocity = Vector2.ZERO
	sprite.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	##sprite.play("Idle")
	##sprite.set_frame_and_progress(0, 0.0)

	for item in active_chunks:
		var chunk = item["chunk"]
		if is_instance_valid(chunk):
			var target_pos: Vector2 = (global_position + item["offset"]).round()
			var delay: float = randf_range(0.0, chunk_recall_max_delay)
			chunk.recall_to(target_pos, delay, chunk_recall_duration)

	await get_tree().create_timer(chunk_recall_duration + chunk_recall_max_delay).timeout
	await get_tree().process_frame

	sprite.visible = true
	is_dead = false
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	# Re-enable painting once the character is fully reconstituted
	get_tree().call_group("paintbrush", "set", "painting_enabled", true)

	for item in active_chunks:
		var chunk = item["chunk"]
		if is_instance_valid(chunk):
			chunk.queue_free()
	reset_gravity_state()
	active_chunks.clear()


func _is_walking() -> bool:
	return (
		not is_dead
		and _is_grounded()
		and not is_landing
		and sprite.animation == "Walking"
		and not is_zero_approx(velocity.x)
	)


func stop_walking_sfx() -> void:
	walking_sfx.stop()
	ice_sfx.stop()


func _update_walking_sfx() -> void:
	var walking_on_ice := _is_walking() and on_ice
	var walking_on_ground := _is_walking() and not on_ice
	if walking_on_ice:
		if not ice_sfx.playing:
			ice_sfx.play()
	elif ice_sfx.playing:
		ice_sfx.stop()
	if walking_on_ground:
		if not walking_sfx.playing:
			walking_sfx.play()
	elif walking_sfx.playing:
		walking_sfx.stop()
