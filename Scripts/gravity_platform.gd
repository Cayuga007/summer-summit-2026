extends StaticBody2D


# Shared by every dab from one paint drag. 0 means a level-placed pad (uses instance id).
var stroke_id := 0

@onready var gravity_platform_sfx: AudioStreamPlayer = $GravityPlatformSFX


func _ready() -> void:
	# Trigger only — painted gravity dabs should never act as solid ground.
	collision_layer = 0
	collision_mask = 0


func get_stroke_id() -> int:
	return stroke_id if stroke_id != 0 else get_instance_id()


func play_flip_sfx() -> void:
	gravity_platform_sfx.play()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("enter_gravity_pad"):
		body.enter_gravity_pad(self)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.has_method("exit_gravity_pad"):
		body.exit_gravity_pad(self)
