extends StaticBody2D

# Portals with the same id teleport to each other. Level 2 can leave this at 0.
@export var portal_id: int = 0

var _closed := false


func _ready() -> void:
	add_to_group("portal")


func close() -> void:
	_closed = true
	modulate.a = 0.4


func _on_area_2d_body_entered(body: Node2D) -> void:
	if _closed:
		return
	if not body.is_in_group("Player") or not body.has_method("teleport_via_portal"):
		return
	if body.is_portal_cooling():
		return
	var partner := _find_partner()
	if partner == null:
		return
	partner.close()
	close()
	body.teleport_via_portal(partner.landing_point(body))


func landing_point(player: Node2D) -> Vector2:
	var up := Vector2.UP
	if player is CharacterBody2D:
		up = player.up_direction
	return global_position + up * PlayerVariables.portal_landing_offset


func _find_partner() -> Node:
	for node in get_tree().get_nodes_in_group("portal"):
		if node != self and node.get("portal_id") == portal_id:
			return node
	return null
