extends Control

@export var container: Control
@export var margin_container: MarginContainer
@export var max_width: int = 300
@export var default_label: PackedScene = preload("res://scripts/InventorySystem/tooltip/sections/labels/DefaultTooltipLabel.tscn")

const ItemTypeSectionScript = preload("res://scripts/InventorySystem/tooltip/sections/ItemTypeSection.gd")
const MaxStacksSectionScript = preload("res://scripts/InventorySystem/tooltip/sections/MaxStacksSection.gd")
const UseHintSectionScript = preload("res://scripts/InventorySystem/tooltip/sections/UseHintSection.gd")

var _show_advanced: bool = false

var sections: Array[TooltipSection] = [
	NameSection.new(),
	ItemTypeSectionScript.new(),
	MaxStacksSectionScript.new(),
	DescriptionSection.new(),
	UseHintSectionScript.new(),
]

func _ready():
	visible = false

func _unhandled_key_input(event):
	if event is InputEventKey:
		if event.keycode == Key.KEY_ALT:
			if _show_advanced != event.pressed:
				_show_advanced = event.pressed

var _pending_rect: Rect2 = Rect2()

func inspect(inventory_item: InventoryItem) -> void:
	print("[ItemTooltip] inspect called, item=%s" % str(inventory_item))
	for child in container.get_children():
		child.free()

	var item = inventory_item.item
	for section in sections:
		if section.applies_to(item):
			section.append(item, self)

	_pending_rect = inventory_item.get_global_rect()
	visible = true
	call_deferred("_deferred_display")

func _deferred_display() -> void:
	if not visible:
		return
	var panel := get_node_or_null("PanelContainer") as Control
	if panel:
		panel.reset_size()
	display(_pending_rect)

func display(rect: Rect2) -> void:
	var panel := get_node_or_null("PanelContainer") as Control
	var tooltip_size := panel.get_combined_minimum_size() if panel else Vector2(200, 100)

	if panel:
		panel.position = Vector2.ZERO

	var new_pos := rect.position + Vector2(rect.size.x + 8, 0)
	var screen_size := get_viewport_rect().size

	if new_pos.x + tooltip_size.x > screen_size.x:
		new_pos.x = rect.position.x - tooltip_size.x - 8
	if new_pos.y + tooltip_size.y > screen_size.y:
		new_pos.y = screen_size.y - tooltip_size.y

	global_position = new_pos


func add_line(text: String, label_path: String = "") -> void:
	var label_instance = null
	
	if not label_path.is_empty():
		var label_scene = load(label_path)
		label_instance = label_scene.instantiate()
	else:
		label_instance = default_label.instantiate()
	
	label_instance.text = text
	label_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label_instance)

func add_spacer() -> void:
	var spacer = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0, 4)
	container.add_child(spacer)
