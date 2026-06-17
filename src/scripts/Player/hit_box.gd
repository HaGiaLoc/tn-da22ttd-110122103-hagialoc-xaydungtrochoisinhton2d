extends Area2D

signal hit(target, damage)

@export var damage: float = 15.0
var debug_show_shape: bool = false
@export var debug_color: Color = Color(0.2, 1.0, 0.2, 0.25)

var owner_entity: Node = null
@onready var collision_shape: CollisionShape2D = null
var debug_shape: Polygon2D = null
var base_position: Vector2 = Vector2.ZERO
var _hit_target_ids: Dictionary = {}

var direction_offsets := {
	"right": Vector2(9, 0),
	"left": Vector2(-9, 0),
	"down": Vector2(0, 18),
	"up": Vector2(0, -18),
}

func init_from_player(p: Node) -> void:
	owner_entity = p

func _ready() -> void:
	if owner_entity == null and get_parent() and get_parent().has_method("start_attack"):
		owner_entity = get_parent()

	if has_node("CollisionShape2D"):
		collision_shape = $CollisionShape2D

	base_position = position
	_setup_debug_shape()

	if has_signal("body_entered"):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if has_signal("area_entered"):
		connect("area_entered", Callable(self, "_on_area_entered"))

	set_active(false)

func set_direction(_dir: String) -> void:
	var offset: Vector2 = direction_offsets.get(_dir, Vector2.ZERO)
	position = base_position + offset

func update_hitbox_by_frame(_frame_index: int) -> void:
	set_active(true)

func update_damage_area_by_frame(frame_index: int) -> void:
	update_hitbox_by_frame(frame_index)

func set_active(enabled: bool) -> void:
	if enabled:
		_hit_target_ids.clear()
	else:
		_hit_target_ids.clear()
	if collision_shape:
		collision_shape.set_deferred("disabled", not enabled)
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)
	_update_debug_shape(enabled)
	if not enabled:
		position = base_position

func _setup_debug_shape() -> void:
	if not debug_show_shape or collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return

	debug_shape = Polygon2D.new()
	debug_shape.name = "DebugShape"
	debug_shape.color = debug_color
	debug_shape.z_index = 1000
	debug_shape.z_as_relative = false

	var rectangle := collision_shape.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5
	debug_shape.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	collision_shape.add_child(debug_shape)

func _update_debug_shape(enabled: bool) -> void:
	if debug_shape == null:
		return

	debug_shape.color.a = 0.35 if enabled else 0.15
	debug_shape.visible = debug_show_shape


func set_debug_visible(enabled: bool) -> void:
	debug_show_shape = enabled
	_setup_debug_shape()
	if debug_shape:
		debug_shape.visible = enabled

func get_attack_damage() -> float:
	if owner_entity != null and owner_entity.has_method("get_attack_damage"):
		return float(owner_entity.get_attack_damage())

	return float(damage)

func _resolve_target(node: Node) -> Node:
	if node == null:
		return null

	var hurt_box := node.get_node_or_null("HurtBox")
	if hurt_box and hurt_box.has_method("receive_attack"):
		return hurt_box

	var owner_node := node.get_owner()
	if owner_node:
		var owner_hurt_box := owner_node.get_node_or_null("HurtBox")
		if owner_hurt_box and owner_hurt_box.has_method("receive_attack"):
			return owner_hurt_box

	return null

func _apply_damage(target: Node) -> void:
	if target == null:
		return

	var target_id := target.get_instance_id()
	if _hit_target_ids.has(target_id):
		return
	_hit_target_ids[target_id] = true

	var final_damage := damage
	if owner_entity != null and owner_entity.has_method("get_attack_damage"):
		final_damage = float(owner_entity.get_attack_damage())

	emit_signal("hit", target, final_damage)
	if target.has_method("receive_attack"):
		target.receive_attack(owner_entity if owner_entity != null else self, final_damage)
		return
	if target.has_method("take_damage"):
		target.take_damage(final_damage)

func _on_body_entered(body: Node) -> void:
	if owner_entity != null and body == owner_entity:
		return
	_apply_damage(_resolve_target(body))

func _on_area_entered(area: Area2D) -> void:
	if owner_entity != null and area == owner_entity:
		return
	_apply_damage(_resolve_target(area))