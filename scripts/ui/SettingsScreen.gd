extends Control
## SettingsScreen.gd - volume, haptics, text size, motion, language, save reset.
## Changes persist immediately through SettingsManager.

var _confirm_reset: bool = false
var _reset_btn: Button
var _content: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_L)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UITheme.SPACE_M)
	scroll.add_child(_content)
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()

	_content.add_child(UITheme.title(L10n.t("settings.title")))
	_content.add_child(UITheme.spacer(UITheme.SPACE_S))

	_content.add_child(_language_row())
	_content.add_child(_slider_row(L10n.t("settings.music"), SettingsManager.music_volume,
		func(v: float) -> void:
			SettingsManager.music_volume = v
			SettingsManager.save_settings()))
	_content.add_child(_slider_row(L10n.t("settings.sfx"), SettingsManager.sfx_volume,
		func(v: float) -> void:
			SettingsManager.sfx_volume = v
			SettingsManager.save_settings()))

	_content.add_child(_toggle_row(L10n.t("settings.haptics"), SettingsManager.haptics_enabled,
		func(v: bool) -> void:
			SettingsManager.haptics_enabled = v
			SettingsManager.save_settings()))
	_content.add_child(_toggle_row(L10n.t("settings.large_text"), SettingsManager.large_text,
		func(v: bool) -> void:
			SettingsManager.large_text = v
			SettingsManager.save_settings()))
	_content.add_child(_toggle_row(L10n.t("settings.reduce_motion"), SettingsManager.reduce_motion,
		func(v: bool) -> void:
			SettingsManager.reduce_motion = v
			SettingsManager.save_settings()))

	_content.add_child(_about_card())
	_content.add_child(UITheme.hseparator())
	_reset_btn = UITheme.button(L10n.t("settings.reset"), "danger", true)
	_reset_btn.pressed.connect(_on_reset_pressed)
	_content.add_child(_reset_btn)

	_content.add_child(UITheme.spacer(UITheme.SPACE_M))
	var back := UITheme.button(L10n.t("common.back"), "ghost", true)
	back.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	_content.add_child(back)


func _language_row() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(box)
	box.add_child(UITheme.label(L10n.t("settings.language"), UITheme.FS_BODY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	box.add_child(row)
	for code in L10n.language_codes():
		var selected := code == L10n.current_locale()
		var btn := UITheme.button(L10n.language_label(code), "primary" if selected else "ghost", true)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_language_selected.bind(code))
		row.add_child(btn)
	return panel


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


func _about_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(box)
	box.add_child(UITheme.label(L10n.t("settings.about_title"), UITheme.FS_SMALL, UITheme.ACCENT))
	box.add_child(UITheme.label(L10n.t("settings.about_body"), UITheme.FS_TINY, UITheme.TEXT_DIM))
	return panel


func _on_language_selected(code: String) -> void:
	L10n.set_locale(code)
	_confirm_reset = false
	_rebuild()


func _on_reset_pressed() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_btn.text = L10n.t("settings.reset_confirm")
		return
	SettingsManager.reset_all_data()
	_confirm_reset = false
	_reset_btn.text = L10n.t("settings.reset_done")
	_reset_btn.disabled = true
