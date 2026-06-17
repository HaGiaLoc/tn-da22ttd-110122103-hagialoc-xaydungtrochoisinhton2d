class_name ResourceSpawner
extends Node2D

@export var resource_scene: PackedScene  ## Scene của ResourceNode cần spawn
@export var respawn_time: float = 60.0   ## Thời gian hồi phục (giây)
@export var building_check_radius: float = 54.0  ## Bán kính kiểm tra building (3 tile × 18px)

const BUILDING_COLLISION_LAYER := 2048

var _current_node: ResourceNode = null
var _respawn_timer: float = 0.0
var _waiting_respawn: bool = false


func _ready() -> void:
	add_to_group("ResourceSpawner")
	var save_system = get_node_or_null("/root/SaveSystem")
	if save_system and save_system.load_on_ready:
		save_system.game_loaded.connect(_spawn, CONNECT_ONE_SHOT)
	else:
		_spawn()


func _process(delta: float) -> void:
	if not _waiting_respawn:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_waiting_respawn = false
		_spawn()


func _spawn() -> void:
	if not resource_scene:
		push_warning("ResourceSpawner: `resource_scene` chưa được gán.")
		return
	if _current_node and is_instance_valid(_current_node):
		return  # Đã có node, không spawn thêm
	if _waiting_respawn:
		return

	if _has_nearby_building():
		_respawn_timer = respawn_time
		_waiting_respawn = true
		return

	_current_node = resource_scene.instantiate() as ResourceNode
	if not _current_node:
		push_warning("ResourceSpawner: scene không phải ResourceNode.")
		return

	add_child(_current_node)
	_current_node.position = Vector2.ZERO
	_current_node.depleted.connect(_on_resource_depleted)


func _has_nearby_building() -> bool:
	var space := get_world_2d().direct_space_state
	if not space:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = building_check_radius
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = BUILDING_COLLISION_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results := space.intersect_shape(query, 1)
	return results.size() > 0


func _on_resource_depleted(_node: ResourceNode) -> void:
	_current_node = null
	_respawn_timer = respawn_time
	_waiting_respawn = true

func save_state() -> Dictionary:
	return {
		"waiting_respawn": _waiting_respawn,
		"respawn_timer": _respawn_timer,
		"has_node": _current_node != null and is_instance_valid(_current_node)
	}

func load_state(data: Dictionary) -> void:
	_waiting_respawn = data.get("waiting_respawn", false)
	_respawn_timer = data.get("respawn_timer", 0.0)
	var saved_has_node = data.get("has_node", true)
	
	if not saved_has_node:
		if _current_node and is_instance_valid(_current_node):
			_current_node.queue_free()
			_current_node = null
