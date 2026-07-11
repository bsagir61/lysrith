extends Control
## RegionPanel.gd - bottom-sheet dossier for a selected region.
## Reads region state from GameState; intel level gates what is visible.

signal plan_requested(region_id: String)
signal closed

var _region_id: String = ""
var _sheet: PanelContainer
var _content: VBoxContainer
var _actions: HBoxContainer


func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, UITheme.OVERLAY_OPACITY * 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			close())
	add_child(dim)

	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.EDGE_BRIGHT))
	_sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sheet.offset_left = UITheme.SPACE_S
	_sheet.offset_right = -UITheme.SPACE_S
	_sheet.offset_top = -UITheme.BOTTOM_SHEET_HEIGHT
	_sheet.offset_bottom = -UITheme.SPACE_S
	add_child(_sheet)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UITheme.SPACE_S)
	_sheet.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UITheme.SPACE_S)
	scroll.add_child(_content)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", UITheme.SPACE_S)
	outer.add_child(_actions)


func open(region_id: String) -> void:
	_region_id = region_id
	_rebuild()
	visible = true
	if not SettingsManager.reduce_motion:
		_sheet.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_sheet, "modulate:a", 1.0, UITheme.ANIM_FAST)


func close() -> void:
	visible = false
	closed.emit()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	for child in _actions.get_children():
		child.queue_free()
	var r: Dictionary = GameState.get_region(_region_id)
	if r.is_empty():
		return
	var intel_lv: int = int(r.get("intel_level", 0))
	var assessment: Dictionary = RegionAssessment.assess(r)
	var assessment_color: Color = _assessment_color(String(assessment.get("id", "under_observed")))

	_content.add_child(UITheme.label(L10n.region_name(r), UITheme.FS_LARGE, UITheme.ACCENT))
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", UITheme.SPACE_S)
	var assessment_badge := UITheme.status_chip(L10n.t(String(assessment["text_key"])), assessment_color, bool(assessment.get("urgent", false)))
	assessment_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges.add_child(assessment_badge)
	var intel_badge := UITheme.status_chip(L10n.t("region.intel_short", [intel_lv]), UITheme.ACCENT_DIM)
	intel_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges.add_child(intel_badge)
	_content.add_child(badges)

	var classification: String = L10n.t("region.classified")
	if bool(r.get("tag_revealed", false)):
		classification = L10n.t(RegionTagRules.name_key(String(r.get("hidden_tag", ""))))
	_content.add_child(UITheme.label(L10n.t("region.classification", [classification]), UITheme.FS_SMALL, UITheme.TEXT_DIM))

	_content.add_child(_section(L10n.t("region.section.situation")))
	_content.add_child(_callout(L10n.t(RegionAssessment.situation_key(r)), assessment_color, UITheme.FS_SMALL))

	if bool(r.get("collapsed", false)):
		_content.add_child(UITheme.label(L10n.t("region.collapsed"), UITheme.FS_BODY, UITheme.COLLAPSED))
		_actions.add_child(_close_button())
		return

	_content.add_child(_section(L10n.t("region.section.metrics")))
	_content.add_child(_stat_row(L10n.t("region.stability"), float(r.get("stability", 0)), UITheme.level_color(float(r.get("stability", 0))), 0, intel_lv))
	_content.add_child(_stat_row(L10n.t("region.network"), float(r.get("local_network", 0)), UITheme.ACCENT, 0, intel_lv))
	_content.add_child(_stat_row(L10n.t("region.rival"), float(r.get("rival_influence", 0)), UITheme.danger_color(float(r.get("rival_influence", 0))), 1, intel_lv))
	_content.add_child(_stat_row(L10n.t("region.surveillance"), float(r.get("surveillance", 0)), UITheme.danger_color(float(r.get("surveillance", 0))), 1, intel_lv))
	_content.add_child(_stat_row(L10n.t("region.pressure"), float(r.get("public_pressure", 0)), UITheme.danger_color(float(r.get("public_pressure", 0))), 2, intel_lv))
	_content.add_child(_stat_row(L10n.t("region.opportunity"), float(r.get("opportunity", 0)), UITheme.SAFE, 2, intel_lv))

	var gaps: Array[String] = _intelligence_gaps(r, intel_lv)
	if not gaps.is_empty():
		_content.add_child(_section(L10n.t("region.section.gaps")))
		for gap_key in gaps:
			_content.add_child(_gap_row(L10n.t(gap_key)))

	if bool(r.get("tag_revealed", false)):
		_content.add_child(_section(L10n.t("region.section.identity")))
		var tag: String = String(r.get("hidden_tag", ""))
		_content.add_child(_identity_view(tag))

	_content.add_child(_section(L10n.t("region.section.recommendations")))
	var recommendations: Array[Dictionary] = StrategicAdvisor.recommendations(r, {"heat": GameState.heat})
	if recommendations.is_empty():
		_content.add_child(UITheme.label(L10n.t("advisor.none"), UITheme.FS_TINY, UITheme.TEXT_DIM))
	else:
		for recommendation in recommendations:
			_content.add_child(_recommendation_card(recommendation))

	var plan := UITheme.button(L10n.t("region.plan_operation"), "primary", true)
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.pressed.connect(func() -> void:
		TutorialManager.notify("region_read")
		plan_requested.emit(_region_id))
	_actions.add_child(plan)
	_actions.add_child(_close_button())


