class_name SlotSection
extends TooltipSection

var label_path = "res://scripts/InventorySystem/tooltip/sections/labels/SlotSectionLabel.tscn"

func applies_to(item: Item) -> bool:
	return item.base.slot_type != ItemBase.SlotType.NONE

func append(item: Item, tooltip: ItemTooltip) -> void:
	var text := ""
	match item.base.slot_type:
		ItemBase.SlotType.HEAD:
			text = "Slot: Đầu"
		ItemBase.SlotType.CHEST:
			text = "Slot: Thân"
		ItemBase.SlotType.GAUNTLET:
			text = "Slot: Găng tay"
		ItemBase.SlotType.FEET:
			text = "Slot: Giày"
		ItemBase.SlotType.WEAPON:
			text = "Slot: Vũ khí"
		ItemBase.SlotType.AXE:
			text = "Slot: Rìu"
		ItemBase.SlotType.PICKAXE:
			text = "Slot: Cuốc"
		ItemBase.SlotType.SHIELD:
			text = "Slot: Khiên"
		_:
			text = "Slot: Không xác định"

	tooltip.add_line(text, label_path)
