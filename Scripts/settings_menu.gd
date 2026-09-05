extends CanvasLayer

signal closed

@onready var music_slider: HSlider = $MusicLabel/MusicSlider
@onready var sfx_slider: HSlider = $SFXLabel/SFXSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.value = LevelManager.music_volume
	sfx_slider.value = LevelManager.sfx_volume


func _on_music_slider_value_changed(value: float) -> void:
	LevelManager.set_music_volume(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	LevelManager.set_sfx_volume(value)


func _on_back_button_pressed() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

