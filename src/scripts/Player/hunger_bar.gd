extends ProgressBar

var _value_label: Label


func _ready() -> void:
	min_value = 0.0
	max_value = 100.0
	value = 100.0
	show_percentage = false
	_setup_value_label()
	_update_value_label()


func init_from_player(max_hunger: float) -> void:
	min_value = 0.0
	max_value = max_hunger
	value = max_hunger
	_update_value_label()


func set_hunger(current: float, max_hunger: float) -> void:
	if max_hunger <= 0:
		max_value = 0.0
		value = 0.0
		_update_value_label()
		return
	max_value = max_hunger
	value = clamp(current, 0.0, max_hunger)
	_update_value_label()


func _setup_value_label() -> void:
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_theme_color_override("font_color"):
		_value_label.add_theme_color_override("font_color", get_theme_color("font_color"))
	if has_theme_color_override("font_outline_color"):
		_value_label.add_theme_color_override("font_outline_color", get_theme_color("font_outline_color"))
	if has_theme_constant_override("outline_size"):
		_value_label.add_theme_constant_override("outline_size", get_theme_constant("outline_size"))
	add_child(_value_label)


func _update_value_label() -> void:
	if not _value_label:
		return
	_value_label.text = "%d / %d" % [int(round(value)), int(round(max_value))]
