class_name Portal
extends StaticBody2D

@export_group("North Rune")
@export var slot0_item_id: String = "diamond"
@export var slot0_quantity: int = 10

@export_group("South Rune")
@export var slot1_item_id: String = "gold_coin"
@export var slot1_quantity: int = 99

@export_group("East Rune")
@export var slot2_item_id: String = "emerald"
@export var slot2_quantity: int = 10

@export_group("West Rune")
@export var slot3_item_id: String = "wolf_fang"
@export var slot3_quantity: int = 10

@export_group("Scenes")
@export var portal_ui_scene: PackedScene
@export var win_screen_scene: PackedScene

@export_group("Rune Nodes (optional)")
@export var rune_north: Node2D
@export var rune_south: Node2D
@export var rune_east:  Node2D
@export var rune_west:  Node2D

const HINT_REPAIR   := "[F]"
const HINT_ACTIVATE := "[F]"

var _player_in_range: bool = false
var _ready_to_activate: bool = false
var _ui_instance: Control = null
var _rune_tweens: Array[Tween] = []  ## Giữ reference tránh GC
var interaction_priority: int = 1

@onready var _portal_sfx: AudioStreamPlayer2D = $PortalActivatePlayer
@onready var _portal_activated_sprite: Node2D = $PortalActivated


func _ready() -> void:
	add_to_group("Portal")
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	$HintLabel.visible = false
	$HintLabel.text = HINT_REPAIR
	if _portal_activated_sprite:
		_portal_activated_sprite.visible = false
	_dim_all_runes()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("action_interact") and not event.is_echo():
		if InteractionManager.active_interactable != self:
			return
		if _ready_to_activate:
			_trigger_win()
		else:
			_toggle_ui()
		get_viewport().set_input_as_handled()



func _dim_all_runes() -> void:
	for rune in [rune_north, rune_south, rune_east, rune_west]:
		if rune:
			rune.visible = false


func on_slot_filled(slot_index: int) -> void:
	var runes: Array[Node2D] = [rune_north, rune_south, rune_east, rune_west]
	if slot_index >= 0 and slot_index < runes.size():
		var r := runes[slot_index]
		if r:
			r.visible = true
			r.modulate = Color(1, 1, 1, 0)
			var tw := create_tween()
			_rune_tweens.append(tw)
			tw.tween_property(r, "modulate", Color(1, 1, 1, 1.0), 0.5)


func on_all_slots_filled() -> void:
	_ready_to_activate = true
	TutorialManager.notify_portal_activated()

	if _portal_activated_sprite:
		_portal_activated_sprite.visible = true
		if _portal_activated_sprite is AnimatedSprite2D:
			_portal_activated_sprite.play("portal_activated")

	if _ui_instance and _ui_instance.visible:
		_ui_instance.visible = false
		_set_player_inventory_visible(false)

	$HintLabel.text = HINT_ACTIVATE



func _trigger_win() -> void:
	if not win_screen_scene:
		push_warning("Portal: win_screen_scene chưa được gán.")
		return

	if _portal_sfx and _portal_sfx.stream:
		_portal_sfx.play()

	_return_held_item_to_inventory()
	get_tree().paused = true

	var canvas := CanvasLayer.new()
	canvas.name = "WinScreenLayer"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas)

	var win := win_screen_scene.instantiate()
	win.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(win)

	var game := get_tree().current_scene
	if game and game.has_method("get_survival_time") and win.has_method("set_survival_time"):
		win.set_survival_time(game.get_survival_time())


func _return_held_item_to_inventory() -> void:
	var inv_sys := get_node_or_null("/root/InventorySystem")
	if not inv_sys or not inv_sys.is_holding_item():
		return
	var held: Item = inv_sys.get_held_item()
	var player_inv = inv_sys.get_player_inventory()
	if player_inv and held:
		if held.slot_id >= 0 and not player_inv.items.has(held.slot_id):
			player_inv.add_item_at(held, held.slot_id)
		else:
			player_inv.add_item(held)
	inv_sys.drop_held_item()



func _toggle_ui() -> void:
	if not _ui_instance:
		if not portal_ui_scene:
			push_warning("Portal: portal_ui_scene chưa được gán.")
			return

		var canvas := CanvasLayer.new()
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(canvas)

		_ui_instance = portal_ui_scene.instantiate()
		_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		canvas.add_child(_ui_instance)
		_ui_instance.visible = false

		if _ui_instance.has_method("setup"):
			_ui_instance.call("setup", self, _get_slot_configs())

		if _ui_instance.has_signal("closed"):
			_ui_instance.closed.connect(_set_player_inventory_visible.bind(false))

	var opening := not _ui_instance.visible
	_ui_instance.visible = opening

	if opening:
		_set_player_inventory_visible(true)
	else:
		_set_player_inventory_visible(false)


func _get_slot_configs() -> Array:
	return [
		{"item_id": slot0_item_id, "quantity": slot0_quantity,
		 "label": "Cổ Ngữ Bắc", "rune_tex": "res://assets/Used/Portal/North Portal Rune.png"},
		{"item_id": slot1_item_id, "quantity": slot1_quantity,
		 "label": "Cổ Ngữ Nam",  "rune_tex": "res://assets/Used/Portal/South Portal Rune.png"},
		{"item_id": slot2_item_id, "quantity": slot2_quantity,
		 "label": "Cổ Ngữ Đông", "rune_tex": "res://assets/Used/Portal/East Portal Rune.png"},
		{"item_id": slot3_item_id, "quantity": slot3_quantity,
		 "label": "Cổ Ngữ Tây",  "rune_tex": "res://assets/Used/Portal/West Portal Rune.png"},
	]


func _set_player_inventory_visible(opening: bool) -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if not player:
		return
	var inventory_ui = player.get("inventory_ui")
	if not inventory_ui:
		return
	if opening:
		if inventory_ui.has_method("open_for_building"):
			inventory_ui.open_for_building(true)
		else:
			inventory_ui.visible = true
	else:
		if inventory_ui.has_method("close_for_building"):
			inventory_ui.close_for_building()
		inventory_ui.visible = false



func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = true
		InteractionManager.register(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_range = false
		InteractionManager.unregister(self)
		if _ui_instance and _ui_instance.visible:
			_ui_instance.visible = false
			_set_player_inventory_visible(false)

func can_interact() -> bool:
	return _player_in_range

func set_hint_visible(v: bool) -> void:
	if is_instance_valid($HintLabel):
		$HintLabel.visible = v
