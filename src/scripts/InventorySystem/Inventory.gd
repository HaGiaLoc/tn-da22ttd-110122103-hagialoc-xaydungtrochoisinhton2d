extends Control

@export var item_id_field: LineEdit
@export var create_item_btn: Button
@export var clear_btn: Button

@export var stash_button: Button
@export var stash_panel: Control

@export var npc1_button: Button
@export var vendor1: VendorComponent
@export var vendor_inventory: VendorInventory

@export var npc2_button: Button
@export var crafting_component: CraftingComponent
@export var crafting_inventory: Control

@export var building_button: Button
@export var building_component: BuildingComponent
@export var building_inventory: Control


@export var player_health: Node
@export var health_label: Label

var player: Node

var _hovered_inventory_item: InventoryItem = null

var _selected_item_id: String = ""        ## ID của item đã chọn từ dropdown
var _all_item_ids: Array[String] = []     ## Cache toàn bộ item id

@onready var _search_dropdown: PanelContainer = $SearchDropdown
@onready var _result_list: VBoxContainer      = $SearchDropdown/ScrollContainer/ResultList
@onready var _open_inventory_player: AudioStreamPlayer = $InventoryPlayer


func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")

	if not player_health:
		player_health = player

	if player_health and player_health.has_signal("health_changed"):
		if not player_health.health_changed.is_connected(_on_health_changed):
			player_health.health_changed.connect(_on_health_changed)

	if player_health:
		var health_values = _get_health_values(player_health)
		if not health_values.is_empty():
			_on_health_changed(health_values["health"], health_values["max_health"])
	else:
		push_warning("Inventory: `player_health` not assigned and player node could not be found; health UI will not update.")

	var inventory_system := get_node_or_null("/root/InventorySystem")
	if inventory_system:
		var player_inv: InventoryModel = inventory_system.get_player_inventory()
		if player_inv and not player_inv.item_used.is_connected(_on_item_used):
			player_inv.item_used.connect(_on_item_used)
		if inventory_system.has_signal("item_hovered"):
			inventory_system.item_hovered.connect(_on_item_hovered)

	if create_item_btn:
		create_item_btn.pressed.connect(_on_create_item_pressed)
		create_item_btn.disabled = true
	else:
		push_warning("Inventory: `create_item_btn` not assigned.")

	if clear_btn:
		clear_btn.pressed.connect(_on_clear_pressed)
	else:
		push_warning("Inventory: `clear_btn` not assigned.")

	if stash_button:
		stash_button.pressed.connect(_on_stash_pressed)
	if npc1_button:
		npc1_button.pressed.connect(_on_npc1_pressed)
	if npc2_button:
		npc2_button.pressed.connect(_on_npc2_pressed)
	if building_button:
		building_button.pressed.connect(_on_building_pressed)

	if item_id_field:
		item_id_field.text_changed.connect(_on_search_text_changed)
		item_id_field.focus_entered.connect(_on_search_focus_entered)
		item_id_field.focus_exited.connect(_on_search_focus_lost)

	if _search_dropdown:
		_search_dropdown.visible = false

	await get_tree().process_frame
	_cache_all_items()



func _cache_all_items() -> void:
	_all_item_ids.clear()
	var inventory_system := get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		return
	_scan_items_recursive("res://resources/")


func _scan_items_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue
		var full := path.path_join(fname)
		if dir.current_is_dir():
			_scan_items_recursive(full)
		elif fname.ends_with(".tres") or fname.ends_with(".res"):
			var res = ResourceLoader.load(full)
			if res and res is ItemBase and res.is_valid():
				var id: String = res.id if not res.id.is_empty() else res.name.to_snake_case()
				if not _all_item_ids.has(id):
					_all_item_ids.append(id)
		fname = dir.get_next()
	dir.list_dir_end()


func _on_search_text_changed(new_text: String) -> void:
	_selected_item_id = ""
	if create_item_btn:
		create_item_btn.disabled = true

	var query := new_text.strip_edges().to_lower()
	if query.is_empty():
		_hide_dropdown()
		return

	var matches: Array[String] = []
	var inv_sys := get_node_or_null("/root/InventorySystem")
	for id in _all_item_ids:
		if query in id.to_lower():
			matches.append(id)
			continue
		if inv_sys:
			var base = inv_sys.get_item_base(id)
			if base and query in base.name.to_lower():
				matches.append(id)

	if matches.is_empty():
		_hide_dropdown()
		return

	_show_dropdown(matches)


func _show_dropdown(matches: Array[String]) -> void:
	if not _result_list or not _search_dropdown:
		return

	for child in _result_list.get_children():
		child.queue_free()

	var inv_sys := get_node_or_null("/root/InventorySystem")

	for id in matches:
		var display := id
		if inv_sys:
			var base = inv_sys.get_item_base(id)
			if base:
				display = "%s  [%s]" % [base.name, id]

		var btn := Button.new()
		btn.text = display
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_result_selected.bind(id, display))
		_result_list.add_child(btn)

	_search_dropdown.visible = true


func _on_result_selected(id: String, display_text: String) -> void:
	_selected_item_id = id
	if item_id_field:
		item_id_field.text = display_text
		item_id_field.caret_column = item_id_field.text.length()
	_hide_dropdown()
	if create_item_btn:
		create_item_btn.disabled = false


