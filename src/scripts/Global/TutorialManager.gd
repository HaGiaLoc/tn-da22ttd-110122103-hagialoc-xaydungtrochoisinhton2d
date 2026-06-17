extends Node

signal objective_updated(text: String, progress: float)
signal objective_completed(index: int)
signal tutorial_finished()

var is_tutorial_enabled: bool = true
var current_objective_index: int = 0

var has_moved_w := false
var has_moved_a := false
var has_moved_s := false
var has_moved_d := false

var fiber_collected := 0
var branch_collected := 0
var wood_collected := 0 # Just in case

var rope_crafted := 0
var stick_crafted := 0

var has_stone_axe := false
var has_stone_pickaxe := false
var has_stone_sword := false

var has_stone_axe_equipped := false
var has_stone_pickaxe_equipped := false
var has_stone_sword_equipped := false

var objectives = [
	{
		"id": "move",
		"text": "Chập chững bước đi:\n• Di chuyển (W, A, S, D).",
	},
	{
		"id": "gather_basic",
		"text": "Bàn tay trần:\n• Sợi (0/27)\n• Cành cây (0/6)\n• Đá (0/9)",
	},
	{
		"id": "open_inventory",
		"text": "Hành trang:\n• Mở Túi đồ (I).",
	},
	{
		"id": "craft_basic",
		"text": "Vật liệu cơ bản:\n• Dây thừng (0/9)\n• Gậy (0/6)",
	},
	{
		"id": "craft_tools",
		"text": "Công cụ đồ đá:\n• Rìu đá [ ]\n• Cuốc chim đá [ ]\n• Kiếm đá [ ]",
	},
	{
		"id": "combat",
		"text": "Tự vệ:\n• Trang bị Rìu đá [ ]\n• Trang bị Cuốc chim đá [ ]\n• Trang bị Kiếm đá [ ]\n• Nhấn chuột trái để tấn công.",
	},
	{
		"id": "build_crafting_table",
		"text": "Góc làm việc:\n• Đặt Bàn chế tạo.",
	},
	{
		"id": "build_chest",
		"text": "Lưu trữ:\n• Đặt Rương.",
	},
	{
		"id": "build_furnace",
		"text": "Hơi nóng của lửa:\n• Xây Lò nung.",
	},
	{
		"id": "gather_copper",
		"text": "Thợ mỏ:\n• Thu thập Quặng đồng.",
	},
	{
		"id": "smelt_copper",
		"text": "Luyện kim:\n• Chế tạo Thỏi đồng.",
	},
	{
		"id": "build_anvil",
		"text": "Thợ rèn:\n• Xây Đe.",
	},
	{
		"id": "activate_portal",
		"text": "Thoát khỏi hòn đảo:\n• Kim cương (0/10)\n• Đồng vàng (0/99)\n• Ngọc lục bảo (0/10)\n• Nanh sói (0/10)\n• Kích hoạt Cổng dịch chuyển.",
	}
]

func _ready() -> void:
	call_deferred("update_ui")


func _get_player_item_count(item_id: String) -> int:
	var inv_sys := get_node_or_null("/root/InventorySystem")
	if not inv_sys:
		return 0
	var total := 0
	var skip_ids := ["stash", "vendor"]
	for inv: InventoryModel in inv_sys._inventories.values():
		if inv.id in skip_ids:
			continue
		for item in inv.items.values():
			if item and item.base and item.base.id == item_id:
				total += item.quantity
	return total

