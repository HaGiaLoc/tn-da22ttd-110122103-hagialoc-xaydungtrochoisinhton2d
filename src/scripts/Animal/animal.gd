extends CharacterBody2D

signal debug_hurtbox_visibility_changed(enabled: bool)
signal health_changed(current_health: int, max_health: int)

@export var hurt_box_path: NodePath ## Đường dẫn hurt box.
@export var health_bar_path: NodePath ## Đường dẫn tới thanh máu.
@export var patrol_area_path: NodePath ## Đường dẫn tới vùng tuần tra (thường gán từ SpawnPoint).
@export var hurt_box_enabled: bool = true ## Bật/tắt hurt box nhận sát thương.

@export_category("Animal Stats")
@export var speed: float = 110.0 ## Tốc độ di chuyển bình thường.
@export var loot_table: LootTable ## Bảng drop loot khi animal chết (tùy chọn).
@export var run_speed: float = 180.0 ## Tốc độ chạy trốn khi bị tấn công.
@export var run_duration: float = 3.0 ## Thời gian chạy trốn sau khi bị tấn công (giây). Reset mỗi lần bị tấn công.
@export var patrol_enabled: bool = true ## Bật/tắt AI tuần tra.
@export var idle_time: float = 15.0 ## Thời gian đứng idle tại mỗi điểm tuần tra.
@export var idle_time_random_variation: float = 5.0 ## Độ lệch ngẫu nhiên quanh thời gian idle.
@export var patrol_step: float = 24.0 ## Độ dài mỗi bước khi tuần tra.
@export var max_health: int = 100 ## Chỉ số sinh mệnh.
@export var hurt_state_duration: float = 0.3 ## Thời gian stunned khi vào trạng thái HURT (giây).
@export var out_of_area_timeout: float = 15.0 ## Thời gian (giây) tối đa nằm ngoài patrol area trước khi quay về spawn.

@export_category("Debug")
@export var show_hurt_box: bool = false: ## Hiển thị hurt box khi chạy game.
	set(value):
		show_hurt_box = value
		if is_inside_tree():
			emit_signal("debug_hurtbox_visibility_changed", show_hurt_box)
@export var debug_state_output: bool = true ## In trạng thái ra output/terminal khi có thay đổi.
@export var debug_state_every_frame: bool = false ## In trạng thái hiện tại mỗi frame.

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: Node = null
var patrol_area: Area2D = null
@onready var health_bar: ProgressBar = null
@onready var _footstep_player: AudioStreamPlayer2D = $FootstepPlayer
@onready var _running_player: AudioStreamPlayer2D = $RunningPlayer
@onready var _death_player: AudioStreamPlayer2D = $DeathPlayer
@onready var _sound_area: Area2D = $SoundArea
@onready var _hurt_sound_player: AudioStreamPlayer2D = $HurtSoundPlayer

@export_category("Footstep Audio")
@export var footstep_interval: float = 0.5
@export var run_footstep_interval: float = 0.35

var _footstep_timer: float = 0.0
var _player_in_sound_area: bool = false

const PATROL_INNER_RADIUS_RATIO: float = 0.8
const PATROL_STUCK_TIME: float = 5.0
const PATROL_STUCK_RADIUS: float = 4.0

var origin: Vector2
var idle_timer: float = 0.0
var patrol_target: Vector2
var idle_animation_started: bool = false
var current_direction: String = "down_right"
var last_direction: String = "down_right"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var patrol_move_direction: Vector2 = Vector2.ZERO
var patrol_stuck_timer: float = 0.0
var patrol_stuck_anchor: Vector2 = Vector2.ZERO
var health: int = 0

var threat: Node = null
var run_timer: float = 0.0

enum AnimalState { IDLE, PATROL, RUN, HURT, RETURN_TO_SPAWN }
var state: AnimalState = AnimalState.IDLE

var _out_of_area_timer: float = 0.0  ## Đếm ngược khi nằm ngoài patrol area


func _ready() -> void:
	origin = global_position
	rng.randomize()
	patrol_target = origin
	health = max_health

	if health_bar_path != null and health_bar_path != NodePath("") and has_node(health_bar_path):
		var bar_node := get_node(health_bar_path)
		if bar_node is ProgressBar:
			health_bar = bar_node
	elif has_node("HealthBar") and $HealthBar is ProgressBar:
		health_bar = $HealthBar

	if health_bar and health_bar.has_method("bind_animal"):
		health_bar.bind_animal(self)
	else:
		emit_signal("health_changed", health, max_health)

	if hurt_box_path != null and hurt_box_path != NodePath("") and has_node(hurt_box_path):
		hurt_box = get_node(hurt_box_path)
	elif has_node("HurtBox"):
		hurt_box = $HurtBox

	if hurt_box and hurt_box.has_method("init_from_animal"):
		hurt_box.init_from_animal(self)
	if hurt_box and hurt_box.has_method("set_enabled"):
		hurt_box.set_enabled(hurt_box_enabled)

	if patrol_area_path != null and patrol_area_path != NodePath("") and has_node(patrol_area_path):
		patrol_area = get_node(patrol_area_path)
	elif has_node("PatrolArea"):
		patrol_area = $PatrolArea

	emit_signal("debug_hurtbox_visibility_changed", show_hurt_box)

	if patrol_enabled:
		_enter_patrol_state()
	else:
		_set_state(AnimalState.IDLE)

	_setup_sound_area()


