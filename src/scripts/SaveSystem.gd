extends Node

signal game_loaded

const SAVE_PATH := "user://savegame.sav"
const SETTINGS_PATH := "user://settings.sav"

const INVENTORY_FILES := [
	"user://player_inventory.inv",
	"user://hotbar.inv",
	"user://stash.inv",
	"user://player_equipment.inv",
]

var load_on_ready: bool = false

var _pending_chest_inventories: Dictionary = {}
var _placed_chest_counter: int = 0

const PLAYER_PLACED_META := "player_placed"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func clear_save_data() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	for path in INVENTORY_FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
			
	TutorialManager.reset_progress()
		
	print("[SaveSystem] Đã xóa toàn bộ dữ liệu lưu.")



func save_game() -> void:
	var data: Dictionary = {}

	data["player"]     = _save_player()
	data["inventories"] = _save_inventories()
	data["portal"]     = _save_portal()
	data["animals"]    = _save_entities("Animal")
	data["enemies"]    = _save_entities("Enemy")
	data["buildings"]  = _save_buildings()
	data["resource_spawners"] = _save_resource_spawners()
	data["tutorial"]   = _save_tutorial()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveSystem] Không thể mở file để ghi: %s" % SAVE_PATH)
		return
	file.store_var(data)
	file.close()
	print("[SaveSystem] Đã lưu game.")


func _save_player() -> Dictionary:
	var player := get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning("[SaveSystem] Không tìm thấy Player.")
		return {}
	return {
		"pos_x":            player.global_position.x,
		"pos_y":            player.global_position.y,
		"current_hp":       player.current_hp,
		"max_hp":           player.max_hp,
		"current_hunger":   player.current_hunger,
		"max_hunger":       player.max_hunger,
		"current_direction": player.get("current_direction") if player.get("current_direction") != null else "down",
	}


func _save_inventories() -> Dictionary:
	var result: Dictionary = {}
	var inv_sys := get_node_or_null("/root/InventorySystem")
	if not inv_sys:
		return result

	var ids_to_save := ["player_inventory", "hotbar", "stash"]
	for inv_id in ids_to_save:
		var inv: InventoryModel = inv_sys.get_inventory(inv_id)
		if inv:
			result[inv_id] = _serialize_inventory_model(inv)

	var equipment := get_tree().get_first_node_in_group("PlayerEquipment")
	if equipment:
		result["equipment"] = _serialize_equipment(equipment)

	return result


func _serialize_inventory_model(inv: InventoryModel) -> Dictionary:
	var slots_data: Dictionary = {}
	for slot_index in inv.items.keys():
		var item: Item = inv.items[slot_index]
		slots_data[slot_index] = item.serialize()
	return slots_data


func _serialize_equipment(equipment) -> Dictionary:
	var slots_data: Dictionary = {}
	for slot_type in equipment.items.keys():
		var item: Item = equipment.items[slot_type]
		slots_data[int(slot_type)] = item.serialize()
	return slots_data


func _save_portal() -> Dictionary:
	var portal := get_tree().get_first_node_in_group("Portal")
	if not portal:
		return {}

	var slot_filled  := [false, false, false, false]
	var slot_current := [0, 0, 0, 0]
	var ready_to_activate: bool = portal.get("_ready_to_activate") if portal.get("_ready_to_activate") != null else false

	var ui_instance = portal.get("_ui_instance")
	if ui_instance and is_instance_valid(ui_instance):
		var filled = ui_instance.get("_slot_filled")
		var current = ui_instance.get("_slot_current")
		if filled:
			slot_filled = filled.duplicate()
		if current:
			slot_current = current.duplicate()

	return {
		"ready_to_activate": ready_to_activate,
		"slot_filled":       slot_filled,
		"slot_current":      slot_current,
	}