func _close_button() -> Button:
	var b := UITheme.button(L10n.t("common.close"), "ghost", true)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(close)
	return b


func _stat_row(label_text: String, value: float, color: Color, required_level: int, intel_level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var lbl := UITheme.label(label_text, UITheme.FS_SMALL, UITheme.TEXT_DIM)
	lbl.custom_minimum_size = Vector2(250, 0)
	row.add_child(lbl)
	if intel_level >= required_level:
		var bar := UITheme.progress_bar(color, 22.0)
		bar.value = value
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := UITheme.label(str(int(value)), UITheme.FS_SMALL, color)
		val.custom_minimum_size = Vector2(70, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
	else:
		var unknown := UITheme.label(L10n.t("region.requires_intel", [required_level]), UITheme.FS_TINY, UITheme.EDGE_BRIGHT)
		unknown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(unknown)
	return row


func _section(text: String) -> Label:
	return UITheme.section_header(text, UITheme.ACCENT)


func _intelligence_gaps(region: Dictionary, intel_level: int) -> Array[String]:
	var gaps: Array[String] = []
	if intel_level == 0:
		gaps.append("region.gap.level1")
	elif intel_level == 1:
		gaps.append("region.gap.level2")
	elif intel_level == 2:
		gaps.append("region.gap.level3")
	if not bool(region.get("tag_revealed", false)):
		gaps.append("region.gap.identity")
	return gaps


func _gap_row(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var marker := UITheme.label("?", UITheme.FS_TINY, UITheme.WARN)
	marker.custom_minimum_size = Vector2(30, 0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(marker)
	var gap_label := UITheme.label(text, UITheme.FS_TINY, UITheme.TEXT_DIM)
	gap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap_label)
	return row


func _recommendation_card(recommendation: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var marker := ColorRect.new()
	marker.color = UITheme.ACCENT_DIM
	marker.custom_minimum_size = Vector2(UITheme.SECTION_MARKER_WIDTH, 0)
	row.add_child(marker)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	row.add_child(box)
	var op_id: String = String(recommendation.get("op_id", ""))
	box.add_child(UITheme.label(L10n.t("operation.%s.name" % op_id), UITheme.FS_TINY, UITheme.ACCENT))
	box.add_child(UITheme.label(L10n.t(String(recommendation.get("text_key", "advisor.none"))), UITheme.FS_TINY, UITheme.TEXT_DIM))
	return row


func _callout(text: String, color: Color, font_size: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var marker := ColorRect.new()
	marker.color = color
	marker.custom_minimum_size = Vector2(UITheme.SECTION_MARKER_WIDTH, 0)
	row.add_child(marker)
	var copy := UITheme.label(text, font_size, UITheme.TEXT)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	return row


func _identity_view(tag: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var marker := ColorRect.new()
	marker.color = UITheme.ACCENT
	marker.custom_minimum_size = Vector2(UITheme.SECTION_MARKER_WIDTH, 0)
	row.add_child(marker)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	row.add_child(box)
	box.add_child(UITheme.label(L10n.t(RegionTagRules.name_key(tag)), UITheme.FS_SMALL, UITheme.ACCENT))
	box.add_child(UITheme.label(L10n.t(RegionTagRules.description_key(tag)), UITheme.FS_TINY, UITheme.TEXT_DIM))
	return row


func _assessment_color(id: String) -> Color:
	match id:
		"critical": return UITheme.DANGER
		"unstable": return UITheme.WARN
		"contested": return UITheme.WARN
		"promising": return UITheme.SAFE
		"stable": return UITheme.ACCENT
	return UITheme.EDGE_BRIGHT
