@tool
extends Button

@export var button_text: String = "BUTTON":
	set(value):
		button_text = value
		_update_label_text()

@export var button_font_size: int = 24:
	set(value):
		button_font_size = value
		_update_font_size()

@onready var container: SubViewportContainer = $DisplayContainer
@onready var sub_viewport: SubViewport = $DisplayContainer/SubViewport
@onready var background: NinePatchRect = $DisplayContainer/SubViewport/Background
@onready var text_label: Label = $DisplayContainer/SubViewport/TextLabel

var shader_material: ShaderMaterial
var impact_timer: float = 99.0
var is_wave_propagating: bool = false

func _ready() -> void:
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	text = ""

	if container:
		container.stretch = false
	

	if container and container.material:
		container.material = container.material.duplicate()
		shader_material = container.material as ShaderMaterial

	_sync_layout()
	_update_label_text()
	_update_font_size()

	if not Engine.is_editor_hint():
		if shader_material:
			shader_material.set_shader_parameter("wave_time", 99.0)
		mouse_entered.connect(_on_mouse_entered)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_layout()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_wave_propagating or not shader_material:
		return

	impact_timer += delta
	shader_material.set_shader_parameter("wave_time", impact_timer)

	if impact_timer > 1.2:
		is_wave_propagating = false
		shader_material.set_shader_parameter("wave_time", 99.0)


func _sync_layout() -> void:
	var w = max(int(size.x), 1)
	var h = max(int(size.y), 1)
	var target_size = Vector2(w, h)

	if container:
		container.size = target_size
	if sub_viewport:
		sub_viewport.size = Vector2i(target_size)
	if background:
		background.size = target_size
	if text_label:
		text_label.size = target_size

func _update_label_text() -> void:
	if text_label:
		text_label.text = button_text

func _update_font_size() -> void:
	if text_label:
		text_label.add_theme_font_size_override("font_size", button_font_size)

func _on_mouse_entered() -> void:
	_trigger_jelly_strike()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_trigger_jelly_strike()

func _trigger_jelly_strike() -> void:
	if not shader_material or size.x <= 0.0 or size.y <= 0.0:
		return

	var local_mouse = get_local_mouse_position()
	var uv_origin = Vector2(
		clamp(local_mouse.x / size.x, 0.0, 1.0),
		clamp(local_mouse.y / size.y, 0.0, 1.0)
	)

	shader_material.set_shader_parameter("hit_origin", uv_origin)
	impact_timer = 0.0
	is_wave_propagating = true