func _save_entities(group: String) -> Array:
	var result: Array = []
	for entity in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(entity):
			continue
		result.append({
			"scene_file":        entity.scene_file_path,
			"spawn_point_path":  str(entity.get_meta("spawn_point_path", "")),
			"pos_x":             entity.global_position.x,
			"pos_y":             entity.global_position.y,
			"health":            entity.get("health") if entity.get("health") != null else entity.get("max_health"),
			"max_health":        entity.get("max_health") if entity.get("max_health") != null else 100,
			"current_direction": entity.get("current_direction") if entity.get("current_direction") != null else "down_right",
			"last_direction":    entity.get("last_direction")    if entity.get("last_direction")    != null else "down_right",
		})
	return result


func _save_buildings() -> Array:
	var result: Array = []
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return result

	var inv_sys := get_node_or_null("/root/InventorySystem")
	_collect_player_buildings(scene_root, result, inv_sys)
	return result


func _collect_player_buildings(node: Node, result: Array, inv_sys: Node) -> void:
	if node.get_meta(PLAYER_PLACED_META, false) and node is Node2D:
		var entry := {
			"scene_file": node.scene_file_path,
			"pos_x":      node.global_position.x,
			"pos_y":      node.global_position.y,
		}
		if node is Chest:
			entry["chest_id"] = node.chest_id
			if inv_sys:
				var chest_inv: InventoryModel = inv_sys.get_inventory(node.chest_id)
				if chest_inv:
					entry["chest_inventory"] = _serialize_inventory_model(chest_inv)
		result.append(entry)
		return

	for child in node.get_children():
		_collect_player_buildings(child, result, inv_sys)



func load_game() -> void:
	if not has_save():
		push_warning("[SaveSystem] Không có bản lưu.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveSystem] Không thể mở file để đọc: %s" % SAVE_PATH)
		return
	var data: Dictionary = file.get_var()
	file.close()

	await get_tree().process_frame
	await get_tree().process_frame

	if data.has("player"):
		_load_player(data["player"])
	if data.has("inventories"):
		_load_inventories(data["inventories"])
	if data.has("portal"):
		_load_portal(data["portal"])
	if data.has("animals"):
		_load_entities(data["animals"], "Animal")
	if data.has("enemies"):
		_load_entities(data["enemies"], "Enemy")
	if data.has("buildings"):
		await _load_buildings(data["buildings"])
	if data.has("resource_spawners"):
		_load_resource_spawners(data["resource_spawners"])
	if data.has("tutorial"):
		_load_tutorial(data["tutorial"])

	game_loaded.emit()
	print("[SaveSystem] Đã tải game.")


func _load_player(player_data: Dictionary) -> void:
	if player_data.is_empty():
		return
	var player := get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning("[SaveSystem] Không tìm thấy Player khi load.")
		return

	player.global_position = Vector2(player_data["pos_x"], player_data["pos_y"])
	player.current_hp      = float(player_data.get("current_hp", player.max_hp))
	player.max_hp          = float(player_data.get("max_hp", player.max_hp))
	player.current_hunger  = float(player_data.get("current_hunger", player.max_hunger))
	player.max_hunger      = float(player_data.get("max_hunger", player.max_hunger))

	var direction: String = player_data.get("current_direction", "down")
	if player.get("current_direction") != null:
		player.current_direction = direction
	var anim_sprite = player.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.play("idle_" + direction)

	player.update_hp_ui()
	player.health_changed.emit(int(player.current_hp), int(player.max_hp))
	player.hunger_changed.emit(player.current_hunger, player.max_hunger)

	var camera := player.get_node_or_null("Camera2D")
	if camera:
		camera.global_position = player.global_position


func _load_inventories(inv_data: Dictionary) -> void:
	var inv_sys := get_node_or_null("/root/InventorySystem")
	if not inv_sys:
		return

	for inv_id in ["player_inventory", "hotbar", "stash"]:
		if not inv_data.has(inv_id):
			continue
		var inv: InventoryModel = inv_sys.get_inventory(inv_id)
		if not inv:
			push_warning("[SaveSystem] Không tìm thấy inventory id='%s'" % inv_id)
			continue
		_restore_inventory_model(inv, inv_data[inv_id], inv_sys)

	if inv_data.has("equipment"):
		var equipment := get_tree().get_first_node_in_group("PlayerEquipment")
		if equipment:
			_restore_equipment(equipment, inv_data["equipment"], inv_sys)


