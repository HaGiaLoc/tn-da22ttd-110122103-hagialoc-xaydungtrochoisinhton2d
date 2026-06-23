extends CharacterBody2D

signal debug_hitbox_visibility_changed(enabled: bool)
signal debug_hurtbox_visibility_changed(enabled: bool)
signal health_changed(current_health: int, max_health: int)

@export var detection_area_path: NodePath ## Đường dẫn tới vùng phát hiện player.
@export var hit_box_path: NodePath ## Đường dẫn hit box.
@export var hurt_box_path: NodePath ## Đường dẫn hurt box.
@export var patrol_area_path: NodePath ## Đường dẫn tới vùng tuần tra cố định từ Spawn Point.
@export var player_path: NodePath ## Đường dẫn tới node player, nếu không dùng detection area.
@export var health_bar_path: NodePath ## Đường dẫn tới thanh máu của enemy.
@export var hit_box_enabled: bool = true ## Bật/tắt hit box gây sát thương.
@export var hurt_box_enabled: bool = true ## Bật/tắt hurt box nhận sát thương.

@export_category("Enemy Stats")
@export var speed: float = 110.0 ## Tốc độ di chuyển.
@export var loot_table: LootTable ## Bảng drop loot khi enemy chết (tùy chọn).
@export var attack_cooldown_time: float = 1 ## Thời gian cooldown sau khi hoàn tất animation tấn công.
@export var aggro_time: float = 1 ## Thời gian dự phòng tối đa trước khi chuyển sang chase.
@export var patrol_enabled: bool = true ## Bật/tắt AI tuần tra.
@export var idle_time: float = 15.0 ## Thời gian đứng idle tại mỗi điểm tuần tra.
@export var idle_time_random_variation: float = 5.0 ## Độ lệch ngẫu nhiên quanh thời gian idle.
@export var patrol_step: float = 24.0 ## Độ dài mỗi bước khi tuần tra.
@export var max_health: int = 100 ## Chỉ số sinh mệnh.
@export var hurt_state_duration: float = 0.5 ## Thời gian stunned khi vào trạng thái HURT (giây).
@export var out_of_area_timeout: float = 15.0 ## Thời gian (giây) tối đa nằm ngoài patrol area trước khi quay về spawn.

@export_category("Debug")
@export var show_hit_box: bool = false: ## Hiển thị hit box khi chạy game.
	set(value):
		show_hit_box = value
		if is_inside_tree():
			emit_signal("debug_hitbox_visibility_changed", show_hit_box)
@export var show_hurt_box: bool = false: ## Hiển thị hurt box khi chạy game.
	set(value):
		show_hurt_box = value
		if is_inside_tree():
			emit_signal("debug_hurtbox_visibility_changed", show_hurt_box)
@export var debug_state_output: bool = true ## In trạng thái enemy ra output/terminal khi có thay đổi.
@export var debug_state_every_frame: bool = false ## In trạng thái hiện tại mỗi frame nếu cần theo dõi realtime.

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Node = null
@onready var hit_box: Node = null
@onready var hurt_box: Node = null
var patrol_area: Area2D = null
@onready var attack_range: Node = null
var _is_detecting_player_for_music: bool = false
@onready var health_bar: ProgressBar = null
@onready var _footstep_player: AudioStreamPlayer2D = $FootstepPlayer
@onready var _running_player: AudioStreamPlayer2D = $RunningPlayer
@onready var _death_player: AudioStreamPlayer2D = $DeathPlayer
@onready var _attack_player: AudioStreamPlayer2D = $EnemyAttackPlayer
@onready var _sound_area: Area2D = $SoundArea
@onready var _hurt_sound_player: AudioStreamPlayer2D = $HurtSoundPlayer

@export_category("Footstep Audio")
@export var footstep_interval: float = 0.5
@export var run_footstep_interval: float = 0.35

var _footstep_timer: float = 0.0
var _player_in_sound_area: bool = false

const CHASE_RADIUS: float = 220.0
const PATROL_STUCK_TIME: float = 5.0
const PATROL_STUCK_RADIUS: float = 4.0

