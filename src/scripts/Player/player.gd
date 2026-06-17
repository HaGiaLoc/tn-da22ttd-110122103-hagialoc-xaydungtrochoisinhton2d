class_name Player
extends CharacterBody2D

signal health_changed(health: int, max_health: int)
signal hunger_changed(hunger: float, max_hunger: float)

@export_category("Node References")
@export var damage_area_path: NodePath
@export var anim_sprite_path: NodePath
@export var health_bar_path: NodePath
@export var hurt_box_path: NodePath
@export var inventory_ui_path: NodePath
@export var hunger_bar_path: NodePath

@export_category("Player Stats")
@export var walk_speed: float = 150.0
@export var run_speed: float = 250.0
@export var max_hp: float = 100.0
@export var base_damage: float = 5.0  ## Sát thương gốc khi không có vũ khí.

@export_category("Hunger")
@export var max_hunger: float = 100.0                   ## Hunger tối đa.
@export var hunger_drain_interval: float = 5.0          ## Mỗi bao nhiêu giây trừ hunger một lần (đi bộ/đứng).
@export var hunger_drain_amount: float = 1.0            ## Lượng hunger bị trừ mỗi interval (đi bộ/đứng).
@export var run_hunger_drain_interval: float = 2.0      ## Mỗi bao nhiêu giây trừ hunger một lần khi chạy.
@export var run_hunger_drain_amount: float = 2.0        ## Lượng hunger bị trừ mỗi interval khi chạy.
@export var starvation_interval: float = 3.0            ## Mỗi bao nhiêu giây trừ máu một lần khi hunger = 0.
@export var starvation_damage: float = 5.0              ## Lượng máu bị trừ mỗi lần đói.

var damage_area: Area2D = null
var anim_sprite: AnimatedSprite2D = null
var health_bar: Node = null
var current_hp: float = 0.0
var hurt_box: Area2D = null
var inventory_ui: Control = null

var current_hunger: float = 0.0
var _hunger_timer: float = 0.0       ## Đếm ngược đến lần trừ hunger tiếp theo
var _starvation_timer: float = 0.0  ## Đếm ngược đến lần trừ máu tiếp theo khi đói

var current_direction: String = "down"
var is_attacking: bool = false
var _is_dead: bool = false
var attack_combo: int = 1 
var combo_buffered: bool = false 
@export var combo_window: float = 0.5
var combo_timer: float = 0.0

@export_category("Footstep Audio")
@export var footstep_interval: float = 0.5
@export var run_footstep_interval: float = 0.35

var _footstep_timer: float = 0.0

@onready var _sword_swing_player: AudioStreamPlayer2D = $SwordSwingPlayer
@onready var _footstep_player: AudioStreamPlayer2D = $FootstepPlayer
@onready var _running_player: AudioStreamPlayer2D = $RunningPlayer
@onready var _death_player: AudioStreamPlayer2D = $DeathPlayer
@onready var _shield_block_player: AudioStreamPlayer2D = $ShieldBlockPlayer
@onready var _drink_potion_player: AudioStreamPlayer2D = $DrinkPotionPlayer
@onready var _item_pickup_player: AudioStreamPlayer2D = $ItemPickupPlayer
@onready var _hurt_sound_player: AudioStreamPlayer2D = $HurtSoundPlayer

func play_item_pickup_sound() -> void:
	if _item_pickup_player and _item_pickup_player.stream:
		_item_pickup_player.play()

@export_category("Debug")
@export var show_hit_box: bool = false:
	set(value):
		show_hit_box = value
		_apply_show_hit_box()
@export var show_hurt_box: bool = false:
	set(value):
		show_hurt_box = value
		_apply_show_hurt_box()

func _apply_show_hit_box() -> void:
	if damage_area and damage_area.has_method("set_debug_visible"):
		damage_area.set_debug_visible(show_hit_box)

func _apply_show_hurt_box() -> void:
	if hurt_box and hurt_box.has_method("set_debug_visible"):
		hurt_box.set_debug_visible(show_hurt_box)

