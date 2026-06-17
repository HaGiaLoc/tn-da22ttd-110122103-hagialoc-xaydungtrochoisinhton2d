class_name Furnace
extends StaticBody2D

signal interacted

@export var crafting_component: CraftingComponent  ## CraftingComponent chứa recipe của lò
@export var furnace_ui_scene: PackedScene           ## Scene của UI lò (furnace_ui.tscn)

var _ui_instance: Control = null  ## UI được tạo động, riêng cho từng furnace

const ANIM_OFF         := "off"
const ANIM_ON          := "on"
const ANIM_TURNING_ON  := "turning_on"
const ANIM_TURNING_OFF := "turning_off"

const INTERACT_HINT := "[F]"

enum State { OFF, TURNING_ON, ON, TURNING_OFF }
var _state: State = State.OFF
var _player_in_range: bool = false
var interaction_priority: int = 1

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var hint_label: Label = $HintLabel
@onready var fire_player: AudioStreamPlayer2D = $FurnaceFirePlayer
@onready var burning_player: AudioStreamPlayer2D = $FurnaceBurningPlayer


func _ready() -> void:
	_configure_animations()

	anim_sprite.animation_finished.connect(_on_animation_finished)
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

	hint_label.visible = false
	hint_label.text = INTERACT_HINT

	_play_state_animation()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("action_interact") and not event.is_echo():
		if InteractionManager.active_interactable != self:
			return
		_toggle_ui()
		get_viewport().set_input_as_handled()



func turn_on() -> void:
	if _state == State.ON or _state == State.TURNING_ON:
		return
	_set_state(State.TURNING_ON)


func turn_off() -> void:
	if _state == State.OFF or _state == State.TURNING_OFF:
		return
	_set_state(State.TURNING_OFF)


func is_on() -> bool:
	return _state == State.ON


func _set_state(new_state: State) -> void:
	_state = new_state
	_play_state_animation()
	
	if _state == State.ON or _state == State.TURNING_ON:
		if burning_player and burning_player.stream and not burning_player.playing:
			burning_player.play()
	else:
		if burning_player and burning_player.playing:
			burning_player.stop()


func _play_state_animation() -> void:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return

	var anim_name: String
	match _state:
		State.OFF:
			anim_name = ANIM_OFF
		State.TURNING_ON:
			anim_name = ANIM_TURNING_ON
		State.ON:
			anim_name = ANIM_ON
		State.TURNING_OFF:
			anim_name = ANIM_TURNING_OFF

	if anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)
	else:
		push_warning("Furnace: không có animation '%s'" % anim_name)


func _configure_animations() -> void:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return
	for anim in [ANIM_TURNING_ON, ANIM_TURNING_OFF]:
		if anim_sprite.sprite_frames.has_animation(anim):
			anim_sprite.sprite_frames.set_animation_loop(anim, false)
	for anim in [ANIM_OFF, ANIM_ON]:
		if anim_sprite.sprite_frames.has_animation(anim):
			anim_sprite.sprite_frames.set_animation_loop(anim, true)


func _on_animation_finished() -> void:
	match _state:
		State.TURNING_ON:
			_set_state(State.ON)
		State.TURNING_OFF:
			_set_state(State.OFF)



func _toggle_ui() -> void:
	if not _ui_instance:
		if not furnace_ui_scene:
			push_warning("Furnace: `furnace_ui_scene` chưa được gán.")
			return
		var canvas := CanvasLayer.new()
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(canvas)

		_ui_instance = furnace_ui_scene.instantiate()
		_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		canvas.add_child(_ui_instance)
		_ui_instance.visible = false

	var dismantle_btn = _ui_instance.get_node_or_null("MarginContainer/VBoxContainer/Header/DismantleButton")
	if dismantle_btn:
		if not dismantle_btn.pressed.is_connected(_on_dismantle_pressed):
			dismantle_btn.pressed.connect(_on_dismantle_pressed)
		dismantle_btn.visible = get_meta("player_placed", false)

	var opening: bool = not _ui_instance.visible
	_ui_instance.visible = opening
	
	if fire_player and fire_player.stream:
		fire_player.play()

	if opening:
		if crafting_component and _ui_instance.has_method("set_crafting_component"):
			_ui_instance.set_crafting_component(crafting_component)
		turn_on()
		_set_player_inventory_visible(true)
		emit_signal("interacted")
	else:
		turn_off()
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
			turn_off()
			_set_player_inventory_visible(false)
			if fire_player and fire_player.stream:
				fire_player.play()

func can_interact() -> bool:
	return _player_in_range

func set_hint_visible(v: bool) -> void:
	if is_instance_valid(hint_label):
		hint_label.visible = v