func _setup_sound_area() -> void:
	if not _sound_area:
		return
	if not _sound_area.body_entered.is_connected(_on_sound_area_body_entered):
		_sound_area.body_entered.connect(_on_sound_area_body_entered)
	if not _sound_area.body_exited.is_connected(_on_sound_area_body_exited):
		_sound_area.body_exited.connect(_on_sound_area_body_exited)
	for body in _sound_area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			_player_in_sound_area = true
			break


func configure_patrol_from_spawn(area: Area2D, spawn_origin: Vector2) -> void:
	patrol_area = area
	origin = spawn_origin
	patrol_target = spawn_origin


func _physics_process(delta: float) -> void:
	_update_state(delta)

	if debug_state_every_frame:
		print("[Animal] state=", _state_to_string(state),
			" dir=", current_direction,
			" vel=", velocity,
			" threat=", threat,
			" run_timer=", snapped(run_timer, 0.01))

	match state:
		AnimalState.IDLE:
			_idle_behavior(delta)

		AnimalState.PATROL:
			_patrol_behavior(delta)

		AnimalState.RUN:
			_run_behavior(delta)

		AnimalState.HURT:
			velocity = Vector2.ZERO

		AnimalState.RETURN_TO_SPAWN:
			_return_to_spawn_behavior()

	if velocity.length() > _current_max_speed():
		velocity = velocity.normalized() * _current_max_speed()

	move_and_slide()
	_update_footstep_sfx(delta)

	if state == AnimalState.PATROL:
		_update_patrol_stuck(delta)

func _current_max_speed() -> float:
	return run_speed if state == AnimalState.RUN else speed


func _update_state(delta: float) -> void:
	if state == AnimalState.HURT:
		return  # Đang stunned — không chuyển state
	if state == AnimalState.RUN:
		run_timer -= delta
		if run_timer <= 0.0:
			_exit_run_state()

	_update_out_of_area_timer(delta)


func _update_out_of_area_timer(delta: float) -> void:
	if state == AnimalState.RETURN_TO_SPAWN or state == AnimalState.HURT:
		return
	if patrol_area == null:
		return

	if WaterTileChecker.is_inside_patrol_area(patrol_area, global_position):
		_out_of_area_timer = 0.0  # Đang trong area — reset
		return

	_out_of_area_timer += delta
	if _out_of_area_timer >= out_of_area_timeout:
		_out_of_area_timer = 0.0
		_enter_return_to_spawn_state()


func _exit_run_state() -> void:
	threat = null
	run_timer = 0.0
	if patrol_area != null:
		if not WaterTileChecker.is_inside_patrol_area(patrol_area, global_position):
			origin = _get_patrol_area_center()
	_enter_idle_state()
	_set_state(AnimalState.IDLE)


func _run_behavior(_delta: float) -> void:
	if not is_instance_valid(threat):
		velocity = Vector2.ZERO
		_play_run_animation()
		return

	var away: Vector2 = global_position - threat.global_position
	if away.length_squared() > 0.01:
		velocity = away.normalized() * run_speed
		current_direction = _vector_to_iso_direction(away)
		last_direction = current_direction
	else:
		var angle := rng.randf_range(0.0, TAU)
		velocity = Vector2(cos(angle), sin(angle)) * run_speed
		current_direction = _vector_to_iso_direction(velocity)
		last_direction = current_direction

	_play_run_animation()


func _play_run_animation() -> void:
	var anim_name: String = "run_" + current_direction
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name or not anim_sprite.is_playing():
			anim_sprite.play(anim_name)
	else:
		var fallback: String = "move_" + current_direction
		if anim_sprite and (anim_sprite.animation != fallback or not anim_sprite.is_playing()):
			anim_sprite.animation = fallback
			anim_sprite.play()