func _restore_inventory_model(inv: InventoryModel, slots_data: Dictionary, inv_sys: Node) -> void:
	inv.clear()
	for slot_index_var in slots_data.keys():
		var slot_index := int(slot_index_var)
		var item_data: Dictionary = slots_data[slot_index_var]
		var base: ItemBase = inv_sys.get_item_base(item_data["base_id"])
		if not base:
			push_warning("[SaveSystem] Không tìm thấy ItemBase id='%s'" % item_data["base_id"])
			continue
		var item := Item.new(base, item_data.get("quantity", 1))
		item.deserialize(item_data)
		inv.add_item_at(item, slot_index)


func _restore_equipment(equipment, slots_data: Dictionary, inv_sys: Node) -> void:
	for slot_type in equipment.items.keys().duplicate():
		equipment.remove_item_at(slot_type)

	for slot_type_var in slots_data.keys():
		var slot_type := int(slot_type_var)
		var item_data: Dictionary = slots_data[slot_type_var]
		var base: ItemBase = inv_sys.get_item_base(item_data["base_id"])
		if not base:
			push_warning("[SaveSystem] Không tìm thấy ItemBase equipment id='%s'" % item_data["base_id"])
			continue
		var item := Item.new(base, item_data.get("quantity", 1))
		item.deserialize(item_data)
		equipment.add_item_at(item, slot_type)


func _load_portal(portal_data: Dictionary) -> void:
	if portal_data.is_empty():
		return
	var portal := get_tree().get_first_node_in_group("Portal")
	if not portal:
		return

	var ready_to_activate: bool = portal_data.get("ready_to_activate", false)
	var slot_filled: Array  = portal_data.get("slot_filled",  [false, false, false, false])
	var slot_current: Array = portal_data.get("slot_current", [0, 0, 0, 0])

	if ready_to_activate:
		portal.call("on_all_slots_filled")
		return

	for i in range(slot_filled.size()):
		if slot_filled[i] and portal.has_method("on_slot_filled"):
			portal.call("on_slot_filled", i)

	var ui_instance = portal.get("_ui_instance")
	if ui_instance and is_instance_valid(ui_instance):
		if ui_instance.get("_slot_filled") != null:
			ui_instance.set("_slot_filled", slot_filled.duplicate())
		if ui_instance.get("_slot_current") != null:
			ui_instance.set("_slot_current", slot_current.duplicate())


func _load_entities(entities_data: Array, group: String) -> void:
	for entity in get_tree().get_nodes_in_group(group):
		if is_instance_valid(entity):
			entity.queue_free()

	if entities_data.is_empty():
		return

	await get_tree().process_frame

	var scene_root := get_tree().current_scene
	for entity_data in entities_data:
		var scene_file: String = entity_data.get("scene_file", "")
		if scene_file.is_empty():
			push_warning("[SaveSystem] Entity thiếu scene_file, bỏ qua.")
			continue
		if not ResourceLoader.exists(scene_file):
			push_warning("[SaveSystem] Scene không tồn tại: %s" % scene_file)
			continue

		var packed: PackedScene = load(scene_file)
		if not packed:
			continue

		var world_pos := Vector2(entity_data["pos_x"], entity_data["pos_y"])
		var instance := packed.instantiate()
		var spawn_point := _resolve_spawn_point(scene_root, entity_data, scene_file, world_pos)

		if spawn_point != null:
			spawn_point.setup_entity(instance, world_pos, scene_root)
		else:
			_setup_entity_without_spawn_point(instance, world_pos, scene_root)

		await get_tree().process_frame
		if is_instance_valid(instance) and instance.get("health") != null:
			instance.health = int(entity_data.get("health", entity_data.get("max_health", 100)))
			if instance.has_signal("health_changed"):
				instance.health_changed.emit(instance.health, instance.get("max_health"))

			var cur_dir: String = entity_data.get("current_direction", "down_right")
			var last_dir: String = entity_data.get("last_direction", cur_dir)
			if instance.get("current_direction") != null:
				instance.current_direction = cur_dir
			if instance.get("last_direction") != null:
				instance.last_direction = last_dir
			var anim_sprite = instance.get_node_or_null("AnimatedSprite2D")
			if anim_sprite:
				anim_sprite.play("idle_" + last_dir)


