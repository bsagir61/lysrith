extends Control
## GameScene.gd - the campaign screen. Wires map, HUD, panels and the
## turn flow together. Game rules live in TurnResolver/GameState.

const RegionPanelScene := preload("res://scenes/game/RegionPanel.tscn")
const OperationPanelScene := preload("res://scenes/game/OperationPanel.tscn")
const RosterPanelScene := preload("res://scenes/game/AgentRosterPanel.tscn")
const EventModalScene := preload("res://scenes/game/EventCardModal.tscn")
const DebriefScene := preload("res://scenes/game/DebriefScreen.tscn")

var _map: MapController
# Panels are instanced scenes with script-defined signals; kept untyped
# so custom members resolve dynamically.
var _region_panel
var _op_panel
var _roster_panel
var _event_modal
var _debrief

var _hud_labels: Dictionary = {}
var _exposure_bar: ProgressBar
var _rival_bar: ProgressBar
var _heat_label: Label
var _tutorial_banner: PanelContainer
var _tutorial_label: Label

var _pending_region: String = ""
var _pending_agent: String = ""
var _pending_event: Dictionary = {}
var _pending_end: Dictionary = {}
var _debrief_mode: String = "turn"
var _heat_pulse_t: float = 0.0


func _ready() -> void:
	if not GameState.campaign_active:
		GameState.new_campaign(Balance.Difficulty.STANDARD)
	_map = MapController.new()
	add_child(_map)
	_map.region_tapped.connect(_on_region_tapped)
	_build_hud()
	_build_bottom_bar()
	_build_panels()
	_build_tutorial_banner()
	GameState.resources_changed.connect(_refresh_hud)
	_refresh_hud()
	if TutorialManager.should_run() and GameState.turn == 1:
		TutorialManager.start()
		_tutorial_banner.visible = true
		_tutorial_label.text = TutorialManager.current_text()
	TutorialManager.step_changed.connect(func(text: String) -> void:
		_tutorial_label.text = text)
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

