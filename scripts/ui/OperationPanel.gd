extends Control
## OperationPanel.gd - region and agent planning view. Every displayed value
## comes from TurnResolver, which also reuses the same preview during resolution.

signal operation_confirmed(op_id: String)
signal closed

var _region_id: String = ""
var _agent_id: String = ""
var _selected_op: String = ""
var _selected_preview: Dictionary = {}
var _list: VBoxContainer
var _scroll: ScrollContainer
var _context: VBoxContainer
var _confirm_btn: Button
var _warning_label: Label
var _risk_acknowledged: bool = false


func _ready() -> void:
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(UITheme.BG_DEEP.r, UITheme.BG_DEEP.g, UITheme.BG_DEEP.b, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := UITheme.safe_area_margin()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(vbox)
	vbox.add_child(UITheme.title(L10n.t("operation.title"), UITheme.FS_LARGE))

	var context_card := UITheme.info_card(UITheme.EDGE_BRIGHT, true)
	vbox.add_child(context_card)
	_context = VBoxContainer.new()
	_context.add_theme_constant_override("separation", UITheme.SPACE_XS)
	context_card.add_child(_context)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", UITheme.SPACE_S)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_warning_label = UITheme.label("", UITheme.FS_TINY, UITheme.DANGER)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.visible = false
	vbox.add_child(_warning_label)

	_confirm_btn = UITheme.button(L10n.t("operation.choose"), "primary")
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	vbox.add_child(_confirm_btn)

	var back := UITheme.button(L10n.t("common.back"), "ghost", true)
	back.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	vbox.add_child(back)


func open(region_id: String, agent_id: String) -> void:
	_region_id = region_id
	_agent_id = agent_id
	_selected_op = ""
	_selected_preview = {}
	_risk_acknowledged = false
	_warning_label.visible = false
	_confirm_btn.disabled = true
	_confirm_btn.text = L10n.t("operation.choose")
	var region: Dictionary = GameState.get_region(region_id)
	var agent: Dictionary = GameState.get_agent(agent_id)
	_rebuild_context(region, agent)
	_rebuild(region, agent)
	visible = true


func _rebuild_context(region: Dictionary, agent: Dictionary) -> void:
	_clear(_context)
	var classification: String = L10n.t("region.classified")
	if bool(region.get("tag_revealed", false)):
		classification = L10n.t(RegionTagRules.name_key(String(region.get("hidden_tag", ""))))
	_context.add_child(UITheme.label(L10n.t("operation.context.region", [region.get("name", _region_id), classification]), UITheme.FS_SMALL, UITheme.ACCENT))
	_context.add_child(UITheme.label(L10n.t("operation.context.agent", [agent.get("name", _agent_id), int(agent.get("fatigue", 0))]), UITheme.FS_TINY, UITheme.TEXT_DIM))


func _rebuild(region: Dictionary, agent: Dictionary, preserve_scroll: bool = false) -> void:
	var scroll_position: int = _scroll.scroll_vertical if preserve_scroll else 0
	_clear(_list)
	for op_variant in OperationData.operations:
		var op: Dictionary = op_variant
		_list.add_child(_op_card(region, agent, op))
	call_deferred("_restore_scroll", scroll_position)


func _op_card(region: Dictionary, agent: Dictionary, op: Dictionary) -> Control:
	var op_id: String = String(op.get("id", ""))
	var preview: Dictionary = TurnResolver.preview_operation(region, agent, op)
	var selected: bool = op_id == _selected_op
	var affordable: bool = bool(preview.get("affordable", false))
	var available: bool = affordable and not bool(region.get("collapsed", false))
	var risk: String = String(preview.get("risk", "severe"))
	var risk_color: Color = UITheme.semantic_risk_color(risk)
	var border: Color = UITheme.ACCENT if selected else (UITheme.EDGE if available else UITheme.DANGER)

	var panel := UITheme.info_card(border, selected)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_select_op(op_id)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_op(op_id))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UITheme.SPACE_S)
	vbox.add_child(top)
	var name_label := UITheme.label(L10n.t("operation.%s.name" % op_id), UITheme.FS_BODY, UITheme.ACCENT if available else UITheme.TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var risk_badge := UITheme.status_chip(L10n.t("operation.risk.%s" % risk), risk_color, risk == "severe")
	risk_badge.custom_minimum_size = Vector2(UITheme.RISK_BADGE_WIDTH, UITheme.STATUS_MIN_HEIGHT)
	top.add_child(risk_badge)

	vbox.add_child(UITheme.label(L10n.t("operation.%s.description" % op_id), UITheme.FS_TINY, UITheme.TEXT_DIM))
	var skill_id: String = String(op.get("skill", "analysis"))
	vbox.add_child(UITheme.modifier_row(
		L10n.t("operation.required_skill"),
		L10n.t("operation.skill_value", [L10n.t("skill.%s" % skill_id), int(agent.get(skill_id, 0))]),
		UITheme.level_color(float(agent.get(skill_id, 0)) * 10.0)))

	var metrics := GridContainer.new()
	metrics.columns = 3
	metrics.add_theme_constant_override("h_separation", UITheme.SPACE_XS)
	vbox.add_child(metrics)
	metrics.add_child(UITheme.metric_chip(L10n.t("operation.chance_label"), "%d%%" % int(preview["chance"]), risk_color, selected))
	metrics.add_child(UITheme.metric_chip(L10n.t("operation.cost"), _cost_text(preview["costs"]), UITheme.TEXT if affordable else UITheme.DANGER, selected))
	metrics.add_child(UITheme.metric_chip(L10n.t("operation.heat"), _signed_int(int(preview["heat"])), UITheme.danger_color(float(GameState.heat + int(preview["heat"]))), selected))
	vbox.add_child(UITheme.modifier_row(L10n.t("operation.effect"), L10n.t("operation.%s.effect" % op_id), UITheme.TEXT))

	_add_visible_modifiers(vbox, preview.get("modifiers", []))
	for warning_variant in preview.get("warnings", []):
		var warning: Dictionary = warning_variant
		var warning_color: Color = UITheme.DANGER if String(warning.get("severity", "warn")) == "danger" else UITheme.WARN
		vbox.add_child(UITheme.label(L10n.t(String(warning.get("text_key", ""))), UITheme.FS_TINY, warning_color))

	if selected:
		vbox.add_child(UITheme.hseparator())
		vbox.add_child(_breakdown_view(preview))
	if not available:
		vbox.add_child(UITheme.label(L10n.t("operation.unavailable"), UITheme.FS_TINY, UITheme.DANGER))
	return panel


func _add_visible_modifiers(parent: VBoxContainer, modifiers: Array) -> void:
	var shown: Dictionary = {}
	for modifier_variant in modifiers:
		var modifier: Dictionary = modifier_variant
		var source: String = String(modifier.get("source", ""))
		if source not in ["agent", "identity"]:
			continue
		var shown_count: int = int(shown.get(source, 0))
		var max_count: int = 2 if source == "identity" else 1
		if shown_count >= max_count:
			continue
		shown[source] = shown_count + 1
		var caption_key: String = "operation.modifier.identity" if source == "identity" else "operation.modifier.agent"
		var color: Color = UITheme.ACCENT if source == "identity" else UITheme.SAFE
		parent.add_child(UITheme.modifier_row(L10n.t(caption_key), _localized_modifier(modifier), color))


func _breakdown_view(preview: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	box.add_child(UITheme.section_header(L10n.t("operation.breakdown.title"), UITheme.ACCENT))
	var chance_breakdown: Dictionary = preview.get("chance_breakdown", {})
	box.add_child(_breakdown_group(
		L10n.t("operation.breakdown.chance"),
		chance_breakdown.get("components", []),
		float(preview.get("chance", 0)), "%"))
	var costs: Dictionary = preview.get("costs", {})
	var cost_breakdown: Dictionary = costs.get("breakdown", {})
	if int(costs.get("funds", 0)) > 0:
		box.add_child(_breakdown_group(L10n.t("operation.breakdown.funds"), cost_breakdown.get("funds", []), float(costs["funds"]), ""))
	if int(costs.get("intel", 0)) > 0:
		box.add_child(_breakdown_group(L10n.t("operation.breakdown.intel"), cost_breakdown.get("intel", []), float(costs["intel"]), ""))
	if int(costs.get("trust", 0)) > 0:
		box.add_child(_breakdown_group(L10n.t("operation.breakdown.trust"), cost_breakdown.get("trust", []), float(costs["trust"]), ""))
	var heat_breakdown: Dictionary = preview.get("heat_breakdown", {})
	box.add_child(_breakdown_group(
		L10n.t("operation.breakdown.heat"),
		heat_breakdown.get("components", []),
		float(preview.get("heat", 0)), ""))
	return box


func _breakdown_group(title_text: String, components: Array, final_value: float, suffix: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XXS)
	box.add_child(UITheme.label(title_text, UITheme.FS_TINY, UITheme.TEXT))
	for component_variant in components:
		var component: Dictionary = component_variant
		var source: String = String(component.get("source", ""))
		var value: float = float(component.get("value", 0.0))
		if source != "base" and is_zero_approx(value):
			continue
		box.add_child(UITheme.modifier_row(
			L10n.t(String(component.get("text_key", ""))),
			_format_value(value, suffix, source == "base"),
			UITheme.TEXT_DIM))
	box.add_child(UITheme.modifier_row(L10n.t("breakdown.final"), _format_value(final_value, suffix, true), UITheme.ACCENT))
	return box


func _select_op(op_id: String) -> void:
	if op_id == _selected_op:
		return
	_selected_op = op_id
	_risk_acknowledged = false
	_warning_label.visible = false
	AudioManager.play_click()
	var region: Dictionary = GameState.get_region(_region_id)
	var agent: Dictionary = GameState.get_agent(_agent_id)
	var op: Dictionary = OperationData.get_def(op_id)
	_selected_preview = TurnResolver.preview_operation(region, agent, op)
	_confirm_btn.disabled = not bool(_selected_preview.get("affordable", false)) or bool(region.get("collapsed", false))
	_confirm_btn.text = L10n.t("operation.run") if not _confirm_btn.disabled else L10n.t("operation.unavailable_short")
	_rebuild(region, agent, true)
	if op_id == "map_signals":
		TutorialManager.notify("map_signals_selected")


func _on_confirm() -> void:
	if _selected_op == "" or _confirm_btn.disabled:
		return
	var reasons: Array[String] = TurnResolver.confirmation_reasons(_selected_preview)
	if not reasons.is_empty() and not _risk_acknowledged:
		var messages: Array[String] = []
		for reason_key in reasons:
			messages.append(L10n.t(reason_key))
		_warning_label.text = "\n".join(messages)
		_warning_label.visible = true
		_confirm_btn.text = L10n.t("operation.confirm_risk")
		_risk_acknowledged = true
		return
	visible = false
	AudioManager.play_confirm()
	operation_confirmed.emit(_selected_op)


func _cost_text(costs: Dictionary) -> String:
	var parts: Array[String] = []
	if int(costs.get("funds", 0)) > 0:
		parts.append("%d%s" % [int(costs["funds"]), L10n.t("game.funds_short")])
	if int(costs.get("intel", 0)) > 0:
		parts.append("%d%s" % [int(costs["intel"]), L10n.t("game.intel_short")])
	if int(costs.get("trust", 0)) > 0:
		parts.append("%d%s" % [int(costs["trust"]), L10n.t("game.trust_short")])
	return " / ".join(parts) if not parts.is_empty() else L10n.t("common.none")


func _localized_modifier(modifier: Dictionary) -> String:
	var args: Array = modifier.get("args", [])
	return L10n.t(String(modifier.get("text_key", "")), args)


func _format_value(value: float, suffix: String, absolute: bool) -> String:
	var rounded_value: int = int(round(value))
	var prefix: String = "" if absolute or rounded_value <= 0 else "+"
	return "%s%d%s" % [prefix, rounded_value, suffix]


func _signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _restore_scroll(position: int) -> void:
	_scroll.scroll_vertical = position


func _clear(parent: Node) -> void:
	for child_variant in parent.get_children():
		var child: Node = child_variant
		parent.remove_child(child)
		child.queue_free()
