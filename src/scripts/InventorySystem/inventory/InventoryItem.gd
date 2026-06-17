class_name InventoryItem
extends TextureRect

var item: Item = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func create_item(item_base: ItemBase, quantity: int = 1) -> void:
	item = Item.new(item_base, max(1, quantity))
	_update_icon()

func set_item(new_item: Item) -> void:
	item = new_item
	_update_icon()

func get_item() -> Item:
	return item

func _update_icon() -> void:
	if item and item.base:
		texture = item.base.icon
	else:
		texture = null