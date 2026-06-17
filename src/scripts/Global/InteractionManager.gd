extends Node

var _interactables: Array[Node] = []
var active_interactable: Node = null

func register(node: Node) -> void:
	if not _interactables.has(node):
		_interactables.append(node)

func unregister(node: Node) -> void:
	_interactables.erase(node)
	if active_interactable == node:
		if is_instance_valid(active_interactable) and active_interactable.has_method("set_hint_visible"):
			active_interactable.set_hint_visible(false)
		active_interactable = null
		_update_active_interactable()

func _process(_delta: float) -> void:
	_update_active_interactable()

func _update_active_interactable() -> void:
	if _interactables.is_empty():
		if active_interactable:
			if is_instance_valid(active_interactable) and active_interactable.has_method("set_hint_visible"):
				active_interactable.set_hint_visible(false)
			active_interactable = null
		return

	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		if active_interactable:
			if is_instance_valid(active_interactable) and active_interactable.has_method("set_hint_visible"):
				active_interactable.set_hint_visible(false)
			active_interactable = null
		return

	var best_node: Node = null
	var best_score: int = -1
	var best_dist: float = INF
	
	for node in _interactables:
		if not is_instance_valid(node):
			continue
		if node.has_method("can_interact") and not node.can_interact():
			continue
			
		var dist = player.global_position.distance_to(node.global_position)
		var priority = node.get("interaction_priority") if node.get("interaction_priority") != null else 0
		
		if best_node == null or priority > best_score or (priority == best_score and dist < best_dist):
			best_node = node
			best_score = priority
			best_dist = dist

	if best_node != active_interactable:
		if is_instance_valid(active_interactable) and active_interactable.has_method("set_hint_visible"):
			active_interactable.set_hint_visible(false)
		
		active_interactable = best_node
		
		if is_instance_valid(active_interactable) and active_interactable.has_method("set_hint_visible"):
			active_interactable.set_hint_visible(true)
