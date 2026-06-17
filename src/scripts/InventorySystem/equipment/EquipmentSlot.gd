class_name EquipmentSlot
extends Control

signal slot_clicked(slot: EquipmentSlot, button: MouseButton)

@export var quantity_label: Label
@export var slot_type: ItemBase.SlotType = ItemBase.SlotType.NONE
@export var placeholder_icon: Texture2D  ## Icon mờ hiển thị khi slot rỗng

@onready var _placeholder: TextureRect = $PlaceholderIcon

var _current_equipment_item: InventoryItem = null  ## Giữ reference để tránh nhầm với child khác

func _ready():
	quantity_label.text = ""
	if _placeholder and placeholder_icon:
		_placeholder.texture = placeholder_icon
	_update_placeholder()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		slot_clicked.emit(self, event.button_index)

func set_item(equipment_item: InventoryItem) -> void:
	_current_equipment_item = equipment_item
	add_child(equipment_item)
	move_child(equipment_item, 0)
	equipment_item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var item = equipment_item.get_item()
	if item and item.base.stackable:
		quantity_label.text = str(item.quantity)
	_update_placeholder()
	var inventory_system := get_node_or_null("/root/InventorySystem")
	if inventory_system:
		if not mouse_entered.is_connected(_on_mouse_entered):
			mouse_entered.connect(_on_mouse_entered)
		if not mouse_exited.is_connected(_on_mouse_exited):
			mouse_exited.connect(_on_mouse_exited)

func remove_item() -> void:
	if _current_equipment_item and is_instance_valid(_current_equipment_item):
		if _current_equipment_item.get_parent() == self:
			remove_child(_current_equipment_item)
	_current_equipment_item = null
	quantity_label.text = ""
	_update_placeholder()
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)

func get_equipment_item() -> InventoryItem:
	return _current_equipment_item if is_instance_valid(_current_equipment_item) else null

func get_item() -> Item:
	var equipment_item = get_equipment_item()
	if equipment_item:
		return equipment_item.get_item()
	return null

func _update_placeholder() -> void:
	if not is_instance_valid(_placeholder):
		return
	_placeholder.visible = get_equipment_item() == null

func _on_mouse_entered() -> void:
	var inventory_system := get_node_or_null("/root/InventorySystem")
	if inventory_system and _current_equipment_item and not inventory_system.is_holding_item():
		inventory_system.on_item_hover(_current_equipment_item, true)

func _on_mouse_exited() -> void:
	var inventory_system := get_node_or_null("/root/InventorySystem")
	if inventory_system:
		inventory_system.on_item_hover(_current_equipment_item, false)
