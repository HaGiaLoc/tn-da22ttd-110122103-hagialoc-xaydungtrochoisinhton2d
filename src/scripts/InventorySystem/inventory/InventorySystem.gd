extends Control

signal inventory_registered(inventory: InventoryModel)
signal inventory_unregistered(inventory: InventoryModel)
signal item_hovered(inventory_item: InventoryItem, hovered: bool)

@export var items_path: String = "res://resources/"
@export var player_inventory: String = "player_inventory"
@export var default_currency: ItemBase

@export var held_item: InventoryItem
@export var held_item_quantity: Label

var _items: Dictionary[String, ItemBase] = {}
var _currency_item: ItemBase = null
var _building_recipes: Array = []

var _inventories: Dictionary[String, InventoryModel] = {}

func _enter_tree():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_items()
	_currency_item = default_currency
	held_item.visible = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_layer)
	remove_child(held_item)
	canvas_layer.add_child(held_item)
	held_item.process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event is InputEventMouseMotion and is_holding_item():
		_move_held_item()

func register_inventory(inventory: InventoryModel) -> void:
	if _inventories.has(inventory.id):
		push_warning("Inventory with ID %s is already registered." % inventory.id)
		return
	_inventories[inventory.id] = inventory
	inventory_registered.emit(inventory)

func unregister_inventory(inventory: InventoryModel) -> void:
	if not _inventories.has(inventory.id):
		push_warning("Inventory with ID %s is not registered." % inventory.id)
		return
	_inventories.erase(inventory.id)
	inventory_unregistered.emit(inventory)

func get_inventory(inventory_id: String) -> InventoryModel:
	return _inventories.get(inventory_id)

func get_player_inventory() -> InventoryModel:
	return get_inventory(player_inventory)

func _load_items():
	_scan_directory(items_path)
	print("Loaded %d base items." % _items.size())


func _scan_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_error("Failed to open items directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path: String = path.path_join(file_name)

		if dir.current_is_dir():
			_scan_directory(full_path)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var item_resource = ResourceLoader.load(full_path)
			if item_resource and item_resource is ItemBase:
				if item_resource.is_valid():
					var item_id: String = item_resource.id
					if item_id.is_empty():
						item_id = item_resource.name.to_snake_case()
						item_resource.id = item_id
					_items[item_id] = item_resource
				else:
					push_warning("Invalid ItemBase in %s" % full_path)
			elif item_resource and item_resource is BuildingRecipe:
				if item_resource.is_valid():
					_building_recipes.append(item_resource)

		file_name = dir.get_next()

	dir.list_dir_end()

func pick_up_item(item: Item) -> void:
	if not item or held_item.item:
		print("[InventorySystem] pick_up_item BLOCKED: item=%s already_holding=%s" % [str(item), str(held_item.item != null)])
		return
	print("[InventorySystem] pick_up_item: %s x%d" % [item.base.name, item.quantity])
	held_item.item = item
	held_item.texture = item.base.icon
	if item.base.stackable:
		held_item_quantity.text = str(item.quantity)
	held_item.visible = true
	_move_held_item()
	_hide_tooltip()

func drop_held_item() -> void:
	print("[InventorySystem] drop_held_item")
	held_item.item = null
	held_item.texture = null
	held_item_quantity.text = ""
	held_item.visible = false

func get_held_item() -> Item:
	return held_item.item

func is_holding_item() -> bool:
	return held_item.item != null && held_item.visible

func _move_held_item() -> void:
	held_item.position = held_item.get_viewport().get_mouse_position() - held_item.size / 2

func on_item_hover(inventory_item: InventoryItem, hovered: bool) -> void:
	if is_holding_item():
		return
	item_hovered.emit(inventory_item, hovered)
	var tooltip_layer = get_node_or_null("/root/ItemTooltip")
	var tooltip = tooltip_layer.get_node_or_null("TooltipControl") if tooltip_layer else null
	if tooltip:
		if hovered:
			tooltip.inspect(inventory_item)
		else:
			tooltip.hide()

func _hide_tooltip() -> void:
	var tooltip_layer = get_node_or_null("/root/ItemTooltip")
	var tooltip = tooltip_layer.get_node_or_null("TooltipControl") if tooltip_layer else null
	if tooltip:
		tooltip.hide()

func get_item_base(item_id: String) -> ItemBase:
	return _items.get(item_id)

func get_currency_item() -> ItemBase:
	return _currency_item

func get_building_recipe_by_scene_path(path: String) -> Resource:
	var path_res = path
	if path.begins_with("uid://"):
		path_res = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
		
	for recipe in _building_recipes:
		var recipe_path = recipe.building_scene
		if recipe_path == path or recipe_path == path_res:
			return recipe
			
		if recipe_path.begins_with("uid://"):
			var res_path = ResourceUID.get_id_path(ResourceUID.text_to_id(recipe_path))
			if res_path == path or res_path == path_res:
				return recipe
				
	return null

func drop_items_around(items_to_drop: Array[Item], global_pos: Vector2, parent_node: Node) -> void:
	if items_to_drop.is_empty() or not parent_node:
		return
	
	var count := items_to_drop.size()
	for i in count:
		var item: Item = items_to_drop[i]
		if not item or item.quantity <= 0:
			continue
		
		var offset := Vector2.ZERO
		if count > 1:
			var angle: float = (TAU / count) * i
			offset = Vector2(cos(angle), sin(angle)) * 16.0
			
		WorldItem.spawn(item, parent_node, global_pos + offset)
