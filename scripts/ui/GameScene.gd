extends Control
## GameScene.gd - the campaign screen. Wires map, HUD, panels and the
## turn flow together. Game rules live in TurnResolver/GameState.

const RegionPanelScene := preload("res://scenes/game/RegionPanel.tscn")
const OperationPanelScene := preload("res://scenes/game/OperationPanel.tscn")
const RosterPanelScene := preload("res://scenes/game/AgentRosterPanel.tscn")
const EventModalScene := preload("res://scenes/game/EventCardModal.tscn")
const DebriefScene := preload("res://scenes/game/DebriefScreen.tscn")

var _map: MapController
var _map_view: Control

# Panels are instanced scenes with script-defined signals; kept untyped
# so custom members resolve dynamically.
var _region_panel
var _op_panel
var _roster_panel
var _event_modal
var _debrief

var _hud_labels: Dictionary = {}
var _hud_chips: Dictionary = {}
var _objective_label: Label
var _danger_label: Label
var _exposure_bar: ProgressBar
var _rival_bar: ProgressBar
var _flow_label: Label
var _flow_detail_label: Label
var _tutorial_banner: PanelContainer
var _tutorial_label: Label
var _directive_overlay: Control
var _directive_card: PanelContainer
var _info_overlay: Control
var _info_card: PanelContainer
var _info_title: Label
var _info_content: VBoxContainer

var _pending_region: String = ""
var _pending_agent: String = ""
var _pending_event: Dictionary = {}
var _pending_end: Dictionary = {}
var _debrief_mode: String = "turn"
var _heat_pulse_t: float = 0.0
var _pulse_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not GameState.campaign_active:
		GameState.new_campaign(Balance.Difficulty.STANDARD)
	_build_screen()
	_map = MapController.new()
	_map_view.add_child(_map)
	_map.region_tapped.connect(_on_region_tapped)
	_map_view.resized.connect(_fit_map_to_view)
	call_deferred("_fit_map_to_view")
	_build_panels()
	_build_directive_card()
	_build_info_overlay()
	GameState.resources_changed.connect(_refresh_hud)
	_refresh_hud()
	_set_step(L10n.t("game.step_region"), L10n.t("game.step_region_detail"))
	_show_directive_if_needed()
	if TutorialManager.should_run() and GameState.turn == 1:
		TutorialManager.start()
		_tutorial_label.text = TutorialManager.current_text()
		_tutorial_banner.visible = not _directive_open()
	TutorialManager.step_changed.connect(func(text: String) -> void:
		_tutorial_label.text = text
		_tutorial_banner.visible = not _directive_open())
	TutorialManager.context_hint.connect(func(text: String) -> void:
		_tutorial_label.text = text
		_tutorial_banner.visible = not _directive_open())
	TutorialManager.tutorial_finished.connect(func() -> void:
		_tutorial_banner.visible = false)


func _process(delta: float) -> void:
	var next_pulse: Label = _critical_pulse_label()
	if _pulse_label != next_pulse:
		if _pulse_label != null:
			_pulse_label.modulate.a = 1.0
		_pulse_label = next_pulse
	if _pulse_label != null and not SettingsManager.reduce_motion:
		_heat_pulse_t += delta * 5.0
		_pulse_label.modulate.a = 0.72 + 0.28 * sin(_heat_pulse_t)
	elif _pulse_label != null:
		_pulse_label.modulate.a = 1.0


# ---------- UI construction ----------

func _build_screen() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_S)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_S)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_S)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_S)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(layout)

	_build_objective_strip(layout)
	_build_hud(layout)
	_build_world_context(layout)
	_build_map_area(layout)
	_build_tutorial_banner(layout)
	_build_bottom_bar(layout)


func _build_hud(parent: Container) -> void:
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", UITheme.glass_style())
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hud)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_XS)
	hud.add_child(row)

	_resource_chip(row, "intel", L10n.t("game.intel"), UITheme.TEXT)
	_resource_chip(row, "funds", L10n.t("game.funds"), UITheme.TEXT)
	_resource_chip(row, "trust", L10n.t("game.trust"), UITheme.TEXT)
	_resource_chip(row, "cover", L10n.t("game.cover"), UITheme.TEXT)
	_resource_chip(row, "heat", L10n.t("game.heat"), UITheme.TEXT)


