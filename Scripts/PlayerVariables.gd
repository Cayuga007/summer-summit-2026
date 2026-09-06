extends Node


var colors = [
	preload("res://platforms/platform.tscn"),
	preload("res://platforms/IcePlatform.tscn"),
	preload("res://platforms/JumpPlatform.tscn"),
	preload("res://platforms/GravityPlatform.tscn"),
	preload("res://platforms/PortalPlatform.tscn"),
]

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
