class_name StrategicValidation
extends Node
## Headless release check for the strategic-clarity update.
## Persistence checks back up and restore the player's save and settings files.

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_test_localization()
	_test_language_persistence()
	_test_unrevealed_isolation()
	_test_identity_rules()
	_test_trait_interactions()
	_test_discovery_reward()
	_test_preview_payment()
	_test_trade_hub_turn_income()
	_test_in_memory_save_compatibility()
	await _test_auxiliary_screens("en", false, false)
	await _test_auxiliary_screens("tr", true, true)
	await _test_ui_flow("en", false, false)
	await _test_ui_flow("tr", false, true)
	await _test_ui_flow("en", true, true)
	await _test_ui_flow("tr", true, true)
	await _test_interactive_loop("en", false)
	await _test_interactive_loop("tr", true)
	_test_end_conditions()
	if _failures.is_empty():
		print("STRATEGIC_VALIDATION_OK checks=%d" % _checks)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("STRATEGIC_VALIDATION: %s" % failure)
	print("STRATEGIC_VALIDATION_FAILED checks=%d failures=%d" % [_checks, _failures.size()])
	get_tree().quit(1)


func _test_localization() -> void:
	var english: Array = L10n.keys("en")
	var turkish: Array = L10n.keys("tr")
	_expect_equal(english.size(), turkish.size(), "EN/TR localization key counts differ")
	for key_variant in english:
		var key: String = String(key_variant)
		_expect(key in turkish, "Turkish localization is missing %s" % key)
	for key_variant in turkish:
		var key: String = String(key_variant)
		_expect(key in english, "English localization is missing %s" % key)
	_test_direct_localization_keys()
	for tag_variant in RegionData.hidden_tags:
		var tag: String = String(tag_variant)
		_expect(_both_have(RegionTagRules.name_key(tag)), "Missing identity name key for %s" % tag)
		_expect(_both_have(RegionTagRules.description_key(tag)), "Missing identity description key for %s" % tag)
	for region_variant in RegionData.regions:
		var region: Dictionary = region_variant
		_expect(_both_have("region_name.%s" % String(region["id"])), "Missing region display name for %s" % region["id"])
	for agent_variant in AgentData.agents:
		var agent: Dictionary = agent_variant
		var agent_id: String = String(agent["id"])
		var role_id: String = String(agent["role"]).to_lower().replace(" ", "_")
		var trait_id: String = String(agent["trait"])
		_expect(_both_have("agent.%s.bio" % agent_id), "Missing agent biography for %s" % agent_id)
		_expect(_both_have("agent_role.%s" % role_id), "Missing agent role for %s" % role_id)
		_expect(_both_have("agent_trait.%s.name" % trait_id), "Missing agent trait name for %s" % trait_id)
		_expect(_both_have("agent_trait.%s.description" % trait_id), "Missing agent trait description for %s" % trait_id)
	for op_variant in OperationData.operations:
		var op: Dictionary = op_variant
		var op_id: String = String(op["id"])
		for suffix in ["name", "description", "effect"]:
			_expect(_both_have("operation.%s.%s" % [op_id, suffix]), "Missing operation localization for %s.%s" % [op_id, suffix])
	for skill_id in ["analysis", "fieldcraft", "diplomacy", "technical", "resolve"]:
		_expect(_both_have("skill.%s" % skill_id), "Missing skill localization for %s" % skill_id)
		_expect(_both_have("skill.%s.short" % skill_id), "Missing short skill localization for %s" % skill_id)
	for event_variant in EventData.events:
		var event: Dictionary = event_variant
		var event_id: String = String(event["id"])
		_expect(_both_have("event.%s.title" % event_id), "Missing event title for %s" % event_id)
		_expect(_both_have("event.%s.desc" % event_id), "Missing event description for %s" % event_id)
		var choices: Array = event.get("choices", [])
		for i in choices.size():
			_expect(_both_have("event.%s.choice.%d.text" % [event_id, i]), "Missing event choice %s.%d" % [event_id, i])
			_expect(_both_have("event.%s.choice.%d.note" % [event_id, i]), "Missing event note %s.%d" % [event_id, i])
	for reason_id in ["win", "global", "trust", "collapse", "funds"]:
		_expect(_both_have("end.reason.%s" % reason_id), "Missing end reason %s" % reason_id)
	for difficulty_id in 3:
		for suffix in ["name", "desc", "short"]:
			_expect(_both_have("difficulty.%d.%s" % [difficulty_id, suffix]), "Missing difficulty localization %d.%s" % [difficulty_id, suffix])
	for risk_id in ["favorable", "uncertain", "risky", "severe"]:
		_expect(_both_have("operation.risk.%s" % risk_id), "Missing operation risk %s" % risk_id)
	for activity_id in ["low", "moderate", "high"]:
		_expect(_both_have("outlook.activity.%s" % activity_id), "Missing outlook activity %s" % activity_id)
	for flow_step in range(1, 7):
		_expect(_both_have("how.flow.%d" % flow_step), "Missing How to Play flow step %d" % flow_step)
	for assessment_id in ["critical", "unstable", "contested", "promising", "under_observed", "stable"]:
		_expect(_both_have("assessment.%s" % assessment_id), "Missing assessment %s" % assessment_id)
	for summary_id in ["unavailable", "collapsed", "low_stability_limited", "limited", "rival_deteriorating", "surveillance", "pressure", "opportunity", "stable"]:
		_expect(_both_have("region.summary.%s" % summary_id), "Missing region summary %s" % summary_id)
	for advisor_id in ["map_signals", "stabilize", "reduce_heat", "counter_influence", "deep_analysis", "build_network", "trace_cell"]:
		_expect(_both_have("advisor.%s" % advisor_id), "Missing advisor recommendation %s" % advisor_id)
	_test_player_facing_terminology()
	_test_no_raw_data_display_paths()