func _resource_chip(parent: Container, key: String, caption: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.chip_style(color))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, UITheme.CHIP_MIN_HEIGHT)
	parent.add_child(panel)
	_hud_chips[key] = panel
	var chip := VBoxContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_constant_override("separation", 0)
	panel.add_child(chip)

	var cap := UITheme.label(caption, UITheme.FS_MICRO, UITheme.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(cap)

	var val := UITheme.label("0", UITheme.FS_SMALL, color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(val)
	_hud_labels[key] = val


func _build_world_context(parent: Container) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glass_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UITheme.SPACE_XS)
	grid.add_theme_constant_override("v_separation", UITheme.SPACE_XS)
	panel.add_child(grid)
	_resource_chip(grid, "turn", L10n.t("game.turn"), UITheme.ACCENT)
	_resource_chip(grid, "difficulty", L10n.t("game.difficulty"), UITheme.TEXT_DIM)
	_resource_chip(grid, "collapsed", L10n.t("game.lost"), UITheme.TEXT_DIM)
	_resource_chip(grid, "stability", L10n.t("game.world_stability"), UITheme.TEXT_DIM)
	_resource_chip(grid, "momentum", L10n.t("game.rival_momentum"), UITheme.TEXT_DIM)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", UITheme.SPACE_XS)
	grid.add_child(tools)
	var outlook := UITheme.button(L10n.t("game.outlook"), "ghost", true)
	outlook.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outlook.pressed.connect(_show_outlook)
	tools.add_child(outlook)
	var legend := UITheme.button(L10n.t("game.legend"), "ghost", true)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.pressed.connect(_show_legend)
	tools.add_child(legend)


func _build_objective_strip(parent: Container) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.glass_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(vbox)

	_objective_label = UITheme.label("", UITheme.FS_TINY, UITheme.ACCENT)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_objective_label)

	_rival_bar = _meter_row(vbox, L10n.t("game.rival_meter"), UITheme.ACCENT, "rival_val")
	_exposure_bar = _meter_row(vbox, L10n.t("game.global_meter"), UITheme.DANGER, "exposure_val")

	_danger_label = UITheme.label("", UITheme.FS_MICRO, UITheme.TEXT_DIM)
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_danger_label)


func _meter_row(parent: Container, caption: String, color: Color, val_key: String) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	parent.add_child(row)
	var cap := UITheme.label(caption, UITheme.FS_MICRO, UITheme.TEXT_DIM)
	cap.custom_minimum_size = Vector2(260, 0)
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(cap)
	var bar := UITheme.progress_bar(color, 18.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var val := UITheme.label("0/100", UITheme.FS_TINY, color)
	val.custom_minimum_size = Vector2(104, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(val)
	_hud_labels[val_key] = val
	return bar


func _build_map_area(parent: Container) -> void:
	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", UITheme.glass_style())
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.custom_minimum_size = Vector2(0, UITheme.MAP_MIN_HEIGHT)
	parent.add_child(map_panel)

	_map_view = Control.new()
	_map_view.clip_contents = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(_map_view)


func _build_bottom_bar(parent: Container) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.glass_style())
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_XS)
	bar.add_child(vbox)

	_flow_label = UITheme.label("", UITheme.FS_SMALL, UITheme.ACCENT)
	_flow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_flow_label)
	_flow_detail_label = UITheme.label("", UITheme.FS_TINY, UITheme.TEXT_DIM)
	_flow_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_flow_detail_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	vbox.add_child(row)
	var roster := UITheme.button(L10n.t("common.roster"), "ghost", true)
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.pressed.connect(func() -> void: _roster_view_mode())
	row.add_child(roster)
	var pass_btn := UITheme.button(L10n.t("common.pass_turn"), "warn", true)
	pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_btn.pressed.connect(_on_pass_turn)
	row.add_child(pass_btn)
	var menu := UITheme.button(L10n.t("common.menu"), "ghost", true)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func() -> void:
		SaveManager.save_game()
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	row.add_child(menu)


