class_name InventoryView
extends Container

const INVENTORY_SLOT_SCENE: PackedScene = preload("res://scenes/InventorySystem/inventory_slot.tscn")

var inventory_model: InventoryModel

func init(model: InventoryModel) -> void:
	inventory_model = model
	_populate_slots()

func _populate_slots() -> void:
	for child in get_children():
		child.queue_free()

	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in inventory_model.config.slots:
		var slot_instance: InventorySlotUI = INVENTORY_SLOT_SCENE.instantiate()
		slot_instance.name = "Slot_%d" % i
		slot_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		slot_instance.slot_clicked.connect(inventory_model._on_slot_clicked)
		add_child(slot_instance)

func set_item(slot_index: int, item: InventoryItem) -> void:
	get_child(slot_index).set_item(item)

func get_slot_at_position(point: Vector2) -> InventorySlotUI:
	for child in get_children():
		if child is InventorySlotUI and child.get_global_rect().has_point(point):
			return child
	
	return null
