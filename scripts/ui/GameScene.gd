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
var _objective_label: Label
var _danger_label: Label
var _exposure_bar: ProgressBar
var _rival_bar: ProgressBar
var _heat_label: Label
var _flow_label: Label
var _flow_detail_label: Label
var _tutorial_banner: PanelContainer
var _tutorial_label: Label
var _directive_overlay: Control
var _directive_card: PanelContainer

var _pending_region: String = ""
var _pending_agent: String = ""
var _pending_event: Dictionary = {}
var _pending_end: Dictionary = {}
var _debrief_mode: String = "turn"
var _heat_pulse_t: float = 0.0


func _ready() -> void:
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
	GameState.resources_changed.connect(_refresh_hud)
	_refresh_hud()
	_set_step("Step 1: Select a region", "Tap a region node to open its dossier.")
	_show_directive_if_needed()
	if TutorialManager.should_run() and GameState.turn == 1:
		TutorialManager.start()
		_tutorial_label.text = TutorialManager.current_text()
		_tutorial_banner.visible = not _directive_open()
	TutorialManager.step_changed.connect(func(text: String) -> void:
		_tutorial_label.text = text
		_tutorial_banner.visible = not _directive_open())
	TutorialManager.tutorial_finished.connect(func() -> void:
		_tutorial_banner.visible = false)


func _process(delta: float) -> void:
	# Heat meter pulse when running hot.
	if GameState.heat >= 60 and not SettingsManager.reduce_motion:
		_heat_pulse_t += delta * 5.0
		_heat_label.modulate.a = 0.7 + 0.3 * sin(_heat_pulse_t)
	else:
		_heat_label.modulate.a = 1.0


# ---------- UI construction ----------

func _build_screen() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_S)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_S)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_S)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_S)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(layout)

	_build_hud(layout)
	_build_objective_strip(layout)
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

	_resource_chip(row, "turn", "TURN", UITheme.ACCENT)
	_resource_chip(row, "intel", "INTEL", UITheme.TEXT)
	_resource_chip(row, "funds", "FUNDS", UITheme.TEXT)
	_resource_chip(row, "trust", "TRUST", UITheme.TEXT)
	_resource_chip(row, "cover", "COVER", UITheme.TEXT)
	_resource_chip(row, "heat", "HEAT", UITheme.TEXT)
	_heat_label = _hud_labels["heat"]


