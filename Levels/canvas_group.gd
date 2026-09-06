extends CanvasGroup

func _ready() -> void:
	randomize()
	
	if material is ShaderMaterial:
		var random_offset := Vector2(
			randf_range(0.0, 10000.0), 
			randf_range(0.0, 10000.0)
		)
		(material as ShaderMaterial).set_shader_parameter("global_offset", random_offset)
		
