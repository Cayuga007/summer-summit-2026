extends StaticBody2D


@export var portal_id: int = 0
# Level-placed pads are exits. The brush sets this false on painted dabs.
var is_exit := true


func _ready() -> void:
	add_to_group("portal")


func _on_area_2d_body_entered(body: Node2D) -> void:
	# Only painted entries teleport. Standing on the level exit does nothing.
	if is_exit:
		return
	if not body.is_in_group("Player") or not body.has_method("teleport_via_portal"):
		return
	if body.has_method("is_portal_cooling") and body.is_portal_cooling():
		return
	var exit_portal := _find_exit()
	if exit_portal == null:
		return
	body.teleport_via_portal(exit_portal.landing_point(body))


func landing_point(player: Node2D) -> Vector2:
	var up := Vector2.UP
	if player is CharacterBody2D:
		up = player.up_direction
	return global_position + up * PlayerVariables.portal_landing_offset


func _find_exit() -> Node:
	var fallback: Node = null
	for node in get_tree().get_nodes_in_group("portal"):
		if node == self or node.get("is_exit") != true:
			continue
		if node.get("portal_id") == portal_id:
			return node
		if fallback == null:
			fallback = node
	return fallback