func _patrol_behavior(_delta: float) -> void:
	if patrol_area != null and not WaterTileChecker.is_inside_patrol_area(patrol_area, patrol_target):
		_set_next_patrol_target()
		patrol_move_direction = (patrol_target - global_position).normalized()

	if patrol_target.distance_to(global_position) < 8.0:
		_enter_idle_state()
		_set_state(AnimalState.IDLE)
		velocity = Vector2.ZERO
		patrol_move_direction = Vector2.ZERO
		return

	if patrol_move_direction == Vector2.ZERO:
		var to_target: Vector2 = patrol_target - global_position
		if to_target.length_squared() <= 0.001:
			velocity = Vector2.ZERO
			return
		patrol_move_direction = to_target.normalized()

	velocity = patrol_move_direction * speed
	_update_animation(velocity, false)


func _idle_behavior(delta: float) -> void:
	if not idle_animation_started:
		_enter_idle_state()

	velocity = Vector2.ZERO

	if idle_timer > 0.0:
		idle_timer -= delta
		if idle_timer <= 0.0:
			idle_timer = 0.0
			idle_animation_started = false
			if patrol_enabled:
				_enter_patrol_state()
			else:
				_set_state(AnimalState.IDLE)


func _enter_idle_state() -> void:
	idle_animation_started = true
	idle_timer = _get_random_idle_time()
	_play_idle_animation()


func _enter_patrol_state() -> void:
	_reset_patrol_stuck()
	_set_next_patrol_target()
	patrol_move_direction = (patrol_target - global_position).normalized()
	_set_state(AnimalState.PATROL)


func _reset_patrol_stuck() -> void:
	patrol_stuck_timer = 0.0
	patrol_stuck_anchor = global_position


func _update_patrol_stuck(delta: float) -> void:
	if patrol_target.distance_to(global_position) < 8.0:
		_reset_patrol_stuck()
		return

	if velocity.length() < 4.0:
		_reset_patrol_stuck()
		return

	if global_position.distance_to(patrol_stuck_anchor) >= PATROL_STUCK_RADIUS:
		patrol_stuck_anchor = global_position
		patrol_stuck_timer = 0.0
		return

	patrol_stuck_timer += delta
	if patrol_stuck_timer >= PATROL_STUCK_TIME:
		_reset_patrol_stuck()
		_set_next_patrol_target()
		patrol_move_direction = (patrol_target - global_position).normalized()


func _enter_run_state(attacker: Node) -> void:
	threat = attacker
	run_timer = run_duration  ## Reset mỗi lần vào RUN (kể cả khi đang RUN bị tấn công lại)
	_set_state(AnimalState.RUN)


func _enter_return_to_spawn_state() -> void:
	threat = null
	run_timer = 0.0
	_set_state(AnimalState.RETURN_TO_SPAWN)


func _return_to_spawn_behavior() -> void:
	var to_origin := origin - global_position
	if to_origin.length() < 8.0:
		velocity = Vector2.ZERO
		_out_of_area_timer = 0.0
		_enter_idle_state()
		if patrol_enabled:
			_enter_patrol_state()
		else:
			_set_state(AnimalState.IDLE)
		return

	velocity = to_origin.normalized() * speed
	_update_animation(velocity, false)


var _hurt_generation: int = 0


func _enter_hurt_state(attacker: Node = null) -> void:
	_hurt_generation += 1
	var my_generation := _hurt_generation

	_set_state(AnimalState.HURT)
	velocity = Vector2.ZERO

	if _hurt_sound_player and _hurt_sound_player.stream:
		_play_creature_sfx(_hurt_sound_player)

	var hurt_anim := "hurt_" + last_direction
	if anim_sprite and anim_sprite.sprite_frames:
		if anim_sprite.sprite_frames.has_animation(hurt_anim):
			anim_sprite.play(hurt_anim)
		else:
			hurt_anim = "hurt_" + current_direction
			if anim_sprite.sprite_frames.has_animation(hurt_anim):
				anim_sprite.play(hurt_anim)

	await get_tree().create_timer(hurt_state_duration).timeout

	if my_generation != _hurt_generation:
		return

	if not is_instance_valid(self) or health <= 0:
		return

	if attacker != null and is_instance_valid(attacker):
		_enter_run_state(attacker)
	elif threat != null and is_instance_valid(threat):
		_enter_run_state(threat)
	else:
		_enter_idle_state()
		_set_state(AnimalState.IDLE)


func take_damage(amount: float, attacker: Node = null) -> void:
	health -= int(amount)
	emit_signal("health_changed", max(health, 0), max_health)

	if health <= 0:
		_play_creature_sfx(_death_player)
		LootDropper.drop(loot_table, get_tree().current_scene, global_position, rng)
		queue_free()
		return

	_enter_hurt_state(attacker)


