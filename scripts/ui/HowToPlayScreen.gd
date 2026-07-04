extends Control
## HowToPlayScreen.gd - visual first-run rules guide.


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_M)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(vbox)

	vbox.add_child(UITheme.title(L10n.t("how.title"), UITheme.FS_LARGE))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UITheme.SPACE_M)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(_mission_card())
	content.add_child(_flow_card())
	content.add_child(_resource_card())
	content.add_child(_global_card())
	content.add_child(_list_card("how.first.title", [
		"how.first.1", "how.first.2", "how.first.3", "how.first.4",
	], UITheme.ACCENT))
	content.add_child(_list_card("how.tips.title", [
		"how.tip.1", "how.tip.2", "how.tip.3", "how.tip.4",
	], UITheme.WARN))

	var back := UITheme.button(L10n.t("common.back"), "ghost", true)
	back.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	vbox.add_child(back)


func _mission_card() -> Control:
	var panel := _card()
	var box := _inner(panel)
	box.add_child(UITheme.label(L10n.t("how.mission.title"), UITheme.FS_BODY, UITheme.ACCENT))
	box.add_child(_callout(L10n.t("how.mission.body"), UITheme.ACCENT))
	box.add_child(_callout(L10n.t("how.mission.losses"), UITheme.DANGER))
	return panel


func _flow_card() -> Control:
	var panel := _card()
	var box := _inner(panel)
	box.add_child(UITheme.label(L10n.t("how.flow.title"), UITheme.FS_BODY, UITheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.SPACE_S)
	grid.add_theme_constant_override("v_separation", UITheme.SPACE_S)
	box.add_child(grid)
	for i in 6:
		grid.add_child(_step_tile(i + 1, L10n.t("how.flow.%d" % (i + 1))))
	return panel


func _resource_card() -> Control:
	var panel := _card()
	var box := _inner(panel)
	box.add_child(UITheme.label(L10n.t("how.resources.title"), UITheme.FS_BODY, UITheme.ACCENT))
	box.add_child(_info_row(L10n.t("game.intel"), L10n.t("how.res.intel"), UITheme.ACCENT))
	box.add_child(_info_row(L10n.t("game.funds"), L10n.t("how.res.funds"), UITheme.TEXT))
	box.add_child(_info_row(L10n.t("game.trust"), L10n.t("how.res.trust"), UITheme.WARN))
	box.add_child(_info_row(L10n.t("game.cover"), L10n.t("how.res.cover"), UITheme.SAFE))
	box.add_child(_info_row(L10n.t("game.heat"), L10n.t("how.res.heat"), UITheme.DANGER))
	return panel


func _global_card() -> Control:
	var panel := _card()
	var box := _inner(panel)
	box.add_child(UITheme.label(L10n.t("how.global.title"), UITheme.FS_BODY, UITheme.ACCENT))
	box.add_child(_meter_hint(L10n.t("game.rival_meter"), L10n.t("how.global.rival"), UITheme.ACCENT))
	box.add_child(_meter_hint(L10n.t("game.global_meter"), L10n.t("how.global.exposure"), UITheme.DANGER))
	box.add_child(_info_row(L10n.t("how.global.stability_label"), L10n.t("how.global.stability"), UITheme.WARN))
	box.add_child(_info_row(L10n.t("how.global.momentum_label"), L10n.t("how.global.momentum"), UITheme.TEXT_DIM))
	return panel


func _list_card(title_key: String, item_keys: Array, color: Color) -> Control:
	var panel := _card()
	var box := _inner(panel)
	box.add_child(UITheme.label(L10n.t(title_key), UITheme.FS_BODY, color))
	for i in item_keys.size():
		var key: String = String(item_keys[i])
		box.add_child(_numbered_line(i + 1, L10n.t(key), color))
	return panel


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _inner(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_S)
	panel.add_child(box)
	return box


func _callout(text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var marker := ColorRect.new()
	marker.color = Color(color.r, color.g, color.b, 0.8)
	marker.custom_minimum_size = Vector2(6, 0)
	row.add_child(marker)
	var lbl := UITheme.label(text, UITheme.FS_SMALL, UITheme.TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row


func _step_tile(number: int, text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.CARD_RAISED, UITheme.EDGE))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	panel.add_child(row)
	var n := UITheme.label(str(number), UITheme.FS_BODY, UITheme.ACCENT)
	n.custom_minimum_size = Vector2(42, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(n)
	var lbl := UITheme.label(text, UITheme.FS_TINY, UITheme.TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return panel


func _info_row(caption: String, body: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var cap := UITheme.label(caption, UITheme.FS_TINY, color)
	cap.custom_minimum_size = Vector2(190, 0)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(cap)
	var lbl := UITheme.label(body, UITheme.FS_TINY, UITheme.TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row


func _meter_hint(caption: String, body: String, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	box.add_child(row)
	var cap := UITheme.label(caption, UITheme.FS_TINY, color)
	cap.custom_minimum_size = Vector2(260, 0)
	row.add_child(cap)
	var bar := UITheme.progress_bar(color, 18.0)
	bar.value = 64
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var lbl := UITheme.label(body, UITheme.FS_TINY, UITheme.TEXT_DIM)
	box.add_child(lbl)
	return box


func _numbered_line(number: int, text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var n := UITheme.label(str(number), UITheme.FS_TINY, color)
	n.custom_minimum_size = Vector2(36, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(n)
	var lbl := UITheme.label(text, UITheme.FS_TINY, UITheme.TEXT)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row