var origin: Vector2
var idle_timer: float = 0.0
var patrol_target: Vector2
var aggro_timer: float = 0.0
var idle_animation_started: bool = false
var current_direction: String = "down_right"
var last_direction: String = "down_right"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var patrol_step_target: Vector2 = Vector2.ZERO
var patrol_move_direction: Vector2 = Vector2.ZERO
var patrol_stuck_timer: float = 0.0
var patrol_stuck_anchor: Vector2 = Vector2.ZERO
var detected_player = null
var detected_animal = null   ## Animal đang bị target (ưu tiên thấp hơn player)
var health: int = 0
var aggro_animation_done: bool = false
var attack_cooldown_timer: float = 0.0
var attack_range_target: Node = null
var attack_lunge_started: bool = false

const ATTACK_LUNGE_FRAME: int = 9
const ATTACK_LUNGE_SPEED_MULTIPLIER: float = 2.0

enum EnemyState { IDLE, PATROL, AGGRO, CHASE, ATTACK, HURT, COOLDOWN, DEAD, RETURN_TO_SPAWN }
var state: EnemyState = EnemyState.IDLE

var _out_of_area_timer: float = 0.0  ## Đếm ngược khi nằm ngoài patrol area

func _ready() -> void:
	origin = global_position
	rng.randomize()
	patrol_target = origin

	if patrol_area_path != null and patrol_area_path != NodePath("") and has_node(patrol_area_path):
		patrol_area = get_node(patrol_area_path)
	elif has_node("PatrolArea"):
		patrol_area = $PatrolArea

	health = max_health

	if health_bar_path != null and health_bar_path != NodePath("") and has_node(health_bar_path):
		health_bar = get_node(health_bar_path)
	elif has_node("HealthBar"):
		health_bar = $HealthBar

	if health_bar and health_bar.has_method("bind_enemy"):
		health_bar.bind_enemy(self)
	else:
		emit_signal("health_changed", health, max_health)

	if detection_area_path != null and detection_area_path != NodePath("") and has_node(detection_area_path):
		detection_area = get_node(detection_area_path)
	elif has_node("DetectionArea"):
		detection_area = $DetectionArea

	if detection_area:
		if detection_area.has_signal("player_entered"):
			detection_area.connect("player_entered", Callable(self, "_on_detection_player_entered"))
		if detection_area.has_signal("player_exited"):
			detection_area.connect("player_exited", Callable(self, "_on_detection_player_exited"))
		if detection_area.has_signal("animal_entered"):
			detection_area.connect("animal_entered", Callable(self, "_on_detection_animal_entered"))
		if detection_area.has_signal("animal_exited"):
			detection_area.connect("animal_exited", Callable(self, "_on_detection_animal_exited"))

	if hit_box_path != null and hit_box_path != NodePath("") and has_node(hit_box_path):
		hit_box = get_node(hit_box_path)
	elif has_node("HitBox"):
		hit_box = $HitBox

	if hit_box and hit_box.has_method("init_from_enemy"):
		hit_box.init_from_enemy(self)
	if hit_box and hit_box.has_method("set_enabled"):
		hit_box.set_enabled(hit_box_enabled and state == EnemyState.ATTACK)

	if hurt_box_path != null and hurt_box_path != NodePath("") and has_node(hurt_box_path):
		hurt_box = get_node(hurt_box_path)
	elif has_node("HurtBox"):
		hurt_box = $HurtBox

	if has_node("AttackRange"):
		attack_range = $AttackRange

	if attack_range and attack_range.has_method("init_from_enemy"):
		attack_range.init_from_enemy(self)
	if attack_range and attack_range.has_signal("attack_requested"):
		attack_range.connect("attack_requested", Callable(self, "_on_attack_range_attack_requested"))
	if attack_range and attack_range.has_signal("attack_cleared"):
		attack_range.connect("attack_cleared", Callable(self, "_on_attack_range_attack_cleared"))

	if hurt_box and hurt_box.has_method("init_from_enemy"):
		hurt_box.init_from_enemy(self)
	if hurt_box and hurt_box.has_method("set_enabled"):
		hurt_box.set_enabled(hurt_box_enabled)

	if anim_sprite and anim_sprite.has_signal("animation_finished"):
		anim_sprite.animation_finished.connect(Callable(self, "_on_anim_sprite_animation_finished"))

	if patrol_enabled:
		_enter_patrol_state()
	else:
		_set_state(EnemyState.IDLE)

	emit_signal("debug_hitbox_visibility_changed", show_hit_box)
	emit_signal("debug_hurtbox_visibility_changed", show_hurt_box)

	_configure_aggro_animations()
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
	if state == EnemyState.DEAD:
		return
	var target = _get_target()
	var to_player: Vector2 = Vector2.ZERO
	var dist: float = INF

	if target != null:
		to_player = target.global_position - global_position
		dist = to_player.length()

	_update_state(delta, target, dist)

	if debug_state_every_frame:
		print("[Enemy] state=", _state_to_string(state), " dir=", current_direction, " vel=", velocity)

	match state:
		EnemyState.IDLE:
			_idle_behavior(delta)

		EnemyState.PATROL:
			_patrol_behavior(delta)

		EnemyState.AGGRO:
			velocity = Vector2.ZERO
			if aggro_animation_done or aggro_timer <= 0.0:
				_set_state(EnemyState.CHASE)

		EnemyState.CHASE:
			_chase_behavior(to_player)

		EnemyState.ATTACK:
			_attack_behavior(to_player)
			_face_vector(to_player)
			if hit_box and hit_box.has_method("set_direction"):
				hit_box.set_direction(current_direction)
			if anim_sprite and not anim_sprite.animation.begins_with("attack_"):
				_start_attack_animation()

		EnemyState.HURT:
			velocity = Vector2.ZERO

		EnemyState.COOLDOWN:
			velocity = Vector2.ZERO
			if to_player.length_squared() > 0.1:
				_face_vector(to_player)
			_play_wait_animation()

		EnemyState.RETURN_TO_SPAWN:
			_return_to_spawn_behavior()

	if velocity.length() > speed:
		velocity = velocity.normalized() * speed

	move_and_slide()
	_update_footstep_sfx(delta)

	if state == EnemyState.PATROL:
		_update_patrol_stuck(delta)

