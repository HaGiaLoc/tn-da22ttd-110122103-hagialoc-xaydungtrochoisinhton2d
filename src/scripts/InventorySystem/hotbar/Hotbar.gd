class_name Hotbar
extends Control

const HOTBAR_SLOT_SCENE := preload("res://scenes/InventorySystem/hotbar_slot.tscn")
const SLOT_COUNT := 6

const SLOT_ACTIONS: Array[String] = [
	"hotbar_slot_1", "hotbar_slot_2", "hotbar_slot_3",
	"hotbar_slot_4", "hotbar_slot_5", "hotbar_slot_6",
]
const KEY_HINTS: Array[String] = ["1", "2", "3", "4", "5", "6"]

var _model: InventoryModel = null
var _vis_slots: Array = []  # Array of HotbarSlot

@onready var _hbox: HBoxContainer = $HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visual_slots()
	await get_tree().process_frame
	_connect_model()


func _build_visual_slots() -> void:
	for i in SLOT_COUNT:
		var slot = HOTBAR_SLOT_SCENE.instantiate()
		slot.name = "HotbarSlot_%d" % i
		slot.process_mode = Node.PROCESS_MODE_ALWAYS
		slot.set_key_hint(KEY_HINTS[i])
		slot.mouse_entered.connect(_on_slot_hovered.bind(slot, true))
		slot.mouse_exited.connect(_on_slot_hovered.bind(slot, false))
		_hbox.add_child(slot)
		_vis_slots.append(slot)

func _on_slot_hovered(slot: HotbarSlot, hovered: bool) -> void:
	var inv_sys = get_node_or_null("/root/InventorySystem")
	if not inv_sys:
		return
	var inv_item = slot.get_inventory_item()
	if inv_item:
		inv_sys.on_item_hover(inv_item, hovered)

func _connect_model() -> void:
	_model = _find_child_model(self)
	if not _model:
		push_warning("[Hotbar] Không tìm thấy InventoryModel con.")
		return

	if _model.inventory_view:
		_finish_connect()
	else:
		await get_tree().process_frame
		_finish_connect()


func _finish_connect() -> void:
	if not _model:
		return

	for slot in _vis_slots:
		if slot.slot_clicked.is_connected(_model._on_slot_clicked):
			continue
		slot.slot_clicked.connect(_model._on_slot_clicked)

	_model.item_added.connect(_sync_slot_from_model)
	_model.item_removed.connect(_sync_slot_removed)

	if not _model.item_used.is_connected(_on_item_used):
		_model.item_used.connect(_on_item_used)

	for i in SLOT_COUNT:
		_sync_slot_from_model_at(i)


func _find_child_model(node: Node) -> InventoryModel:
	for child in node.get_children():
		if child is InventoryModel:
			return child
		var found := _find_child_model(child)
		if found:
			return found
	return null



func _sync_slot_from_model(_item: Item, slot_index: int) -> void:
	_sync_slot_from_model_at(slot_index)


func _sync_slot_removed(slot_index: int) -> void:
	if slot_index < _vis_slots.size():
		_vis_slots[slot_index].remove_item()


func _sync_slot_from_model_at(slot_index: int) -> void:
	if slot_index >= _vis_slots.size() or not _model:
		return
	var vis_slot = _vis_slots[slot_index]

	if vis_slot.get_inventory_item():
		vis_slot.remove_item()

	var item: Item = _model.get_item_at(slot_index)
	if not item:
		return

	if _model.inventory_view:
		var hidden_slot = _model.inventory_view.get_child(slot_index)
		if hidden_slot and hidden_slot is InventorySlotUI:
			var inv_item_from_hidden = hidden_slot.get_inventory_item()
			if inv_item_from_hidden:
				var vis_inv_a := InventoryItem.new()
				vis_inv_a.set_item(item)
				vis_slot.set_item(vis_inv_a)
				return

	var vis_inv_b := InventoryItem.new()
	vis_inv_b.set_item(item)
	vis_slot.set_item(vis_inv_b)



func _unhandled_input(event: InputEvent) -> void:
	for i in SLOT_COUNT:
		if event.is_action(SLOT_ACTIONS[i]) and not event.is_echo():
			_activate_slot(i)
			get_viewport().set_input_as_handled()
			return


func _activate_slot(index: int) -> void:
	print("[Hotbar] _activate_slot: index=%d" % index)
	if not _model:
		print("[Hotbar] _activate_slot: FAIL — _model is null")
		return
	if index >= _vis_slots.size():
		print("[Hotbar] _activate_slot: FAIL — index out of range (%d >= %d)" % [index, _vis_slots.size()])
		return

	var inv_item = _vis_slots[index].get_inventory_item()
	if not inv_item:
		print("[Hotbar] _activate_slot: FAIL — slot %d is empty (no InventoryItem)" % index)
		return

	var item: Item = inv_item.get_item()
	if not item:
		print("[Hotbar] _activate_slot: FAIL — inv_item.get_item() returned null")
		return
	if not item.base:
		print("[Hotbar] _activate_slot: FAIL — item.base is null")
		return

	print("[Hotbar] _activate_slot: item='%s' type=%d" % [item.base.name, item.base.item_type])

	if item.base.item_type != ItemBase.ItemType.CONSUMABLE:
		print("[Hotbar] _activate_slot: SKIP — item_type is %d, not CONSUMABLE (%d)" % [item.base.item_type, ItemBase.ItemType.CONSUMABLE])
		return

	print("[Hotbar] _activate_slot: emitting item_used for '%s'" % item.base.name)
	_use_item(inv_item)



func _use_item(inv_item: InventoryItem) -> void:
	print("[Hotbar] _use_item: item='%s'" % (inv_item.item.base.name if inv_item and inv_item.item and inv_item.item.base else "null"))

	if not inv_item or not inv_item.item:
		print("[Hotbar] _use_item: FAIL — inv_item hoặc inv_item.item là null")
		return

	var item: Item = inv_item.item

	if not item.base:
		print("[Hotbar] _use_item: FAIL — item.base là null")
		return

	if not item.base.get_on_use():
		print("[Hotbar] _use_item: FAIL — item '%s' không có on_use được gán" % item.base.name)
		return

	var player := get_tree().get_first_node_in_group("Player")
	if not player:
		print("[Hotbar] _use_item: FAIL — không tìm thấy node trong group 'Player'")
		return

	print("[Hotbar] _use_item: can_use=%s" % str(item.base.get_on_use().can_use(item, player)))
	if item.base.get_on_use().can_use(item, player):
		var result := item.base.get_on_use().on_use(item, player)
		print("[Hotbar] _use_item: on_use returned %s" % str(result))
	else:
		print("[Hotbar] _use_item: can_use trả về false — không sử dụng được (HP/Hunger đã đầy?)")


func _on_item_used(inv_item: InventoryItem) -> void:
	print("[Hotbar] _on_item_used (RMB): item='%s'" % (inv_item.item.base.name if inv_item and inv_item.item and inv_item.item.base else "null"))
	_use_item(inv_item)