func _build_panels() -> void:
	_region_panel = RegionPanelScene.instantiate()
	add_child(_region_panel)
	_region_panel.plan_requested.connect(_on_plan_requested)
	_region_panel.closed.connect(func() -> void:
		_map.clear_selection()
		_set_step(L10n.t("game.step_region"), L10n.t("game.step_region_detail")))

	_roster_panel = RosterPanelScene.instantiate()
	add_child(_roster_panel)
	_roster_panel.agent_selected.connect(_on_agent_selected)
	_roster_panel.closed.connect(func() -> void:
		_set_step(L10n.t("game.step_region"), L10n.t("game.step_region_detail")))

	_op_panel = OperationPanelScene.instantiate()
	add_child(_op_panel)
	_op_panel.operation_confirmed.connect(_on_operation_confirmed)
	_op_panel.closed.connect(func() -> void:
		_set_step(L10n.t("game.step_region"), L10n.t("game.step_region_detail")))

	_event_modal = EventModalScene.instantiate()
	add_child(_event_modal)
	_event_modal.choice_made.connect(_on_event_choice)

	_debrief = DebriefScene.instantiate()
	add_child(_debrief)
	_debrief.dismissed.connect(_on_debrief_dismissed)


func _build_tutorial_banner(parent: Container) -> void:
	_tutorial_banner = PanelContainer.new()
	var style := UITheme.panel_style(UITheme.CARD, UITheme.ACCENT_DIM, 10)
	style.set_content_margin_all(UITheme.SPACE_S)
	_tutorial_banner.add_theme_stylebox_override("panel", style)
	_tutorial_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_banner.visible = false
	parent.add_child(_tutorial_banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	_tutorial_banner.add_child(row)
	_tutorial_label = UITheme.label("", UITheme.FS_TINY, UITheme.ACCENT)
	_tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tutorial_label)
	var skip := UITheme.button(L10n.t("common.skip"), "ghost", true)
	skip.custom_minimum_size = Vector2(140, UITheme.TOUCH_MIN)
	skip.pressed.connect(func() -> void: TutorialManager.skip())
	row.add_child(skip)
	_tutorial_banner.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			TutorialManager.notify("tap"))


func _build_directive_card() -> void:
	_directive_overlay = Control.new()
	_directive_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_directive_overlay.visible = false
	_directive_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_directive_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_directive_overlay.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_M)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_M)
	_directive_overlay.add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	_directive_card = PanelContainer.new()
	_directive_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.EDGE_BRIGHT))
	_directive_card.custom_minimum_size = Vector2(UITheme.MODAL_WIDTH, 0)
	center.add_child(_directive_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UITheme.SPACE_S)
	_directive_card.add_child(content)
	content.add_child(UITheme.title(L10n.t("game.directive_title"), UITheme.FS_TITLE))
	var body := UITheme.label(L10n.t("game.directive_body"), UITheme.FS_SMALL, UITheme.TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body)
	var begin := UITheme.button(L10n.t("common.begin"), "primary")
	begin.pressed.connect(_dismiss_directive)
	content.add_child(begin)


func _build_info_overlay() -> void:
	_info_overlay = Control.new()
	_info_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_overlay.visible = false
	_info_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, UITheme.OVERLAY_OPACITY)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_overlay.add_child(dim)

	var margin := UITheme.safe_area_margin()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_overlay.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)

	_info_card = PanelContainer.new()
	_info_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.EDGE_BRIGHT))
	_info_card.custom_minimum_size = Vector2(UITheme.MODAL_WIDTH, UITheme.INFO_MODAL_HEIGHT)
	center.add_child(_info_card)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", UITheme.SPACE_S)
	_info_card.add_child(shell)
	_info_title = UITheme.title("", UITheme.FS_LARGE)
	shell.add_child(_info_title)
	shell.add_child(UITheme.hseparator())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	_info_content = VBoxContainer.new()
	_info_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_content.add_theme_constant_override("separation", UITheme.SPACE_S)
	scroll.add_child(_info_content)
	var close := UITheme.button(L10n.t("common.close"), "ghost", true)
	close.pressed.connect(func() -> void: _info_overlay.visible = false)
	shell.add_child(close)