func _ready() -> void:
	if damage_area_path != null and not damage_area_path.is_empty():
		damage_area = get_node_or_null(damage_area_path)
	if anim_sprite_path != null and not anim_sprite_path.is_empty():
		anim_sprite = get_node_or_null(anim_sprite_path)
	if health_bar_path != null and not health_bar_path.is_empty():
		health_bar = get_node_or_null(health_bar_path)
	if inventory_ui_path != null and not inventory_ui_path.is_empty():
		inventory_ui = get_node_or_null(inventory_ui_path)

	if hurt_box_path != null and not hurt_box_path.is_empty():
		hurt_box = get_node_or_null(hurt_box_path)
	elif has_node("HurtBox"):
		hurt_box = $HurtBox

	if not inventory_ui and has_node("Inventory"):
		inventory_ui = $Inventory

	if inventory_ui:
		inventory_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	process_mode = Node.PROCESS_MODE_ALWAYS

	if hurt_box and hurt_box.has_method("init_from_player"):
		hurt_box.init_from_player(self)
	_apply_show_hit_box()
	_apply_show_hurt_box()
	if health_bar and health_bar.has_method("init_from_owner"): health_bar.init_from_owner(max_hp)
	current_hp = max_hp
	update_hp_ui()
	health_changed.emit(int(current_hp), int(max_hp))
	current_hunger = max_hunger
	_hunger_timer = hunger_drain_interval
	_starvation_timer = starvation_interval
	var hunger_bar: Node = null
	if hunger_bar_path != null and not hunger_bar_path.is_empty():
		hunger_bar = get_node_or_null(hunger_bar_path)
	if hunger_bar and hunger_bar.has_method("init_from_player"):
		hunger_bar.init_from_player(max_hunger)
	if not hunger_changed.is_connected(_on_hunger_changed):
		hunger_changed.connect(_on_hunger_changed)
	hunger_changed.emit(current_hunger, max_hunger)
	if anim_sprite and not anim_sprite.animation_finished.is_connected(_on_animation_finished): anim_sprite.animation_finished.connect(_on_animation_finished)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_hunger(delta)
	_update_footstep_sfx(delta)


func _update_hunger(delta: float) -> void:
	if current_hp <= 0:
		return

	var is_running := Input.is_action_pressed("action_run") and velocity.length() > 0.0
	var interval := run_hunger_drain_interval if is_running else hunger_drain_interval
	var amount   := run_hunger_drain_amount   if is_running else hunger_drain_amount

	_hunger_timer -= delta
	if _hunger_timer <= 0.0:
		_hunger_timer = interval
		if current_hunger > 0.0:
			current_hunger = maxf(0.0, current_hunger - amount)
			hunger_changed.emit(current_hunger, max_hunger)

	if current_hunger <= 0.0:
		_starvation_timer -= delta
		if _starvation_timer <= 0.0:
			_starvation_timer = starvation_interval
			_apply_starvation_damage()
	else:
		_starvation_timer = starvation_interval


func _apply_starvation_damage() -> void:
	if current_hp <= 0:
		return
	current_hp = maxf(0.0, current_hp - starvation_damage)
	update_hp_ui()
	health_changed.emit(int(current_hp), int(max_hp))
	if current_hp <= 0:
		die()


func restore_hunger(amount: float) -> void:
	current_hunger = minf(max_hunger, current_hunger + amount)
	hunger_changed.emit(current_hunger, max_hunger)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("action_open_inventory"):
		var placer := get_tree().root.get_node_or_null("BuildingPlacer")
		if placer and placer.has_method("is_active") and placer.is_active():
			pass
		else:
			toggle_inventory_ui()

	if get_tree().paused:
		return

	if inventory_ui and inventory_ui.visible:
		velocity = Vector2.ZERO
		move_and_slide()
		update_animations()
		return

	if not is_attacking and attack_combo > 1:
		combo_timer -= delta
		if combo_timer <= 0: attack_combo = 1

	if Input.is_action_just_pressed("action_attack"):
		var placer := get_tree().root.get_node_or_null("BuildingPlacer")
		if placer and placer.has_method("is_active") and placer.is_active():
			pass
		elif not is_attacking:
			start_attack()
		else:
			combo_buffered = true

	if is_attacking:
		velocity = Vector2.ZERO 
		move_and_slide()
		return 

	var current_speed = get_move_speed()
	
	var input_dir = get_input_direction()

	if input_dir != Vector2.ZERO:
		velocity = input_dir * current_speed
		update_facing_direction(input_dir)
		TutorialManager.notify_movement(input_dir)
	else:
		velocity = Vector2.ZERO 

	move_and_slide()
	update_animations()