func _both_have(key: String) -> bool:
	return L10n.has_key(key, "en") and L10n.has_key(key, "tr")


func _test_language_persistence() -> void:
	var settings_backup: Dictionary = _backup_file(SettingsManager.SETTINGS_PATH)
	var original_locale: String = String(L10n.get("_locale"))
	var original_language: String = SettingsManager.language_code
	L10n.set("_locale", "en")
	SettingsManager.language_code = "en"
	L10n.set_locale("tr")
	SettingsManager.language_code = "en"
	SettingsManager.load_settings()
	_expect_equal(SettingsManager.language_code, "tr", "Turkish language selection did not persist")
	_restore_file(SettingsManager.SETTINGS_PATH, settings_backup)
	SettingsManager.language_code = original_language
	L10n.set("_locale", original_locale)


func _test_player_facing_terminology() -> void:
	var original_locale: String = String(L10n.get("_locale"))
	var expected: Dictionary = {
		"en": {
			"game.rival_meter": "RIVAL NETWORK UNCOVERED",
			"game.rival_momentum": "RIVAL SPREAD",
			"game.difficulty": "DIFFICULTY",
			"region.classification": "Region Profile: %s",
			"resource.rival_exposure": "Rival Network Uncovered",
			"resource.rival_momentum": "Rival Spread",
		},
		"tr": {
			"game.intel": "İSTİHBARAT",
			"game.funds": "BÜTÇE",
			"game.trust": "GÜVEN",
			"game.cover": "GİZLİLİK",
			"game.heat": "İZ",
			"game.rival_meter": "RAKİP AĞ DEŞİFRESİ",
			"game.global_meter": "KÜRESEL RİSK",
			"game.rival_momentum": "RAKİP YAYILIMI",
			"region.classification": "Bölge Profili: %s",
			"resource.trust": "Kurum Güveni",
			"operation.map_signals.name": "Sinyalleri Tara",
			"operation.reduce_heat.name": "İzleri Temizle",
			"operation.trace_cell.name": "Rakip Hücreyi Takip Et",
			"operation.deep_analysis.name": "Derin Analiz",
			"operation.quiet_audit.name": "Gizli Denetim",
			"operation.breakdown.heat": "Bırakılan İz",
		},
	}
	for locale_variant in expected:
		var locale: String = String(locale_variant)
		L10n.set("_locale", locale)
		var terms: Dictionary = expected[locale]
		for key_variant in terms:
			var key: String = String(key_variant)
			_expect_equal(L10n.t(key), String(terms[key]), "%s terminology drifted for %s" % [locale, key])
	L10n.set("_locale", "tr")
	var obsolete_terms: Array[String] = [
		"Isı",
		"Rakip Ağ Maruziyeti",
		"Örtü",
		"Duruş",
		"Map Signals",
		"Deep Analysis",
		"Trace Rival Cell",
		"Sinyalleri Haritala",
		"Rakip Hücreyi İzle",
		"Sessiz Denetim",
		"Kamu Baskısı",
		"KÜRESEL İZ",
		"Bütçea",
	]
	var obsolete_acronym := RegEx.new()
	obsolete_acronym.compile("(^|[^A-ZÇĞİÖŞÜ])(ISI|FON)([^A-ZÇĞİÖŞÜ]|$)")
	for key_variant in L10n.keys("tr"):
		var key: String = String(key_variant)
		var value: String = L10n.t(key)
		for term in obsolete_terms:
			_expect(term not in value, "Obsolete Turkish term '%s' remains in %s" % [term, key])
		_expect(obsolete_acronym.search(value) == null, "Obsolete Turkish acronym remains in %s" % key)
	L10n.set("_locale", original_locale)


