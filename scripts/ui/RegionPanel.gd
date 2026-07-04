extends Control
## RegionPanel.gd - bottom-sheet dossier for a selected region.
## Reads region state from GameState; intel level gates what is visible.

signal plan_requested(region_id: String)
signal closed

var _region_id: String = ""
var _sheet: PanelContainer
var _content: VBoxContainer


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
	_sheet.offset_bottom = -UITheme.SPACE_S
	add_child(_sheet)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", UITheme.SPACE_S)
	_sheet.add_child(_content)


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
	var r: Dictionary = GameState.get_region(_region_id)
	if r.is_empty():
		return
	var intel_lv := int(r["intel_level"])

	# Header: name + tag + intel pips.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.SPACE_S)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(UITheme.label(String(r["name"]).to_upper(), UITheme.FS_LARGE, UITheme.ACCENT))
	var tag_text := "Classification: " + (String(r["hidden_tag"]) if r["tag_revealed"] else "UNKNOWN")
	name_box.add_child(UITheme.label(tag_text, UITheme.FS_SMALL, UITheme.TEXT_DIM))
	header.add_child(name_box)
	header.add_child(UITheme.label("INTEL %d/3" % intel_lv, UITheme.FS_SMALL, UITheme.ACCENT_DIM))
	_content.add_child(header)

	if r["collapsed"]:
		_content.add_child(UITheme.label("REGION COLLAPSED. No further operations possible here.", UITheme.FS_BODY, UITheme.COLLAPSED))
		_content.add_child(_close_button())
		return

	# Stat bars, gated by intel level.
	_content.add_child(_stat_row("Stability", float(r["stability"]), UITheme.level_color(float(r["stability"])), true))
	_content.add_child(_stat_row("Rival Influence", float(r["rival_influence"]), UITheme.danger_color(float(r["rival_influence"])), intel_lv >= 1))
	_content.add_child(_stat_row("Surveillance", float(r["surveillance"]), UITheme.danger_color(float(r["surveillance"])), intel_lv >= 1))
	_content.add_child(_stat_row("Public Pressure", float(r["public_pressure"]), UITheme.danger_color(float(r["public_pressure"])), intel_lv >= 2))
	_content.add_child(_stat_row("Local Network", float(r["local_network"]), UITheme.ACCENT, true))
	_content.add_child(_stat_row("Opportunity", float(r["opportunity"]), UITheme.SAFE, intel_lv >= 2))
	if intel_lv == 0:
		_content.add_child(UITheme.label("Run Map Signals here to reveal more.", 22, UITheme.TEXT_DIM))

	var plan := UITheme.button("PLAN OPERATION", "primary")
	plan.pressed.connect(func() -> void:
		TutorialManager.notify("region_read")
		plan_requested.emit(_region_id))
	_content.add_child(plan)
	_content.add_child(_close_button())


func _close_button() -> Button:
	var b := UITheme.button("CLOSE", "ghost", true)
	b.pressed.connect(close)
	return b


func _stat_row(label_text: String, value: float, color: Color, known: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var lbl := UITheme.label(label_text, UITheme.FS_SMALL, UITheme.TEXT_DIM)
	lbl.custom_minimum_size = Vector2(320, 0)
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
		var unknown := UITheme.label("— insufficient intel —", UITheme.FS_SMALL, UITheme.EDGE_BRIGHT)
		unknown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(unknown)
	return row