func get_current_objective_text() -> String:
	if current_objective_index >= objectives.size():
		return ""
	
	var obj = objectives[current_objective_index]
	var text = obj["text"]
	
	if current_objective_index == 1:
		var fiber: int = min(_get_player_item_count("fiber"), 27)
		var branch: int = min(_get_player_item_count("branch"), 6)
		var stone: int = min(_get_player_item_count("stone"), 9)
		text = "Bàn tay trần:\n• Sợi (%d/27)\n• Cành cây (%d/6)\n• Đá (%d/9)" % [fiber, branch, stone]
	elif current_objective_index == 3:
		text = "Vật liệu cơ bản:\n• Dây thừng (%d/9)\n• Gậy (%d/6)" % [min(rope_crafted, 9), min(stick_crafted, 6)]
	elif current_objective_index == 4:
		var axe_mark := "x" if has_stone_axe else " "
		var pick_mark := "x" if has_stone_pickaxe else " "
		var sword_mark := "x" if has_stone_sword else " "
		text = "Công cụ đồ đá:\n• Rìu đá [%s]\n• Cuốc chim đá [%s]\n• Kiếm đá [%s]" % [axe_mark, pick_mark, sword_mark]
	elif current_objective_index == 5:
		var axe_eq := "x" if has_stone_axe_equipped else " "
		var pick_eq := "x" if has_stone_pickaxe_equipped else " "
		var sword_eq := "x" if has_stone_sword_equipped else " "
		text = "Tự vệ:\n• Trang bị Rìu đá [%s]\n• Trang bị Cuốc chim đá [%s]\n• Trang bị Kiếm đá [%s]\n• Nhấn chuột trái để tấn công." % [axe_eq, pick_eq, sword_eq]
			
	return text

func complete_current_objective() -> void:
	if current_objective_index >= objectives.size(): return
	
	objective_completed.emit(current_objective_index)
	current_objective_index += 1
	
	if current_objective_index >= objectives.size():
		tutorial_finished.emit()
	else:
		update_ui()

func update_ui() -> void:
	if current_objective_index < objectives.size():
		objective_updated.emit(get_current_objective_text(), 0.0)
	else:
		objective_updated.emit("", 1.0)


func notify_movement(dir: Vector2) -> void:
	if current_objective_index != 0 or not is_tutorial_enabled: return
	if dir.y < 0: has_moved_w = true
	if dir.y > 0: has_moved_s = true
	if dir.x < 0: has_moved_a = true
	if dir.x > 0: has_moved_d = true
	
	if has_moved_w and has_moved_a and has_moved_s and has_moved_d:
		complete_current_objective()

func notify_item_collected(item_id: String, _amount: int = 1) -> void:
	if not is_tutorial_enabled: return
	
	if current_objective_index == 1:
		if item_id == "fiber" or item_id == "branch":
			update_ui()
			var fiber := _get_player_item_count("fiber")
			var branch := _get_player_item_count("branch")
			if fiber >= 27 and branch >= 6:
				complete_current_objective()

	elif current_objective_index == 4:
		if item_id == "stone":
			update_ui()

	elif current_objective_index == 9:
		if item_id == "copper_ore":
			update_ui()
			complete_current_objective()

func notify_inventory_opened() -> void:
	if current_objective_index == 2 and is_tutorial_enabled:
		complete_current_objective()

func notify_crafted(item_id: String, amount: int = 1) -> void:
	if not is_tutorial_enabled: return
	
	if current_objective_index == 3:
		if item_id == "rope":
			rope_crafted += amount
			update_ui()
		elif item_id == "stick":
			stick_crafted += amount
			update_ui()
			
		if rope_crafted >= 9 and stick_crafted >= 6:
			complete_current_objective()
			
	elif current_objective_index == 4:
		if item_id == "stone_axe":
			has_stone_axe = true
			update_ui()
		elif item_id == "stone_pickaxe":
			has_stone_pickaxe = true
			update_ui()
		elif item_id == "stone_sword":
			has_stone_sword = true
			update_ui()
			
		if has_stone_axe and has_stone_pickaxe and has_stone_sword:
			complete_current_objective()
			
	elif current_objective_index == 10:
		if item_id == "copper_ingot":
			complete_current_objective()

func notify_equipped(item_id: String) -> void:
	if not is_tutorial_enabled: return
	if current_objective_index == 5:
		if item_id == "stone_axe":
			has_stone_axe_equipped = true
			update_ui()
		elif item_id == "stone_pickaxe":
			has_stone_pickaxe_equipped = true
			update_ui()
		elif item_id == "stone_sword":
			has_stone_sword_equipped = true
			update_ui()

