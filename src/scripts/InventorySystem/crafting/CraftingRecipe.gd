@tool
class_name CraftingRecipe
extends Resource

const CraftIngredientScript = preload("res://scripts/InventorySystem/crafting/CraftIngredient.gd")

@export_group("Item")
@export var result_item_id: String = ""
@export_range(1, 999, 1) var result_quantity: int = 1

@export_group("Material")
@export var ingredients: Array[Resource] = []

func is_valid() -> bool:
	return not result_item_id.is_empty() and not ingredients.is_empty()
