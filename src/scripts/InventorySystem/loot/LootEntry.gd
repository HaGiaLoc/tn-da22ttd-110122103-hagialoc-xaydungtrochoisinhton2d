@tool
class_name LootEntry
extends Resource

@export_group("Item")
@export var item_id: String = ""
@export_range(1, 999, 1) var quantity_min: int = 1
@export_range(1, 999, 1) var quantity_max: int = 1

@export_group("Drop Chance")
@export_range(0.0, 100.0, 0.1, "suffix:%") var drop_chance: float = 100.0


func is_valid() -> bool:
	return not item_id.is_empty() and drop_chance > 0.0


func get_random_quantity(rng: RandomNumberGenerator = null) -> int:
	if quantity_min >= quantity_max:
		return quantity_min
	if rng:
		return rng.randi_range(quantity_min, quantity_max)
	return randi_range(quantity_min, quantity_max)
