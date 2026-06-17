class_name BuildingPlacer
extends Node

signal placement_confirmed(recipe_index: int, world_position: Vector2)
signal placement_cancelled

@export var grid_size: int = 18

var _active: bool = false
var _recipe_index: int = -1
var _building_component: BuildingComponent
var _inventory_ui: Control
var _resolved_grid_size: int = 18

var _ghost: Node2D = null
const GHOST_COLOR         := Color(1.0, 1.0, 1.0, 0.55)
const GHOST_COLOR_INVALID := Color(1.0, 0.2, 0.2, 0.65)
const RESOURCE_OVERLAP_COLOR := Color(1.0, 0.15, 0.15, 1.0)

const BUILDING_COLLISION_LAYER := 2048

var _highlighted_resources: Array[Node2D] = []
var _highlighted_buildings: Array[Node2D] = []
var _placement_valid: bool = true
var _warning_label: Label = null


func start_placement(
	recipe_index: int,
	component: BuildingComponent,
	inventory_ui: Control
) -> void:
	if _active:
		_clear_ghost()

	_recipe_index = recipe_index
	_building_component = component
	_inventory_ui = inventory_ui

	_resolved_grid_size = _read_tilemap_grid_size()

	var recipe = component.get_recipe(recipe_index)
	if not recipe or not recipe.is_valid():
		push_warning("[BuildingPlacer] Recipe không hợp lệ.")
		return

	if _inventory_ui:
		_inventory_ui.visible = false

	_spawn_ghost(recipe.building_scene)
	_active = true


func _process(_delta: float) -> void:
	if not _active or not _ghost:
		return

	var viewport := get_viewport()
	var mouse_world := viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
	_ghost.global_position = _snap_to_grid(mouse_world)

	_update_overlap()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_confirm_placement()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				_cancel_placement()
				get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_placement()
		get_viewport().set_input_as_handled()



func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		snappedf(pos.x, _resolved_grid_size),
		snappedf(pos.y, _resolved_grid_size)
	)


func _read_tilemap_grid_size() -> int:
	var scene := get_tree().current_scene
	if not scene:
		return grid_size
	var tilemap := _find_tilemap(scene)
	if tilemap and tilemap.tile_set:
		var ts: Vector2i = tilemap.tile_set.tile_size
		return mini(ts.x, ts.y)
	return grid_size


