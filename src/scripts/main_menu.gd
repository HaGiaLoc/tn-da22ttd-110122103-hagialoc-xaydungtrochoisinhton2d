extends Control

@onready var play_btn: Button      = $VBoxContainer/NewGameBtn
@onready var continue_btn: Button  = $VBoxContainer/ContinueBtn
@onready var quit_btn: Button      = $VBoxContainer/QuitBtn
@onready var settings_btn: Button  = $VBoxContainer/SettingsBtn

@onready var _save_system: Node = get_node_or_null("/root/SaveSystem")

var _overwrite_dialog: ConfirmationDialog


func _ready() -> void:
	if has_node("/root/MusicManager"):
		var music_mgr = get_node("/root/MusicManager")
		if music_mgr.has_method("play_state"):
			music_mgr.play_state(music_mgr.MusicState.MENU)

	_build_overwrite_dialog()

	if continue_btn:
		continue_btn.disabled = not (_save_system and _save_system.has_save())

	play_btn.pressed.connect(_on_play_btn_pressed)
	quit_btn.pressed.connect(_on_quit_btn_pressed)



func _build_overwrite_dialog() -> void:
	_overwrite_dialog = ConfirmationDialog.new()
	_overwrite_dialog.title = "Chơi mới"
	_overwrite_dialog.dialog_text = "Bạn đã có bản lưu.\nBắt đầu trò chơi mới sẽ xoá bản lưu hiện tại.\nBạn có chắc không?"
	_overwrite_dialog.ok_button_text = "Chấp nhận"
	_overwrite_dialog.get_cancel_button().text = "Từ chối"
	_overwrite_dialog.confirmed.connect(_start_new_game)
	add_child(_overwrite_dialog)



func _on_play_btn_pressed() -> void:
	if _save_system and _save_system.has_save():
		_overwrite_dialog.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	if _save_system:
		_save_system.clear_save_data()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_continue_btn_pressed() -> void:
	if _save_system:
		_save_system.load_on_ready = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_settings_btn_pressed() -> void:
	$SettingPanel.visible = true


func _on_load_game_btn_pressed() -> void:
	_on_continue_btn_pressed()
