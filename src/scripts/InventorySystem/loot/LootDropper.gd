class_name LootDropper
extends RefCounted


static func drop(
	loot_table: Resource,
	parent: Node,
	drop_position: Vector2,
	rng: RandomNumberGenerator = null
) -> void:
	if not loot_table or not parent:
		return

	if not loot_table.has_method("roll"):
		push_warning("LootDropper: loot_table không có method roll().")
		return

	var inventory_system: Node = Engine.get_main_loop().root.get_node_or_null("/root/InventorySystem") \
		if Engine.get_main_loop() else null
	if not inventory_system:
		push_warning("LootDropper: InventorySystem không tồn tại, không thể drop loot.")
		return

	var rolled: Array = loot_table.roll(rng)
	if rolled.is_empty():
		return

	var count: int = rolled.size()
	for i in count:
		var entry: Dictionary = rolled[i]
		var item_id: String = entry.get("item_id", "")
		var quantity: int = entry.get("quantity", 1)

		if item_id.is_empty():
			continue

		var base: ItemBase = inventory_system.get_item_base(item_id)
		if not base:
			push_warning("LootDropper: Không tìm thấy ItemBase id='%s'" % item_id)
			continue

		var item := Item.new(base, quantity)

		var offset := Vector2.ZERO
		if count > 1:
			var angle: float = (TAU / count) * i
			offset = Vector2(cos(angle), sin(angle)) * 16.0

		WorldItem.spawn(item, parent, drop_position + offset)
