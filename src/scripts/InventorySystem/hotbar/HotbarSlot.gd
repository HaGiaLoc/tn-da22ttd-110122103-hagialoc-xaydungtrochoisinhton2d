class_name HotbarSlot
extends InventorySlotUI

@export var key_label: Label  ## Label hiển thị phím tắt (vd: "1", "2", ...)

func set_key_hint(text: String) -> void:
	if key_label:
		key_label.text = text