func notify_attacked() -> void:
	if not is_tutorial_enabled: return
	if current_objective_index == 5 and has_stone_axe_equipped and has_stone_pickaxe_equipped and has_stone_sword_equipped:
		complete_current_objective()

func notify_built(building_id: String) -> void:
	if not is_tutorial_enabled: return
	
	if current_objective_index == 6 and building_id == "crafting_table":
		complete_current_objective()
	elif current_objective_index == 7 and building_id == "chest":
		complete_current_objective()
	elif current_objective_index == 8 and building_id == "furnace":
		complete_current_objective()
	elif current_objective_index == 11 and building_id == "anvil":
		complete_current_objective()

func notify_portal_activated() -> void:
	if current_objective_index == 12: # It's okay if not enabled, 12 is the final anyway
		complete_current_objective()

func get_save_data() -> Dictionary:
	return {
		"is_tutorial_enabled": is_tutorial_enabled,
		"current_objective_index": current_objective_index,
		"fiber_collected": fiber_collected,
		"branch_collected": branch_collected,
		"rope_crafted": rope_crafted,
		"stick_crafted": stick_crafted,
		"has_stone_axe": has_stone_axe,
		"has_stone_pickaxe": has_stone_pickaxe,
		"has_stone_sword": has_stone_sword,
		"has_stone_axe_equipped": has_stone_axe_equipped,
		"has_stone_pickaxe_equipped": has_stone_pickaxe_equipped,
		"has_stone_sword_equipped": has_stone_sword_equipped
	}

func load_save_data(data: Dictionary) -> void:
	if data.is_empty(): return
	
	is_tutorial_enabled = data.get("is_tutorial_enabled", true)
	current_objective_index = data.get("current_objective_index", 0)
	fiber_collected = data.get("fiber_collected", 0)
	branch_collected = data.get("branch_collected", 0)
	rope_crafted = data.get("rope_crafted", 0)
	stick_crafted = data.get("stick_crafted", 0)
	has_stone_axe = data.get("has_stone_axe", false)
	has_stone_pickaxe = data.get("has_stone_pickaxe", false)
	has_stone_sword = data.get("has_stone_sword", false)
	has_stone_axe_equipped = data.get("has_stone_axe_equipped", false)
	has_stone_pickaxe_equipped = data.get("has_stone_pickaxe_equipped", false)
	has_stone_sword_equipped = data.get("has_stone_sword_equipped", false)
	
	call_deferred("update_ui")
	_deferred_check_collect.call_deferred()

func enable_tutorial(enabled: bool) -> void:
	is_tutorial_enabled = enabled
	if not enabled:
		current_objective_index = objectives.size() - 1 # Jump to the last objective (Portal)
	else:
		if current_objective_index == objectives.size() - 1:
			current_objective_index = 0 # Reset if turning back on from disabled state? Let's just say we don't reset if they made progress.
	update_ui()

func reset_progress() -> void:
	current_objective_index = 0 if is_tutorial_enabled else (objectives.size() - 1)
	has_moved_w = false
	has_moved_a = false
	has_moved_s = false
	has_moved_d = false
	fiber_collected = 0
	branch_collected = 0
	wood_collected = 0
	rope_crafted = 0
	stick_crafted = 0
	has_stone_axe = false
	has_stone_pickaxe = false
	has_stone_sword = false
	has_stone_axe_equipped = false
	has_stone_pickaxe_equipped = false
	has_stone_sword_equipped = false
	call_deferred("update_ui")

func _check_collect_objective_on_load() -> void:
	if current_objective_index == 1:
		update_ui()
		var fiber := _get_player_item_count("fiber")
		var branch := _get_player_item_count("branch")
		if fiber >= 18 and branch >= 4:
			complete_current_objective()

func _deferred_check_collect() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_check_collect_objective_on_load()
