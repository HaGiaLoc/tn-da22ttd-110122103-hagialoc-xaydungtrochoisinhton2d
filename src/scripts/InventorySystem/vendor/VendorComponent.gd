class_name VendorComponent
extends Node

const VendorItemScript = preload("res://scripts/InventorySystem/vendor/VendorItem.gd")

@export var items_for_sale: Array[Resource] ## Mảng VendorItem resources

var _cached_items: Array[Item] = []

func buy_item(slot_index: int, item: Item) -> bool:
	if slot_index < 0 or slot_index >= _cached_items.size() or not item:
		return false

	var cached_item = _cached_items[slot_index]
	if not cached_item:
		return false

	if item.id != cached_item.id:
		return false

	if item.quantity > cached_item.quantity:
		return false

	cached_item.remove(item.quantity)

	if cached_item.quantity <= 0:
		_cached_items[slot_index] = null

	return true

func get_price(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= _cached_items.size():
		return -1

	var cached_item = _cached_items[slot_index]
	if not cached_item:
		return -1

	return cached_item.get_worth()

func get_item(slot_index: int) -> Item:
	if slot_index < 0 or slot_index >= _cached_items.size():
		return null

	return _cached_items[slot_index]

func get_items() -> Array[Item]:
	if _cached_items.is_empty():
		for res in items_for_sale:
			if not res or not (res is VendorItemScript):
				_cached_items.append(null)
				continue

			var vendor_item = res as VendorItemScript
			if not vendor_item.item_base:
				_cached_items.append(null)
				continue

			var item = Item.new(vendor_item.item_base, vendor_item.quantity)
			if vendor_item.roll_affixes:
				item.roll_affixes()
			item.vendor_item = true
			item.set_price(vendor_item.gold_price)
			if vendor_item.custom_item:
				item.currency_item = vendor_item.custom_item
			_cached_items.append(item)

	return _cached_items