func _resolve_spawn_point(scene_root: Node, entity_data: Dictionary, scene_file: String, world_pos: Vector2) -> Node:
	var saved_path: String = entity_data.get("spawn_point_path", "")
	if not saved_path.is_empty():
		var saved_node := scene_root.get_node_or_null(NodePath(saved_path))
		if saved_node != null and saved_node.get("entity_scene") != null:
			var sp_scene: PackedScene = saved_node.entity_scene
			if sp_scene != null and sp_scene.resource_path == scene_file:
				return saved_node

	return _find_spawn_point_for(scene_file, world_pos)


func _find_spawn_point_for(scene_file: String, near_position: Vector2) -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null

	var best_containing: Node = null
	var best_containing_dist := INF
	var best_fallback: Node = null
	var best_fallback_dist := INF

	for node in scene_root.get_children():
		if node.get("entity_scene") == null:
			continue
		var sp_scene: PackedScene = node.entity_scene
		if sp_scene == null or sp_scene.resource_path != scene_file:
			continue

		var patrol_area: Area2D = node.get_node_or_null("PatrolArea")
		var patrol_center: Vector2 = (
			WaterTileChecker.get_patrol_area_center(patrol_area)
			if patrol_area != null else node.global_position
		)

		if patrol_area != null and WaterTileChecker.is_inside_patrol_area(patrol_area, near_position):
			var containing_dist := near_position.distance_to(patrol_center)
			if containing_dist < best_containing_dist:
				best_containing_dist = containing_dist
				best_containing = node
			continue

		var fallback_dist := near_position.distance_to(patrol_center)
		if fallback_dist < best_fallback_dist:
			best_fallback_dist = fallback_dist
			best_fallback = node

	return best_containing if best_containing != null else best_fallback


func _setup_entity_without_spawn_point(instance: Node, world_position: Vector2, parent: Node) -> void:
	var had_patrol_enabled: bool = instance.get("patrol_enabled") if instance.get("patrol_enabled") != null else false
	instance.set("patrol_enabled", false)
	parent.add_child(instance)
	if instance is Node2D:
		instance.global_position = world_position
	var nearest := _find_spawn_point_for(instance.scene_file_path, world_position)
	if nearest != null and nearest.has_method("configure_patrol_for"):
		nearest.configure_patrol_for(instance, world_position)
	elif instance.has_method("configure_patrol_from_spawn"):
		instance.configure_patrol_from_spawn(null, world_position)
	else:
		instance.set("origin", world_position)
		instance.set("patrol_target", world_position)
	instance.set("patrol_enabled", had_patrol_enabled)
	if had_patrol_enabled and instance.has_method("_enter_patrol_state"):
		instance.call_deferred("_enter_patrol_state")


func prepare_player_placed_building(building: Node) -> void:
	if building == null:
		return
	building.set_meta(PLAYER_PLACED_META, true)
	if building is Chest and String(building.chest_id).is_empty():
		_placed_chest_counter += 1
		building.chest_id = "placed_chest_%d" % _placed_chest_counter


