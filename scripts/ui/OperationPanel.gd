extends Control
## OperationPanel.gd - operation selection with full transparency:
## cost, success chance, Heat impact and expected effect are shown
## before the player commits.

signal operation_confirmed(op_id: String)
signal closed

var _region_id: String = ""
var _agent_id: String = ""
var _selected_op: String = ""
var _list: VBoxContainer
var _confirm_btn: Button
var _header: Label
var _cards: Dictionary = {}


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
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_M)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(vbox)

	vbox.add_child(UITheme.title("SELECT OPERATION", UITheme.FS_LARGE))
	_header = UITheme.label("", UITheme.FS_TINY, UITheme.TEXT_DIM)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", UITheme.SPACE_S)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_confirm_btn = UITheme.button("CHOOSE AN OPERATION", "primary")
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_btn)

	var back := UITheme.button("BACK", "ghost", true)
	back.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	vbox.add_child(back)


func open(region_id: String, agent_id: String) -> void:
	_region_id = region_id
	_agent_id = agent_id
	_selected_op = ""
	_confirm_btn.disabled = true
	_confirm_btn.text = "CHOOSE AN OPERATION"
	var region: Dictionary = GameState.get_region(region_id)
	var agent: Dictionary = GameState.get_agent(agent_id)
	_header.text = "%s / %s" % [String(region["name"]).to_upper(), String(agent["name"]).to_upper()]
	_rebuild(region, agent)
	visible = true


func _rebuild(region: Dictionary, agent: Dictionary) -> void:
	for child in _list.get_children():
		child.queue_free()
	_cards.clear()
	for op in OperationData.operations:
		_list.add_child(_op_card(region, agent, op))


func _op_card(region: Dictionary, agent: Dictionary, op: Dictionary) -> Control:
	var op_id: String = String(op["id"])
	var chance: int = TurnResolver.compute_chance(region, agent, op)
	var costs: Dictionary = TurnResolver.compute_costs(agent, op)
	var heat: int = TurnResolver.heat_preview(agent, op)
	var affordable: bool = TurnResolver.can_afford(costs)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if affordable and event is InputEventScreenTouch and event.pressed:
			_select_op(op_id)
		if affordable and event is InputEventMouseButton and event.pressed:
			_select_op(op_id))
	_cards[op_id] = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UITheme.SPACE_S)
	vbox.add_child(top)
	var name_lbl: Label = UITheme.label(String(op["name"]).to_upper(), UITheme.FS_BODY, UITheme.ACCENT if affordable else UITheme.TEXT_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var chance_lbl := UITheme.label("Chance %d%%" % chance, UITheme.FS_TINY, UITheme.level_color(float(chance)))
	chance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(chance_lbl)

	vbox.add_child(UITheme.label(String(op["desc"]), UITheme.FS_TINY, UITheme.TEXT_DIM))

	var cost_parts: Array[String] = []
	if int(costs["funds"]) > 0:
		cost_parts.append("%d Funds" % int(costs["funds"]))
	if int(costs["intel"]) > 0:
		cost_parts.append("%d Intel" % int(costs["intel"]))
	if int(costs["trust"]) > 0:
		cost_parts.append("%d Trust" % int(costs["trust"]))
	var cost_text: String = ", ".join(cost_parts) if not cost_parts.is_empty() else "None"
	var heat_text: String = "+%d" % heat if heat > 0 else "None"
	var detail_color: Color = UITheme.TEXT if affordable else UITheme.DANGER
	vbox.add_child(_detail_row("Cost", cost_text, detail_color))
	vbox.add_child(_detail_row("Heat", heat_text, UITheme.danger_color(float(heat))))
	vbox.add_child(_detail_row("Effect", String(op.get("effect_hint", "")), detail_color))
	if not affordable:
		vbox.add_child(UITheme.label("Insufficient resources.", UITheme.FS_TINY, UITheme.DANGER))
	return panel


func _detail_row(caption: String, value: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var cap := UITheme.label(caption, UITheme.FS_TINY, UITheme.TEXT_DIM)
	cap.custom_minimum_size = Vector2(100, 0)
	row.add_child(cap)
	var val := UITheme.label(value, UITheme.FS_TINY, color)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	return row


func _select_op(op_id: String) -> void:
	_selected_op = op_id
	AudioManager.play_click()
	for id in _cards:
		var card: PanelContainer = _cards[id]
		var style := UITheme.card_style(UITheme.ACCENT if id == op_id else UITheme.EDGE)
		card.add_theme_stylebox_override("panel", style)
	_confirm_btn.disabled = false
	_confirm_btn.text = "RUN OPERATION"
	if op_id == "map_signals":
		TutorialManager.notify("map_signals_selected")


func _on_confirm() -> void:
	if _selected_op == "":
		return
	visible = false
	AudioManager.play_confirm()
	operation_confirmed.emit(_selected_op)