func _test_direct_localization_keys() -> void:
	var regex := RegEx.new()
	regex.compile("L10n\\.t\\(\"([^\"]+)\"")
	for path in _gdscript_paths("res://scripts"):
		var source: String = FileAccess.get_file_as_string(path)
		for match_variant in regex.search_all(source):
			var match_result: RegExMatch = match_variant
			var key: String = match_result.get_string(1)
			if "%" in key:
				continue
			_expect(_both_have(key), "Direct localization key is missing: %s (%s)" % [key, path])


func _gdscript_paths(root: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		var path: String = root.path_join(entry)
		if directory.current_is_dir():
			paths.append_array(_gdscript_paths(path))
		elif entry.ends_with(".gd"):
			paths.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return paths


func _test_no_raw_data_display_paths() -> void:
	var forbidden := {
		"res://scripts/ui/EventCardModal.gd": ["_event[\"title\"]", "_event[\"desc\"]", "choice[\"text\"]", "choice.get(\"note\""],
		"res://scripts/ui/GameScene.gd": ["event[\"title\"]"],
		"res://scripts/map/MapController.gd": ["def[\"name\"]"],
		"res://scripts/ui/RegionPanel.gd": ["r.get(\"name\""],
	}
	for path_variant in forbidden:
		var path: String = String(path_variant)
		var source: String = FileAccess.get_file_as_string(path)
		for token_variant in forbidden[path]:
			var token: String = String(token_variant)
			_expect(token not in source, "Raw player-facing data path remains: %s in %s" % [token, path])


func _test_unrevealed_isolation() -> void:
	for tag_variant in RegionData.hidden_tags:
		var region: Dictionary = _region(String(tag_variant), false)
		for op_variant in OperationData.operations:
			var op: Dictionary = op_variant
			_expect_equal(RegionTagRules.chance_bonus(region, op), 0, "Unrevealed %s changed chance" % tag_variant)
			_expect_approx(RegionTagRules.funds_cost_multiplier(region, op), 1.0, "Unrevealed %s changed Funds cost" % tag_variant)
			_expect_equal(RegionTagRules.funds_cost_adjustment(region, op), 0, "Unrevealed %s added a Funds adjustment" % tag_variant)
			_expect_equal(RegionTagRules.intel_cost_adjustment(region, op), 0, "Unrevealed %s added an Intel adjustment" % tag_variant)
			_expect_equal(RegionTagRules.heat_adjustment(region, op), 0, "Unrevealed %s changed Heat" % tag_variant)
			_expect_approx(RegionTagRules.effect_multiplier(region, op, "primary"), 1.0, "Unrevealed %s changed effects" % tag_variant)
			_expect(not RegionTagRules.affects_operation(region, op), "Unrevealed %s exposed a modifier" % tag_variant)
	_expect_equal(RegionTagRules.passive_income_bonus([_region("Trade Hub", false)]), 0, "Unrevealed Trade Hub generated income")


func _test_identity_rules() -> void:
	var map_op: Dictionary = OperationData.get_def("map_signals")
	var build_op: Dictionary = OperationData.get_def("build_network")
	var counter_op: Dictionary = OperationData.get_def("counter_influence")
	var stabilize_op: Dictionary = OperationData.get_def("stabilize")
	var reduce_op: Dictionary = OperationData.get_def("reduce_heat")
	var trace_op: Dictionary = OperationData.get_def("trace_cell")
	var contain_op: Dictionary = OperationData.get_def("containment")
	var analysis_op: Dictionary = OperationData.get_def("deep_analysis")
	var audit_op: Dictionary = OperationData.get_def("quiet_audit")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Media Core", true), reduce_op, "heat"), Balance.TAG_MEDIA_REDUCE_HEAT_MULT, "Media Core multiplier")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Border Zone", true), counter_op, "rival"), Balance.TAG_BORDER_EFFECT_MULT, "Border Zone Counter multiplier")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Border Zone", true), contain_op, "stability"), Balance.TAG_BORDER_EFFECT_MULT, "Border Zone Containment multiplier")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Research Node", true), map_op, "intel"), Balance.TAG_RESEARCH_MAP_INTEL_MULT, "Research Node Intel multiplier")
	_expect_equal(RegionTagRules.intel_cost_adjustment(_region("Research Node", true), analysis_op), -Balance.TAG_RESEARCH_DEEP_INTEL_DISCOUNT, "Research Node Deep Analysis discount")
	_expect_approx(RegionTagRules.funds_cost_multiplier(_region("Financial Gate", true), trace_op), Balance.TAG_FINANCIAL_FUNDS_MULT, "Financial Gate multiplier")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Civil Pressure Zone", true), stabilize_op, "stability"), Balance.TAG_CIVIL_STABILITY_MULT, "Civil Pressure Stability multiplier")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Civil Pressure Zone", true), stabilize_op, "pressure"), Balance.TAG_CIVIL_PRESSURE_MULT, "Civil Pressure pressure multiplier")
	_expect_equal(RegionTagRules.chance_bonus(_region("Signal Corridor", true), trace_op), Balance.TAG_SIGNAL_TRACE_CHANCE, "Signal Corridor Trace chance")
	_expect_equal(RegionTagRules.chance_bonus(_region("Signal Corridor", true), map_op), Balance.TAG_SIGNAL_MAP_CHANCE, "Signal Corridor Map chance")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Old Alliance", true), audit_op, "trust"), Balance.TAG_OLD_ALLIANCE_TRUST_MULT, "Old Alliance Trust multiplier")
	_expect_equal(RegionTagRules.chance_bonus(_region("Old Alliance", true), stabilize_op), Balance.TAG_OLD_ALLIANCE_STABILIZE_CHANCE, "Old Alliance Stabilize chance")
	_expect_approx(RegionTagRules.effect_multiplier(_region("Black Market Route", true), build_op, "network"), Balance.TAG_BLACK_MARKET_NETWORK_MULT, "Black Market network multiplier")
	_expect_equal(RegionTagRules.heat_adjustment(_region("Black Market Route", true), build_op), Balance.TAG_BLACK_MARKET_HEAT, "Black Market Heat adjustment")
	_expect_equal(RegionTagRules.chance_bonus(_region("Diplomatic Junction", true), stabilize_op), Balance.TAG_DIPLOMATIC_CHANCE, "Diplomatic Junction chance")
	_expect_equal(RegionTagRules.funds_cost_adjustment(_region("Diplomatic Junction", true), audit_op), -Balance.TAG_DIPLOMATIC_AUDIT_FUNDS_DISCOUNT, "Diplomatic Junction audit discount")
	var active_hubs: Array = [_region("Trade Hub", true), _region("Trade Hub", true), _region("Trade Hub", true), _region("Trade Hub", true)]
	_expect_equal(RegionTagRules.passive_income_bonus(active_hubs), Balance.TAG_TRADE_HUB_INCOME_CAP, "Trade Hub income cap")
	var collapsed_hub: Dictionary = _region("Trade Hub", true)
	collapsed_hub["collapsed"] = true
	_expect_equal(RegionTagRules.passive_income_bonus([_region("Trade Hub", true), _region("Trade Hub", true), collapsed_hub]), 4, "Collapsed Trade Hub generated income")


