@tool
class_name LootTable
extends Resource

const LootEntryScript = preload("res://scripts/InventorySystem/loot/LootEntry.gd")

@export var entries: Array[Resource] = []


func roll(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for res in entries:
		if not res or not (res is LootEntryScript):
			continue
		var entry := res as LootEntryScript
		if not entry or not entry.is_valid():
			continue

		var roll_value: float
		if rng:
			roll_value = rng.randf_range(0.0, 100.0)
		else:
			roll_value = randf_range(0.0, 100.0)

		if roll_value <= entry.drop_chance:
			var qty: int = entry.get_random_quantity(rng)
			results.append({ "item_id": entry.item_id, "quantity": qty })

	return results
