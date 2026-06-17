class_name InventorySlotUI
extends Control

signal slot_clicked(slot: InventorySlotUI, button: MouseButton, ctrl_pressed: bool, shift_pressed: bool)

@export var quantity_label: Label

func _ready():
	if not quantity_label:
		var resolved = get_node_or_null("MarginContainer/Label")
		if resolved and resolved is Label:
			quantity_label = resolved
		else:
			push_warning("InventorySlot: `quantity_label` not assigned and could not be auto-resolved.")

	if quantity_label:
		quantity_label.text = ""

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("[Slot] _gui_input fired: button=%d slot=%s" % [event.button_index, name])
		slot_clicked.emit(self, event.button_index, event.ctrl_pressed, event.shift_pressed)

func set_item(inventory_item: InventoryItem) -> void:
	add_child(inventory_item)
	move_child(inventory_item, 0)
	inventory_item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var item = inventory_item.get_item()
	if item and item.base.stackable:
		if item.quantity > 0:
			quantity_label.text = str(item.quantity)
		else:
			quantity_label.text = ""
		if not item.changed.is_connected(_on_item_changed):
			item.changed.connect(_on_item_changed)

func remove_item() -> void:
	var inventory_item = get_inventory_item()
	if inventory_item:
		var item = inventory_item.get_item()
		if item and item.base.stackable:
			if item.changed.is_connected(_on_item_changed):
				item.changed.disconnect(_on_item_changed)
		inventory_item.queue_free()
	quantity_label.text = ""

func get_inventory_item() -> InventoryItem:
	var inventory_item = get_child(0)
	if inventory_item is InventoryItem:
		return inventory_item
	return null

func get_item() -> Item:
	var inventory_item = get_inventory_item()
	if inventory_item:
		return inventory_item.get_item()
	return null

func _on_item_changed(item: Item):
	if item and item.base.stackable:
		if item.quantity > 0:
			quantity_label.text = str(item.quantity)
		else:
			quantity_label.text = ""
