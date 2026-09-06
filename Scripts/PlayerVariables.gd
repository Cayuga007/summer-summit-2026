extends Node


signal unlocks_changed

const UNLOCK_EVERY := 3
const STARTER_COLOR = preload("res://platforms/platform.tscn")

# Waiting to be unlocked, in order.
var colors = [
	preload("res://platforms/IcePlatform.tscn"),
	preload("res://platforms/JumpPlatform.tscn"),
	preload("res://platforms/GravityPlatform.tscn"),
	preload("res://platforms/PortalPlatform.tscn"),
]

# Currently available paint colors.
var unlocked_colors = [
	STARTER_COLOR,
]

var completed_levels: Array[int] = []
var debug_all_colors := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("unlock debug"):
		toggle_debug_unlocks()


func toggle_debug_unlocks() -> void:
	debug_all_colors = not debug_all_colors
	_rebuild_unlocked_colors()
	unlocks_changed.emit()


func register_level_completed(level_index: int) -> void:
	if completed_levels.has(level_index):
		return
	completed_levels.append(level_index)
	_rebuild_unlocked_colors()
	unlocks_changed.emit()


func _rebuild_unlocked_colors() -> void:
	unlocked_colors = [STARTER_COLOR]
	if debug_all_colors:
		unlocked_colors.append_array(colors)
		return
	var unlock_count := completed_levels.size() / UNLOCK_EVERY
	for i in range(mini(unlock_count, colors.size())):
		unlocked_colors.append(colors[i])

# Level parameters
var max_meter_amount: float = 100
var meter_spill_amount: float = 0.25
var paint_radius := 15

# Core movement — change these anytime; the player reads them live.
var speed := 500.0
var jump_velocity := -1000.0
var gravity_multiplier := 3.0

# Normal ground: snappy start and stop.
var acceleration := 5000.0
var friction := 5000.0

# ICE PLATFORM
# Ice: slow to change speed, keeps sliding, can build a bit extra momentum.
var ice_speed := 1200.0
var ice_acceleration := 2000.0
var ice_friction := 50.0

# Air: keep ice momentum, still allow some steering.
var air_acceleration := 300
var air_friction := 0.0

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