func _get_player():
	if detected_player != null:
		return detected_player
	if player_path != null and player_path != NodePath("") and has_node(player_path):
		return get_node(player_path)
	return null

func _get_target() -> Node:
	var player = _get_player()
	if player != null and is_instance_valid(player):
		return player
	if detected_animal != null and not is_instance_valid(detected_animal):
		detected_animal = null
	if detected_animal != null:
		return detected_animal
	if detection_area and detection_area.has_method("get_nearest_animal"):
		detected_animal = detection_area.get_nearest_animal(global_position)
	return detected_animal

func _on_detection_player_entered(player: Node) -> void:
	detected_player = player
	if not _is_detecting_player_for_music:
		_is_detecting_player_for_music = true
		if has_node("/root/MusicManager"):
			var music_mgr = get_node("/root/MusicManager")
			if music_mgr.has_method("register_enemy_detection"):
				music_mgr.register_enemy_detection(true)

func _on_detection_player_exited(player: Node) -> void:
	if detected_player == player:
		detected_player = null
		if _is_detecting_player_for_music:
			_is_detecting_player_for_music = false
			if has_node("/root/MusicManager"):
				var music_mgr = get_node("/root/MusicManager")
				if music_mgr.has_method("register_enemy_detection"):
					music_mgr.register_enemy_detection(false)

func _on_detection_animal_entered(animal: Node) -> void:
	if detected_player == null and detected_animal == null:
		detected_animal = animal

func _on_detection_animal_exited(animal: Node) -> void:
	if detected_animal == animal:
		detected_animal = null
		if detection_area and detection_area.has_method("get_nearest_animal"):
			detected_animal = detection_area.get_nearest_animal(global_position)

func _on_hit_box_hit(_attacker: Node, _damage: int) -> void:
	pass

func set_hit_box_enabled(enabled: bool) -> void:
	hit_box_enabled = enabled
	if hit_box and hit_box.has_method("set_enabled"):
		hit_box.set_enabled(hit_box_enabled and state == EnemyState.ATTACK)

func set_hurt_box_enabled(enabled: bool) -> void:
	hurt_box_enabled = enabled
	if hurt_box and hurt_box.has_method("set_enabled"):
		hurt_box.set_enabled(hurt_box_enabled)

func _on_attack_range_attack_requested(target: Node) -> void:
	if target == null:
		return

	if target.is_in_group("Player"):
		detected_player = target
		attack_range_target = target
		if state != EnemyState.COOLDOWN:
			_enter_attack_state(target)
	else:
		if detected_player == null:
			detected_animal = target
			attack_range_target = target
			if state == EnemyState.CHASE and state != EnemyState.COOLDOWN:
				_enter_attack_state(target)

