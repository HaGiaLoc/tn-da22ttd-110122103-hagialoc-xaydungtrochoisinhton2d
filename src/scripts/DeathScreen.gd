class_name DeathScreen
extends Control

@onready var survival_label: Label  = $CenterContainer/VBoxContainer/SurvivalTimeLabel
@onready var load_button: Button    = $CenterContainer/VBoxContainer/LoadButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button    = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	load_button.pressed.connect(_on_load_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 1.2)


func set_survival_time(seconds: float) -> void:
	if survival_label:
		survival_label.text = "Thời gian sống sót: %s" % _format_time(seconds)


func _format_time(total_seconds: float) -> String:
	var total := int(total_seconds)
	@warning_ignore("integer_division")
	var h := total / 3600
	@warning_ignore("integer_division")
	var m := (total % 3600) / 60
	var s := total % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


func _on_load_pressed() -> void:
	var save_system := get_node_or_null("/root/SaveSystem")
	if not save_system or not save_system.has_save():
		return
	get_tree().paused = false
	save_system.load_on_ready = true
	var canvas := get_parent()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	if is_instance_valid(canvas):
		canvas.queue_free()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	var canvas := get_parent()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if is_instance_valid(canvas):
		canvas.queue_free()


func _on_quit_pressed() -> void:
	get_tree().quit()
