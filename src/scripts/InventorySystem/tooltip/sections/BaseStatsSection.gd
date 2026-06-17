class_name BaseStatsSection
extends TooltipSection

func applies_to(item: Item) -> bool:
	return item.base.slot_type != ItemBase.SlotType.NONE

func append(item: Item, tooltip: ItemTooltip) -> void:
	var armor = item.base.armor
	var block_chance = item.base.block_chance
	var damage = item.base.damage
	var attack_speed = item.base.attack_speed

	if armor > 0:
		tooltip.add_line("%s %s" % [_prefix("Giáp"), _suffix("%d" % armor)])

	if block_chance > 0:
		tooltip.add_line("%s %s" % [_prefix("Tỉ lệ chặn"), _suffix("%d%%" % block_chance)])

	if damage > 0:
		tooltip.add_line("%s %s" % [_prefix("Sát thương"), _suffix("%d" % damage)])

	if attack_speed > 0:
		tooltip.add_line("%s %s" % [_prefix("Tốc độ tấn công"), _suffix("%.2f" % attack_speed)])

func _prefix(s: String) -> String:
	return "[color=#999999]%s:[/color]" % s

func _suffix(s: String) -> String:
	return "[color=#FFFFFF]%s[/color]" % s