func _hide_dropdown() -> void:
	if _search_dropdown:
		_search_dropdown.visible = false


func _on_search_focus_entered() -> void:
	if player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO


func _on_search_focus_lost() -> void:
	await get_tree().create_timer(0.15).timeout
	_hide_dropdown()
	if player:
		player.set_physics_process(true)



func _on_create_item_pressed() -> void:
	if _selected_item_id.is_empty():
		push_warning("Inventory: chưa chọn item từ dropdown.")
		return

	var inventory_system := get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		return

	var base_item = inventory_system.get_item_base(_selected_item_id)
	if not base_item:
		push_warning("No base item found with ID: %s" % _selected_item_id)
		return

	inventory_system.get_player_inventory().create_item(base_item, base_item.max_stacks)


func _on_item_used(inventory_item: InventoryItem) -> void:
	var item_name := inventory_item.item.base.name if inventory_item and inventory_item.item and inventory_item.item.base else "null"
	print("[Inventory] _on_item_used: item='%s'" % item_name)

	if not inventory_item or not inventory_item.item:
		print("[Inventory] _on_item_used: FAIL — inventory_item hoặc item là null")
		return

	var item: Item = inventory_item.item

	if not item.base:
		print("[Inventory] _on_item_used: FAIL — item.base là null")
		return

	if not item.base.get_on_use():
		print("[Inventory] _on_item_used: FAIL — item '%s' không có on_use được gán" % item.base.name)
		return

	if not player:
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			print("[Inventory] _on_item_used: FAIL — không tìm thấy node trong group 'Player'")
			return
		print("[Inventory] _on_item_used: player được lấy lại thành công")

	print("[Inventory] _on_item_used: can_use=%s" % str(item.base.get_on_use().can_use(item, player)))
	if item.base.get_on_use().can_use(item, player):
		var result := item.base.get_on_use().on_use(item, player)
		print("[Inventory] _on_item_used: on_use returned %s" % str(result))
	else:
		print("[Inventory] _on_item_used: can_use trả về false — không sử dụng được (HP/Hunger đã đầy?)")


func _on_item_hovered(inventory_item: InventoryItem, hovered: bool) -> void:
	if hovered:
		_hovered_inventory_item = inventory_item
	else:
		if _hovered_inventory_item == inventory_item:
			_hovered_inventory_item = null


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("action_use_item"):
		return
	if not _hovered_inventory_item or not _hovered_inventory_item.item:
		return
	var item: Item = _hovered_inventory_item.item
	if not item.base or item.base.item_type != ItemBase.ItemType.CONSUMABLE:
		return
	_on_item_used(_hovered_inventory_item)
	get_viewport().set_input_as_handled()


func _on_clear_pressed() -> void:
	var inventory_system := get_node_or_null("/root/InventorySystem")
	if not inventory_system:
		return
	var player_inv: InventoryModel = inventory_system.get_player_inventory()
	if player_inv:
		player_inv.clear()


func _get_health_values(source: Object) -> Dictionary:
	if "current_hp" in source and "max_hp" in source:
		return {"health": int(source.current_hp), "max_health": int(source.max_hp)}
	return {}


func _on_health_changed(health: int, max_health: int) -> void:
	health_label.text = "%d / %d" % [health, max_health]


func _on_stash_pressed() -> void:
	stash_panel.visible = not stash_panel.visible


func _on_npc1_pressed() -> void:
	if vendor_inventory and vendor1:
		vendor_inventory.visible = true
		vendor_inventory.set_vendor(vendor1)


func _on_npc2_pressed() -> void:
	if not crafting_inventory:
		return
	crafting_inventory.visible = not crafting_inventory.visible
	if crafting_inventory.visible:
		if building_inventory:
			building_inventory.visible = false
		if crafting_component:
			if crafting_inventory.has_method("set_crafting_component"):
				crafting_inventory.set_crafting_component(crafting_component)


func _on_building_pressed() -> void:
	if not building_inventory:
		return
	building_inventory.visible = not building_inventory.visible
	if building_inventory.visible:
		if crafting_inventory:
			crafting_inventory.visible = false
		if building_component:
			if building_inventory.has_method("set_building_component"):
				building_inventory.set_building_component(building_component)


func open_for_building(hide_crafting: bool = true) -> void:
	var was_visible := visible
	visible = true
	if not was_visible:
		play_open_inventory_sound()
	if npc2_button:
		npc2_button.visible = not hide_crafting
	if building_button:
		building_button.visible = false
	if hide_crafting and crafting_inventory and crafting_inventory.visible:
		crafting_inventory.visible = false
	if building_inventory and building_inventory.visible:
		building_inventory.visible = false


func close_all_submenus() -> void:
	if crafting_inventory:
		crafting_inventory.visible = false
	if building_inventory:
		building_inventory.visible = false
	if vendor_inventory:
		vendor_inventory.visible = false
	if stash_panel:
		stash_panel.visible = false


func close_for_building() -> void:
	if npc2_button:
		npc2_button.visible = true
	if building_button:
		building_button.visible = true


func play_open_inventory_sound() -> void:
	if _open_inventory_player and _open_inventory_player.stream:
		_open_inventory_player.play()
