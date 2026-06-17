extends Control

@onready var master_label: Label = $SettingPanel/MarginContainer/SettingsContainer/MasterVolume
@onready var music_label: Label = $SettingPanel/MarginContainer/SettingsContainer/MusicVolume
@onready var sfx_label: Label = $"SettingPanel/MarginContainer/SettingsContainer/SFX Volume"

@onready var master_slider: HSlider = $SettingPanel/MarginContainer/SettingsContainer/MasterSlider
@onready var music_slider: HSlider = $SettingPanel/MarginContainer/SettingsContainer/MusicSlider
@onready var sfx_slider: HSlider = $SettingPanel/MarginContainer/SettingsContainer/SFXSlider

func _ready() -> void:
	var saved = SaveSystem.get_settings()
	if not saved.is_empty():
		if master_slider: master_slider.set_value_no_signal(saved.get("master", 1.0))
		if music_slider: music_slider.set_value_no_signal(saved.get("music", 1.0))
		if sfx_slider: sfx_slider.set_value_no_signal(saved.get("sfx", 1.0))
		
		var fs_checkbox = $SettingPanel/MarginContainer/SettingsContainer/FullscreenCheckBox
		if fs_checkbox: fs_checkbox.set_pressed_no_signal(saved.get("full_screen", false))
		
	if master_slider: _update_master_label(master_slider.value)
	if music_slider: _update_music_label(music_slider.value)
	if sfx_slider: _update_sfx_label(sfx_slider.value)
	
	var tut_checkbox = $SettingPanel/MarginContainer/SettingsContainer/TutorialCheckBox
	if tut_checkbox:
		tut_checkbox.set_pressed_no_signal(TutorialManager.is_tutorial_enabled)

func _save_current_settings() -> void:
	var master = master_slider.value if master_slider else 1.0
	var music = music_slider.value if music_slider else 1.0
	var sfx = sfx_slider.value if sfx_slider else 1.0
	var fs_checkbox = $SettingPanel/MarginContainer/SettingsContainer/FullscreenCheckBox
	var fs = fs_checkbox.button_pressed if fs_checkbox else false
	var tut_checkbox = $SettingPanel/MarginContainer/SettingsContainer/TutorialCheckBox
	var tut = tut_checkbox.button_pressed if tut_checkbox else true
	SaveSystem.save_settings(master, music, sfx, fs, tut)

func _update_master_label(value: float) -> void:
	if master_label:
		master_label.text = "Âm lượng tổng: %d%%" % int(value * 100)

func _update_music_label(value: float) -> void:
	if music_label:
		music_label.text = "Âm lượng nhạc: %d%%" % int(value * 100)

func _update_sfx_label(value: float) -> void:
	if sfx_label:
		sfx_label.text = "Âm lượng hiệu ứng: %d%%" % int(value * 100)

func _on_master_slider_value_changed(value: float) -> void:
	_update_master_label(value)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value)
	)
	_save_current_settings()

func _on_music_slider_value_changed(value: float) -> void:
	_update_music_label(value)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(value)
	)
	_save_current_settings()

func _on_sfx_slider_value_changed(value: float) -> void:
	_update_sfx_label(value)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"),
		linear_to_db(value)
	)
	_save_current_settings()

func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	print("DEBUG: _on_fullscreen_check_box_toggled called, toggled_on=", toggled_on)
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var current_mode = DisplayServer.window_get_mode()
	print("DEBUG: DisplayServer.window_get_mode() =", current_mode)
	_save_current_settings()

func _on_tutorial_check_box_toggled(toggled_on: bool) -> void:
	TutorialManager.enable_tutorial(toggled_on)
	_save_current_settings()

func _on_close_btn_pressed() -> void:
	print("DEBUG: _on_close_btn_pressed called")
	visible = false