func _on_attack_range_attack_cleared(target: Node) -> void:
	if target != null and attack_range_target == target:
		attack_range_target = null



func take_damage(amount: int) -> void:
	health -= amount
	emit_signal("health_changed", max(health, 0), max_health)
	if health <= 0:
		_enter_dead_state()
		return

	var hurt_dir := last_direction
	_enter_hurt_state(hurt_dir)


func _enter_dead_state() -> void:
	if state == EnemyState.DEAD:
		return
		
	if _is_detecting_player_for_music:
		_is_detecting_player_for_music = false
		if has_node("/root/MusicManager"):
			var music_mgr = get_node("/root/MusicManager")
			if music_mgr.has_method("register_enemy_detection"):
				music_mgr.register_enemy_detection(false)

	_set_state(EnemyState.DEAD)

	velocity = Vector2.ZERO

	if hit_box and hit_box.has_method("set_enabled"):
		hit_box.set_enabled(false)
	if hurt_box and hurt_box.has_method("set_enabled"):
		hurt_box.set_enabled(false)

	if _death_player and _death_player.stream:
		_play_creature_sfx(_death_player)

	var death_anim_name := "death_" + last_direction
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(death_anim_name):
		anim_sprite.play(death_anim_name)
		return

	death_anim_name = "death_" + current_direction
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(death_anim_name):
		anim_sprite.play(death_anim_name)
		return

	LootDropper.drop(loot_table, get_tree().current_scene, global_position, rng)
	queue_free()

func _update_state(delta: float, player, dist: float) -> void:
	if state == EnemyState.ATTACK or state == EnemyState.HURT or state == EnemyState.DEAD or state == EnemyState.RETURN_TO_SPAWN:
		return

	if state == EnemyState.COOLDOWN:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0.0:
			attack_cooldown_timer = 0.0
			var live_attack_target: Node = null
			if attack_range and attack_range.has_method("get_overlapping_target"):
				live_attack_target = attack_range.get_overlapping_target()

			if live_attack_target != null:
				if live_attack_target.is_in_group("Player"):
					_enter_attack_state(live_attack_target)
				elif detected_player == null:
					_enter_attack_state(live_attack_target)
				else:
					_set_state(EnemyState.CHASE)
			elif detected_player != null:
				_set_state(EnemyState.CHASE)
			elif detected_animal != null:
				_set_state(EnemyState.CHASE)
			else:
				_enter_idle_state()
				_set_state(EnemyState.IDLE)
		return

	if player == null:
		if patrol_enabled:
			if state != EnemyState.IDLE and state != EnemyState.PATROL:
				_enter_patrol_state()
		else:
			if state != EnemyState.IDLE:
				_enter_idle_state()
			_set_state(EnemyState.IDLE)
		return

	if dist <= CHASE_RADIUS:
		var target_is_animal: bool = (detected_player == null and detected_animal != null)
		if target_is_animal:
			if state == EnemyState.AGGRO:
				aggro_timer -= delta
				if aggro_animation_done or aggro_timer <= 0.0:
					_set_state(EnemyState.CHASE)
			elif state != EnemyState.CHASE and state != EnemyState.ATTACK:
				_set_state(EnemyState.AGGRO)
				aggro_timer = aggro_time
				_start_aggro_animation()
		else:
			if state == EnemyState.AGGRO:
				aggro_timer -= delta
				if aggro_animation_done or aggro_timer <= 0.0:
					_set_state(EnemyState.CHASE)
			elif state != EnemyState.CHASE:
				_set_state(EnemyState.AGGRO)
				aggro_timer = aggro_time
				_start_aggro_animation()
		return

	if dist > CHASE_RADIUS * 1.3:
		if state == EnemyState.CHASE or state == EnemyState.AGGRO or state == EnemyState.ATTACK:
			if patrol_enabled:
				_enter_patrol_state()
			else:
				_enter_idle_state()
		return

	if patrol_area != null and (state == EnemyState.PATROL or state == EnemyState.IDLE):
		if not WaterTileChecker.is_inside_patrol_area(patrol_area, global_position):
			if patrol_enabled:
				_enter_patrol_state()
			else:
				_enter_idle_state()

	_update_out_of_area_timer(delta)

