class_name CraftingComponent
extends Node

signal item_crafted


const RecipeScript = preload("res://scripts/InventorySystem/crafting/CraftingRecipe.gd")
const IngredientScript = preload("res://scripts/InventorySystem/crafting/CraftIngredient.gd")

@export var recipes: Array[Resource] = []

func can_craft(recipe_index: int) -> bool:
	var recipe = get_recipe(recipe_index)
	if not recipe or not recipe.is_valid():
		return false

	var inventory_system := Engine.get_singleton("InventorySystem") if Engine.has_singleton("InventorySystem") \
		else (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		push_warning("[CraftingComponent] can_craft: không tìm thấy InventorySystem")
		return false

	var player_inv = inventory_system.get_player_inventory()
	if not player_inv:
		push_warning("[CraftingComponent] can_craft: get_player_inventory() trả về null (inventory chưa được register?)")
		return false

	for res in recipe.ingredients:
		if not res or not (res is IngredientScript):
			continue
		var ingredient := res as IngredientScript
		var have: int = player_inv.get_item_count(ingredient.item_id)
		if have < ingredient.quantity:
			print("[CraftingComponent] can_craft FAIL: cần '%s' x%d, có %d" % [ingredient.item_id, ingredient.quantity, have])
			return false

	return true


func craft(recipe_index: int) -> bool:
	if not can_craft(recipe_index):
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

	var success = player_inv.create_item_by_id(recipe.result_item_id, recipe.result_quantity)
	if not success:
		push_warning("CraftingComponent: craft thành công nhưng không thể thêm '%s' vào inventory (đầy?)." % recipe.result_item_id)
	else:
		item_crafted.emit()
		TutorialManager.notify_crafted(recipe.result_item_id, recipe.result_quantity)

	return true


func get_recipe(index: int) -> RecipeScript:
	if index < 0 or index >= recipes.size():
		return null
	var res = recipes[index]
	if not res or not (res is RecipeScript):
		return null
	return res as RecipeScript


func get_all_recipes() -> Array:
	var result := []
	for res in recipes:
		if res and res is RecipeScript and (res as RecipeScript).is_valid():
			result.append(res)
	return result


func get_ingredients_info(recipe_index: int) -> Array[Dictionary]:
	var recipe = get_recipe(recipe_index)
	var result: Array[Dictionary] = []
	if not recipe:
		return result

	for res in recipe.ingredients:
		if not res or not (res is IngredientScript):
			continue
		var ing := res as IngredientScript
		result.append({"item_id": ing.item_id, "quantity": ing.quantity})

	return result
