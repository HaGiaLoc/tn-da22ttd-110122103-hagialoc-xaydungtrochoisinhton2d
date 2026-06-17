class_name ResourceNode
extends StaticBody2D

signal harvested(node: ResourceNode)      ## Phát mỗi lần harvest thành công
signal depleted(node: ResourceNode)       ## Phát khi cạn kiệt hoàn toàn

enum RequiredTool { NONE, AXE, PICKAXE }

@export_group("Resource Settings")
@export var harvest_time: float = 3.0          ## Thời gian thu thập cơ bản (giây)
@export var harvest_count: int = 3             ## Số lần thu thập trước khi cạn kiệt
@export var required_tool: RequiredTool = RequiredTool.NONE
@export var loot_table: LootTable              ## Bảng loot khi thu thập (dùng LootTable resource)
@export var drop_radius: float = 54.0          ## Bán kính drop item xung quanh node (3 tile × 18px)

@export_group("Visual")
@export var depleted_texture: Texture2D        ## Texture khi cạn kiệt (vd: gốc cây)
@export var depleted_sprite_offset: Vector2 = Vector2.ZERO  ## Dịch chuyển sprite khi chuyển sang trạng thái depleted
@export var depleted_harvest_count: int = 0    ## Số lần harvest thêm ở trạng thái depleted (0 = biến mất)
@export var depleted_loot_table: LootTable     ## Loot khi ở trạng thái depleted (gốc cây)

const INTERACT_HINT := "[F]"

var _remaining_harvests: int = 0
var _is_depleted_state: bool = false  ## Đang ở trạng thái depleted (vd: gốc cây)
var _is_harvesting: bool = false
var _harvest_timer: float = 0.0
var _harvest_progress: float = 0.0
var _player_in_range: bool = false
var _player_ref: Player = null
var interaction_priority: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var interact_area: Area2D = $InteractArea
@onready var hint_label: Label = $HintLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var sprite: Sprite2D = $Sprite2D
@onready var _harvest_player: AudioStreamPlayer2D = $HarvestPlayer


func _ready() -> void:
	_remaining_harvests = harvest_count
	_rng.randomize()
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	hint_label.visible = false
	hint_label.text = INTERACT_HINT
	progress_bar.visible = false
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("action_interact") and not event.is_echo():
		if InteractionManager.active_interactable != self:
			return
		if _is_harvesting:
			return  # Đang thu thập rồi, bỏ qua
		if _can_harvest():
			_start_harvest()
			get_viewport().set_input_as_handled()
		elif not _has_required_tool():
			_show_tool_hint()


func _physics_process(delta: float) -> void:
	if not _is_harvesting:
		return

	if not _player_in_range:
		_cancel_harvest()
		return

	if _player_ref and _player_ref.velocity.length() > 5.0:
		_cancel_harvest()
		return

	_harvest_timer -= delta
	_harvest_progress = 1.0 - (_harvest_timer / _get_effective_harvest_time())
	progress_bar.value = _harvest_progress

	if _harvest_timer <= 0.0:
		_finish_harvest()



func _has_required_tool() -> bool:
	if required_tool == RequiredTool.NONE:
		return true

	var player := get_tree().get_first_node_in_group("Player") as Player
	if not player:
		return false

	var equipment := player._get_equipment()
	if not equipment:
		return false

	match required_tool:
		RequiredTool.AXE:
			return equipment.items.has(ItemBase.SlotType.AXE)
		RequiredTool.PICKAXE:
			return equipment.items.has(ItemBase.SlotType.PICKAXE)

	return false


func _can_harvest() -> bool:
	if _remaining_harvests <= 0:
		return false
	return _has_required_tool()


func _show_tool_hint() -> void:
	var tool_name := ""
	match required_tool:
		RequiredTool.AXE:
			tool_name = "rìu"
		RequiredTool.PICKAXE:
			tool_name = "cuốc"
	if not tool_name.is_empty():
		hint_label.text = "Cần %s" % tool_name
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(self):
			hint_label.text = INTERACT_HINT


func _get_effective_harvest_time() -> float:
	var base := harvest_time
	var player := get_tree().get_first_node_in_group("Player") as Player
	if not player:
		return base

	var equipment := player._get_equipment()
	if not equipment:
		return base

	var efficiency := 0.0
	for slot_type in [ItemBase.SlotType.AXE, ItemBase.SlotType.PICKAXE]:
		var item: Item = equipment.items.get(slot_type)
		if item and item.base:
			efficiency = max(efficiency, item.base.mining_efficiency)

	return max(0.5, base - efficiency)  # Tối thiểu 0.5 giây


func _start_harvest() -> void:
	_is_harvesting = true
	_harvest_timer = _get_effective_harvest_time()
	_harvest_progress = 0.0
	hint_label.visible = false
	progress_bar.visible = true
	progress_bar.value = 0.0
	_play_harvest_sfx()


func _cancel_harvest() -> void:
	_is_harvesting = false
	_harvest_timer = 0.0
	_harvest_progress = 0.0
	progress_bar.visible = false
	progress_bar.value = 0.0
	_stop_harvest_sfx()
	hint_label.text = INTERACT_HINT


func _finish_harvest() -> void:
	_is_harvesting = false
	progress_bar.visible = false
	progress_bar.value = 0.0
	_remaining_harvests -= 1
	_stop_harvest_sfx()

	var current_loot := depleted_loot_table if _is_depleted_state else loot_table
	_drop_loot(current_loot)

	emit_signal("harvested", self)

	if _remaining_harvests <= 0:
		_on_depleted()
	else:
		hint_label.text = INTERACT_HINT


func _on_depleted() -> void:
	if not _is_depleted_state and depleted_texture and depleted_harvest_count > 0:
		_is_depleted_state = true
		_remaining_harvests = depleted_harvest_count
		if sprite:
			sprite.texture = depleted_texture
			sprite.position = depleted_sprite_offset
		return

	emit_signal("depleted", self)
	hint_label.visible = false
	queue_free()


func _drop_loot(table: LootTable) -> void:
	if not table:
		return

	var inv_sys := get_node_or_null("/root/InventorySystem")
	if not inv_sys:
		return

	var rolled := table.roll()
	for entry in rolled:
		var item_id: String = entry.get("item_id", "")
		var qty: int = entry.get("quantity", 1)
		if item_id.is_empty():
			continue

		var item_base: ItemBase = inv_sys.get_item_base(item_id)
		if not item_base:
			push_warning("ResourceNode: không tìm thấy ItemBase id='%s'" % item_id)
			continue

		var item := Item.new(item_base, qty)
		var drop_pos := _random_drop_position()
		WorldItem.spawn(item, get_tree().current_scene, drop_pos)


func _random_drop_position() -> Vector2:
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(0.0, drop_radius)
	return global_position + Vector2(cos(angle), sin(angle)) * radius



func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = true
		_player_ref = body as Player
		InteractionManager.register(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = false
		_player_ref = null
		InteractionManager.unregister(self)
		if _is_harvesting:
			_cancel_harvest()

func can_interact() -> bool:
	return _remaining_harvests > 0 and not _is_harvesting

func set_hint_visible(v: bool) -> void:
	if is_instance_valid(hint_label):
		hint_label.visible = v


func _play_harvest_sfx() -> void:
	if not _harvest_player or not _harvest_player.stream:
		return
	_harvest_player.play()


func _stop_harvest_sfx() -> void:
	if _harvest_player and _harvest_player.playing:
		_harvest_player.stop()
