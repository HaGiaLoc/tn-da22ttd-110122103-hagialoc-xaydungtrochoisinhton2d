extends Node2D

@export_category("Spawn")
@export var entity_scene: PackedScene        ## Scene sẽ được spawn ra từ điểm này.
@export_range(1, 999, 1) var max_spawn_count: int = 3       ## Số lượng entity tối đa sống cùng lúc.
@export_range(0.1, 999.0, 0.1) var spawn_interval: float = 30.0  ## Thời gian giữa các lần spawn (giây).
@export var spawn_on_ready: bool = true     ## Spawn đủ max_spawn_count ngay khi vào scene.

@onready var spawn_timer: Timer   = $"Spawn Timer"
@onready var spawn_area: Marker2D = $"Spawn Area"
@onready var patrol_area: Area2D  = $PatrolArea

var spawned_enemies: Array[Node] = []


func _ready() -> void:
	_setup_timer()
	if spawn_on_ready:
		_spawn_all_missing()
	if spawn_timer:
		spawn_timer.start()


func _setup_timer() -> void:
	if spawn_timer == null:
		return
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func _on_spawn_timer_timeout() -> void:
	_spawn_all_missing()


func _spawn_all_missing() -> void:
	_cleanup_spawned_enemies()
	if entity_scene == null:
		return
	var missing := max_spawn_count - spawned_enemies.size()
	for _i in range(missing):
		_do_spawn()


func _do_spawn() -> void:
	var instance := entity_scene.instantiate()
	if instance == null:
		return

	var spawn_pos := spawn_area.global_position if spawn_area != null else global_position
	setup_entity(instance, spawn_pos)


func setup_entity(instance: Node, world_position: Vector2, parent_node: Node = null) -> void:
	if instance == null:
		return

	var had_patrol_enabled: bool = instance.get("patrol_enabled") if instance.get("patrol_enabled") != null else false
	instance.set("patrol_enabled", false)

	var parent := parent_node if parent_node != null else self
	parent.add_child(instance)
	_finish_entity_setup(instance, world_position, had_patrol_enabled)


func _finish_entity_setup(instance: Node, world_position: Vector2, had_patrol_enabled: bool) -> void:
	if instance is Node2D:
		instance.global_position = world_position

	var scene_root := get_tree().current_scene
	if scene_root and instance is Node:
		instance.set_meta("spawn_point_path", str(scene_root.get_path_to(self)))

	if patrol_area != null:
		if instance.has_method("configure_patrol_from_spawn"):
			instance.configure_patrol_from_spawn(patrol_area, world_position)
		else:
			instance.set("patrol_area", patrol_area)
			instance.set("origin", world_position)
			instance.set("patrol_target", world_position)
	else:
		instance.set("origin", world_position)
		instance.set("patrol_target", world_position)

	instance.set("patrol_enabled", had_patrol_enabled)
	if had_patrol_enabled and instance.has_method("_enter_patrol_state"):
		instance.call_deferred("_enter_patrol_state")

	if not spawned_enemies.has(instance):
		spawned_enemies.append(instance)
		if instance.has_signal("tree_exited"):
			instance.tree_exited.connect(_on_spawned_enemy_tree_exited.bind(instance))


func configure_patrol_for(instance: Node, world_position: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root and instance is Node:
		instance.set_meta("spawn_point_path", str(scene_root.get_path_to(self)))

	if patrol_area != null and instance.has_method("configure_patrol_from_spawn"):
		instance.configure_patrol_from_spawn(patrol_area, world_position)
	else:
		instance.set("origin", world_position)
		instance.set("patrol_target", world_position)

	if not spawned_enemies.has(instance):
		spawned_enemies.append(instance)
		if instance.has_signal("tree_exited"):
			instance.tree_exited.connect(_on_spawned_enemy_tree_exited.bind(instance))


func _on_spawned_enemy_tree_exited(instance: Node) -> void:
	spawned_enemies.erase(instance)


func _cleanup_spawned_enemies() -> void:
	for i in range(spawned_enemies.size() - 1, -1, -1):
		if not is_instance_valid(spawned_enemies[i]):
			spawned_enemies.remove_at(i)


