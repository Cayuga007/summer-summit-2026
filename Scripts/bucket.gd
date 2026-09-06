class_name Bucket extends Area2D


signal collected(amount)
@export var fill_amount: int = 50
var touched := false

@onready var collect_sfx: AudioStreamPlayer = $PaintBucketSFX


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not touched:
		touched = true
		collected.emit(fill_amount)
		_play_collect_sfx()
		queue_free()


func _play_collect_sfx() -> void:
	var sfx := collect_sfx
	remove_child(sfx)
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
