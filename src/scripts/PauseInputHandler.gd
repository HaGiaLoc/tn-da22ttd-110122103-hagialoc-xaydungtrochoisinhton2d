extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("action_pause"):
		return
	var game := get_tree().current_scene
	if not game or not game.has_method("toggle_pause"):
		return
	var player := get_tree().get_first_node_in_group("Player")
	if player and player.get("inventory_ui") and player.inventory_ui.visible:
		return
	game.toggle_pause()
	get_viewport().set_input_as_handled()
