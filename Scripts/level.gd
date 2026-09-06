extends Node2D

const PAUSE_MENU := preload("res://UI/Pause_Menu.tscn")
const PAINTBRUSH = preload("res://paintbrush.tscn")
const LEVEL_STARTED = preload("res://UI/level_started.tscn")
const LEVEL_COMPLETED = preload("res://UI/Level_completed.tscn")

var pause_menu: CanvasLayer
var _resetting := false

@export var _buckets: Node2D
@export var starting_paint_amount: float = 100
@export var unlocks: int = 1


func _ready() -> void:
	LevelManager.sync_current_index_from_scene()
	var paintbrush = PAINTBRUSH.instantiate()
	paintbrush.num_colors = unlocks
	add_child(paintbrush)
	add_child(LEVEL_STARTED.instantiate())
	add_child(LEVEL_COMPLETED.instantiate())
	paintbrush.set_paint_amount(starting_paint_amount)
	$VictoryDoor.level_completed.connect(_on_level_completed)
	pause_menu = PAUSE_MENU.instantiate()
	add_child(pause_menu)
	
	if _buckets:
		for bucket: Node in _buckets.get_children():
			bucket = bucket as Bucket
			bucket.collected.connect(func(amount):
				paintbrush.add_paint_amount(amount))


func _physics_process(_delta: float) -> void:
	if _resetting or get_tree().paused:
		return
	if has_node("LevelCompleted") and $LevelCompleted.visible:
		return
	var player := get_node_or_null("Player") as CharacterBody2D
	if player == null:
		return
	for i in player.get_slide_collision_count():
		var collider := player.get_slide_collision(i).get_collider()
		if collider is Node and collider.name in ["Floor", "Ceiling"]:
			_resetting = true
			LevelManager.retry()
			return


func _on_level_completed() -> void:
	pause_menu.hide()
	$LevelCompleted.show()
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused:
		if $LevelCompleted.visible:
			return
		pause_menu.open()
