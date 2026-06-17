class_name MaxStacksSection
extends TooltipSection

func applies_to(item: Item) -> bool:
	return item.base.stackable

func append(item: Item, tooltip: ItemTooltip) -> void:
	tooltip.add_line("[color=#AAAAAA]Số lượng tối đa: %d[/color]" % item.base.max_stacks)