func get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func get_move_speed() -> float:
	return run_speed if Input.is_action_pressed("action_run") else walk_speed

func update_facing_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		current_direction = "right" if direction.x > 0 else "left"
	else:
		current_direction = "down" if direction.y > 0 else "up"

func update_animations() -> void:
	var is_moving := velocity.length() > 0.0 
	var state := "move" if is_moving else "idle"
	var anim_name = state + "_" + current_direction
	if anim_sprite and anim_sprite.animation != anim_name: anim_sprite.play(anim_name)

func start_attack() -> void:
	is_attacking = true
	combo_buffered = false
	_footstep_timer = 0.0
	
	TutorialManager.notify_attacked()

	if _sword_swing_player and _sword_swing_player.stream:
		_sword_swing_player.play()

	var anim_name = "attack_" + str(attack_combo) + "_" + current_direction

	if damage_area and damage_area.has_method("set_direction"):
		damage_area.set_direction(current_direction)
	if damage_area and damage_area.has_method("set_active"):
		damage_area.set_active(false)

	if anim_sprite:
		if not anim_sprite.frame_changed.is_connected(_on_attack_frame_changed):
			anim_sprite.frame_changed.connect(_on_attack_frame_changed)
		anim_sprite.play(anim_name)

	attack_combo = 2 if attack_combo == 1 else 1


func _on_attack_frame_changed() -> void:
	if not anim_sprite or not anim_sprite.animation.begins_with("attack_"):
		return
	var active := anim_sprite.frame == 1
	if damage_area and damage_area.has_method("set_active"):
		damage_area.set_active(active)

func _on_animation_finished() -> void:
	if anim_sprite and anim_sprite.animation.begins_with("attack_"):
		if _sword_swing_player and _sword_swing_player.playing:
			_sword_swing_player.stop()
		if anim_sprite.frame_changed.is_connected(_on_attack_frame_changed):
			anim_sprite.frame_changed.disconnect(_on_attack_frame_changed)

		if combo_buffered or Input.is_action_pressed("action_attack"):
			start_attack()
		else:
			is_attacking = false
			combo_timer = combo_window
			if damage_area and damage_area.has_method("set_active"):
				damage_area.set_active(false)

func take_damage(amount: float) -> void:
	if current_hp <= 0:
		return

	var final_damage := amount

	var equipment := _get_equipment()
	if equipment:
		var total_armor := equipment.get_total_armor()
		if total_armor > 0:
			var reduction := total_armor / (total_armor + 100.0)
			final_damage *= (1.0 - reduction)

	var blocked := false
	if equipment:
		var shield: Item = equipment.items.get(ItemBase.SlotType.SHIELD)
		if shield and shield.base.block_chance > 0:
			var roll := randi_range(0, 99)
			if roll < shield.base.block_chance:
				print("[Player] Đỡ đòn thành công! (block_chance=%d%%)" % shield.base.block_chance)
				final_damage = 0.0
				blocked = true

	if final_damage <= 0.0:
		if blocked and _shield_block_player and _shield_block_player.stream:
			_shield_block_player.play()
		return

	print("player bị tấn công")
	if _hurt_sound_player and _hurt_sound_player.stream:
		_hurt_sound_player.play()

	current_hp -= final_damage
	current_hp = clamp(current_hp, 0.0, max_hp)
	update_hp_ui()
	health_changed.emit(int(current_hp), int(max_hp))

	if current_hp <= 0:
		die()

func update_hp_ui() -> void:
	if health_bar:
		if health_bar.has_method("set_hp_fraction"):
			health_bar.set_hp_fraction(current_hp, max_hp)
		else:
			health_bar.max_value = max_hp
			health_bar.value = current_hp


func _on_hunger_changed(hunger: float, max_h: float) -> void:
	var hunger_bar: Node = null
	if hunger_bar_path != null and not hunger_bar_path.is_empty():
		hunger_bar = get_node_or_null(hunger_bar_path)
	if hunger_bar:
		if hunger_bar.has_method("set_hunger"):
			hunger_bar.set_hunger(hunger, max_h)
		else:
			hunger_bar.value = clamp(hunger, 0.0, max_h)

