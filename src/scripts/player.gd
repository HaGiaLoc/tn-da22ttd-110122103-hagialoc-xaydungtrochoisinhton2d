extends CharacterBody2D

@export var walk_speed: float = 150.0
@export var run_speed: float = 250.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

@onready var anim_sprite = $AnimatedSprite2D

var facing_direction: String = "down"

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var current_speed = run_speed if Input.is_action_pressed("action_run") else walk_speed

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * current_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	update_animations(input_dir)

func update_animations(input_dir: Vector2) -> void:
	var state: String
	var is_moving := input_dir != Vector2.ZERO 

	state = "move" if is_moving else "idle"

	if input_dir != Vector2.ZERO:
		if input_dir.y < -0.1:
			facing_direction = "up"
		elif input_dir.y > 0.1:
			facing_direction = "down"
		elif input_dir.x < -0.1:
			facing_direction = "left"
		elif input_dir.x > 0.1:
			facing_direction = "right"

	var anim_name = state + "_" + facing_direction

	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)
		