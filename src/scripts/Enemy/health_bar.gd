extends ProgressBar

var enemy: Node = null

var _health_changed_callable: Callable
var _last_health_value: int = -1
var _health_decrement_count: int = 0

func _ready() -> void:
	min_value = 0
	show_percentage = false
	_health_changed_callable = Callable(self, "_on_enemy_health_changed")


func bind_enemy(enemy_node: Node) -> void:
	enemy = enemy_node
	if enemy and enemy.has_signal("health_changed"):
		if not enemy.health_changed.is_connected(_health_changed_callable):
			enemy.health_changed.connect(_health_changed_callable)

	if enemy and enemy.has_method("get"):
		var max_health_value = int(enemy.get("max_health"))
		max_value = max_health_value
		var current_health_value = int(enemy.get("health"))
		value = clamp(current_health_value, 0, max_health_value)
		_last_health_value = int(value)
		_health_decrement_count = 0
		print("DEBUG: HealthBar bound -> health=", _last_health_value, "/", max_health_value)


func _on_enemy_health_changed(current_health: int, max_health: int) -> void:
	var previous_health := _last_health_value
	max_value = max_health
	value = clamp(current_health, 0, max_health)

	if previous_health >= 0 and current_health < previous_health:
		_health_decrement_count += 1
		print(
			"DEBUG: HealthBar decrement #",
			_health_decrement_count,
			" -> ",
			previous_health,
			" to ",
			current_health,
			" (delta=",
			previous_health - current_health,
			")"
		)
	elif previous_health >= 0 and current_health > previous_health:
		print("DEBUG: HealthBar heal/update -> ", previous_health, " to ", current_health)
	else:
		print("DEBUG: HealthBar unchanged -> ", current_health, "/", max_health)

	_last_health_value = current_health