func _test_trait_interactions() -> void:
	GameState.difficulty = Balance.Difficulty.STANDARD
	GameState.funds = 1000
	GameState.intel = 1000
	GameState.trust = 70
	GameState.heat = 10
	var expensive: Dictionary = _agent("expensive_specialist")
	var financial: Dictionary = _region("Financial Gate", true)
	var trace_op: Dictionary = OperationData.get_def("trace_cell")
	var costs: Dictionary = TurnResolver.compute_costs(financial, expensive, trace_op)
	_expect_equal(int(costs["funds"]), 26, "Financial Gate and Expensive Specialist modifier order")
	var low_profile: Dictionary = _agent("low_profile")
	var black_market: Dictionary = _region("Black Market Route", true)
	var build_op: Dictionary = OperationData.get_def("build_network")
	_expect_equal(TurnResolver.heat_preview(black_market, low_profile, build_op), 4, "Black Market Route and Low Profile Heat order")
	var risk_averse: Dictionary = _agent("risk_averse")
	risk_averse["fatigue"] = 80
	var neutral: Dictionary = _region("Diplomatic Junction", false)
	var diplomatic: Dictionary = _region("Diplomatic Junction", true)
	var stabilize_op: Dictionary = OperationData.get_def("stabilize")
	var neutral_chance: int = TurnResolver.compute_chance(neutral, risk_averse, stabilize_op)
	var diplomatic_chance: int = TurnResolver.compute_chance(diplomatic, risk_averse, stabilize_op)
	_expect_equal(diplomatic_chance - neutral_chance, Balance.TAG_DIPLOMATIC_CHANCE, "Diplomatic Junction and Risk Averse chance order")
	var signal_region: Dictionary = _region("Signal Corridor", true)
	signal_region["local_network"] = 100
	signal_region["intel_level"] = 3
	_expect(TurnResolver.compute_chance(signal_region, _agent(""), trace_op) <= Balance.CHANCE_MAX, "Signal Corridor chance exceeded clamp")