func _get_equipment() -> EquipmentModel:
	var nodes := get_tree().get_nodes_in_group("PlayerEquipment")
	if nodes.is_empty():
		return null
	return nodes[0] as EquipmentModel


func get_attack_damage() -> float:
	var equipment := _get_equipment()
	var weapon_damage := 0.0
	if equipment:
		for slot_type in [ItemBase.SlotType.WEAPON, ItemBase.SlotType.AXE, ItemBase.SlotType.PICKAXE]:
			var weapon: Item = equipment.items.get(slot_type)
			if weapon:
				weapon_damage = float(weapon.base.damage)
				break
	return base_damage + weapon_damage


func has_weapon() -> bool:
	var equipment := _get_equipment()
	if not equipment:
		return false
	for slot_type in [ItemBase.SlotType.WEAPON, ItemBase.SlotType.AXE, ItemBase.SlotType.PICKAXE]:
		if equipment.items.get(slot_type) != null:
			return true
	return false


func toggle_inventory_ui() -> void:
	if not inventory_ui:
		return

	if not inventory_ui.visible and get_tree().paused:
		return

	var opening := not inventory_ui.visible
	inventory_ui.visible = opening
	if opening and TutorialManager: TutorialManager.notify_inventory_opened()
	if inventory_ui.has_method("play_open_inventory_sound"):
		inventory_ui.play_open_inventory_sound()

	if not inventory_ui.visible:
		if inventory_ui.has_method("close_all_submenus"):
			inventory_ui.close_all_submenus()

	if not inventory_ui.visible:
		var inventory_system := get_node_or_null("/root/InventorySystem")
		if inventory_system and inventory_system.is_holding_item():
			var held: Item = inventory_system.get_held_item()
			var player_inv = inventory_system.get_player_inventory()
			if player_inv and held:
				if held.slot_id >= 0 and not player_inv.items.has(held.slot_id):
					player_inv.add_item_at(held, held.slot_id)
				else:
					player_inv.add_item(held)
			inventory_system.drop_held_item()


func play_drink_potion_sfx() -> void:
	if _drink_potion_player and _drink_potion_player.stream:
		_drink_potion_player.play()


func _update_footstep_sfx(delta: float) -> void:
	if _is_dead or is_attacking or current_hp <= 0:
		_footstep_timer = 0.0
		_stop_footstep_sfx()
		return
	if inventory_ui and inventory_ui.visible:
		_footstep_timer = 0.0
		_stop_footstep_sfx()
		return
	if velocity.length() <= 4.0:
		_footstep_timer = 0.0
		_stop_footstep_sfx()
		return

	var is_running := Input.is_action_pressed("action_run")
	var interval := run_footstep_interval if is_running else footstep_interval
	var player := _running_player if is_running else _footstep_player

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = interval
		if player and player.stream:
			player.play()

func _stop_footstep_sfx() -> void:
	if _footstep_player and _footstep_player.playing:
		_footstep_player.stop()
	if _running_player and _running_player.playing:
		_running_player.stop()


func die() -> void:
	if _is_dead:
		return  # Guard tránh gọi 2 lần
	_is_dead = true
	_footstep_timer = 0.0

	if _death_player and _death_player.stream:
		_death_player.play()

	print("Player died")

	set_physics_process(false)
	set_process(false)

	if hurt_box and hurt_box.has_method("set_invulnerable"):
		hurt_box.set_invulnerable(true)

	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

	if inventory_ui and inventory_ui.visible:
		inventory_ui.visible = false

	if anim_sprite:
		anim_sprite.play("idle_" + current_direction)
		var tween := create_tween()
		tween.tween_property(anim_sprite, "modulate", Color(0.8, 0.0, 0.0, 1.0), 0.25)
		tween.tween_property(anim_sprite, "modulate", Color(0.8, 0.0, 0.0, 0.0), 0.6)
		await tween.finished
	else:
		await get_tree().create_timer(0.5).timeout

	visible = false

	var game := get_tree().current_scene
	if game and game.has_method("show_death_screen"):
		game.show_death_screen()
