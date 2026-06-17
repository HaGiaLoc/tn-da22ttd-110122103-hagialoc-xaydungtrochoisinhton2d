extends Camera2D

@export var follow_speed: float = 14.0
@export var snap_distance: float = 4.0
@export var free_look_speed: float = 400.0
enum CameraMode { FOLLOW, FREE }
var current_mode = CameraMode.FOLLOW

func _ready() -> void:
	top_level = true
	global_position = get_parent().global_position

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("action_camera_toggle"):
		if current_mode == CameraMode.FOLLOW:
			current_mode = CameraMode.FREE
		else:
			current_mode = CameraMode.FOLLOW

	match current_mode:
		CameraMode.FOLLOW:
			update_follow_mode(delta)
		CameraMode.FREE:
			update_free_mode(delta)

func update_follow_mode(delta: float) -> void:
	var target_pos = get_parent().global_position
	var t: float = clampf(1.0 - exp(-follow_speed * delta), 0.0, 1.0)
	global_position = global_position.lerp(target_pos, t)

	if global_position.distance_to(target_pos) <= snap_distance:
		global_position = target_pos

func update_free_mode(delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	global_position += input_dir * free_look_speed * delta