func _find_tilemap(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		return node as TileMapLayer
	for child in node.get_children():
		var result := _find_tilemap(child)
		if result:
			return result
	return null


func _spawn_ghost(scene_path: String) -> void:
	if scene_path.is_empty():
		return

	var packed: PackedScene = load(scene_path)
	if not packed:
		push_warning("[BuildingPlacer] Không load được scene ghost: %s" % scene_path)
		return

	_ghost = packed.instantiate()

	_disable_ghost_node(_ghost)

	if _ghost is CanvasItem:
		_ghost.modulate = GHOST_COLOR

	var world := get_tree().current_scene
	world.add_child(_ghost)


func _disable_ghost_node(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		(node as Node2D).visible = false
		(node as CollisionShape2D).disabled = true if node is CollisionShape2D else (node as CollisionShape2D).disabled
	if node is CollisionShape2D:
		node.disabled = true
	if node is Area2D or node is StaticBody2D or node is CharacterBody2D or node is RigidBody2D:
		(node as CollisionObject2D).collision_layer = 0
		(node as CollisionObject2D).collision_mask = 0
	if node.get_script():
		node.set_script(null)
	for child in node.get_children():
		_disable_ghost_node(child)


func _confirm_placement() -> void:
	if not _placement_valid:
		_show_cannot_build_warning()
		return

	if not _building_component or not _building_component.can_build(_recipe_index):
		_cancel_placement()
		return

	var place_pos := _ghost.global_position
	_clear_ghost()
	_active = false

	var recipe = _building_component.get_recipe(_recipe_index)
	var inventory_system := get_tree().root.get_node_or_null("/root/InventorySystem")
	if inventory_system:
		var player_inv = inventory_system.get_player_inventory()
		if player_inv:
			for res in recipe.ingredients:
				var ing = res as BuildIngredient
				if ing:
					player_inv.remove_item_by_id(ing.item_id, ing.quantity)

	var packed: PackedScene = load(recipe.building_scene)
	if packed:
		var building := packed.instantiate()
		var save_system := get_tree().root.get_node_or_null("/root/SaveSystem")
		if save_system and save_system.has_method("prepare_player_placed_building"):
			save_system.prepare_player_placed_building(building)
		else:
			building.set_meta("player_placed", true)
		get_tree().current_scene.add_child(building)
		if building is Node2D:
			building.global_position = place_pos
			
		if building.scene_file_path != "":
			var b_id = building.scene_file_path.get_file().get_basename()
			TutorialManager.notify_built(b_id)

	emit_signal("placement_confirmed", _recipe_index, place_pos)

	if _inventory_ui:
		_inventory_ui.visible = true


func _cancel_placement() -> void:
	_clear_ghost()
	_active = false

	emit_signal("placement_cancelled")

	if _inventory_ui:
		_inventory_ui.visible = true


func _clear_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_clear_resource_highlights()
	_clear_building_highlights()
	_placement_valid = true


func is_active() -> bool:
	return _active



func _update_overlap() -> void:
	if not _ghost:
		return

	_clear_resource_highlights()
	_clear_building_highlights()

	var ghost_pos := _ghost.global_position
	var check_radius: float = _resolved_grid_size * 1.5

	var overlapping_resources: Array[Node2D] = []
	_find_overlapping_resources(get_tree().current_scene, ghost_pos, check_radius, overlapping_resources)

	var overlapping_buildings: Array[Node2D] = _find_overlapping_buildings(ghost_pos)

	if overlapping_resources.is_empty() and overlapping_buildings.is_empty():
		_placement_valid = true
		if _ghost is CanvasItem:
			_ghost.modulate = GHOST_COLOR
	else:
		_placement_valid = false
		if _ghost is CanvasItem:
			_ghost.modulate = GHOST_COLOR_INVALID
		for node in overlapping_resources:
			node.modulate = RESOURCE_OVERLAP_COLOR
			_highlighted_resources.append(node)
		for node in overlapping_buildings:
			node.modulate = GHOST_COLOR_INVALID
			_highlighted_buildings.append(node)


func _find_overlapping_buildings(ghost_pos: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []

	var space := get_tree().current_scene.get_world_2d().direct_space_state as PhysicsDirectSpaceState2D
	if not space:
		return result

	var shape := RectangleShape2D.new()
	shape.size = Vector2(_resolved_grid_size, _resolved_grid_size) * 0.9

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, ghost_pos)
	params.collision_mask = BUILDING_COLLISION_LAYER
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var hits: Array[Dictionary] = space.intersect_shape(params, 8)
	for hit in hits:
		var body := hit.get("collider") as Node2D
		if body and is_instance_valid(body):
			result.append(body)

	return result


func _find_overlapping_resources(node: Node, ghost_pos: Vector2, radius: float, result: Array[Node2D]) -> void:
	if node is ResourceNode:
		var rn := node as Node2D
		if rn.global_position.distance_to(ghost_pos) <= radius:
			result.append(rn)
		return
	if node == _ghost:
		return
	for child in node.get_children():
		_find_overlapping_resources(child, ghost_pos, radius, result)


func _clear_resource_highlights() -> void:
	for node in _highlighted_resources:
		if is_instance_valid(node):
			node.modulate = Color.WHITE
	_highlighted_resources.clear()


func _clear_building_highlights() -> void:
	for node in _highlighted_buildings:
		if is_instance_valid(node):
			node.modulate = Color.WHITE
	_highlighted_buildings.clear()



func _show_cannot_build_warning() -> void:
	if not _warning_label or not is_instance_valid(_warning_label):
		_warning_label = Label.new()
		_warning_label.z_index = 100
		_warning_label.add_theme_font_size_override("font_size", 14)
		_warning_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		_warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_warning_label.add_theme_constant_override("outline_size", 4)
		get_tree().current_scene.add_child(_warning_label)

	_warning_label.text = "Không thể xây ở đây"
	if _ghost:
		_warning_label.global_position = _ghost.global_position + Vector2(-60, -40)
	_warning_label.visible = true
	_warning_label.modulate = Color.WHITE

	var tw := get_tree().create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_warning_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): if is_instance_valid(_warning_label): _warning_label.visible = false)
