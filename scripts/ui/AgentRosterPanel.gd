extends Control
## AgentRosterPanel.gd - full-screen agent list.
## select_mode true: picking an agent for an operation.
## select_mode false: reviewing the roster from the bottom bar.

signal agent_selected(agent_id: String)
signal closed

var _select_mode: bool = false
var _region_id: String = ""
var _list: VBoxContainer
var _title_label: Label
var _hint_label: Label


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

	_title_label = UITheme.title(L10n.t("agent.title"), UITheme.FS_LARGE)
	vbox.add_child(_title_label)
	_hint_label = UITheme.label("", UITheme.FS_TINY, UITheme.TEXT_DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", UITheme.SPACE_S)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var back := UITheme.button(L10n.t("common.back"), "ghost", true)
	back.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	vbox.add_child(back)


func open(select_mode: bool, region_id: String = "") -> void:
	_select_mode = select_mode
	_region_id = region_id if select_mode else ""
	_title_label.text = L10n.t("agent.select_title") if select_mode else L10n.t("agent.title")
	_hint_label.text = L10n.t("agent.select_hint") if select_mode else L10n.t("agent.roster_hint")
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
	info.add_child(UITheme.label("%s / %s" % [String(agent["name"]).to_upper(), L10n.t("agent.level_short", [int(agent["level"])])], UITheme.FS_BODY, UITheme.ACCENT))
	info.add_child(UITheme.label(_role_name(String(agent.get("role", ""))), UITheme.FS_SMALL, UITheme.TEXT))
	info.add_child(UITheme.label(L10n.t("agent.%s.bio" % String(agent["id"])), UITheme.FS_TINY, UITheme.TEXT_DIM))
	var trait_id: String = String(agent.get("trait", ""))
	var trait_text: String = L10n.t("agent_trait.%s.name" % trait_id) + " - " + L10n.t("agent_trait.%s.description" % trait_id)
	info.add_child(UITheme.label(L10n.t("agent.trait", [trait_text]), UITheme.FS_TINY, UITheme.TEXT_DIM))
	var strained: bool = int(agent.get("fatigue", 0)) >= Balance.FATIGUE_STRAINED_THRESHOLD
	var status_color: Color = UITheme.WARN if strained else UITheme.SAFE
	var status_text: String = L10n.t("agent.strained") if strained else L10n.t("agent.ready")
	info.add_child(UITheme.label(L10n.t("agent.fatigue_status", [int(agent["fatigue"]), status_text]), UITheme.FS_TINY, status_color))

	var strengths: Array[Dictionary] = _sorted_skills(agent)
	var strength_parts: Array[String] = []
	for i in mini(2, strengths.size()):
		strength_parts.append("%s %d" % [L10n.t("skill.%s" % String(strengths[i]["id"])), int(strengths[i]["value"])])
	info.add_child(UITheme.label(L10n.t("agent.strengths", [" / ".join(strength_parts)]), UITheme.FS_TINY, UITheme.ACCENT_DIM))

	var skills := HBoxContainer.new()
	skills.add_theme_constant_override("separation", UITheme.SPACE_S)
	vbox.add_child(skills)
	var skill_data: Array = [
		["skill.analysis.short", int(agent["analysis"])], ["skill.fieldcraft.short", int(agent["fieldcraft"])],
		["skill.diplomacy.short", int(agent["diplomacy"])], ["skill.technical.short", int(agent["technical"])],
		["skill.resolve.short", int(agent["resolve"])],
	]
	for s in skill_data:
		var skill_name: String = L10n.t(String(s[0]))
		var skill_value: int = int(s[1])
		var chip_text: String = skill_name + " " + str(skill_value)
		var chip := UITheme.label(chip_text, UITheme.FS_TINY, UITheme.level_color(float(skill_value) * 10.0))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.autowrap_mode = TextServer.AUTOWRAP_OFF
		skills.add_child(chip)

	if _select_mode:
		var region: Dictionary = GameState.get_region(_region_id)
		if not region.is_empty():
			var fit: Dictionary = TurnResolver.agent_suitability(region, agent)
			var fit_color: Color = _fit_color(String(fit.get("id", "risky")))
			var fit_content := VBoxContainer.new()
			fit_content.add_theme_constant_override("separation", UITheme.SPACE_XS)
			var fit_chip := UITheme.status_chip(L10n.t(String(fit.get("text_key", "agent.fit.risky"))), fit_color)
			fit_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fit_content.add_child(fit_chip)
			var best_op_id: String = String(fit.get("best_op_id", ""))
			if best_op_id != "":
				fit_content.add_child(UITheme.label(L10n.t("agent.fit.best", [
					L10n.t("operation.%s.name" % best_op_id),
					int(fit.get("best_chance", 0)),
				]), UITheme.FS_TINY, UITheme.TEXT_DIM))
			vbox.add_child(fit_content)
		var pick := UITheme.button(L10n.t("agent.select"), "primary", true)
		pick.pressed.connect(func() -> void:
			visible = false
			TutorialManager.notify("agent_selected")
			agent_selected.emit(String(agent["id"])))
		vbox.add_child(pick)
	return panel


func _sorted_skills(agent: Dictionary) -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for skill_id in ["analysis", "fieldcraft", "diplomacy", "technical", "resolve"]:
		skills.append({"id": skill_id, "value": int(agent.get(skill_id, 0))})
	skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["value"]) > int(b["value"]))
	return skills


func _role_name(role: String) -> String:
	var key: String = "agent_role.%s" % role.to_lower().replace(" ", "_")
	return L10n.t(key)


func _fit_color(id: String) -> Color:
	match id:
		"strong": return UITheme.SAFE
		"viable": return UITheme.ACCENT
		"specialist": return UITheme.SAFE
		"tradeoff": return UITheme.WARN
		"exhausted": return UITheme.DANGER
	return UITheme.WARN