func _test_discovery_reward() -> void:
	GameState.new_campaign(Balance.Difficulty.STANDARD)
	var region: Dictionary = GameState.regions[0]
	region["hidden_tag"] = "Research Node"
	region["tag_revealed"] = false
	region["intel_level"] = 3
	region["local_network"] = 100
	var agent: Dictionary = GameState.agents[0]
	agent["analysis"] = 10
	agent["fatigue"] = 0
	GameState.funds = 1000
	GameState.intel = 100
	var op: Dictionary = OperationData.get_def("deep_analysis")
	var first_preview: Dictionary = TurnResolver.preview_operation(region, agent, op)
	_expect_equal(int(first_preview["costs"]["intel"]), 8, "Unrevealed Research Node discounted its own discovery")
	var first_before: int = GameState.intel
	RandomService.reseed(101)
	var first: Dictionary = TurnResolver.resolve_operation(String(region["id"]), String(agent["id"]), "deep_analysis")
	_expect(bool(first["identity_revealed"]), "First Deep Analysis did not report identity discovery")
	_expect_equal(GameState.intel, first_before - 8 + Balance.TAG_DISCOVERY_INTEL_REWARD, "First identity reward amount")
	var second_preview: Dictionary = TurnResolver.preview_operation(region, agent, op)
	_expect_equal(int(second_preview["costs"]["intel"]), 6, "Revealed Research Node did not discount Deep Analysis")
	var second_before: int = GameState.intel
	RandomService.reseed(102)
	var second: Dictionary = TurnResolver.resolve_operation(String(region["id"]), String(agent["id"]), "deep_analysis")
	_expect(not bool(second["identity_revealed"]), "Repeated Deep Analysis repeated identity discovery")
	_expect_equal(GameState.intel, second_before - 6, "Repeated Deep Analysis repeated discovery reward")


func _test_preview_payment() -> void:
	GameState.new_campaign(Balance.Difficulty.STANDARD)
	var region: Dictionary = GameState.regions[0]
	region["hidden_tag"] = "Financial Gate"
	region["tag_revealed"] = true
	region["intel_level"] = 3
	var agent: Dictionary = GameState.agents[3]
	agent["fatigue"] = 0
	GameState.funds = 1000
	GameState.intel = 100
	var op: Dictionary = OperationData.get_def("trace_cell")
	var preview: Dictionary = TurnResolver.preview_operation(region, agent, op)
	var before_funds: int = GameState.funds
	RandomService.reseed(203)
	var result: Dictionary = TurnResolver.resolve_operation(String(region["id"]), String(agent["id"]), "trace_cell")
	_expect_equal(GameState.funds, before_funds - int(preview["costs"]["funds"]), "Actual Funds payment differed from preview")
	_expect_equal(int(result["chance"]), int(preview["chance"]), "Resolution chance differed from preview")
	_expect(result.has("cost_breakdown") and result.has("heat_breakdown") and result.has("effect_breakdown"), "Resolution omitted structured breakdowns")


func _test_trade_hub_turn_income() -> void:
	GameState.new_campaign(Balance.Difficulty.STANDARD)
	for region_variant in GameState.regions:
		var region: Dictionary = region_variant
		region["tag_revealed"] = false
		region["collapsed"] = false
		region["stability"] = 80
		region["rival_influence"] = 0
	for i in 4:
		GameState.regions[i]["hidden_tag"] = "Trade Hub"
		GameState.regions[i]["tag_revealed"] = true
	GameState.trust = 60
	GameState.funds = 100
	GameState.heat = 0
	var outlook: Dictionary = TurnResolver.turn_outlook()
	_expect_equal(int(outlook["trade_income"]), Balance.TAG_TRADE_HUB_INCOME_CAP, "Turn Outlook missed Trade Hub cap")
	var before_funds: int = GameState.funds
	RandomService.reseed(304)
	var advance: Dictionary = TurnResolver.advance_turn("")
	_expect_equal(GameState.funds, before_funds + int(outlook["budget_change"]), "Actual turn income differed from Outlook")
	_expect_equal(int(advance["economy"]["trade_income"]), Balance.TAG_TRADE_HUB_INCOME_CAP, "Turn result missed Trade Hub income")


func _test_in_memory_save_compatibility() -> void:
	GameState.new_campaign(Balance.Difficulty.STANDARD)
	GameState.regions[0]["hidden_tag"] = "Signal Corridor"
	GameState.regions[0]["tag_revealed"] = true
	var saved: Dictionary = GameState.to_dict()
	saved.erase("directive_seen")
	GameState.from_dict(saved)
	_expect_equal(String(GameState.regions[0]["hidden_tag"]), "Signal Corridor", "In-memory load changed stable identity ID")
	_expect(bool(GameState.regions[0]["tag_revealed"]), "In-memory load lost revealed identity")
	_expect(not GameState.directive_seen, "Old save default for directive_seen changed")