func _show_outlook() -> void:
	_clear_info_content()
	_info_title.text = L10n.t("outlook.title")
	var outlook: Dictionary = TurnResolver.turn_outlook()
	_info_content.add_child(UITheme.section_header(L10n.t("outlook.economy"), UITheme.ACCENT))
	_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.base_income"), _signed_value(int(outlook["base_income"])), UITheme.SAFE))
	_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.trust_income"), _signed_value(int(outlook["trust_income"])), UITheme.SAFE))
	_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.agent_upkeep"), _signed_value(-int(outlook["upkeep"])), UITheme.WARN))
	if int(outlook["trade_income"]) > 0:
		_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.trade_hubs"), _signed_value(int(outlook["trade_income"])), UITheme.SAFE))
	var budget_change: int = int(outlook["budget_change"])
	_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.budget_change"), _signed_value(budget_change), UITheme.SAFE if budget_change >= 0 else UITheme.DANGER))
	_info_content.add_child(UITheme.section_header(L10n.t("outlook.pressure"), UITheme.ACCENT))
	var heat_change: int = int(outlook["heat_change"])
	_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.heat_change"), _signed_value(heat_change), UITheme.SAFE if heat_change <= 0 else UITheme.DANGER))
	_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.exposure_pressure"), L10n.t("outlook.approx", [float(outlook["exposure_pressure"])]), UITheme.WARN))
	_info_content.add_child(UITheme.modifier_row(L10n.t("outlook.rival_activity"), L10n.t("outlook.activity.%s" % String(outlook["rival_activity"])), UITheme.WARN))
	_info_content.add_child(UITheme.label(L10n.t("outlook.disclaimer"), UITheme.FS_TINY, UITheme.TEXT_DIM))
	_show_info_overlay()


func _show_legend() -> void:
	_clear_info_content()
	_info_title.text = L10n.t("legend.title")
	_info_content.add_child(_legend_row(UITheme.DANGER, L10n.t("legend.risk.title"), L10n.t("legend.risk.body")))
	_info_content.add_child(_legend_row(UITheme.SAFE, L10n.t("legend.opportunity.title"), L10n.t("legend.opportunity.body")))
	_info_content.add_child(_legend_row(UITheme.ACCENT, L10n.t("legend.intel.title"), L10n.t("legend.intel.body")))
	_info_content.add_child(_legend_row(UITheme.ACCENT, L10n.t("legend.selected.title"), L10n.t("legend.selected.body")))
	_info_content.add_child(_legend_row(UITheme.COLLAPSED, L10n.t("legend.collapsed.title"), L10n.t("legend.collapsed.body")))
	_info_content.add_child(_legend_row(UITheme.SAFE, L10n.t("legend.identity.title"), L10n.t("legend.identity.body")))
	_show_info_overlay()


func _legend_row(color: Color, title_text: String, body_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	var marker := ColorRect.new()
	marker.color = color
	marker.custom_minimum_size = Vector2(UITheme.SECTION_MARKER_WIDTH, 0)
	row.add_child(marker)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", UITheme.SPACE_XS)
	row.add_child(copy)
	copy.add_child(UITheme.label(title_text, UITheme.FS_SMALL, color))
	copy.add_child(UITheme.label(body_text, UITheme.FS_TINY, UITheme.TEXT_DIM))
	return row


func _show_info_overlay() -> void:
	_info_overlay.visible = true
	if not SettingsManager.reduce_motion:
		_info_card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_info_card, "modulate:a", 1.0, UITheme.ANIM_FAST)


func _clear_info_content() -> void:
	for child_variant in _info_content.get_children():
		var child: Node = child_variant
		_info_content.remove_child(child)
		child.queue_free()


