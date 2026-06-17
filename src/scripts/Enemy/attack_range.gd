extends Area2D

signal attack_requested(target)
signal attack_cleared(target)

var owner_entity: Node = null

func init_from_enemy(enemy: Node) -> void:
	owner_entity = enemy

func _ready() -> void:
	if owner_entity == null and get_parent():
		owner_entity = get_parent()

	if has_signal("body_entered"):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if has_signal("body_exited"):
		connect("body_exited", Callable(self, "_on_body_exited"))
	if has_signal("area_entered"):
		connect("area_entered", Callable(self, "_on_area_entered"))
	if has_signal("area_exited"):
		connect("area_exited", Callable(self, "_on_area_exited"))

func _resolve_player(node: Node) -> Node:
	if node == null:
		return null

	if node.has_method("take_damage"):
		return node

	var owner_node := node.get_owner()
	if owner_node and owner_node.has_method("take_damage"):
		return owner_node

	if node.get_parent() and node.get_parent().has_method("take_damage"):
		return node.get_parent()

	return null

func _emit_requested_for(node: Node) -> void:
	var target := _resolve_player(node)
	if target == null:
		return

	emit_signal("attack_requested", target)

func _emit_cleared_for(node: Node) -> void:
	var target := _resolve_player(node)
	if target == null:
		return

	if _is_target_still_overlapping(target):
		return

	emit_signal("attack_cleared", target)

func _is_target_still_overlapping(target: Node) -> bool:
	if target == null:
		return false

	for body in get_overlapping_bodies():
		if _resolve_player(body) == target:
			return true

	for area in get_overlapping_areas():
		if _resolve_player(area) == target:
			return true

	return false

func has_target_overlapping(target: Node) -> bool:
	return _is_target_still_overlapping(target)

func get_overlapping_target() -> Node:
	for body in get_overlapping_bodies():
		var target := _resolve_player(body)
		if target != null:
			return target

	for area in get_overlapping_areas():
		var target := _resolve_player(area)
		if target != null:
			return target

	return null

func _on_body_entered(body: Node) -> void:
	_emit_requested_for(body)

func _on_body_exited(body: Node) -> void:
	_emit_cleared_for(body)

func _on_area_entered(area: Area2D) -> void:
	_emit_requested_for(area)

func _on_area_exited(area: Area2D) -> void:
	_emit_cleared_for(area)