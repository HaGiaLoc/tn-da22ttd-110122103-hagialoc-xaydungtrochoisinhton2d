class_name WorldItem
extends Area2D

signal picked_up(item: Item)

@export var item_id: String = ""
@export var item_quantity: int = 1
@export var display_size: float = 32.0

@onready var sprite: Sprite2D = $Sprite2D

var _item: Item = null
var _bob_time: float = 0.0
const BOB_SPEED: float = 2.0
const BOB_AMOUNT: float = 3.0


func _ready() -> void:
	if _item == null and not item_id.is_empty():
		var inventory_system := get_node_or_null("/root/InventorySystem")
		if inventory_system:
			var base: ItemBase = inventory_system.get_item_base(item_id)
			if base:
				_item = Item.new(base, item_quantity)
			else:
				push_warning("WorldItem: không tìm thấy ItemBase id='%s'" % item_id)
		else:
			push_warning("WorldItem: InventorySystem không tồn tại.")

	_refresh_visuals()


func _process(delta: float) -> void:
	_bob_time += delta * BOB_SPEED
	sprite.position.y = sin(_bob_time) * BOB_AMOUNT


static func spawn(item: Item, parent: Node, world_position: Vector2) -> WorldItem:
	var scene := load("res://scenes/InventorySystem/world_item.tscn") as PackedScene
	if not scene:
		push_error("WorldItem: không tìm thấy world_item.tscn")
		return null

	var wi := scene.instantiate() as WorldItem
	wi._item = item
	wi.position = world_position  # set trước khi add để global_position đúng ngay khi _ready chạy
	parent.call_deferred("add_child", wi)
	return wi


func set_item(item: Item) -> void:
	_item = item
	if is_inside_tree():
		_refresh_visuals()


func get_item() -> Item:
	return _item


func _refresh_visuals() -> void:
	if not _item or not _item.base or not _item.base.icon:
		return
	sprite.texture = _item.base.icon

	var tex_size: Vector2 = _item.base.icon.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		var longest_side: float = maxf(tex_size.x, tex_size.y)
		var uniform_scale: float = display_size / longest_side
		sprite.scale = Vector2(uniform_scale, uniform_scale)

func emit_picked_up() -> void:
	picked_up.emit(_item)
