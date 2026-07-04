extends Control
## SettingsScreen.gd - volume, haptics, text size, motion, save reset.
## Changes persist immediately through SettingsManager.

var _confirm_reset: bool = false
var _reset_btn: Button


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_L)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_M)
	margin.add_child(vbox)

	vbox.add_child(UITheme.title("SETTINGS"))
	vbox.add_child(UITheme.spacer(UITheme.SPACE_S))

	vbox.add_child(_slider_row("Music Volume", SettingsManager.music_volume,
		func(v: float) -> void:
			SettingsManager.music_volume = v
			SettingsManager.save_settings()))
	vbox.add_child(_slider_row("SFX Volume", SettingsManager.sfx_volume,
		func(v: float) -> void:
			SettingsManager.sfx_volume = v
			SettingsManager.save_settings()))

	vbox.add_child(_toggle_row("Haptic Feedback", SettingsManager.haptics_enabled,
		func(v: bool) -> void:
			SettingsManager.haptics_enabled = v
			SettingsManager.save_settings()))
	vbox.add_child(_toggle_row("Large Text", SettingsManager.large_text,
		func(v: bool) -> void:
			SettingsManager.large_text = v
			SettingsManager.save_settings()))
	vbox.add_child(_toggle_row("Reduce Motion", SettingsManager.reduce_motion,
		func(v: bool) -> void:
			SettingsManager.reduce_motion = v
			SettingsManager.save_settings()))

	vbox.add_child(UITheme.hseparator())
	_reset_btn = UITheme.button("RESET SAVE DATA", "danger", true)
	_reset_btn.pressed.connect(_on_reset_pressed)
	vbox.add_child(_reset_btn)

	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))
	var back := UITheme.button("BACK", "ghost", true)
	back.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	vbox.add_child(back)


func _slider_row(label_text: String, value: float, on_change: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(row)
	row.add_child(UITheme.label(label_text, UITheme.FS_BODY))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 64)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return panel


func _toggle_row(label_text: String, value: bool, on_change: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_M)
	panel.add_child(row)
	var lbl := UITheme.label(label_text, UITheme.FS_BODY)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var check := CheckButton.new()
	check.button_pressed = value
	check.custom_minimum_size = Vector2(120, UITheme.TOUCH_MIN)
	check.toggled.connect(on_change)
	row.add_child(check)
	return panel


func _on_reset_pressed() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = "TAP AGAIN TO CONFIRM RESET"
		return
	SettingsManager.reset_all_data()
	_confirm_reset = false
	_reset_btn.text = "SAVE DATA CLEARED"
	_reset_btn.disabled = true
