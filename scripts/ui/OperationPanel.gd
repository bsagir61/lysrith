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
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_M)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(vbox)

	vbox.add_child(UITheme.title("SELECT OPERATION", UITheme.FS_TITLE))
	_header = UITheme.label("", UITheme.FS_SMALL, UITheme.TEXT_DIM)
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

	_confirm_btn = UITheme.button("SELECT AN OPERATION", "primary")
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
	_confirm_btn.text = "SELECT AN OPERATION"
	var region: Dictionary = GameState.get_region(region_id)
	var agent: Dictionary = GameState.get_agent(agent_id)
	_header.text = "%s  ·  %s" % [String(region["name"]).to_upper(), String(agent["name"]).to_upper()]
	_rebuild(region, agent)
	visible = true


func _rebuild(region: Dictionary, agent: Dictionary) -> void:
	for child in _list.get_children():
		child.queue_free()
	_cards.clear()
	for op in OperationData.operations:
		_list.add_child(_op_card(region, agent, op))


func _op_card(region: Dictionary, agent: Dictionary, op: Dictionary) -> Control:
	var op_id := String(op["id"])
	var chance := TurnResolver.compute_chance(region, agent, op)
	var costs := TurnResolver.compute_costs(agent, op)
	var heat := TurnResolver.heat_preview(agent, op)
	var affordable := TurnResolver.can_afford(costs)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards[op_id] = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var name_lbl := UITheme.label(String(op["name"]).to_upper(), UITheme.FS_BODY, UITheme.ACCENT if affordable else UITheme.TEXT_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	var chance_lbl := UITheme.label("%d%%" % chance, UITheme.FS_BODY, UITheme.level_color(float(chance)))
	top.add_child(chance_lbl)

	vbox.add_child(UITheme.label(String(op["desc"]), 22, UITheme.TEXT_DIM))

	var cost_parts: Array[String] = []
	if int(costs["funds"]) > 0:
		cost_parts.append("%d Funds" % int(costs["funds"]))
	if int(costs["intel"]) > 0:
		cost_parts.append("%d Intel" % int(costs["intel"]))
	if int(costs["trust"]) > 0:
		cost_parts.append("%d Trust" % int(costs["trust"]))
	var cost_text := "Cost: " + (", ".join(cost_parts) if not cost_parts.is_empty() else "None")
	var heat_text := "   Heat: +%d" % heat if heat > 0 else "   Heat: none"
	var detail := UITheme.label(cost_text + heat_text + "   ->  " + String(op.get("effect_hint", "")), 22,
		UITheme.TEXT if affordable else UITheme.DANGER)
	vbox.add_child(detail)
	if not affordable:
		vbox.add_child(UITheme.label("Insufficient resources.", 22, UITheme.DANGER))

	# Whole card is tappable.
	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.disabled = not affordable
	tap.pressed.connect(func() -> void: _select_op(op_id))
	panel.add_child(tap)
	return panel


func _select_op(op_id: String) -> void:
	_selected_op = op_id
	AudioManager.play_click()
	for id in _cards:
		var style := UITheme.card_style(UITheme.ACCENT if id == op_id else UITheme.EDGE)
		_cards[id].add_theme_stylebox_override("panel", style)
	var op: Dictionary = OperationData.get_def(op_id)
	_confirm_btn.disabled = false
	_confirm_btn.text = "CONFIRM: " + String(op["name"]).to_upper()
	if op_id == "map_signals":
		TutorialManager.notify("map_signals_selected")


func _on_confirm() -> void:
	if _selected_op == "":
		return
	visible = false
	AudioManager.play_confirm()
	operation_confirmed.emit(_selected_op)
