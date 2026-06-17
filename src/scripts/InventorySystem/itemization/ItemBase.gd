@tool
class_name ItemBase
extends Resource

enum ItemType {
	RESOURCE,    ## Nguyên liệu dùng để chế tạo và xây dựng.
	CONSUMABLE,  ## Tiêu thụ để khôi phục máu, đói, khát.
	EQUIPMENT,   ## Trang bị lên người: giáp, vũ khí, công cụ.
}

enum SlotType {
	NONE,
	HEAD,
	CHEST,
	GAUNTLET,
	FEET,
	WEAPON,
	AXE,
	PICKAXE,
	SHIELD,
}

@export_group("Basic Info")
@export var id: String  ## ID định danh duy nhất. Nếu để trống sẽ tự sinh từ name.
@export var name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_group("Properties")
@export var item_type: ItemType:
	set(value):
		item_type = value
		_cached_on_use = null  # Xóa cache khi đổi type
		notify_property_list_changed()
@export var stackable: bool
@export var max_stacks: int = 1
@export var base_value: int = 1

@export_group("Consumable")
@export var restore_health: int = 0:
	set(value):
		restore_health = value
		_cached_on_use = null
@export var restore_hunger: int = 0:
	set(value):
		restore_hunger = value
		_cached_on_use = null
@export var restore_thirst: int = 0:
	set(value):
		restore_thirst = value
		_cached_on_use = null

@export_group("Equipment")
@export var slot_type: SlotType:
	set(value):
		slot_type = value
		notify_property_list_changed()

@export var armor: int
@export var damage: int
@export var attack_speed: float
@export var mining_efficiency: float
@export var block_chance: int

@export_group("Events")
@export var on_equip: ItemEvent
@export var on_unequip: ItemEvent

var _cached_on_use: ItemEvent = null

func get_on_use() -> ItemEvent:
	if item_type != ItemType.CONSUMABLE:
		return null
	if _cached_on_use == null:
		var evt := ConsumableItemEvent.new()
		evt.require_benefit = true
		_cached_on_use = evt
	return _cached_on_use

func is_valid() -> bool:
	return not name.is_empty() and icon != null

func _validate_property(property: Dictionary) -> void:
	if property.name in ["restore_health", "restore_hunger", "restore_thirst"]:
		if item_type != ItemType.CONSUMABLE:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name == "slot_type":
		if item_type != ItemType.EQUIPMENT:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name == "armor":
		if item_type != ItemType.EQUIPMENT or slot_type not in [SlotType.HEAD, SlotType.CHEST, SlotType.GAUNTLET, SlotType.FEET]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name in ["damage", "attack_speed"]:
		if item_type != ItemType.EQUIPMENT or slot_type not in [SlotType.WEAPON, SlotType.AXE, SlotType.PICKAXE]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name == "mining_efficiency":
		if item_type != ItemType.EQUIPMENT or slot_type not in [SlotType.AXE, SlotType.PICKAXE]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name == "block_chance":
		if item_type != ItemType.EQUIPMENT or slot_type != SlotType.SHIELD:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name == "on_use":
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name in ["on_equip", "on_unequip"]:
		if item_type != ItemType.EQUIPMENT:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		return
