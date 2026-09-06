extends CanvasLayer


@onready var gradient: TextureRect = $Gradient


func _ready() -> void:
	gradient.global_position = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(gradient, "global_position:x", -1700, 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
