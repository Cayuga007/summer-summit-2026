extends Button


func _ready() -> void:
	mouse_entered.connect(func():
		ButtonSFX.get_child(0).play())
	pressed.connect(func():
		ButtonSFX.get_child(1).play())

func _play_select_sfx() -> void:
	var template := $SelectSFX as AudioStreamPlayer
	if template == null or template.stream == null:
		return
	# Root-level copy so the sound survives menu close / scene change.
	var sfx := template.duplicate() as AudioStreamPlayer
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	sfx.finished.connect(sfx.queue_free)
	get_tree().root.add_child(sfx)
	sfx.play()
