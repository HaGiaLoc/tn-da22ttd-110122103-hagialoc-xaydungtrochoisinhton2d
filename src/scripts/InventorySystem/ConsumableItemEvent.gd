class_name ConsumableItemEvent
extends ItemEvent

const PlayerScript = preload("res://scripts/Player/player.gd")

@export var require_benefit: bool = true

func can_use(item: Item, user: Node) -> bool:
	if item.vendor_item:
		return false
	if not user is PlayerScript:
		return false

	if not require_benefit:
		return true

	var player := user as PlayerScript
	var base := item.base

	if base.restore_health != 0:
		if base.restore_health > 0 and player.current_hp < player.max_hp:
			return true
		if base.restore_health < 0:
			return true  # Trừ máu luôn cho phép (ví dụ: đồ độc)

	if base.restore_hunger != 0:
		if base.restore_hunger > 0 and player.current_hunger < player.max_hunger:
			return true
		if base.restore_hunger < 0:
			return true  # Trừ hunger luôn cho phép

	return false


func on_use(item: Item, user: Node) -> bool:
	if not user is PlayerScript:
		return false

	var player := user as PlayerScript
	var base := item.base
	var consumed := false

	if base.restore_health != 0:
		var new_hp := clampf(player.current_hp + base.restore_health, 0.0, player.max_hp)
		if new_hp != player.current_hp:
			player.current_hp = new_hp
			player.update_hp_ui()
			player.health_changed.emit(int(player.current_hp), int(player.max_hp))
			consumed = true

	if base.restore_hunger != 0:
		var new_hunger := clampf(player.current_hunger + base.restore_hunger, 0.0, player.max_hunger)
		if new_hunger != player.current_hunger:
			player.current_hunger = new_hunger
			player.hunger_changed.emit(player.current_hunger, player.max_hunger)
			consumed = true

	if not consumed:
		return false

	if player.has_method("play_drink_potion_sfx"):
		player.play_drink_potion_sfx()

	item.remove(1)
	return true
