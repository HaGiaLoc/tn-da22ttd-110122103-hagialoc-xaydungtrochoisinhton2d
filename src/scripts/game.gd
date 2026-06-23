extends Node2D

var pause := false
var _survival_time: float = 0.0  ## Thời gian sống sót tính bằng giây

var _pending_action := ""

@onready var _save_system: Node = get_node_or_null("/root/SaveSystem")
@onready var _pause_menu := $PauseLayer/PauseMenu
var _confirm_dialog: ConfirmationDialog
var _saved_dialog: AcceptDialog


func _ready() -> void:

	
	if has_node("/root/MusicManager"):
		var music_mgr = get_node("/root/MusicManager")
		if music_mgr.has_method("play_state"):
			music_mgr.play_state(music_mgr.MusicState.DAY)

	_pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$PauseLayer/SettingPanel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var pause_input := preload("res://scripts/PauseInputHandler.gd").new()
	pause_input.name = "PauseInputHandler"
	$PauseLayer.add_child(pause_input)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_dialog.title = "Xác nhận"
	_confirm_dialog.ok_button_text = "Có"
	_confirm_dialog.get_cancel_button().text = "Không"
	_confirm_dialog.confirmed.connect(_on_confirm_save_yes)
	_confirm_dialog.canceled.connect(_on_confirm_save_no)
	_confirm_dialog.close_requested.connect(_on_confirm_dismissed)
	$PauseLayer.add_child(_confirm_dialog)

	_saved_dialog = AcceptDialog.new()
	_saved_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_saved_dialog.title = "Thông báo"
	_saved_dialog.dialog_text = "Đã lưu lại trò chơi."
	_saved_dialog.ok_button_text = "OK"
	$PauseLayer.add_child(_saved_dialog)

	if _save_system and _save_system.load_on_ready:
		_save_system.load_on_ready = false
		await get_tree().process_frame
		await get_tree().process_frame
		await _save_system.load_game()
	else:
		if _save_system:
			await get_tree().process_frame
			await get_tree().process_frame
			_save_system.save_game()



func _show_save_confirm(action: String) -> void:
	_pending_action = action
	_confirm_dialog.dialog_text = "Bạn chưa lưu trò chơi.\nBạn có muốn lưu lại không?"
	_confirm_dialog.popup_centered()


func _on_confirm_save_yes() -> void:
	if _save_system:
		_save_system.save_game()
	_execute_pending_action()


func _on_confirm_save_no() -> void:
	_execute_pending_action()


func _on_confirm_dismissed() -> void:
	_pending_action = ""
	_confirm_dialog.hide()


func _execute_pending_action() -> void:
	match _pending_action:
		"quit":
			get_tree().quit()
		"main_menu":
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	_pending_action = ""



func _process(delta: float) -> void:
	_survival_time += delta


func _unhandled_input(_event: InputEvent) -> void:
	pass


func toggle_pause() -> void:
	pause = !pause
	get_tree().paused = pause
	_pause_menu.visible = pause



func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	pause = false
	_pause_menu.visible = false


func _on_save_button_pressed() -> void:
	if _save_system:
		_save_system.save_game()
		_saved_dialog.popup_centered()


func _on_load_button_pressed() -> void:
	if not _save_system or not _save_system.has_save():
		push_warning("[Game] Không có bản lưu để tải.")
		return
	get_tree().paused = false
	pause = false
	_pause_menu.visible = false
	await _save_system.load_game()


func _on_settings_button_pressed() -> void:
	$PauseLayer/SettingPanel.visible = true


func show_death_screen() -> void:
	if has_node("/root/MusicManager"):
		var music_mgr = get_node("/root/MusicManager")
		if music_mgr.has_method("play_state"):
			music_mgr.play_state(music_mgr.MusicState.LOSE)

	get_tree().paused = true
	var canvas := CanvasLayer.new()
	canvas.name = "DeathScreenLayer"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas)
	var death_scene: PackedScene = load("res://scenes/death_screen.tscn")
	var death := death_scene.instantiate()
	death.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(death)
	if death.has_method("set_survival_time"):
		death.set_survival_time(_survival_time)


func get_survival_time() -> float:
	return _survival_time


func _on_main_menu_button_pressed() -> void:
	_show_save_confirm("main_menu")


func _on_quit_button_pressed() -> void:
	_show_save_confirm("quit")
