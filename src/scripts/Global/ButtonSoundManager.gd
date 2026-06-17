extends AudioStreamPlayer

func _ready() -> void:
	bus = &"SFX"
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	get_tree().node_added.connect(_on_node_added)
	_apply_to_existing_nodes(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_sound):
			node.pressed.connect(_play_button_sound)

func _apply_to_existing_nodes(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_sound):
			node.pressed.connect(_play_button_sound)
	for child in node.get_children():
		_apply_to_existing_nodes(child)

func _play_button_sound() -> void:
	if stream:
		play()