func _patrol_behavior(_delta: float) -> void:
	if patrol_area != null and not WaterTileChecker.is_inside_patrol_area(patrol_area, patrol_target):
		_set_next_patrol_target()
		patrol_move_direction = (patrol_target - global_position).normalized()

	if patrol_target.distance_to(global_position) < 8.0:
		_enter_idle_state()
		_set_state(EnemyState.IDLE)
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
				_set_state(EnemyState.IDLE)
			if patrol_enabled:
				pass

func _enter_idle_state() -> void:
	idle_animation_started = true
	idle_timer = _get_random_idle_time()
	_play_idle_animation()

func _enter_patrol_state() -> void:
	_reset_patrol_stuck()
	_set_next_patrol_target()
	patrol_move_direction = (patrol_target - global_position).normalized()
	_set_state(EnemyState.PATROL)

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

func _update_out_of_area_timer(delta: float) -> void:
	if state == EnemyState.RETURN_TO_SPAWN or state == EnemyState.HURT or state == EnemyState.DEAD:
		return
	if patrol_area == null:
		return

	if WaterTileChecker.is_inside_patrol_area(patrol_area, global_position):
		_out_of_area_timer = 0.0
		return

	_out_of_area_timer += delta
	if _out_of_area_timer >= out_of_area_timeout:
		_out_of_area_timer = 0.0
		_enter_return_to_spawn_state()


func _enter_return_to_spawn_state() -> void:
	if _is_detecting_player_for_music:
		_is_detecting_player_for_music = false
		if has_node("/root/MusicManager"):
			var music_mgr = get_node("/root/MusicManager")
			if music_mgr.has_method("register_enemy_detection"):
				music_mgr.register_enemy_detection(false)
	detected_player = null
	detected_animal = null
	attack_range_target = null
	_set_state(EnemyState.RETURN_TO_SPAWN)


func _return_to_spawn_behavior() -> void:
	var to_origin := origin - global_position
	if to_origin.length() < 8.0:
		velocity = Vector2.ZERO
		_out_of_area_timer = 0.0
		if patrol_enabled:
			_enter_patrol_state()
		else:
			_enter_idle_state()
			_set_state(EnemyState.IDLE)
		return

	velocity = to_origin.normalized() * speed
	_update_animation(velocity, false)


func _enter_attack_state(target: Node) -> void:
	if target != null:
		_face_vector(target.global_position - global_position)
	_set_state(EnemyState.ATTACK)
	attack_lunge_started = false
	velocity = Vector2.ZERO
	if hit_box and hit_box.has_method("set_direction"):
		hit_box.set_direction(current_direction)
	_start_attack_animation()

func _start_attack_animation() -> void:
	var attack_animation_name := "attack_" + current_direction
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(attack_animation_name):
		if _attack_player and _attack_player.stream:
			_play_creature_sfx(_attack_player)
		anim_sprite.play(attack_animation_name)

func _attack_behavior(to_player: Vector2) -> void:
	if anim_sprite == null:
		velocity = Vector2.ZERO
		return

	if anim_sprite.frame < ATTACK_LUNGE_FRAME:
		velocity = Vector2.ZERO
		return

	if to_player.length_squared() <= 0.1:
		velocity = Vector2.ZERO
		return

	attack_lunge_started = true
	velocity = to_player.normalized() * speed * ATTACK_LUNGE_SPEED_MULTIPLIER

func _play_wait_animation() -> void:
	var wait_animation_name := "wait_" + current_direction
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(wait_animation_name):
		if anim_sprite.animation != wait_animation_name or not anim_sprite.is_playing():
			anim_sprite.play(wait_animation_name)
		return

	_update_animation(Vector2.ZERO, true)

func _play_idle_animation() -> void:
	var anim_name: String = "idle_" + last_direction
	if anim_sprite and (anim_sprite.animation != anim_name or not anim_sprite.is_playing()):
		anim_sprite.animation = anim_name
		anim_sprite.play()

func _chase_behavior(to_player: Vector2) -> void:
	if to_player.length_squared() > 0.1:
		velocity = to_player.normalized() * speed
		_update_animation(velocity, false)
	else:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO, true)

func _face_vector(vec: Vector2) -> void:
	if vec.length_squared() <= 0.1:
		current_direction = last_direction
		return

	current_direction = _vector_to_iso_direction(vec)

