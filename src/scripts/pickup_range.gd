extends Area2D

func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		if area is not WorldItem:
			continue
		_try_pickup(area)


func _try_pickup(world_item: WorldItem) -> void:
	var item := world_item.get_item()
	if not item:
		push_warning("[PickupRange] WorldItem không có item.")
		return

	var inventory_system := get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		push_warning("[PickupRange] InventorySystem không tìm thấy.")
		return

	var player_inv: InventoryModel = inventory_system.get_player_inventory()
	if not player_inv:
		push_warning("[PickupRange] Không tìm thấy player inventory.")
		return

	var hotbar_inv: InventoryModel = inventory_system.get_inventory("hotbar")
	var added := false

	if hotbar_inv and item.base.stackable:
		var has_partial_stack := false
		for i in hotbar_inv.items.keys():
			var h_item = hotbar_inv.items[i]
			if h_item.base.id == item.base.id and h_item.quantity < h_item.base.max_stacks:
				has_partial_stack = true
				break
		if has_partial_stack and hotbar_inv.can_add_item(item):
			added = hotbar_inv.add_item(item)

	if not added:
		if player_inv.can_add_item(item):
			added = player_inv.add_item(item)

	if not added:
		return  # Inventory đầy — không log spam mỗi frame
	world_item.emit_picked_up()
	var player_node := get_parent()
	if player_node and player_node.has_method("play_item_pickup_sound"):
		player_node.play_item_pickup_sound()
	var tutorial_mgr := get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.notify_item_collected(item.base.id, item.quantity)
	world_item.queue_free()
