extends Node

const RESOURCE_CHECK_RADIUS := 16.0

var _water_layer: TileMapLayer = null
var _resource_nodes: Array[Node] = []
var _last_scene: Node = null


func is_water(world_pos: Vector2) -> bool:
	var layer := _get_water_layer()
	if layer == null:
		return false
	var tile_pos: Vector2i = layer.local_to_map(layer.to_local(world_pos))
	var data := layer.get_cell_tile_data(tile_pos)
	return data != null


func is_valid_patrol_position(world_pos: Vector2) -> bool:
	if is_water(world_pos):
		return false
	return not _is_on_resource_node(world_pos)


func _is_on_resource_node(world_pos: Vector2) -> bool:
	_refresh_resource_cache()
	for node in _resource_nodes:
		if not is_instance_valid(node):
			continue
		if node is Node2D and world_pos.distance_to((node as Node2D).global_position) <= RESOURCE_CHECK_RADIUS:
			return true
	return false


func _refresh_resource_cache() -> void:
	_sync_scene_cache()
	if _resource_nodes.is_empty() and _last_scene != null:
		_collect_resource_nodes(_last_scene)


func _get_water_layer() -> TileMapLayer:
	_sync_scene_cache()

	if _water_layer != null and is_instance_valid(_water_layer):
		return _water_layer

	_water_layer = _find_water_layer(_last_scene)
	return _water_layer


func _sync_scene_cache() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == _last_scene:
		return
	_water_layer = null
	_resource_nodes.clear()
	_last_scene = current_scene


func _find_water_layer(node: Node) -> TileMapLayer:
	if node == null:
		return null
	if node is TileMapLayer and node.name == "Water":
		return node as TileMapLayer
	for child in node.get_children():
		var result := _find_water_layer(child)
		if result != null:
			return result
	return null


func _collect_resource_nodes(node: Node) -> void:
	if node is ResourceNode:
		_resource_nodes.append(node)
		return
	for child in node.get_children():
		_collect_resource_nodes(child)



func _get_patrol_shape(patrol_area: Area2D) -> CollisionShape2D:
	if patrol_area == null:
		return null
	var shape_node := patrol_area.get_node_or_null("CollisionShape2D")
	if shape_node is CollisionShape2D:
		return shape_node
	return null


func get_patrol_area_center(patrol_area: Area2D) -> Vector2:
	var shape_node := _get_patrol_shape(patrol_area)
	if shape_node != null:
		return shape_node.global_position
	if patrol_area != null:
		return patrol_area.global_position
	return Vector2.ZERO


func get_patrol_area_radius(patrol_area: Area2D) -> float:
	var shape_node := _get_patrol_shape(patrol_area)
	if shape_node != null and shape_node.shape is CircleShape2D:
		var circle_shape := shape_node.shape as CircleShape2D
		var scale := shape_node.global_transform.get_scale()
		return maxf(1.0, circle_shape.radius * maxf(abs(scale.x), abs(scale.y)))
	return 0.0


func is_inside_patrol_area(patrol_area: Area2D, world_pos: Vector2) -> bool:
	var shape_node := _get_patrol_shape(patrol_area)
	if shape_node == null or shape_node.shape == null:
		return false
	var local_pos := shape_node.global_transform.affine_inverse() * world_pos
	if shape_node.shape is CircleShape2D:
		var circle_shape := shape_node.shape as CircleShape2D
		return local_pos.length() <= circle_shape.radius
	return false


func clamp_to_patrol_area(patrol_area: Area2D, world_pos: Vector2) -> Vector2:
	var shape_node := _get_patrol_shape(patrol_area)
	if shape_node == null or shape_node.shape == null:
		return world_pos
	var local_pos := shape_node.global_transform.affine_inverse() * world_pos
	if shape_node.shape is CircleShape2D:
		var circle_shape := shape_node.shape as CircleShape2D
		if local_pos.length() <= circle_shape.radius:
			return world_pos
		var clamped_local := local_pos.normalized() * circle_shape.radius
		return shape_node.global_transform * clamped_local
	return world_pos


func pick_patrol_target(
	patrol_area: Area2D,
	fallback_center: Vector2,
	from_position: Vector2,
	patrol_step: float,
	rng: RandomNumberGenerator,
	max_attempts: int = 32
) -> Vector2:
	if patrol_area == null:
		return fallback_center

	var shape_node := _get_patrol_shape(patrol_area)
	if shape_node == null or shape_node.shape == null or not shape_node.shape is CircleShape2D:
		return get_patrol_area_center(patrol_area)

	var circle_shape := shape_node.shape as CircleShape2D
	var radius := circle_shape.radius
	if radius <= 0.0:
		return shape_node.global_position

	var from_inside := is_inside_patrol_area(patrol_area, from_position)

	for _i in max_attempts:
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.0, radius)
		var local_candidate := Vector2(cos(angle), sin(angle)) * dist
		var candidate := shape_node.global_transform * local_candidate
		if not is_inside_patrol_area(patrol_area, candidate):
			continue
		if from_inside and candidate.distance_to(from_position) < patrol_step:
			continue
		if is_valid_patrol_position(candidate):
			return candidate

	for a in range(8):
		var angle := (TAU / 8.0) * a
		var local_candidate := Vector2(cos(angle), sin(angle)) * radius * 0.8
		var candidate := shape_node.global_transform * local_candidate
		if is_inside_patrol_area(patrol_area, candidate) and is_valid_patrol_position(candidate):
			return candidate

	return clamp_to_patrol_area(patrol_area, from_position)
