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
	dim.color = Color(0, 0, 0, 0.45)
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
	var intel_lv: int = int(r["intel_level"])

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.SPACE_S)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(UITheme.label(String(r["name"]).to_upper(), UITheme.FS_LARGE, UITheme.ACCENT))
	var tag_text: String = L10n.t("region.classification", [String(r["hidden_tag"]) if r["tag_revealed"] else L10n.t("region.unknown")])
	name_box.add_child(UITheme.label(tag_text, UITheme.FS_SMALL, UITheme.TEXT_DIM))
	header.add_child(name_box)
	var intel_badge := UITheme.label(L10n.t("region.intel_level", [intel_lv]), UITheme.FS_SMALL, UITheme.ACCENT_DIM)
	intel_badge.custom_minimum_size = Vector2(170, 0)
	intel_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(intel_badge)
	_content.add_child(header)

	if bool(r["collapsed"]):
		_content.add_child(UITheme.label(L10n.t("region.collapsed"), UITheme.FS_BODY, UITheme.COLLAPSED))
		_actions.add_child(_close_button())
		return

	_content.add_child(_stat_row(L10n.t("region.stability"), float(r["stability"]), UITheme.level_color(float(r["stability"])), true))
	_content.add_child(_stat_row(L10n.t("region.rival"), float(r["rival_influence"]), UITheme.danger_color(float(r["rival_influence"])), intel_lv >= 1))
	_content.add_child(_stat_row(L10n.t("region.surveillance"), float(r["surveillance"]), UITheme.danger_color(float(r["surveillance"])), intel_lv >= 1))
	_content.add_child(_stat_row(L10n.t("region.pressure"), float(r["public_pressure"]), UITheme.danger_color(float(r["public_pressure"])), intel_lv >= 2))
	_content.add_child(_stat_row(L10n.t("region.network"), float(r["local_network"]), UITheme.ACCENT, true))
	_content.add_child(_stat_row(L10n.t("region.opportunity"), float(r["opportunity"]), UITheme.SAFE, intel_lv >= 2))
	if intel_lv == 0:
		_content.add_child(UITheme.label(L10n.t("region.map_signals_hint"), UITheme.FS_TINY, UITheme.TEXT_DIM))

	var plan := UITheme.button(L10n.t("region.choose_agent"), "primary", true)
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


func _stat_row(label_text: String, value: float, color: Color, known: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var lbl := UITheme.label(label_text, UITheme.FS_SMALL, UITheme.TEXT_DIM)
	lbl.custom_minimum_size = Vector2(250, 0)
	row.add_child(lbl)
	if known:
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
		var unknown := UITheme.label(L10n.t("region.need_intel"), UITheme.FS_SMALL, UITheme.EDGE_BRIGHT)
		unknown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(unknown)
	return row