func set_hurt_box_enabled(enabled: bool) -> void:
	hurt_box_enabled = enabled
	if hurt_box and hurt_box.has_method("set_enabled"):
		hurt_box.set_enabled(hurt_box_enabled)


func _set_state(new_state: AnimalState) -> void:
	if state == new_state:
		return

	state = new_state

	if debug_state_output:
		print("[Animal] → ", _state_to_string(state),
			" | dir=", current_direction,
			" | pos=", global_position,
			" | threat=", threat)


func _state_to_string(value: AnimalState) -> String:
	match value:
		AnimalState.IDLE:
			return "IDLE"
		AnimalState.PATROL:
			return "PATROL"
		AnimalState.RUN:
			return "RUN"
		AnimalState.HURT:
			return "HURT"
		AnimalState.RETURN_TO_SPAWN:
			return "RETURN_TO_SPAWN"
		_:
			return "UNKNOWN"


func _play_idle_animation() -> void:
	var anim_name: String = "idle_" + last_direction
	if anim_sprite and (anim_sprite.animation != anim_name or not anim_sprite.is_playing()):
		anim_sprite.animation = anim_name
		anim_sprite.play()


func _face_vector(vec: Vector2) -> void:
	if vec.length_squared() <= 0.1:
		current_direction = last_direction
		return
	current_direction = _vector_to_iso_direction(vec)


func _vector_to_iso_direction(vec: Vector2) -> String:
	var directions := {
		"up_left": Vector2(-1, -1).normalized(),
		"up_right": Vector2(1, -1).normalized(),
		"down_right": Vector2(1, 1).normalized(),
		"down_left": Vector2(-1, 1).normalized(),
	}

	var best_direction: String = last_direction
	var best_dot: float = -INF
	var normalized_vec := vec.normalized()

	for direction_name in directions.keys():
		var dot_value: float = normalized_vec.dot(directions[direction_name])
		if dot_value > best_dot:
			best_dot = dot_value
			best_direction = direction_name

	return best_direction


func _set_next_patrol_target() -> void:
	if patrol_area == null:
		patrol_target = origin
		return
	patrol_target = WaterTileChecker.pick_patrol_target(
		patrol_area,
		origin,
		global_position,
		patrol_step,
		rng
	)
	patrol_target = WaterTileChecker.clamp_to_patrol_area(patrol_area, patrol_target)


func _get_patrol_area_center() -> Vector2:
	return WaterTileChecker.get_patrol_area_center(patrol_area) if patrol_area != null else origin


func _get_patrol_area_radius() -> float:
	return WaterTileChecker.get_patrol_area_radius(patrol_area)


func _get_random_idle_time() -> float:
	if idle_time_random_variation <= 0.0:
		return idle_time
	return idle_time + rng.randf_range(-idle_time_random_variation, idle_time_random_variation)


func _update_animation(vel: Vector2, keep_idle_direction: bool) -> void:
	var is_moving: bool = vel.length() > 4.0

	if is_moving:
		current_direction = _vector_to_iso_direction(vel)
		last_direction = current_direction
	elif keep_idle_direction:
		current_direction = last_direction

	var anim_name: String = ("move" if is_moving else "idle") + "_" + current_direction
	if anim_sprite and (anim_sprite.animation != anim_name or not anim_sprite.is_playing()):
		anim_sprite.animation = anim_name
		anim_sprite.play()


func _update_footstep_sfx(delta: float) -> void:
	if not _can_play_creature_sfx():
		_footstep_timer = 0.0
		_stop_movement_sfx()
		return
	if state == AnimalState.IDLE or state == AnimalState.HURT:
		_footstep_timer = 0.0
		_stop_movement_sfx()
		return
	if velocity.length() <= 4.0:
		_footstep_timer = 0.0
		_stop_movement_sfx()
		return

	var is_running := state == AnimalState.RUN
	var interval := run_footstep_interval if is_running else footstep_interval
	var player := _running_player if is_running else _footstep_player

	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = interval
		_play_creature_sfx(player)


func _can_play_creature_sfx() -> bool:
	return _player_in_sound_area


func _play_creature_sfx(player: AudioStreamPlayer2D) -> void:
	if not _can_play_creature_sfx():
		return
	if player and player.stream:
		player.play()


func _stop_movement_sfx() -> void:
	if _footstep_player and _footstep_player.playing:
		_footstep_player.stop()
	if _running_player and _running_player.playing:
		_running_player.stop()

func _stop_creature_sfx() -> void:
	for sfx_player in [_footstep_player, _running_player, _death_player, _hurt_sound_player]:
		if sfx_player and sfx_player.playing:
			sfx_player.stop()
	_footstep_timer = 0.0


func _on_sound_area_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_sound_area = true


func _on_sound_area_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_sound_area = false
		_stop_creature_sfx()