func _build_hud() -> void:
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", UITheme.glass_style())
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = UITheme.SPACE_S
	hud.offset_right = -UITheme.SPACE_S
	hud.offset_top = UITheme.SPACE_S
	add_child(hud)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_XS)
	hud.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	_hud_labels["turn"] = UITheme.label("TURN 1", UITheme.FS_SMALL, UITheme.ACCENT)
	top_row.add_child(_hud_labels["turn"])
	var title := UITheme.label("LYSRITH", UITheme.FS_SMALL, UITheme.TEXT_DIM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(title)
	top_row.add_child(UITheme.label(Balance.difficulty_name(GameState.difficulty).to_upper(), UITheme.FS_SMALL, UITheme.TEXT_DIM))

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", UITheme.SPACE_XS)
	vbox.add_child(res_row)
	for key in ["intel", "funds", "trust", "cover", "heat"]:
		var chip := VBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_constant_override("separation", 0)
		var cap := UITheme.label(key.to_upper(), 20, UITheme.TEXT_DIM)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(cap)
		var val := UITheme.label("0", UITheme.FS_BODY, UITheme.TEXT)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(val)
		_hud_labels[key] = val
		res_row.add_child(chip)
	_heat_label = _hud_labels["heat"]

	_exposure_bar = _meter_row(vbox, "GLOBAL EXPOSURE", UITheme.DANGER, "exposure_val")
	_rival_bar = _meter_row(vbox, "RIVAL NETWORK EXPOSED", UITheme.ACCENT, "rival_val")

	var world_row := HBoxContainer.new()
	vbox.add_child(world_row)
	_hud_labels["stability"] = UITheme.label("", 20, UITheme.TEXT_DIM)
	_hud_labels["stability"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_row.add_child(_hud_labels["stability"])
	_hud_labels["momentum"] = UITheme.label("", 20, UITheme.TEXT_DIM)
	_hud_labels["momentum"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_labels["momentum"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_row.add_child(_hud_labels["momentum"])


func _meter_row(parent: Container, caption: String, color: Color, val_key: String) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	parent.add_child(row)
	var cap := UITheme.label(caption, 20, UITheme.TEXT_DIM)
	cap.custom_minimum_size = Vector2(330, 0)
	row.add_child(cap)
	var bar := UITheme.progress_bar(color, 20.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var val := UITheme.label("0", 22, color)
	val.custom_minimum_size = Vector2(70, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	_hud_labels[val_key] = val
	return bar


func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.glass_style())
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = UITheme.SPACE_S
	bar.offset_right = -UITheme.SPACE_S
	bar.offset_bottom = -UITheme.SPACE_S
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	bar.add_child(row)
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
	_region_panel.closed.connect(func() -> void: _map.clear_selection())

	_roster_panel = RosterPanelScene.instantiate()
	add_child(_roster_panel)
	_roster_panel.agent_selected.connect(_on_agent_selected)

	_op_panel = OperationPanelScene.instantiate()
	add_child(_op_panel)
	_op_panel.operation_confirmed.connect(_on_operation_confirmed)

	_event_modal = EventModalScene.instantiate()
	add_child(_event_modal)
	_event_modal.choice_made.connect(_on_event_choice)

	_debrief = DebriefScene.instantiate()
	add_child(_debrief)
	_debrief.dismissed.connect(_on_debrief_dismissed)


func _build_tutorial_banner() -> void:
	_tutorial_banner = PanelContainer.new()
	var style := UITheme.panel_style(UITheme.CARD, UITheme.ACCENT_DIM, 10)
	style.set_content_margin_all(UITheme.SPACE_S)
	_tutorial_banner.add_theme_stylebox_override("panel", style)
	_tutorial_banner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tutorial_banner.offset_left = UITheme.SPACE_S
	_tutorial_banner.offset_right = -UITheme.SPACE_S
	_tutorial_banner.offset_bottom = -150
	_tutorial_banner.visible = false
	add_child(_tutorial_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.SPACE_S)
	_tutorial_banner.add_child(row)
	_tutorial_label = UITheme.label("", 24, UITheme.ACCENT)
	_tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tutorial_label)
	var skip := UITheme.button("SKIP", "ghost", true)
	skip.custom_minimum_size = Vector2(140, UITheme.TOUCH_MIN)
	skip.pressed.connect(func() -> void: TutorialManager.skip())
	row.add_child(skip)
	_tutorial_banner.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			TutorialManager.notify("tap"))


# ---------- HUD refresh ----------

func _refresh_hud() -> void:
	_hud_labels["turn"].text = "TURN %d" % GameState.turn
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
	_hud_labels["exposure_val"].text = str(int(GameState.global_exposure))
	_rival_bar.value = GameState.rival_exposure
	_hud_labels["rival_val"].text = str(int(GameState.rival_exposure))
	_hud_labels["stability"].text = "WORLD STABILITY %d" % int(GameState.world_stability())
	_hud_labels["momentum"].text = "RIVAL MOMENTUM %d" % int(GameState.rival_momentum)


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
	_region_panel.open(region_id)


func _on_plan_requested(region_id: String) -> void:
	var r: Dictionary = GameState.get_region(region_id)
	if bool(r.get("collapsed", false)):
		return
	_pending_region = region_id
	_region_panel.visible = false
	_roster_panel.open(true)


func _roster_view_mode() -> void:
	if _modal_open():
		return
	_roster_panel.open(false)


func _on_agent_selected(agent_id: String) -> void:
	_pending_agent = agent_id
	_op_panel.open(_pending_region, agent_id)


func _on_operation_confirmed(op_id: String) -> void:
	var before := _meter_snapshot()
	var result: Dictionary = TurnResolver.resolve_operation(_pending_region, _pending_agent, op_id)
	_map.play_scan(_pending_region)
	if result["success"]:
		AudioManager.play_success()
		UITransitions.flash(UITheme.SAFE, 0.12)
	else:
		AudioManager.play_fail()
		UITransitions.flash(UITheme.DANGER, 0.14)
		SettingsManager.vibrate(60)
	var advance: Dictionary = TurnResolver.advance_turn(_pending_agent)
	_pending_event = advance["event"]
	_pending_end = advance["end"]
	_map.refresh_all()
	_map.clear_selection()
	var lines: Array = []
	lines.append_array(result["lines"])
	lines.append_array(advance["lines"])
	var verdict := "SUCCESS" if result["success"] else ("NEAR MISS" if result["near_miss"] else "FAILURE")
	var title := "%s - %s (%d%% odds, rolled %d)" % [result["op_name"], verdict, result["chance"], result["roll"]]
	_debrief_mode = "turn"
	_debrief.open(title, "success" if result["success"] else "fail", lines, before)


func _on_pass_turn() -> void:
	if _modal_open():
		return
	var before := _meter_snapshot()
	var advance: Dictionary = TurnResolver.advance_turn("")
	_pending_event = advance["event"]
	_pending_end = advance["end"]
	_map.refresh_all()
	_debrief_mode = "turn"
	_debrief.open("Holding Pattern - agents rest", "neutral", advance["lines"], before)


func _on_debrief_dismissed() -> void:
	if bool(_pending_end.get("over", false)):
		_handle_end()
		return
	if _debrief_mode == "turn" and not _pending_event.is_empty():
		_event_modal.open(_pending_event)
		return
	_finish_cycle()


func _on_event_choice(choice_index: int) -> void:
	var event := _pending_event
	_pending_event = {}
	var before := _meter_snapshot()
	var choices: Array = event.get("choices", [])
	var lines: Array[String] = []
	if choice_index < choices.size():
		lines = GameState.apply_effects(choices[choice_index].get("effects", {}))
	GameState.record_event(String(event["id"]), choice_index)
	_map.refresh_all()
	var end := GameState.check_end_conditions()
	_pending_end = end
	if lines.is_empty():
		lines.append("No measurable consequences. Yet.")
	_debrief_mode = "event"
	_debrief.open(String(event["title"]), "neutral", lines, before)


func _finish_cycle() -> void:
	SaveManager.save_game()
	_refresh_hud()


func _handle_end() -> void:
	SaveManager.delete_save()
	if bool(_pending_end.get("won", false)):
		AudioManager.play_success()
		UITransitions.change_scene("res://scenes/game/WinScreen.tscn")
	else:
		AudioManager.play_alarm()
		UITransitions.change_scene("res://scenes/game/LossScreen.tscn")


func _modal_open() -> bool:
	return _region_panel.visible or _op_panel.visible or _roster_panel.visible \
		or _event_modal.visible or _debrief.visible


func _meter_snapshot() -> Dictionary:
	return {
		"global_exposure": GameState.global_exposure,
		"rival_exposure": GameState.rival_exposure,
		"heat": GameState.heat,
		"funds": GameState.funds,
	}