func _start_aggro_animation() -> void:
	aggro_animation_done = false

	var aggro_animation_name := "aggro_" + last_direction
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(aggro_animation_name):
		anim_sprite.play(aggro_animation_name)
	else:
		aggro_animation_done = true

func _set_state(new_state: EnemyState) -> void:
	if state == new_state:
		return

	state = new_state

	if debug_state_output:
		print("[Enemy] state=", _state_to_string(state), " dir=", current_direction, " pos=", global_position)

func _state_to_string(value: EnemyState) -> String:
	match value:
		EnemyState.IDLE:
			return "IDLE"
		EnemyState.PATROL:
			return "PATROL"
		EnemyState.AGGRO:
			return "AGGRO"
		EnemyState.CHASE:
			return "CHASE"
		EnemyState.ATTACK:
			return "ATTACK"
		EnemyState.HURT:
			return "HURT"
		EnemyState.DEAD:
			return "DEAD"
		EnemyState.COOLDOWN:
			return "COOLDOWN"
		EnemyState.RETURN_TO_SPAWN:
			return "RETURN_TO_SPAWN"
		_:
			return "UNKNOWN"

func is_dead() -> bool:
	return state == EnemyState.DEAD


func _enter_hurt_state(hurt_direction: String = "") -> void:
	if state == EnemyState.DEAD or state == EnemyState.HURT:
		return

	_set_state(EnemyState.HURT)

	velocity = Vector2.ZERO

	if hit_box and hit_box.has_method("set_enabled"):
		hit_box.set_enabled(false)

	if _hurt_sound_player and _hurt_sound_player.stream:
		_play_creature_sfx(_hurt_sound_player)

	var chosen_dir := hurt_direction
	if chosen_dir == "":
		chosen_dir = last_direction

	var hurt_anim_name := "hurt_" + chosen_dir
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(hurt_anim_name):
		anim_sprite.play(hurt_anim_name)
	else:
		hurt_anim_name = "hurt_" + last_direction
		if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(hurt_anim_name):
			anim_sprite.play(hurt_anim_name)
		else:
			hurt_anim_name = "hurt_" + current_direction
			if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(hurt_anim_name):
				anim_sprite.play(hurt_anim_name)

	var stun_duration: float = hurt_state_duration
	await get_tree().create_timer(stun_duration).timeout

	if state == EnemyState.DEAD:
		return

	_enter_attack_state(null)

func _on_anim_sprite_animation_finished() -> void:
	if state == EnemyState.AGGRO and anim_sprite and anim_sprite.animation.begins_with("aggro_"):
		aggro_animation_done = true
	elif state == EnemyState.ATTACK and anim_sprite and anim_sprite.animation.begins_with("attack_"):
		if _attack_player and _attack_player.playing:
			_attack_player.stop()
		if hit_box and hit_box.has_method("set_enabled"):
			hit_box.set_enabled(false)
		attack_cooldown_timer = attack_cooldown_time
		_set_state(EnemyState.COOLDOWN)
	elif state == EnemyState.DEAD and anim_sprite and anim_sprite.animation.begins_with("death_"):
		LootDropper.drop(loot_table, get_tree().current_scene, global_position, rng)
		queue_free()

func _configure_aggro_animations() -> void:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return

	for animation_name in anim_sprite.sprite_frames.get_animation_names():
		if String(animation_name).begins_with("aggro_"):
			anim_sprite.sprite_frames.set_animation_loop(animation_name, false)
		if String(animation_name).begins_with("death_"):
			anim_sprite.sprite_frames.set_animation_loop(animation_name, false)
		if String(animation_name).begins_with("hurt_"):
			anim_sprite.sprite_frames.set_animation_loop(animation_name, false)

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
	if state == EnemyState.DEAD or state == EnemyState.IDLE or state == EnemyState.HURT:
		_footstep_timer = 0.0
		_stop_movement_sfx()
		return
	if state == EnemyState.ATTACK or state == EnemyState.AGGRO or state == EnemyState.COOLDOWN:
		_footstep_timer = 0.0
		_stop_movement_sfx()
		return
	if velocity.length() <= 4.0:
		_footstep_timer = 0.0
		_stop_movement_sfx()
		return

	var is_running := state == EnemyState.CHASE
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
	for sfx_player in [_footstep_player, _running_player, _death_player, _attack_player]:
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
