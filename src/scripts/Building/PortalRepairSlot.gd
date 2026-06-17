class_name PortalRepairSlot
extends Panel

signal item_inserted(slot: PortalRepairSlot)

@export var required_item_id: String = ""
@export var glyph_index: int = 0

var _filled: bool = false
var _quantity_label: Label
var _placeholder: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)

	_placeholder = TextureRect.new()
	_placeholder.anchors_preset = Control.PRESET_FULL_RECT
	_placeholder.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_placeholder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_placeholder.modulate = Color(1, 1, 1, 0.3)
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placeholder)

	_quantity_label = Label.new()
	_quantity_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_quantity_label.add_theme_font_size_override("font_size", 11)
	_quantity_label.add_theme_constant_override("outline_size", 6)
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quantity_label.text = ""
	add_child(_quantity_label)


func setup(req_item_id: String, idx: int, placeholder_tex: Texture2D = null) -> void:
	required_item_id = req_item_id
	glyph_index = idx
	if placeholder_tex and _placeholder:
		_placeholder.texture = placeholder_tex


func is_filled() -> bool:
	return _filled


func mark_filled_externally() -> void:
	if _filled:
		return
	_filled = true
	if _placeholder:
		_placeholder.modulate = Color(1, 1, 1, 1.0)


func try_insert(item: Item) -> bool:
	if _filled:
		return false
	if item.base.id != required_item_id:
		return false

	_filled = true
	_placeholder.modulate = Color(1, 1, 1, 1.0)
	emit_signal("item_inserted", self)
	return true


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if _filled:
		return
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var inventory_system := get_node_or_null("/root/InventorySystem")
	if not inventory_system or not inventory_system.is_holding_item():
		return

	var held: Item = inventory_system.get_held_item()
	if try_insert(held):
		inventory_system.drop_held_item()
		get_viewport().set_input_as_handled()