func _load_buildings(buildings_data: Array) -> void:
	_pending_chest_inventories.clear()
	_placed_chest_counter = 0
	for building_data in buildings_data:
		if building_data.has("chest_id"):
			var chest_id := String(building_data["chest_id"])
			if chest_id.begins_with("placed_chest_"):
				var suffix := chest_id.trim_prefix("placed_chest_")
				if suffix.is_valid_int():
					_placed_chest_counter = maxi(_placed_chest_counter, int(suffix))

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	_remove_player_buildings(scene_root)
	await get_tree().process_frame

	var inv_sys := get_node_or_null("/root/InventorySystem")
	for building_data in buildings_data:
		var scene_file: String = building_data.get("scene_file", "")
		if scene_file.is_empty() or not ResourceLoader.exists(scene_file):
			push_warning("[SaveSystem] Building scene không hợp lệ: %s" % scene_file)
			continue

		var packed: PackedScene = load(scene_file)
		if not packed:
			continue

		var instance := packed.instantiate()
		if building_data.has("chest_id") and instance is Chest:
			instance.chest_id = String(building_data["chest_id"])

		prepare_player_placed_building(instance)
		scene_root.add_child(instance)
		if instance is Node2D:
			instance.global_position = Vector2(building_data["pos_x"], building_data["pos_y"])

		if building_data.has("chest_inventory") and building_data.has("chest_id"):
			_pending_chest_inventories[String(building_data["chest_id"])] = building_data["chest_inventory"]
			if inv_sys:
				var chest_inv: InventoryModel = inv_sys.get_inventory(String(building_data["chest_id"]))
				if chest_inv:
					_restore_inventory_model(chest_inv, building_data["chest_inventory"], inv_sys)


func _remove_player_buildings(node: Node) -> void:
	for child in node.get_children().duplicate():
		if child.get_meta(PLAYER_PLACED_META, false):
			child.queue_free()
		else:
			_remove_player_buildings(child)


func _on_inventory_registered_for_chest_restore(inventory: InventoryModel) -> void:
	if _pending_chest_inventories.is_empty():
		return
	if not _pending_chest_inventories.has(inventory.id):
		return
	var inv_sys := get_node_or_null("/root/InventorySystem")
	if not inv_sys:
		return
	_restore_inventory_model(inventory, _pending_chest_inventories[inventory.id], inv_sys)
	_pending_chest_inventories.erase(inventory.id)


func _ready() -> void:
	var inv_sys := get_node_or_null("/root/InventorySystem")
	if inv_sys and not inv_sys.inventory_registered.is_connected(_on_inventory_registered_for_chest_restore):
		inv_sys.inventory_registered.connect(_on_inventory_registered_for_chest_restore)
	load_and_apply_settings()

func _save_tutorial() -> Dictionary:
	return TutorialManager.get_save_data()

func _load_tutorial(data: Dictionary) -> void:
	TutorialManager.load_save_data(data)

func _save_resource_spawners() -> Dictionary:
	var result: Dictionary = {}
	for spawner in get_tree().get_nodes_in_group("ResourceSpawner"):
		if spawner.has_method("save_state"):
			result[str(spawner.get_path())] = spawner.save_state()
	return result

func _load_resource_spawners(spawner_data: Dictionary) -> void:
	for spawner in get_tree().get_nodes_in_group("ResourceSpawner"):
		var path_str = str(spawner.get_path())
		if spawner_data.has(path_str) and spawner.has_method("load_state"):
			spawner.load_state(spawner_data[path_str])

func load_and_apply_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var data: Dictionary = file.get_var()
			file.close()
			
			if data.has("master"):
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(data["master"]))
			if data.has("music"):
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(data["music"]))
			if data.has("sfx"):
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(data["sfx"]))
			
			if data.has("full_screen"):
				if data["full_screen"]:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					
			if data.has("tutorial"):
				TutorialManager.enable_tutorial(data["tutorial"])

func get_settings() -> Dictionary:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var data: Dictionary = file.get_var()
			file.close()
			return data
	return {}

func save_settings(master: float, music: float, sfx: float, full_screen: bool, tutorial: bool) -> void:
	var data := {
		"master": master,
		"music": music,
		"sfx": sfx,
		"full_screen": full_screen,
		"tutorial": tutorial
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