func _resource_chip(parent: Container, key: String, caption: String, color: Color) -> void:
	var chip := VBoxContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_constant_override("separation", 0)
	parent.add_child(chip)

	var cap := UITheme.label(caption, UITheme.FS_MICRO, UITheme.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(cap)

	var val := UITheme.label("0", UITheme.FS_SMALL, color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(val)
	_hud_labels[key] = val


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

	_rival_bar = _meter_row(vbox, "RIVAL NETWORK", UITheme.ACCENT, "rival_val")
	_exposure_bar = _meter_row(vbox, "GLOBAL EXPOSURE", UITheme.DANGER, "exposure_val")

	var world_row := HBoxContainer.new()
	world_row.add_theme_constant_override("separation", UITheme.SPACE_S)
	vbox.add_child(world_row)
	_hud_labels["stability"] = UITheme.label("", UITheme.FS_MICRO, UITheme.TEXT_DIM)
	_hud_labels["stability"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_row.add_child(_hud_labels["stability"])
	_hud_labels["momentum"] = UITheme.label("", UITheme.FS_MICRO, UITheme.TEXT_DIM)
	_hud_labels["momentum"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_labels["momentum"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_row.add_child(_hud_labels["momentum"])

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
	var roster := UITheme.button("ROSTER", "ghost", true)
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.pressed.connect(func() -> void: _roster_view_mode())
	row.add_child(roster)
	var pass_btn := UITheme.button("PASS TURN", "warn", true)
	pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_btn.pressed.connect(_on_pass_turn)
	row.add_child(pass_btn)
	var menu := UITheme.button("MENU", "ghost", true)
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
		_set_step("Step 1: Select a region", "Tap a region node to open its dossier."))

	_roster_panel = RosterPanelScene.instantiate()
	add_child(_roster_panel)
	_roster_panel.agent_selected.connect(_on_agent_selected)
	_roster_panel.closed.connect(func() -> void:
		_set_step("Step 1: Select a region", "Tap a region node to open its dossier."))

	_op_panel = OperationPanelScene.instantiate()
	add_child(_op_panel)
	_op_panel.operation_confirmed.connect(_on_operation_confirmed)
	_op_panel.closed.connect(func() -> void:
		_set_step("Step 1: Select a region", "Tap a region node to open its dossier."))

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
	var skip := UITheme.button("SKIP", "ghost", true)
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
	content.add_child(UITheme.title("DIRECTIVE", UITheme.FS_TITLE))
	var body := UITheme.label(
		"Expose the Rival Network before Global Exposure reaches 100. Select a region, assign an agent, then run an operation. Build local networks and use Trace Rival Cell to progress toward victory.",
		UITheme.FS_SMALL,
		UITheme.TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body)
	var begin := UITheme.button("BEGIN", "primary")
	begin.pressed.connect(_dismiss_directive)
	content.add_child(begin)


# ---------- HUD refresh ----------

func _refresh_hud() -> void:
	_hud_labels["turn"].text = str(GameState.turn)
	_hud_labels["intel"].text = str(GameState.intel)
	_hud_labels["funds"].text = str(GameState.funds)
	_hud_labels["funds"].add_theme_color_override("font_color",
		UITheme.DANGER if GameState.funds < 0 else UITheme.TEXT)
	_hud_labels["trust"].text = str(GameState.trust)
	_hud_labels["trust"].add_theme_color_override("font_color", UITheme.level_color(float(GameState.trust)))
	_hud_labels["cover"].text = str(GameState.cover)
	_hud_labels["heat"].text = str(GameState.heat)
	_hud_labels["heat"].add_theme_color_override("font_color", UITheme.danger_color(float(GameState.heat)))
	_exposure_bar.value = GameState.global_exposure
	_hud_labels["exposure_val"].text = "%d/100" % int(GameState.global_exposure)
	_rival_bar.value = GameState.rival_exposure
	_hud_labels["rival_val"].text = "%d/100" % int(GameState.rival_exposure)
	_hud_labels["stability"].text = "Stability %d" % int(GameState.world_stability())
	_hud_labels["momentum"].text = "Momentum %d" % int(GameState.rival_momentum)
	_objective_label.text = "Goal: expose Rival Network before Global Exposure reaches 100."
	_danger_label.text = "Danger: Global %d/100 | Trust %d | Lost regions %d/%d" % [
		int(GameState.global_exposure),
		GameState.trust,
		GameState.collapsed_count(),
		Balance.COLLAPSE_LIMIT,
	]


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
	_set_step("Step 2: Review region", "Choose Agent to assign work here.")
	_region_panel.open(region_id)


func _on_plan_requested(region_id: String) -> void:
	var r: Dictionary = GameState.get_region(region_id)
	if bool(r.get("collapsed", false)):
		return
	_pending_region = region_id
	_region_panel.visible = false
	_set_step("Step 2: Choose an agent", "Pick the agent whose skills fit the job.")
	_roster_panel.open(true)


func _roster_view_mode() -> void:
	if _modal_open():
		return
	_roster_panel.open(false)


func _on_agent_selected(agent_id: String) -> void:
	_pending_agent = agent_id
	_set_step("Step 3: Choose an operation", "Check cost, chance, Heat, and expected effect.")
	_op_panel.open(_pending_region, agent_id)


func _on_operation_confirmed(op_id: String) -> void:
	_set_step("Step 4: Review the result", "Read what changed, then adapt next turn.")
	var before := _meter_snapshot()
	var result: Dictionary = TurnResolver.resolve_operation(_pending_region, _pending_agent, op_id)
	_map.play_scan(_pending_region)
	var success: bool = bool(result["success"])
	var near_miss: bool = bool(result["near_miss"])
	if success:
		AudioManager.play_success()
		UITransitions.flash(UITheme.SAFE, 0.12)
	else:
		AudioManager.play_fail()
		UITransitions.flash(UITheme.DANGER, 0.14)
		SettingsManager.vibrate(60)
	var advance: Dictionary = TurnResolver.advance_turn(_pending_agent)
	_pending_event = advance.get("event", {})
	_pending_end = advance.get("end", {})
	_map.refresh_all()
	_map.clear_selection()
	var lines: Array = []
	var result_lines: Array = result.get("lines", [])
	var advance_lines: Array = advance.get("lines", [])
	lines.append_array(result_lines)
	lines.append_array(advance_lines)
	var verdict: String = "SUCCESS" if success else ("NEAR MISS" if near_miss else "FAILURE")
	var title: String = "%s - %s (%d%% odds, rolled %d)" % [result["op_name"], verdict, result["chance"], result["roll"]]
	_debrief_mode = "turn"
	_debrief.open(title, "success" if success else "fail", lines, before)


func _on_pass_turn() -> void:
	if _modal_open():
		return
	_set_step("Step 4: Review the result", "Agents rest while the rival network moves.")
	var before := _meter_snapshot()
	var advance: Dictionary = TurnResolver.advance_turn("")
	_pending_event = advance.get("event", {})
	_pending_end = advance.get("end", {})
	_map.refresh_all()
	_debrief_mode = "turn"
	var advance_lines: Array = advance.get("lines", [])
	_debrief.open("Holding Pattern - agents rest", "neutral", advance_lines, before)


func _on_debrief_dismissed() -> void:
	if bool(_pending_end.get("over", false)):
		_handle_end()
		return
	if _debrief_mode == "turn" and not _pending_event.is_empty():
		_set_step("Incoming report", "Choose a response, then review the consequences.")
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
		lines.append("No measurable consequences. Yet.")
	_debrief_mode = "event"
	_set_step("Step 4: Review the result", "Read what changed, then choose the next region.")
	_debrief.open(String(event["title"]), "neutral", lines, before)


func _finish_cycle() -> void:
	SaveManager.save_game()
	_refresh_hud()
	_set_step("Step 1: Select a region", "Tap a region node to begin the next operation.")


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
		or _event_modal.visible or _debrief.visible


func _meter_snapshot() -> Dictionary:
	return {
		"global_exposure": GameState.global_exposure,
		"rival_exposure": GameState.rival_exposure,
		"heat": GameState.heat,
		"funds": GameState.funds,
	}