func _signed_value(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


# ---------- HUD refresh ----------

func _refresh_hud() -> void:
	_hud_labels["turn"].text = str(GameState.turn)
	_hud_labels["difficulty"].text = L10n.t("difficulty.%d.short" % GameState.difficulty)
	_hud_labels["intel"].text = str(GameState.intel)
	_hud_labels["funds"].text = str(GameState.funds)
	var funds_color: Color = UITheme.DANGER if GameState.funds < 0 else UITheme.TEXT
	_hud_labels["funds"].add_theme_color_override("font_color", funds_color)
	_style_hud_chip("funds", funds_color, GameState.funds < 0)
	_hud_labels["trust"].text = str(GameState.trust)
	var trust_color: Color = UITheme.DANGER if GameState.trust <= Balance.UI_TRUST_DANGER_AT else UITheme.level_color(float(GameState.trust))
	_hud_labels["trust"].add_theme_color_override("font_color", trust_color)
	_style_hud_chip("trust", trust_color, GameState.trust <= Balance.UI_TRUST_DANGER_AT)
	_hud_labels["cover"].text = str(GameState.cover)
	_hud_labels["heat"].text = str(GameState.heat)
	var heat_color: Color = UITheme.DANGER if GameState.heat >= Balance.UI_HEAT_DANGER_AT else (UITheme.WARN if GameState.heat >= Balance.UI_HEAT_WARNING_AT else UITheme.ACCENT)
	_hud_labels["heat"].add_theme_color_override("font_color", heat_color)
	_style_hud_chip("heat", heat_color, GameState.heat >= Balance.UI_HEAT_WARNING_AT)
	_style_hud_chip("intel", UITheme.ACCENT, false)
	_style_hud_chip("cover", UITheme.SAFE, false)
	_exposure_bar.value = GameState.global_exposure
	_hud_labels["exposure_val"].text = "%d/100" % int(GameState.global_exposure)
	_hud_labels["exposure_val"].add_theme_color_override("font_color", UITheme.DANGER if GameState.global_exposure >= Balance.UI_GLOBAL_EXPOSURE_DANGER_AT else UITheme.WARN)
	_rival_bar.value = GameState.rival_exposure
	_hud_labels["rival_val"].text = "%d/100" % int(GameState.rival_exposure)
	var stability: float = GameState.world_stability()
	_hud_labels["stability"].text = str(int(stability))
	_hud_labels["stability"].add_theme_color_override("font_color", UITheme.level_color(stability))
	_style_hud_chip("stability", UITheme.level_color(stability), stability < Balance.ASSESS_UNSTABLE_STABILITY_AT)
	_hud_labels["momentum"].text = str(int(GameState.rival_momentum))
	var momentum_color: Color = UITheme.WARN if GameState.rival_momentum >= Balance.UI_RIVAL_MOMENTUM_WARNING_AT else UITheme.TEXT_DIM
	_hud_labels["momentum"].add_theme_color_override("font_color", momentum_color)
	_style_hud_chip("momentum", momentum_color, GameState.rival_momentum >= Balance.UI_RIVAL_MOMENTUM_WARNING_AT)
	_hud_labels["collapsed"].text = "%d/%d" % [GameState.collapsed_count(), Balance.COLLAPSE_LIMIT]
	var collapsed_danger: bool = GameState.collapsed_count() >= Balance.UI_COLLAPSED_DANGER_AT
	_hud_labels["collapsed"].add_theme_color_override("font_color", UITheme.DANGER if collapsed_danger else UITheme.TEXT_DIM)
	_style_hud_chip("collapsed", UITheme.DANGER if collapsed_danger else UITheme.TEXT_DIM, collapsed_danger)
	_style_hud_chip("turn", UITheme.ACCENT, false)
	_style_hud_chip("difficulty", UITheme.TEXT_DIM, false)
	_objective_label.text = L10n.t("game.objective")
	_danger_label.text = _hud_warning_text()
	_danger_label.add_theme_color_override("font_color", UITheme.DANGER if _critical_pulse_label() != null else UITheme.TEXT_DIM)


func _style_hud_chip(key: String, color: Color, emphasized: bool) -> void:
	var panel: PanelContainer = _hud_chips.get(key)
	if panel != null:
		panel.add_theme_stylebox_override("panel", UITheme.chip_style(color, emphasized))


func _hud_warning_text() -> String:
	if GameState.global_exposure >= Balance.UI_GLOBAL_EXPOSURE_DANGER_AT:
		return L10n.t("hud.warning.global", [int(GameState.global_exposure)])
	if GameState.trust <= Balance.UI_TRUST_DANGER_AT:
		return L10n.t("hud.warning.trust", [GameState.trust])
	if GameState.funds < 0:
		return L10n.t("hud.warning.funds", [GameState.funds])
	if GameState.heat >= Balance.UI_HEAT_DANGER_AT:
		return L10n.t("hud.warning.heat_danger", [GameState.heat])
	if GameState.collapsed_count() >= Balance.UI_COLLAPSED_DANGER_AT:
		return L10n.t("hud.warning.collapsed", [GameState.collapsed_count(), Balance.COLLAPSE_LIMIT])
	if GameState.heat >= Balance.UI_HEAT_WARNING_AT:
		return L10n.t("hud.warning.heat", [GameState.heat])
	if GameState.rival_momentum >= Balance.UI_RIVAL_MOMENTUM_WARNING_AT:
		return L10n.t("hud.warning.momentum", [int(GameState.rival_momentum)])
	return L10n.t("hud.risks_nominal", [Balance.COLLAPSE_LIMIT])


func _critical_pulse_label() -> Label:
	if _hud_labels.is_empty():
		return null
	if GameState.global_exposure >= Balance.UI_GLOBAL_EXPOSURE_DANGER_AT:
		return _hud_labels.get("exposure_val") as Label
	if GameState.trust <= Balance.UI_TRUST_DANGER_AT:
		return _hud_labels.get("trust") as Label
	if GameState.funds < 0:
		return _hud_labels.get("funds") as Label
	if GameState.heat >= Balance.UI_HEAT_DANGER_AT:
		return _hud_labels.get("heat") as Label
	if GameState.collapsed_count() >= Balance.UI_COLLAPSED_DANGER_AT:
		return _hud_labels.get("collapsed") as Label
	return null


func _set_step(title: String, detail: String) -> void:
	if _flow_label == null or _flow_detail_label == null:
		return
	_flow_label.text = title
	_flow_detail_label.text = detail


func _fit_map_to_view() -> void:
	if _map == null or _map_view == null:
		return
	_map.fit_to_rect(_map_view.size)


func _show_directive_if_needed() -> void:
	if GameState.directive_seen:
		return
	_directive_overlay.visible = true
	_tutorial_banner.visible = false
	if not SettingsManager.reduce_motion:
		_directive_card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_directive_card, "modulate:a", 1.0, UITheme.ANIM_MED)


