extends Control
## AgentRosterPanel.gd - full-screen agent list.
## select_mode true: picking an agent for an operation.
## select_mode false: reviewing the roster from the bottom bar.

signal agent_selected(agent_id: String)
signal closed

var _select_mode: bool = false
var _list: VBoxContainer
var _title_label: Label


func _ready() -> void:
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(UITheme.BG_DEEP.r, UITheme.BG_DEEP.g, UITheme.BG_DEEP.b, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_M)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(vbox)

	_title_label = UITheme.title("AGENT ROSTER", UITheme.FS_TITLE)
	vbox.add_child(_title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", UITheme.SPACE_S)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var back := UITheme.button("BACK", "ghost", true)
	back.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	vbox.add_child(back)


func open(select_mode: bool) -> void:
	_select_mode = select_mode
	_title_label.text = "SELECT AGENT" if select_mode else "AGENT ROSTER"
	_rebuild()
	visible = true
	TutorialManager.notify("roster_opened")


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	for agent in GameState.agents:
		_list.add_child(_agent_card(agent))


func _agent_card(agent: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UITheme.SPACE_S)
	vbox.add_child(top)

	top.add_child(AgentPortrait.new(String(agent["id"])))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	top.add_child(info)
	info.add_child(UITheme.label("%s  ·  LV %d" % [String(agent["name"]).to_upper(), int(agent["level"])], UITheme.FS_BODY, UITheme.ACCENT))
	info.add_child(UITheme.label(String(agent["role"]), UITheme.FS_SMALL, UITheme.TEXT))
	info.add_child(UITheme.label(AgentData.trait_name(agent["trait"]) + " - " + AgentData.trait_desc(agent["trait"]), 22, UITheme.TEXT_DIM))
	var status_color := UITheme.SAFE if agent["status"] == "Ready" else UITheme.WARN
	info.add_child(UITheme.label("Status: %s   Fatigue: %d" % [agent["status"], int(agent["fatigue"])], 22, status_color))

	# Compact skill strip.
	var skills := HBoxContainer.new()
	skills.add_theme_constant_override("separation", UITheme.SPACE_S)
	vbox.add_child(skills)
	var skill_data := [
		["ANL", int(agent["analysis"])], ["FLD", int(agent["fieldcraft"])],
		["DIP", int(agent["diplomacy"])], ["TEC", int(agent["technical"])],
		["RSV", int(agent["resolve"])],
	]
	for s in skill_data:
		var chip := UITheme.label("%s %d" % [s[0], s[1]], 22, UITheme.level_color(float(s[1]) * 10.0))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skills.add_child(chip)

	if _select_mode:
		var pick := UITheme.button("ASSIGN " + String(agent["name"]).to_upper(), "primary", true)
		pick.pressed.connect(func() -> void:
			visible = false
			TutorialManager.notify("agent_selected")
			agent_selected.emit(String(agent["id"])))
		vbox.add_child(pick)
	return panel
