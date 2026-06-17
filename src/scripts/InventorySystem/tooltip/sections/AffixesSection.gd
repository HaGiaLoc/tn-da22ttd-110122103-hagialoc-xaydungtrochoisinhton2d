class_name AffixesSection
extends TooltipSection

const VALUE_CHAR = '#'
const AffixPoolScript = preload("res://scripts/InventorySystem/itemization/AffixPool.gd")

var label_path = "res://scripts/InventorySystem/tooltip/sections/labels/AffixesSectionLabel.tscn"
var regex: RegEx
var _affix_pool = AffixPoolScript.new()

func applies_to(item: Item) -> bool:
	return item.affixes.size() > 0

func append(item: Item, tooltip: ItemTooltip) -> void:
	tooltip.add_spacer()
	for affix_instance in item.affixes:
		var affix = _affix_pool.get_affix(affix_instance.id)
		if affix == null or affix.hidden:
			continue
		
		var description = affix.description

		if not regex:
			regex = RegEx.new()
			regex.compile(VALUE_CHAR)

		var matches = regex.search_all(description)
		if matches.size() != affix_instance.values.size():
			push_error("Number of values does not match number of placeholders in attribute name")
			continue
		
		for value in affix_instance.values:
			description = regex.sub(description, "%s" % str(value))
		
		tooltip.add_line(description, label_path)
