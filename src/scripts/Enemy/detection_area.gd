extends Area2D

signal player_entered(player)
signal player_exited(player)
signal animal_entered(animal)
signal animal_exited(animal)

@export var player_path: NodePath
@export var player_group: String = "player"
@export var animal_group: String = "Animal"

var detected_player = null
var detected_animals: Array = []  ## Danh sách animal đang trong phạm vi


func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited",  Callable(self, "_on_body_exited"))


func _on_body_entered(body: Node) -> void:
	if _is_player_node(body):
		detected_player = body
		emit_signal("player_entered", body)
	elif _is_animal_node(body):
		if not detected_animals.has(body):
			detected_animals.append(body)
		emit_signal("animal_entered", body)


func _on_body_exited(body: Node) -> void:
	if _is_player_node(body):
		if detected_player == body:
			detected_player = null
		emit_signal("player_exited", body)
	elif _is_animal_node(body):
		detected_animals.erase(body)
		emit_signal("animal_exited", body)


func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if player_path != null and player_path != NodePath("") and has_node(player_path) and get_node(player_path) == node:
		return true
	if node.is_in_group(player_group) or node.is_in_group("Player"):
		return true
	return node.name.to_lower().find("player") != -1


func _is_animal_node(node: Node) -> bool:
	if node == null:
		return false
	return node.is_in_group(animal_group)


func get_detected_player():
	return detected_player


func get_nearest_animal(from_position: Vector2) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	var stale: Array = []

	for animal in detected_animals:
		if not is_instance_valid(animal):
			stale.append(animal)
			continue
		var d := from_position.distance_to(animal.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = animal

	for s in stale:
		detected_animals.erase(s)

	return nearest
