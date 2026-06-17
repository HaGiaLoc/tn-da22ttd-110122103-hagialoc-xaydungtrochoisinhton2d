class_name EquipmentModel
extends BaseInventoryModel

signal item_equipped(item: Item)
signal item_unequipped(item: Item)

@export var slots: Dictionary[ItemBase.SlotType, EquipmentSlot] = {}

var items: Dictionary[ItemBase.SlotType, Item] = {} ## Maps slot type to equipped InventoryItem
@onready var inventory_system := get_node_or_null("/root/InventorySystem")
@onready var _equip_player: AudioStreamPlayer = $EquipPlayer

var _suppress_equip_sfx: bool = false

func _ready():
	var missing_types: Array = []
	var search_root: Node = get_owner() if get_owner() else self
	for slot_type in slots.keys():
		var slot = slots[slot_type]

		if slot is NodePath:
			if str(slot) != "":
				var resolved = get_node_or_null(slot)
				if resolved:
					slots[slot_type] = resolved
					slot = resolved
				else:
					var found = _find_slot_by_type(search_root, slot_type)
					if found:
						slots[slot_type] = found
						slot = found
					else:
						missing_types.append(slot_type)
						continue
			else:
				var found = _find_slot_by_type(search_root, slot_type)
				if found:
					slots[slot_type] = found
					slot = found
				else:
					missing_types.append(slot_type)
					continue
		elif slot == null:
			var found = _find_slot_by_type(search_root, slot_type)
			if found:
				slots[slot_type] = found
				slot = found
			else:
				missing_types.append(slot_type)
				continue

		if not slot:
			missing_types.append(slot_type)
			continue

		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)
		else:
			push_warning("EquipmentModel: resolved slot for type %s has no 'slot_clicked' signal." % str(slot_type))

	if missing_types.size() > 0:
		push_warning("EquipmentModel: %d slots unassigned; assign them in the inspector or add child EquipmentSlot nodes. Missing types: %s" % [missing_types.size(), str(missing_types)])

	_load()

func _find_slot_by_type(search_in: Node, slot_type: ItemBase.SlotType) -> EquipmentSlot:
	for child in search_in.get_children():
		if child is EquipmentSlot:
			if child.slot_type == slot_type:
				return child
		elif child is Node:
			var found = _find_slot_by_type(child, slot_type)
			if found:
				return found
	return null

func _exit_tree():
	_save()

func _on_slot_clicked(slot: EquipmentSlot, button: MouseButton) -> void:
	var equipment_item: InventoryItem = slot.get_equipment_item()
	var slot_type = slot.slot_type

	if button == MOUSE_BUTTON_LEFT:
		if equipment_item:
			if inventory_system.is_holding_item(): ## Swap
				var held_item = inventory_system.get_held_item()
				if held_item.base.slot_type != slot_type:
					return
				
				if stack_items(held_item, equipment_item.item):
					if held_item.quantity == 0:
						inventory_system.drop_held_item()
					return
				
				inventory_system.drop_held_item()
				remove_item_at(slot_type)

				add_item_at(held_item, slot_type)
				inventory_system.pick_up_item(equipment_item.item)
			else: ## Pick up
				inventory_system.pick_up_item(equipment_item.item)
				remove_item_at(slot_type)
		elif inventory_system.is_holding_item(): ## Place
			var held_item = inventory_system.get_held_item()
			if add_item_at(held_item, slot_type):
				inventory_system.drop_held_item()
	elif button == MOUSE_BUTTON_RIGHT and equipment_item:
		remove_item_at(slot_type)
		inventory_system.get_player_inventory().add_item(equipment_item.item)

func equip_item(item: Item) -> int:
	if not item:
		return false
	
	if not slots.has(item.base.slot_type):
		return false
		
	if item.base.on_equip:
		var ret = item.base.on_equip.on_equip(item, self )
		if not ret:
			return false
	
	var slot = slots[item.base.slot_type]
	var equipment_item: InventoryItem = slot.get_equipment_item()
	if equipment_item: ## Swap
		remove_item_at(item.base.slot_type)
		add_item_at(item, item.base.slot_type)
		var parent_inventory = inventory_system.get_inventory(item.parent_inventory)
		parent_inventory.remove_item(item)
		parent_inventory.add_item(equipment_item.item)
	else: ## Place
		var parent_inventory = inventory_system.get_inventory(item.parent_inventory)
		parent_inventory.remove_item(item)
		add_item_at(item, item.base.slot_type)

	return true

func get_total_armor() -> int:
	var total := 0
	for item in items.values():
		if item and item.base:
			total += item.base.armor
	return total


func create_item_at(slot_type: ItemBase.SlotType, item_base: ItemBase, quantity: int = 1) -> bool:
	if not slots.has(slot_type):
		push_warning("EquipmentModel has no slot for type %s." % str(slot_type))
		return false
	
	if item_base.slot_type != slot_type:
		return false

	var equipment_item = InventoryItem.new()
	equipment_item.create_item(item_base, quantity)
	_add_item(equipment_item, slot_type)

	return true

func add_item_at(item: Item, slot_type: ItemBase.SlotType) -> bool:
	if items.has(slot_type):
		return false
	
	if item.base.slot_type != slot_type:
		return false

	var equipment_item = InventoryItem.new()
	equipment_item.set_item(item)
	_add_item(equipment_item, slot_type)

	return true

func remove_item_at(slot_type: ItemBase.SlotType) -> void:
	if items.has(slot_type):
		var item = items[slot_type]
		if item.base.on_unequip:
			item.base.on_unequip.on_unequip(item, self )
		item_unequipped.emit(items[slot_type])
		var slot: EquipmentSlot = slots[slot_type]
		slot.remove_item()
		items.erase(slot_type)
		if not _suppress_equip_sfx and _equip_player and _equip_player.stream:
			_equip_player.play()

func _add_item(equipment_item: InventoryItem, slot_type: ItemBase.SlotType):
	items[slot_type] = equipment_item.item
	slots[slot_type].set_item(equipment_item)
	item_equipped.emit(equipment_item.item)
	TutorialManager.notify_equipped(equipment_item.item.base.id)
	if not _suppress_equip_sfx and _equip_player and _equip_player.stream:
		_equip_player.play()

func _save() -> void:
	var save_path = "user://player_equipment.inv"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return

	var save_data: Dictionary = {}
	for slot_type in items.keys():
		var item: Item = items[slot_type]
		save_data[slot_type] = item.serialize()

	file.store_var(save_data)
	file.close()

func _load() -> void:
	var save_path = "user://player_equipment.inv"
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return

	_suppress_equip_sfx = true
	var save_data: Dictionary = file.get_var()
	for slot_type in save_data.keys():
		var item_data: Dictionary = save_data[slot_type]
		var item_base: ItemBase = inventory_system.get_item_base(item_data["base_id"])
		if item_base:
			var item = Item.new(item_base, item_data["quantity"])
			item.deserialize(item_data)
			add_item_at(item, int(slot_type))
		else:
			push_warning("Base item with ID %s not found while loading equipment." % item_data["base_id"])

	file.close()
	_suppress_equip_sfx = false
