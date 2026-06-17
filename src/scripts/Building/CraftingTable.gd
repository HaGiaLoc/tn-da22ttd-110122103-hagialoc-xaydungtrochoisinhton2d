class_name CraftingTable
extends StaticBody2D

signal interacted

@export var crafting_component: CraftingComponent  ## CraftingComponent chứa recipe
@export var crafting_ui_scene: PackedScene          ## Scene UI chế tạo

const INTERACT_HINT := "[F]"

var _player_in_range: bool = false
var _ui_instance: Control = null
var interaction_priority: int = 1

@onready var interact_area: Area2D = $InteractArea
@onready var hint_label: Label = $HintLabel


var crafting_player: AudioStreamPlayer2D = null

func _ready() -> void:
	crafting_player = get_node_or_null("CraftingPlayer")
	if not crafting_player:
		crafting_player = get_node_or_null("AnvilPlayer")

	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

	hint_label.visible = false
	hint_label.text = INTERACT_HINT


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("action_interact") and not event.is_echo():
		if InteractionManager.active_interactable != self:
			return
		_toggle_ui()
		get_viewport().set_input_as_handled()



func _toggle_ui() -> void:
	if not _ui_instance:
		if not crafting_ui_scene:
			push_warning("CraftingTable: `crafting_ui_scene` chưa được gán.")
			return

		var canvas := CanvasLayer.new()
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(canvas)

		_ui_instance = crafting_ui_scene.instantiate()
		_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		canvas.add_child(_ui_instance)
		_ui_instance.visible = false

	var dismantle_btn = _ui_instance.get_node_or_null("MarginContainer/VBoxContainer/Header/DismantleButton")
	if dismantle_btn:
		if not dismantle_btn.pressed.is_connected(_on_dismantle_pressed):
			dismantle_btn.pressed.connect(_on_dismantle_pressed)
		dismantle_btn.visible = get_meta("player_placed", false)

	var opening := not _ui_instance.visible
	_ui_instance.visible = opening

	if opening:
		if crafting_player and crafting_player.stream:
			crafting_player.play()
		if crafting_component and _ui_instance.has_method("set_crafting_component"):
			_ui_instance.set_crafting_component(crafting_component)
		_set_player_inventory_visible(true)
		emit_signal("interacted")
	else:
		_set_player_inventory_visible(false)


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



func _on_dismantle_pressed() -> void:
	if _ui_instance and _ui_instance.visible:
		_toggle_ui()
		
	var inventory_system = get_node_or_null("/root/InventorySystem")
	if inventory_system:
		var items_to_drop: Array[Item] = []
			
		var recipe = inventory_system.get_building_recipe_by_scene_path(scene_file_path)
		if recipe:
			for res in recipe.ingredients:
				var ing = res as Resource
				if ing and "item_id" in ing and "quantity" in ing:
					var return_qty: int = maxi(1, ing.quantity / 2)
					var base = inventory_system.get_item_base(ing.item_id)
					if base:
						items_to_drop.append(Item.new(base, return_qty))
						
		inventory_system.drop_items_around(items_to_drop, global_position, get_tree().current_scene)
	
	queue_free()

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
	if is_instance_valid(hint_label):
		hint_label.visible = v