func _dismiss_directive() -> void:
	GameState.directive_seen = true
	_directive_overlay.visible = false
	SaveManager.save_game()
	if TutorialManager.active:
		_tutorial_banner.visible = true


func _directive_open() -> bool:
	return _directive_overlay != null and _directive_overlay.visible


# ---------- Turn flow ----------

func _on_region_tapped(region_id: String) -> void:
	if _modal_open():
		return
	var r: Dictionary = GameState.get_region(region_id)
	if r.is_empty():
		return
	_map.select_region(region_id)
	AudioManager.play_click()
	TutorialManager.notify("region_selected")
	_set_step(L10n.t("game.step_review_region"), L10n.t("game.step_review_region_detail"))
	_region_panel.open(region_id)


func _on_plan_requested(region_id: String) -> void:
	var r: Dictionary = GameState.get_region(region_id)
	if bool(r.get("collapsed", false)):
		return
	_pending_region = region_id
	_region_panel.visible = false
	_set_step(L10n.t("game.step_agent"), L10n.t("game.step_agent_detail"))
	_roster_panel.open(true, region_id)


func _roster_view_mode() -> void:
	if _modal_open():
		return
	_roster_panel.open(false)


func _on_agent_selected(agent_id: String) -> void:
	_pending_agent = agent_id
	_set_step(L10n.t("game.step_operation"), L10n.t("game.step_operation_detail"))
	_op_panel.open(_pending_region, agent_id)


func _on_operation_confirmed(op_id: String) -> void:
	_set_step(L10n.t("game.step_result"), L10n.t("game.step_result_detail"))
	var before := _meter_snapshot(_pending_region)
	var result: Dictionary = TurnResolver.resolve_operation(_pending_region, _pending_agent, op_id)
	_map.play_scan(_pending_region)
	var success: bool = bool(result["success"])
	var near_miss: bool = bool(result["near_miss"])
	if success:
		AudioManager.play_success()
		UITransitions.flash(UITheme.SAFE, 0.12)
	elif near_miss:
		AudioManager.play_fail()
		UITransitions.flash(UITheme.WARN, 0.10)
		SettingsManager.vibrate(35)
	else:
		AudioManager.play_fail()
		UITransitions.flash(UITheme.DANGER, 0.14)
		SettingsManager.vibrate(60)
	var advance: Dictionary = TurnResolver.advance_turn(_pending_agent)
	_pending_event = advance.get("event", {})
	_pending_end = advance.get("end", {})
	_map.refresh_all()
	_map.clear_selection()
	var result_lines: Array = result.get("lines", [])
	var verdict: String = L10n.t("game.verdict_success") if success else (L10n.t("game.verdict_near_miss") if near_miss else L10n.t("game.verdict_failure"))
	_debrief_mode = "turn"
	var result_kind: String = "success" if success else ("near_miss" if near_miss else "fail")
	_debrief.open(verdict, result_kind, result_lines, before, {
		"result": result,
		"advance": advance,
		"region_id": _pending_region,
	})


