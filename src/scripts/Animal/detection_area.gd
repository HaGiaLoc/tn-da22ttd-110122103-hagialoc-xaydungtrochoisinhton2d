extends Area2D

signal player_entered(player)
signal player_exited(player)

@export var player_path: NodePath
@export var player_group: String = "player"

var detected_player = null

func _ready() -> void:
	if has_signal("body_entered"):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if has_signal("body_exited"):
		connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if _is_player_node(body):
		detected_player = body
		emit_signal("player_entered", body)

func _on_body_exited(body: Node) -> void:
	if _is_player_node(body):
		if detected_player == body:
			detected_player = null
		emit_signal("player_exited", body)

func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if player_path != null and player_path != NodePath("") and has_node(player_path) and get_node(player_path) == node:
		return true
	if node.has_method("is_in_group") and node.is_in_group(player_group):
		return true
	return node.name.to_lower().find("player") != -1

func get_detected_player():
	return detected_player