func _test_auxiliary_screens(locale: String, large_text: bool, reduce_motion: bool) -> void:
	var original_locale: String = String(L10n.get("_locale"))
	var original_large: bool = SettingsManager.large_text
	var original_motion: bool = SettingsManager.reduce_motion
	L10n.set("_locale", locale)
	SettingsManager.large_text = large_text
	SettingsManager.reduce_motion = reduce_motion
	GameState.new_campaign(Balance.Difficulty.STANDARD)
	GameState.last_end = {"reason": L10n.t("end.reason.win")}
	var scene_paths: Array[String] = [
		"res://scenes/menus/MainMenu.tscn",
		"res://scenes/menus/NewGameSetup.tscn",
		"res://scenes/menus/SettingsScreen.tscn",
		"res://scenes/menus/HowToPlayScreen.tscn",
		"res://scenes/game/WinScreen.tscn",
		"res://scenes/game/LossScreen.tscn",
	]
	for path in scene_paths:
		var screen: Control = load(path).instantiate()
		get_tree().root.add_child(screen)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(screen.size.x > 0.0 and screen.size.y > 0.0, "%s did not lay out in %s" % [path, locale])
		_test_visible_ui(screen, "%s %s" % [locale, path.get_file()])
		screen.queue_free()
		await get_tree().process_frame
	L10n.set("_locale", original_locale)
	SettingsManager.large_text = original_large
	SettingsManager.reduce_motion = original_motion


func _test_ui_flow(locale: String, large_text: bool, reduce_motion: bool) -> void:
	var original_locale: String = String(L10n.get("_locale"))
	var original_large: bool = SettingsManager.large_text
	var original_motion: bool = SettingsManager.reduce_motion
	var original_tutorial: bool = SettingsManager.tutorial_completed
	L10n.set("_locale", locale)
	SettingsManager.large_text = large_text
	SettingsManager.reduce_motion = reduce_motion
	SettingsManager.tutorial_completed = true
	GameState.new_campaign(Balance.Difficulty.STANDARD)
	GameState.directive_seen = true
	var packed: PackedScene = load("res://scenes/game/GameScene.tscn")
	var game: Control = packed.instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view: Control = game.get("_map_view")
	_expect(map_view != null and map_view.size.x > 0.0 and map_view.size.y > 0.0, "%s GameScene map area did not lay out" % locale)
	var region_id: String = String(GameState.regions[0]["id"])
	game.call("_on_region_tapped", region_id)
	var region_panel: Control = game.get("_region_panel")
	_expect(region_panel.visible, "%s region dossier did not open" % locale)
	_expect(_visible_text_contains(region_panel, L10n.region_name(region_id)), "%s dossier did not use localized region name" % locale)
	_test_visible_ui(region_panel, "%s dossier" % locale)
	game.call("_on_plan_requested", region_id)
	var roster: Control = game.get("_roster_panel")
	_expect(roster.visible, "%s agent roster did not open" % locale)
	_expect(_visible_text_contains(roster, L10n.t("agent.%s.bio" % String(GameState.agents[0]["id"]))), "%s roster did not show localized biography" % locale)
	_test_visible_ui(roster, "%s roster" % locale)
	var agent_id: String = String(GameState.agents[0]["id"])
	game.call("_on_agent_selected", agent_id)
	var operation_panel: Control = game.get("_op_panel")
	_expect(operation_panel.visible, "%s operation planner did not open" % locale)
	operation_panel.call("_select_op", "map_signals")
	var confirm_button: Button = operation_panel.get("_confirm_btn")
	_expect(not confirm_button.disabled, "%s affordable operation was disabled" % locale)
	_test_visible_ui(operation_panel, "%s operation panel" % locale)
	game.call("_on_operation_confirmed", "map_signals")
	await get_tree().process_frame
	var debrief: Control = game.get("_debrief")
	_expect(debrief.visible, "%s debrief did not open" % locale)
	_test_visible_ui(debrief, "%s debrief" % locale)
	debrief.visible = false
	var event_modal: Control = game.get("_event_modal")
	var event: Dictionary = EventData.events[0]
	event_modal.open(event)
	await get_tree().process_frame
	_expect(_visible_text_contains(event_modal, L10n.t("event.%s.title" % String(event["id"])).to_upper()), "%s event title was not localized" % locale)
	_expect(not _visible_text_contains(event_modal, String(event["title"])) or locale == "en", "%s event card leaked raw English title" % locale)
	_test_visible_ui(event_modal, "%s event modal" % locale)
	game.queue_free()
	await get_tree().process_frame
	L10n.set("_locale", original_locale)
	SettingsManager.large_text = original_large
	SettingsManager.reduce_motion = original_motion
	SettingsManager.tutorial_completed = original_tutorial


