extends Area2D

signal hit(target, damage)

@export var owner_path: NodePath
@export var iframe_duration: float = 0.6
@export var flash_enabled: bool = true
var debug_show_shape: bool = false
@export var debug_color: Color = Color(1.0, 0.2, 0.2, 0.25)

var owner_entity: Node = null
var is_invulnerable: bool = false
@onready var collision_shape: CollisionShape2D = null
var sprite_node: AnimatedSprite2D = null
var flash_token: int = 0
var debug_shape: Polygon2D = null

func init_from_player(p: Node) -> void:
	owner_entity = p
	_setup_owner_nodes()

func _ready() -> void:
	if owner_path != null and owner_path != NodePath("") and has_node(owner_path):
		owner_entity = get_node(owner_path)
	elif owner_entity == null and get_parent():
		owner_entity = get_parent()

	if has_node("CollisionShape2D"):
		collision_shape = $CollisionShape2D

	_setup_owner_nodes()
	_setup_debug_shape()

	if has_signal("body_entered"):
		connect("body_entered", Callable(self, "_on_body_entered"))
	if has_signal("area_entered"):
		connect("area_entered", Callable(self, "_on_area_entered"))

	set_invulnerable(false)

func _setup_owner_nodes() -> void:
	if owner_entity == null:
		return

	sprite_node = _find_flash_node(owner_entity)

func _find_flash_node(node: Node) -> AnimatedSprite2D:
	if node == null:
		return null

	var direct_sprite := node.get_node_or_null("AnimatedSprite2D")
	if direct_sprite is AnimatedSprite2D:
		return direct_sprite

	for child in node.get_children():
		if child is AnimatedSprite2D:
			return child
		var nested_sprite := _find_flash_node(child)
		if nested_sprite != null:
			return nested_sprite

	return null

func _is_attack_source(node: Node) -> bool:
	if node == null:
		return false

	return node.has_method("set_active") or node.has_method("set_enabled") or node.has_method("update_damage_area_by_frame") or node.has_method("set_direction")

func set_invulnerable(enabled: bool) -> void:
	is_invulnerable = enabled
	if collision_shape:
		collision_shape.set_deferred("disabled", enabled)
	set_deferred("monitoring", not enabled)
	set_deferred("monitorable", not enabled)
	_update_debug_shape(enabled)

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

func take_damage(amount: float) -> void:
	if owner_entity == null or is_invulnerable:
		return

	if owner_entity.has_method("take_damage"):
		owner_entity.take_damage(amount)

	_start_iframe()

func _start_iframe() -> void:
	set_invulnerable(true)

	flash_token += 1
	var current_flash_token := flash_token
	var original_color := Color.WHITE
	if sprite_node:
		original_color = sprite_node.self_modulate
	var elapsed_time: float = 0.0
	var flash_interval: float = 0.08
	if flash_enabled and sprite_node:
		while elapsed_time < iframe_duration and current_flash_token == flash_token:
			sprite_node.self_modulate = Color(1.0, 0.25, 0.25, original_color.a)
			var on_time := minf(flash_interval, iframe_duration - elapsed_time)
			await get_tree().create_timer(on_time).timeout
			elapsed_time += on_time
			if elapsed_time >= iframe_duration or current_flash_token != flash_token:
				break
			sprite_node.self_modulate = original_color
			var off_time := minf(flash_interval, iframe_duration - elapsed_time)
			await get_tree().create_timer(off_time).timeout
			elapsed_time += off_time
		sprite_node.self_modulate = original_color
	else:
		await get_tree().create_timer(iframe_duration).timeout

	set_invulnerable(false)

	if sprite_node:
		sprite_node.self_modulate = original_color

func set_iframe_duration(val: float) -> void:
	iframe_duration = val

func _resolve_source(node: Node) -> Node:
	if node == null:
		return null

	if _is_attack_source(node):
		return node

	return null

func receive_attack(attacker: Node, damage: float) -> void:
	if owner_entity == null or is_invulnerable:
		return

	if damage <= 0.0:
		return

	print("hurt box bị tấn công")
	emit_signal("hit", attacker, damage)
	if owner_entity and owner_entity.has_method("take_damage"):
		owner_entity.take_damage(damage)

	_start_iframe()

func _get_attack_damage_from_source(source: Node) -> float:
	if source == null:
		return 0.0

	if source.has_method("get_attack_damage"):
		return float(source.get_attack_damage())
	if source.has_method("get_damage"):
		return float(source.get_damage())

	var owner_node := source.get_owner()
	if owner_node and owner_node.has_method("get_attack_damage"):
		return float(owner_node.get_attack_damage())
	if owner_node and owner_node.has_method("get_damage"):
		return float(owner_node.get_damage())

	if source.get_parent() and source.get_parent().has_method("get_attack_damage"):
		return float(source.get_parent().get_attack_damage())
	if source.get_parent() and source.get_parent().has_method("get_damage"):
		return float(source.get_parent().get_damage())

	return 0.0

func _apply_hit(source: Node) -> void:
	if owner_entity == null or is_invulnerable:
		return

	var damage := _get_attack_damage_from_source(source)

	if damage <= 0.0:
		return

	receive_attack(source, damage)

func _on_body_entered(body: Node) -> void:
	if is_invulnerable:
		return
	if owner_entity != null and body == owner_entity:
		return
	_apply_hit(_resolve_source(body))

func _on_area_entered(area: Area2D) -> void:
	if is_invulnerable:
		return
	if owner_entity != null and area == owner_entity:
		return
	_apply_hit(_resolve_source(area))
