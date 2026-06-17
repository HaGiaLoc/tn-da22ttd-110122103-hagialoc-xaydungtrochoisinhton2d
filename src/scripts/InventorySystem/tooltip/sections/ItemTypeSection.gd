class_name ItemTypeSection
extends TooltipSection

func applies_to(_item: Item) -> bool:
	return true

func append(item: Item, tooltip: ItemTooltip) -> void:
	var type_name: String
	match item.base.item_type:
		ItemBase.ItemType.RESOURCE:
			type_name = "Nguyên liệu"
		ItemBase.ItemType.CONSUMABLE:
			type_name = "Tiêu thụ"
		ItemBase.ItemType.EQUIPMENT:
			type_name = "Trang bị"
		_:
			type_name = "Không xác định"
	tooltip.add_line("[color=#AAAAAA]Loại: %s[/color]" % type_name)