func _test_interactive_loop(locale: String, use_touch: bool) -> void:
	var save_backup: Dictionary = _backup_file(SaveManager.SAVE_PATH)
	var original_locale: String = String(L10n.get("_locale"))
	var original_tutorial: bool = SettingsManager.tutorial_completed
	L10n.set("_locale", locale)
	SettingsManager.tutorial_completed = true
	GameState.new_campaign(Balance.Difficulty.STANDARD)
	GameState.directive_seen = true
	var game: Control = load("res://scenes/game/GameScene.tscn").instantiate()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var map: MapController = game.get("_map")
	var region_nodes: Dictionary = map.get("_region_nodes")
	var region_id: String = String(GameState.regions[0]["id"])
	var region_node: Node2D = region_nodes[region_id]
	var region_position: Vector2 = map.get_global_transform_with_canvas() * region_node.position
	if use_touch:
		_push_touch(region_position)
	else:
		_push_mouse(region_position)
	await get_tree().process_frame
	var region_panel: Control = game.get("_region_panel")
	_expect(region_panel.visible, "%s interactive region selection failed" % locale)
	var plan_button: Button = _find_button(region_panel, L10n.t("region.plan_operation"))
	_expect(plan_button != null, "%s interactive dossier action missing" % locale)
	if plan_button != null:
		_push_mouse(plan_button.get_global_rect().get_center())
		await get_tree().process_frame
	var roster: Control = game.get("_roster_panel")
	_expect(roster.visible, "%s interactive roster did not open" % locale)
	var select_button: Button = _find_button(roster, L10n.t("agent.select"))
	_expect(select_button != null, "%s interactive agent action missing" % locale)
	if select_button != null:
		_push_mouse(select_button.get_global_rect().get_center())
		await get_tree().process_frame
	var operation_panel: Control = game.get("_op_panel")
	_expect(operation_panel.visible, "%s interactive operation panel did not open" % locale)
	await get_tree().process_frame
	var operation_list: VBoxContainer = operation_panel.get("_list")
	var first_card: Control = operation_list.get_child(0)
	_push_mouse(first_card.get_global_rect().get_center())
	await get_tree().process_frame
	var confirm_button: Button = operation_panel.get("_confirm_btn")
	_expect(not confirm_button.disabled, "%s opening operation was not affordable" % locale)
	var turn_before: int = GameState.turn
	var ops_before: int = int(GameState.stats.get("ops_run", 0))
	_push_mouse(confirm_button.get_global_rect().get_center())
	await get_tree().process_frame
	var debrief: Control = game.get("_debrief")
	_expect(debrief.visible, "%s interactive debrief did not open" % locale)
	_expect(GameState.turn == turn_before + 1, "%s operation advanced an incorrect number of turns" % locale)
	_expect(int(GameState.stats.get("ops_run", 0)) == ops_before + 1, "%s operation resolved an incorrect number of times" % locale)
	await _dismiss_debrief_and_event(game, locale)
	_expect(not bool(game.call("_modal_open")), "%s operation cycle left a modal open" % locale)
	_expect(SaveManager.has_save(), "%s operation cycle did not save" % locale)
	var saved_state: Dictionary = GameState.to_dict()
	_expect(SaveManager.save_game(), "%s explicit campaign save failed" % locale)
	await get_tree().process_frame
	GameState.turn = 99
	_expect(SaveManager.load_game(), "%s Continue load failed" % locale)
	_expect(GameState.turn == int(saved_state["turn"]), "%s Continue changed the saved turn" % locale)
	_expect_equal(GameState.campaign_seed, int(saved_state["seed"]), "%s Continue rerolled the campaign seed" % locale)
	_expect(_regions_match(GameState.regions, saved_state["regions"]), "%s Continue regenerated region state" % locale)
	var pass_button: Button = _find_button(game, L10n.t("common.pass_turn"))
	var pass_before: int = GameState.turn
	_expect(pass_button != null, "%s Pass Turn button missing" % locale)
	if pass_button != null:
		_push_mouse(pass_button.get_global_rect().get_center())
		await get_tree().process_frame
	_expect(GameState.turn == pass_before + 1, "%s Pass Turn advanced an incorrect number of turns" % locale)
	await _dismiss_debrief_and_event(game, locale)
	game.queue_free()
	await get_tree().process_frame
	_restore_file(SaveManager.SAVE_PATH, save_backup)
	L10n.set("_locale", original_locale)
	SettingsManager.tutorial_completed = original_tutorial


func _dismiss_debrief_and_event(game: Control, locale: String) -> void:
	var debrief: Control = game.get("_debrief")
	var continue_button: Button = _find_button(debrief, L10n.t("common.continue"))
	_expect(continue_button != null, "%s Continue button missing from debrief" % locale)
	if continue_button != null:
		_push_mouse(continue_button.get_global_rect().get_center())
		await get_tree().process_frame
	var event_modal: Control = game.get("_event_modal")
	if event_modal.visible:
		var event: Dictionary = event_modal.get("_event")
		var event_id: String = String(event["id"])
		var choice_button: Button = _find_button(event_modal, L10n.t("event.%s.choice.0.text" % event_id))
		_expect(choice_button != null, "%s localized event choice missing" % locale)
		if choice_button != null:
			_push_mouse(choice_button.get_global_rect().get_center())
			await get_tree().process_frame
		continue_button = _find_button(debrief, L10n.t("common.continue"))
		if continue_button != null:
			_push_mouse(continue_button.get_global_rect().get_center())
			await get_tree().process_frame


