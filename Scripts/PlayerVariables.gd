extends Node


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

# Air: keep ice momentum, but A/D should still steer freely.
var air_acceleration := 2500.0
var air_friction := 100.0

# JUMP PLATFORM
# More negative = higher bounce. Same value every launch, so height stays constant.
var bounce_velocity := -1800

# GRAVITY PLATFORM
# Flip state lives on the player and stays until the next gravity pad.
# Only the Y gravity direction changes. Position and speed are not touched.
# Don't flip again until you leave the current stroke, plus this extra delay.
var gravity_flip_cooldown := 0.2


# PORTAL PLATFORM
# Painted dabs are entries; the level-placed pad is the one-way exit.
# Appear this far along the player's "up" from the exit pad.
var portal_landing_offset := 70.0
# Ignore painted entries briefly after a teleport.
var portal_cooldown := 0.25
# Exit uses air friction / ice carry so ground snap does not dump momentum.