func _on_pass_turn() -> void:
	if _modal_open():
		return
	_set_step(L10n.t("game.step_result"), L10n.t("game.step_pass_detail"))
	var before := _meter_snapshot()
	var advance: Dictionary = TurnResolver.advance_turn("")
	_pending_event = advance.get("event", {})
	_pending_end = advance.get("end", {})
	_map.refresh_all()
	_debrief_mode = "turn"
	var advance_lines: Array = advance.get("lines", [])
	_debrief.open(L10n.t("game.pass_debrief_title"), "neutral", advance_lines, before, {"advance": advance})


func _on_debrief_dismissed() -> void:
	if bool(_pending_end.get("over", false)):
		_handle_end()
		return
	if _debrief_mode == "turn" and not _pending_event.is_empty():
		_set_step(L10n.t("game.incoming_report"), L10n.t("game.incoming_report_detail"))
		_event_modal.open(_pending_event)
		return
	_finish_cycle()


func _on_event_choice(choice_index: int) -> void:
	var event: Dictionary = _pending_event
	_pending_event = {}
	var before := _meter_snapshot()
	var choices: Array = event.get("choices", [])
	var lines: Array[String] = []
	if choice_index < choices.size():
		var choice: Dictionary = choices[choice_index]
		lines = GameState.apply_effects(choice.get("effects", {}))
	GameState.record_event(String(event["id"]), choice_index)
	_map.refresh_all()
	var end: Dictionary = GameState.check_end_conditions()
	_pending_end = end
	if lines.is_empty():
		lines.append(L10n.t("game.no_consequence"))
	_debrief_mode = "event"
	_set_step(L10n.t("game.step_result"), L10n.t("game.step_result_next_detail"))
	_debrief.open(String(event["title"]), "neutral", lines, before)


func _finish_cycle() -> void:
	SaveManager.save_game()
	_refresh_hud()
	_set_step(L10n.t("game.step_region"), L10n.t("game.step_next_region_detail"))


func _handle_end() -> void:
	SaveManager.delete_save()
	if bool(_pending_end.get("won", false)):
		AudioManager.play_success()
		UITransitions.change_scene("res://scenes/game/WinScreen.tscn")
	else:
		AudioManager.play_alarm()
		UITransitions.change_scene("res://scenes/game/LossScreen.tscn")


func _modal_open() -> bool:
	return _directive_open() or _region_panel.visible or _op_panel.visible or _roster_panel.visible \
		or _event_modal.visible or _debrief.visible or (_info_overlay != null and _info_overlay.visible)


func _meter_snapshot(region_id: String = "") -> Dictionary:
	var snapshot := {
		"global_exposure": GameState.global_exposure,
		"rival_exposure": GameState.rival_exposure,
		"heat": GameState.heat,
		"funds": GameState.funds,
		"intel": GameState.intel,
		"trust": GameState.trust,
		"cover": GameState.cover,
		"rival_momentum": GameState.rival_momentum,
		"world_stability": GameState.world_stability(),
		"collapsed_regions": GameState.collapsed_count(),
	}
	var region: Dictionary = GameState.get_region(region_id)
	if not region.is_empty():
		snapshot["region_stability"] = float(region.get("stability", 0))
		snapshot["region_rival"] = float(region.get("rival_influence", 0))
		snapshot["region_pressure"] = float(region.get("public_pressure", 0))
		snapshot["local_network"] = float(region.get("local_network", 0))
		snapshot["intel_level"] = float(region.get("intel_level", 0))
	return snapshot