func _test_end_conditions() -> void:
	var emits: Array[int] = [0]
	var callback := func(_won: bool, _reason: String) -> void: emits[0] += 1
	GameState.game_ended.connect(callback)
	for condition in ["win", "global", "trust", "collapse"]:
		GameState.new_campaign(Balance.Difficulty.STANDARD)
		match condition:
			"win": GameState.rival_exposure = Balance.WIN_RIVAL_EXPOSURE
			"global": GameState.global_exposure = Balance.LOSS_GLOBAL_EXPOSURE
			"trust": GameState.trust = Balance.LOSS_TRUST
			"collapse":
				for i in Balance.COLLAPSE_LIMIT:
					GameState.regions[i]["collapsed"] = true
		var before: int = emits[0]
		var result: Dictionary = GameState.check_end_conditions()
		GameState.check_end_conditions()
		_expect(bool(result.get("over", false)), "%s end condition did not trigger" % condition)
		_expect(bool(result.get("won", false)) == (condition == "win"), "%s end condition returned the wrong outcome" % condition)
		_expect(emits[0] == before + 1, "%s end condition emitted more than once" % condition)
	GameState.game_ended.disconnect(callback)


func _push_mouse(position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	get_viewport().push_input(press, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	get_viewport().push_input(release, true)


func _push_touch(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = position
	get_viewport().push_input(event, true)


func _find_button(root: Node, text: String) -> Button:
	for child_variant in root.find_children("*", "Button", true, false):
		var button: Button = child_variant
		if button.text == text:
			return button
	return null


func _backup_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	return {"exists": true, "bytes": FileAccess.get_file_as_bytes(path)}


func _restore_file(path: String, backup: Dictionary) -> void:
	if not bool(backup.get("exists", false)):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(backup.get("bytes", PackedByteArray()))


func _regions_match(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in actual.size():
		var actual_region: Dictionary = actual[i]
		var expected_region: Dictionary = expected[i]
		if actual_region.keys().size() != expected_region.keys().size():
			return false
		for key_variant in expected_region:
			var key: String = String(key_variant)
			if not actual_region.has(key):
				return false
			var actual_value: Variant = actual_region[key]
			var expected_value: Variant = expected_region[key]
			if (actual_value is int or actual_value is float) and (expected_value is int or expected_value is float):
				if not is_equal_approx(float(actual_value), float(expected_value)):
					return false
			elif actual_value != expected_value:
				return false
	return true


func _test_visible_ui(root: Control, context: String) -> void:
	for label_variant in root.find_children("*", "Label", true, false):
		var label: Label = label_variant
		if label.is_visible_in_tree():
			_expect("[MISSING:" not in label.text, "%s displayed a missing localization key" % context)
	for button_variant in root.find_children("*", "Button", true, false):
		var button: Button = button_variant
		if button.is_visible_in_tree():
			_expect("[MISSING:" not in button.text, "%s button displayed a missing localization key" % context)
	for scroll_variant in root.find_children("*", "ScrollContainer", true, false):
		var scroll: ScrollContainer = scroll_variant
		_expect(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s enabled horizontal scrolling" % context)


func _visible_text_contains(root: Control, expected: String) -> bool:
	for label_variant in root.find_children("*", "Label", true, false):
		var label: Label = label_variant
		if label.is_visible_in_tree() and expected in label.text:
			return true
	for button_variant in root.find_children("*", "Button", true, false):
		var button: Button = button_variant
		if button.is_visible_in_tree() and expected in button.text:
			return true
	return false


func _region(tag: String, revealed: bool) -> Dictionary:
	return {
		"id": "test",
		"name": "Test Region",
		"stability": 60,
		"surveillance": 30,
		"rival_influence": 30,
		"public_pressure": 30,
		"intel_level": 2,
		"local_network": 20,
		"opportunity": 50,
		"collapsed": false,
		"hidden_tag": tag,
		"tag_revealed": revealed,
	}


func _agent(trait_id: String) -> Dictionary:
	return {
		"id": "test_agent",
		"name": "Test Agent",
		"analysis": 6,
		"fieldcraft": 6,
		"diplomacy": 6,
		"technical": 6,
		"resolve": 6,
		"fatigue": 20,
		"trait": trait_id,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])


func _expect_approx(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (actual=%s expected=%s)" % [message, actual, expected])
