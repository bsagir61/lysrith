class_name StrategicValidation
extends Node
## Headless release check for the strategic-clarity update.
## Does not call SaveManager and never touches the player's save slot.

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_test_localization()
	_test_unrevealed_isolation()
	_test_identity_rules()
	_test_trait_interactions()
	_test_discovery_reward()
	_test_preview_payment()
	_test_trade_hub_turn_income()
	_test_in_memory_save_compatibility()
	await _test_ui_flow("en", false, false)
	await _test_ui_flow("tr", true, true)
	if _failures.is_empty():
		print("STRATEGIC_VALIDATION_OK checks=%d" % _checks)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("STRATEGIC_VALIDATION: %s" % failure)
	print("STRATEGIC_VALIDATION_FAILED checks=%d failures=%d" % [_checks, _failures.size()])
	get_tree().quit(1)


func _test_localization() -> void:
	var english: Dictionary = L10n.TEXT["en"]
	var turkish: Dictionary = L10n.TEXT["tr"]
	_expect_equal(english.size(), turkish.size(), "EN/TR localization key counts differ")
	for key_variant in english.keys():
		var key: String = String(key_variant)
		_expect(turkish.has(key), "Turkish localization is missing %s" % key)
	for tag_variant in RegionData.hidden_tags:
		var tag: String = String(tag_variant)
		_expect(english.has(RegionTagRules.name_key(tag)), "Missing identity name key for %s" % tag)
		_expect(english.has(RegionTagRules.description_key(tag)), "Missing identity description key for %s" % tag)
	for op_variant in OperationData.operations:
		var op: Dictionary = op_variant
		var op_id: String = String(op["id"])
		for suffix in ["name", "description", "effect"]:
			_expect(english.has("operation.%s.%s" % [op_id, suffix]), "Missing operation localization for %s.%s" % [op_id, suffix])


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
	game.call("_on_plan_requested", region_id)
	var roster: Control = game.get("_roster_panel")
	_expect(roster.visible, "%s agent roster did not open" % locale)
	var agent_id: String = String(GameState.agents[0]["id"])
	game.call("_on_agent_selected", agent_id)
	var operation_panel: Control = game.get("_op_panel")
	_expect(operation_panel.visible, "%s operation planner did not open" % locale)
	operation_panel.call("_select_op", "map_signals")
	var confirm_button: Button = operation_panel.get("_confirm_btn")
	_expect(not confirm_button.disabled, "%s affordable operation was disabled" % locale)
	game.call("_on_operation_confirmed", "map_signals")
	await get_tree().process_frame
	var debrief: Control = game.get("_debrief")
	_expect(debrief.visible, "%s debrief did not open" % locale)
	game.queue_free()
	await get_tree().process_frame
	L10n.set("_locale", original_locale)
	SettingsManager.large_text = original_large
	SettingsManager.reduce_motion = original_motion
	SettingsManager.tutorial_completed = original_tutorial


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
