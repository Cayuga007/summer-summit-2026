extends Node


const UNLOCK_EVERY := 3

# Waiting to be unlocked, in order.
var colors = [
	preload("res://platforms/IcePlatform.tscn"),
	preload("res://platforms/JumpPlatform.tscn"),
	preload("res://platforms/GravityPlatform.tscn"),
	preload("res://platforms/PortalPlatform.tscn"),
]

# Currently available paint colors.
var unlocked_colors = [
	preload("res://platforms/platform.tscn"),
]

var completed_levels: Array[int] = []


func register_level_completed(level_index: int) -> void:
	if completed_levels.has(level_index):
		return
	completed_levels.append(level_index)
	if completed_levels.size() % UNLOCK_EVERY == 0:
		_unlock_next_color()


func _unlock_next_color() -> void:
	var next_index := unlocked_colors.size() - 1
	if next_index < 0 or next_index >= colors.size():
		return
	unlocked_colors.append(colors[next_index])

# Level parameters
var max_meter_amount: float = 100
var meter_spill_amount: float = 0.25

# Core movement — change these anytime; the player reads them live.
var speed := 300.0
var jump_velocity := -600.0

# Normal ground: snappy start and stop.
var acceleration := 4000.0
var friction := 4000.0

# ICE PLATFORM
# Ice: slow to change speed, keeps sliding, can build a bit extra momentum.
var ice_speed := 400.0
var ice_acceleration := 800.0
var ice_friction := 200.0

# Air: keep ice momentum, still allow some steering.
var air_acceleration := 1500.0
var air_friction := 200.0

# JUMP PLATFORM
# More negative = higher bounce. Same value every launch, so height stays constant.
var bounce_velocity := -800.0

# GRAVITY PLATFORM
# Flip state lives on the player and stays until the next gravity pad.

# PORTAL PLATFORM
# Appear this far along the player's "up" from the destination pad.
var portal_landing_offset := 70.0
# Ignore portal pads briefly after a teleport so you don't bounce back.
var portal_cooldown := 0.25
