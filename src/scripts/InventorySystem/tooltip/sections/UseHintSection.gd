class_name UseHintSection
extends TooltipSection

func applies_to(item: Item) -> bool:
	return item.base.item_type == ItemBase.ItemType.CONSUMABLE

func append(_item: Item, tooltip: ItemTooltip) -> void:
	tooltip.add_spacer()
	tooltip.add_line("[color=#88FF88][E] Sử dụng[/color]")
