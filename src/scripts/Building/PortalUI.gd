class_name PortalUI
extends PanelContainer

signal closed  ## Phát khi UI bị đóng (close button hoặc ESC)

var _portal: Node = null
var _slot_configs: Array = []  ## [{item_id, quantity, label, rune_tex}, ...]

var _slot_filled:  Array[bool] = [false, false, false, false]
var _slot_current: Array[int]  = [0, 0, 0, 0]

var _drop_panels: Array[Control] = []
var _prog_labels: Array[Label]   = []

const SLOT_OFFSETS := [
	Vector2(0,   -100),  # Bắc  — trên
	Vector2(0,    100),  # Nam  — dưới
	Vector2(120,    0),  # Đông — phải
	Vector2(-120,   0),  # Tây  — trái
]
const SLOT_SIZE := Vector2(56, 56)

@onready var title_label:  Label   = $MarginContainer/VBoxContainer/Title
@onready var status_label: Label   = $MarginContainer/VBoxContainer/StatusLabel
@onready var portal_area:  Control = $MarginContainer/VBoxContainer/PortalArea
@onready var close_button: Button  = $MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_requested)
	_update_status_label()


func _on_close_requested() -> void:
	visible = false
	closed.emit()


func setup(portal: Node, configs: Array) -> void:
	_portal = portal
	_slot_configs = configs
	if is_node_ready():
		_build_portal_area()
	else:
		await ready
		_build_portal_area()



func _build_portal_area() -> void:
	for child in portal_area.get_children():
		child.queue_free()
	_drop_panels.clear()
	_prog_labels.clear()

	var portal_img := TextureRect.new()
	portal_img.name = "PortalImage"
	portal_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portal_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portal_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portal_img.texture = load("res://assets/Sprites/Portal/Portal.png")
	portal_img.modulate = Color(1, 1, 1, 0.35)
	portal_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_area.add_child(portal_img)

	portal_area.mouse_filter = Control.MOUSE_FILTER_STOP

	await get_tree().process_frame
	if not is_instance_valid(portal_area) or portal_area.size == Vector2.ZERO:
		await get_tree().process_frame

	for i in range(_slot_configs.size()):
		_build_slot(i, _slot_configs[i])

	_update_status_label()


func _build_slot(idx: int, cfg: Dictionary) -> void:
	var area_size: Vector2 = portal_area.size
	var center: Vector2   = area_size / 2.0
	var slot_pos: Vector2 = center + SLOT_OFFSETS[idx] - SLOT_SIZE / 2.0

	var slot := Panel.new()
	slot.name = "Slot%d" % idx
	slot.custom_minimum_size = SLOT_SIZE
	slot.position = slot_pos
	slot.size = SLOT_SIZE

	var placeholder := TextureRect.new()
	placeholder.name = "Placeholder"
	placeholder.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	placeholder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	placeholder.modulate = Color(1, 1, 1, 0.35)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inv_sys := get_node_or_null("/root/InventorySystem")
	if inv_sys:
		var base = inv_sys.get_item_base(cfg["item_id"])
		if base and base.icon:
			placeholder.texture = base.icon
	slot.add_child(placeholder)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var prog := Label.new()
	prog.name = "Progress"
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog.text = "0/%d" % cfg["quantity"]
	prog.add_theme_font_size_override("font_size", 10)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(prog)
	prog.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_prog_labels.append(prog)

	slot.gui_input.connect(_on_slot_gui_input.bind(idx))

	portal_area.add_child(slot)
	_drop_panels.append(slot)



func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _slot_filled[slot_index]:
		return

	var inv_sys := get_node_or_null("/root/InventorySystem")
	if not inv_sys or not inv_sys.is_holding_item():
		return

	var held: Item = inv_sys.get_held_item()
	if not held or not held.base:
		return

	var cfg: Dictionary = _slot_configs[slot_index]
	if held.base.id != cfg["item_id"]:
		return

	var needed: int = (cfg["quantity"] as int) - _slot_current[slot_index]
	var to_add: int = min(held.quantity, needed)

	_slot_current[slot_index] += to_add

	if to_add >= held.quantity:
		inv_sys.drop_held_item()
	else:
		held.quantity -= to_add
		var qty_label = inv_sys.get("held_item_quantity")
		if qty_label:
			qty_label.text = str(held.quantity)

	_prog_labels[slot_index].text = "%d/%d" % [_slot_current[slot_index], cfg["quantity"]]

	if _slot_current[slot_index] >= (cfg["quantity"] as int):
		_on_slot_complete(slot_index)

	get_viewport().set_input_as_handled()


func _on_slot_complete(slot_index: int) -> void:
	_slot_filled[slot_index] = true

	if slot_index < _drop_panels.size():
		var ph := _drop_panels[slot_index].get_node_or_null("Placeholder") as TextureRect
		if ph:
			ph.modulate = Color(1, 1, 1, 1.0)
		var pg := _drop_panels[slot_index].get_node_or_null("Progress")
		if pg:
			pg.visible = false
		_drop_panels[slot_index].mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _portal and _portal.has_method("on_slot_filled"):
		_portal.on_slot_filled(slot_index)

	_update_status_label()

	if _slot_filled.all(func(v): return v):
		if _portal and _portal.has_method("on_all_slots_filled"):
			_portal.on_all_slots_filled()



func _update_status_label() -> void:
	if not status_label:
		return
	var filled_count := _slot_filled.count(true)
	if filled_count >= 4:
		status_label.text = "✦ PORTAL SẴN SÀNG ✦"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.85, 1.0))
	else:
		status_label.text = "%d / 4 cổ ngữ đã kích hoạt" % filled_count
		status_label.remove_theme_color_override("font_color")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_requested()
		get_viewport().set_input_as_handled()
