class_name BuildingComponent
extends Node

const RecipeScript = preload("res://scripts/InventorySystem/building/BuildingRecipe.gd")
const IngredientScript = preload("res://scripts/InventorySystem/building/BuildIngredient.gd")

@export var recipes: Array[Resource] = []

func can_build(recipe_index: int) -> bool:
	var recipe = get_recipe(recipe_index)
	if not recipe or not recipe.is_valid():
		return false

	var inventory_system := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		push_warning("[BuildingComponent] can_build: không tìm thấy InventorySystem")
		return false

	var player_inv = inventory_system.get_player_inventory()
	if not player_inv:
		push_warning("[BuildingComponent] can_build: get_player_inventory() trả về null")
		return false

	for res in recipe.ingredients:
		if not res or not (res is IngredientScript):
			continue
		var ingredient := res as IngredientScript
		var have: int = player_inv.get_item_count(ingredient.item_id)
		if have < ingredient.quantity:
			return false

	return true


func build(recipe_index: int) -> bool:
	if not can_build(recipe_index):
		return false

	var recipe = get_recipe(recipe_index)

	var inventory_system := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		return false

	var player_inv = inventory_system.get_player_inventory()
	if not player_inv:
		return false

	for res in recipe.ingredients:
		if not res or not (res is IngredientScript):
			continue
		var ingredient := res as IngredientScript
		player_inv.remove_item_by_id(ingredient.item_id, ingredient.quantity)

	_spawn_building(recipe.building_scene)
	return true


func _spawn_building(scene_path: String) -> void:
	if scene_path.is_empty():
		push_warning("[BuildingComponent] _spawn_building: building_scene rỗng.")
		return

	var packed: PackedScene = load(scene_path)
	if not packed:
		push_warning("[BuildingComponent] _spawn_building: không load được scene '%s'." % scene_path)
		return

	var player := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("Player")
	var spawn_pos := Vector2.ZERO
	if player:
		spawn_pos = player.global_position + Vector2(64, 0)  ## Đặt ngay bên phải player

	var building := packed.instantiate()
	var world := (Engine.get_main_loop() as SceneTree).current_scene
	var save_system := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/SaveSystem")
	if save_system and save_system.has_method("prepare_player_placed_building"):
		save_system.prepare_player_placed_building(building)
	else:
		building.set_meta("player_placed", true)
	world.add_child(building)
	if building is Node2D:
		building.global_position = spawn_pos


func get_recipe(index: int) -> RecipeScript:
	if index < 0 or index >= recipes.size():
		return null
	var res = recipes[index]
	if not res or not (res is RecipeScript):
		return null
	return res as RecipeScript
