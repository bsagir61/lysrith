extends Node
## TurnResolver.gd - all operation resolution and turn advancement rules.
## Reads and mutates GameState; produces result dictionaries the UI renders.
## No UI code, no drawing, no scene logic.

# ---------- Previews (used by OperationPanel before confirming) ----------

func preview_operation(region: Dictionary, agent: Dictionary, op: Dictionary) -> Dictionary:
	var chance_data: Dictionary = chance_breakdown(region, agent, op)
	var cost_data: Dictionary = compute_costs(region, agent, op)
	var heat_data: Dictionary = heat_breakdown(region, agent, op)
	var modifiers: Array[Dictionary] = []
	var identity_modifier: Dictionary = RegionTagRules.modifier_data(region, op)
	if bool(identity_modifier.get("active", false)):
		_append_unique_modifiers(modifiers, [identity_modifier])
	_append_unique_modifiers(modifiers, chance_data.get("modifiers", []))
	_append_unique_modifiers(modifiers, cost_data.get("modifiers", []))
	_append_unique_modifiers(modifiers, heat_data.get("modifiers", []))
	_append_unique_modifiers(modifiers, _trait_preview_modifiers(agent, op))
	var result := {
		"chance": int(chance_data["final"]),
		"chance_breakdown": chance_data,
		"costs": cost_data,
		"heat": int(heat_data["final"]),
		"heat_breakdown": heat_data,
		"risk": risk_id(int(chance_data["final"])),
		"affordable": can_afford(cost_data),
		"modifiers": modifiers,
	}
	result["warnings"] = operation_warnings(region, agent, op, result)
	return result


func compute_chance(region: Dictionary, agent: Dictionary, op: Dictionary) -> int:
	return int(chance_breakdown(region, agent, op)["final"])


func chance_breakdown(region: Dictionary, agent: Dictionary, op: Dictionary) -> Dictionary:
	var components: Array[Dictionary] = []
	var modifiers: Array[Dictionary] = []
	var skill_key: String = String(op.get("skill", "analysis"))
	var skill: float = float(agent.get(skill_key, 1))
	var chance: float = float(op.get("base_chance", 50))
	components.append(_component("breakdown.base", chance, "base"))
	var skill_value: float = skill * Balance.W_SKILL
	chance += skill_value
	components.append(_component("breakdown.agent_skill", skill_value, "agent"))
	var fatigue_value: float = -float(agent.get("fatigue", 0)) * Balance.W_FATIGUE
	chance += fatigue_value
	components.append(_component("breakdown.fatigue", fatigue_value, "agent"))
	var network_value: float = float(region.get("local_network", 0)) * Balance.W_NETWORK
	chance += network_value
	components.append(_component("breakdown.local_network", network_value, "region"))
	var intel_value: float = float(region.get("intel_level", 0)) * Balance.W_INTEL_LEVEL
	chance += intel_value
	components.append(_component("breakdown.intel_level", intel_value, "region"))
	if op.get("covert", false):
		var surveillance_value: float = -float(region.get("surveillance", 0)) * Balance.W_SURVEILLANCE
		chance += surveillance_value
		components.append(_component("breakdown.surveillance", surveillance_value, "region"))
		var rival_value: float = -float(region.get("rival_influence", 0)) * Balance.W_RIVAL
		chance += rival_value
		components.append(_component("breakdown.rival_influence", rival_value, "region"))
	var difficulty_value: float = float(Balance.CHANCE_MOD[GameState.difficulty])
	chance += difficulty_value
	components.append(_component("breakdown.difficulty", difficulty_value, "difficulty"))
	var trait_value: float = 0.0
	match agent.get("trait", ""):
		"expensive_specialist":
			trait_value = Balance.TRAIT_EXPENSIVE_CHANCE
			modifiers.append(_modifier("agent", "agent_trait.modifier.expensive.chance"))
		"risk_averse":
			trait_value = Balance.TRAIT_RISK_AVERSE_CHANCE
			modifiers.append(_modifier("agent", "agent_trait.modifier.risk_averse.chance"))
	chance += trait_value
	components.append(_component("breakdown.agent_trait", trait_value, "agent"))
	var identity_value: float = float(RegionTagRules.chance_bonus(region, op))
	chance += identity_value
	components.append(_component("breakdown.region_identity", identity_value, "identity"))
	if not is_zero_approx(identity_value):
		var identity_modifier: Dictionary = RegionTagRules.modifier_data(region, op)
		if bool(identity_modifier.get("active", false)):
			modifiers.append(identity_modifier)
	return {
		"raw": chance,
		"final": clampi(int(round(chance)), Balance.CHANCE_MIN, Balance.CHANCE_MAX),
		"components": components,
		"modifiers": modifiers,
	}


func compute_costs(region: Dictionary, agent: Dictionary, op: Dictionary) -> Dictionary:
	var base_funds: int = int(op.get("cost_funds", 0))
	var base_intel: int = int(op.get("cost_intel", 0))
	var trust_cost: int = int(op.get("extra_cost_trust", 0))
	var funds_cost: int = base_funds
	var intel_cost: int = base_intel
	var modifiers: Array[Dictionary] = []
	var funds_components: Array[Dictionary] = [_component("breakdown.base", base_funds, "base")]
	var intel_components: Array[Dictionary] = [_component("breakdown.base", base_intel, "base")]
	if agent.get("trait", "") == "expensive_specialist":
		var trait_funds: int = int(round(funds_cost * Balance.TRAIT_EXPENSIVE_COST_MULT))
		funds_components.append(_component("breakdown.agent_trait", trait_funds - funds_cost, "agent"))
		funds_cost = trait_funds
		modifiers.append(_modifier("agent", "agent_trait.modifier.expensive.cost"))
	var before_identity_funds: int = funds_cost
	funds_cost = int(round(float(funds_cost) * RegionTagRules.funds_cost_multiplier(region, op)))
	funds_cost += RegionTagRules.funds_cost_adjustment(region, op)
	if base_funds > 0:
		funds_cost = maxi(Balance.MIN_POSITIVE_COST, funds_cost)
	var identity_funds_delta: int = funds_cost - before_identity_funds
	if identity_funds_delta != 0:
		funds_components.append(_component("breakdown.region_identity", identity_funds_delta, "identity"))
	var identity_intel_delta: int = RegionTagRules.intel_cost_adjustment(region, op)
	intel_cost += identity_intel_delta
	if base_intel > 0:
		intel_cost = maxi(Balance.MIN_POSITIVE_COST, intel_cost)
	if identity_intel_delta != 0:
		intel_components.append(_component("breakdown.region_identity", intel_cost - base_intel, "identity"))
	var identity_modifier: Dictionary = RegionTagRules.modifier_data(region, op)
	if bool(identity_modifier.get("active", false)) and (identity_funds_delta != 0 or identity_intel_delta != 0):
		modifiers.append(identity_modifier)
	return {
		"funds": funds_cost,
		"intel": intel_cost,
		"trust": trust_cost,
		"breakdown": {
			"funds": funds_components,
			"intel": intel_components,
			"trust": [_component("breakdown.base", trust_cost, "base")],
		},
		"modifiers": modifiers,
	}


func can_afford(costs: Dictionary) -> bool:
	return GameState.funds >= int(costs["funds"]) and GameState.intel >= int(costs["intel"])


func heat_preview(region: Dictionary, agent: Dictionary, op: Dictionary) -> int:
	return int(heat_breakdown(region, agent, op)["final"])


func heat_breakdown(region: Dictionary, agent: Dictionary, op: Dictionary) -> Dictionary:
	var components: Array[Dictionary] = []
	var modifiers: Array[Dictionary] = []
	var base_heat: float = float(op.get("heat", 0))
	var h: float = base_heat
	components.append(_component("breakdown.base", base_heat, "base"))
	var difficulty_heat: float = h * Balance.HEAT_PENALTY_RATE[GameState.difficulty]
	components.append(_component("breakdown.difficulty", difficulty_heat - h, "difficulty"))
	h = difficulty_heat
	if agent.get("trait", "") == "low_profile":
		var trait_heat: float = h * Balance.TRAIT_LOW_PROFILE_HEAT_MULT
		components.append(_component("breakdown.agent_trait", trait_heat - h, "agent"))
		h = trait_heat
		modifiers.append(_modifier("agent", "agent_trait.modifier.low_profile.heat"))
	var identity_heat: int = RegionTagRules.heat_adjustment(region, op)
	h += identity_heat
	if identity_heat != 0:
		components.append(_component("breakdown.region_identity", identity_heat, "identity"))
		modifiers.append({
			"source": "identity",
			"tag": RegionTagRules.tag_id(region),
			"text_key": "region_tag.modifier.black_market.heat",
		})
	return {"final": int(round(h)), "raw": h, "components": components, "modifiers": modifiers}


func risk_id(chance: int) -> String:
	if chance >= Balance.RISK_FAVORABLE_MIN:
		return "favorable"
	if chance >= Balance.RISK_UNCERTAIN_MIN:
		return "uncertain"
	if chance >= Balance.RISK_RISKY_MIN:
		return "risky"
	return "severe"


func operation_warnings(region: Dictionary, agent: Dictionary, op: Dictionary, preview: Dictionary) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	if not bool(preview.get("affordable", true)):
		warnings.append({"text_key": "operation.warning.resources", "severity": "danger"})
	if int(agent.get("fatigue", 0)) >= Balance.FATIGUE_STRAINED_THRESHOLD:
		warnings.append({"text_key": "operation.warning.fatigue", "severity": "warn"})
	if String(op.get("id", "")) == "trace_cell" and int(region.get("local_network", 0)) < Balance.ADVISOR_LOW_NETWORK_BELOW:
		warnings.append({"text_key": "operation.warning.low_network", "severity": "warn"})
	if int(region.get("intel_level", 0)) >= 1 and bool(op.get("covert", false)) and int(region.get("surveillance", 0)) >= Balance.ADVISOR_SURVEILLANCE_AT:
		warnings.append({"text_key": "operation.warning.surveillance", "severity": "warn"})
	if int(op.get("extra_cost_trust", 0)) > 0 and GameState.trust <= Balance.UI_TRUST_DANGER_AT:
		warnings.append({"text_key": "operation.warning.low_trust", "severity": "danger"})
	if GameState.heat >= Balance.UI_HEAT_WARNING_AT:
		warnings.append({"text_key": "operation.warning.high_heat", "severity": "warn"})
	return warnings


func confirmation_reasons(preview: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if int(preview.get("chance", 100)) < Balance.CONFIRM_CHANCE_BELOW:
		reasons.append("operation.confirm.low_chance")
	if GameState.heat + int(preview.get("heat", 0)) >= Balance.CONFIRM_HEAT_AT:
		reasons.append("operation.confirm.high_heat")
	var costs: Dictionary = preview.get("costs", {})
	if GameState.trust - int(costs.get("trust", 0)) <= Balance.CONFIRM_TRUST_AT and int(costs.get("trust", 0)) > 0:
		reasons.append("operation.confirm.low_trust")
	if GameState.funds - int(costs.get("funds", 0)) < 0:
		reasons.append("operation.confirm.negative_funds")
	return reasons


func agent_suitability(region: Dictionary, agent: Dictionary) -> Dictionary:
	var best_chance: int = -1
	var best_op_id: String = ""
	var specialist_advantage: bool = false
	for op_variant in OperationData.operations:
		var op: Dictionary = op_variant
		var preview: Dictionary = preview_operation(region, agent, op)
		if not bool(preview.get("affordable", false)):
			continue
		var chance: int = int(preview["chance"])
		if chance > best_chance:
			best_chance = chance
			best_op_id = String(op.get("id", ""))
		if RegionTagRules.affects_operation(region, op) and int(agent.get(String(op.get("skill", "analysis")), 0)) >= 7:
			specialist_advantage = true
	var fit: String = "risky"
	if int(agent.get("fatigue", 0)) >= Balance.AGENT_EXHAUSTED_FATIGUE:
		fit = "exhausted"
	elif specialist_advantage:
		fit = "specialist"
	elif best_chance >= Balance.RISK_FAVORABLE_MIN:
		fit = "strong"
	elif String(agent.get("trait", "")) in ["expensive_specialist", "risk_averse", "unstable_contact"] and best_chance >= Balance.RISK_UNCERTAIN_MIN:
		fit = "tradeoff"
	elif best_chance >= Balance.RISK_UNCERTAIN_MIN:
		fit = "viable"
	return {"id": fit, "text_key": "agent.fit.%s" % fit, "best_chance": best_chance, "best_op_id": best_op_id}


func turn_outlook() -> Dictionary:
	var trust_income: int = GameState.trust / Balance.INCOME_TRUST_DIVISOR
	var trade_income: int = RegionTagRules.passive_income_bonus(GameState.regions)
	var income: int = Balance.BASE_INCOME + trust_income + trade_income
	var upkeep: int = GameState.agents.size() * Balance.AGENT_UPKEEP
	var heat_change: int = -mini(GameState.heat, Balance.HEAT_DECAY_PER_TURN)
	var projected_heat: float = float(GameState.heat + heat_change)
	var projected_momentum: float = clampf(
		GameState.rival_momentum + Balance.RIVAL_MOMENTUM_GROWTH * Balance.RIVAL_SPREAD_RATE[GameState.difficulty],
		0.0, float(Balance.RIVAL_MOMENTUM_MAX))
	var exposure_pressure: float = (projected_heat / Balance.HEAT_TO_EXPOSURE + projected_momentum / Balance.MOMENTUM_TO_EXPOSURE) \
		* Balance.EXPOSURE_RATE[GameState.difficulty]
	var activity: String = "low"
	if projected_momentum >= Balance.OUTLOOK_ACTIVITY_HIGH_AT:
		activity = "high"
	elif projected_momentum >= Balance.OUTLOOK_ACTIVITY_MODERATE_AT:
		activity = "moderate"
	return {
		"base_income": Balance.BASE_INCOME,
		"trust_income": trust_income,
		"trade_income": trade_income,
		"income": income,
		"upkeep": upkeep,
		"budget_change": income - upkeep,
		"heat_change": heat_change,
		"exposure_pressure": exposure_pressure,
		"rival_activity": activity,
	}


# ---------- Operation resolution ----------

func resolve_operation(region_id: String, agent_id: String, op_id: String) -> Dictionary:
	var region: Dictionary = GameState.get_region(region_id)
	var agent: Dictionary = GameState.get_agent(agent_id)
	var op: Dictionary = OperationData.get_def(op_id)
	var preview: Dictionary = preview_operation(region, agent, op)
	var chance: int = int(preview["chance"])
	var costs: Dictionary = preview["costs"]
	var roll: int = RandomService.rand_int(1, 100)
	var success: bool = roll <= chance
	var near_miss: bool = not success and roll <= chance + 15
	var lines: Array[String] = []
	var effect_breakdown: Array[Dictionary] = []
	var applied_modifiers: Array[Dictionary] = []
	var resolved_chance: Dictionary = preview.get("chance_breakdown", {})
	var resolved_heat: Dictionary = preview.get("heat_breakdown", {})
	_append_unique_modifiers(applied_modifiers, resolved_chance.get("modifiers", []))
	_append_unique_modifiers(applied_modifiers, costs.get("modifiers", []))
	_append_unique_modifiers(applied_modifiers, resolved_heat.get("modifiers", []))
	var agent_effect_mult: float = _effect_multiplier(agent)
	var identity_was_revealed: bool = bool(region.get("tag_revealed", false))
	var identity_modifier_before: Dictionary = RegionTagRules.modifier_data(region, op)
	var before: Dictionary = _operation_snapshot(region)

	# Pay costs up front; failure does not refund them.
	GameState.add_resources({
		"funds": -int(costs["funds"]),
		"intel": -int(costs["intel"]),
		"trust": -int(costs["trust"]),
	})
	if int(costs["trust"]) > 0:
		lines.append(L10n.t("resolve.trust_spent", [int(costs["trust"])]))

	# Heat is generated by acting at all, success or not.
	var heat_gain: int = int(preview["heat"])
	if heat_gain != 0:
		GameState.add_resources({"heat": heat_gain})
		lines.append(L10n.t("resolve.heat_gain", [heat_gain]))

	if success:
		lines.append_array(_apply_success(region, agent, op, agent_effect_mult, 1.0, effect_breakdown))
	elif near_miss:
		lines.append(L10n.t("resolve.near_miss"))
		lines.append_array(_apply_success(region, agent, op, agent_effect_mult, Balance.OP_PARTIAL_EFFECT_MULT, effect_breakdown))
		lines.append_array(_apply_failure(region, agent, op, 0.5))
	else:
		lines.append_array(_apply_failure(region, agent, op, 1.0))
	var trait_id: String = String(agent.get("trait", ""))
	if (success or near_miss) and trait_id == "fast_analyst" and op_id == "map_signals":
		_append_unique_modifiers(applied_modifiers, [_modifier("agent", "agent_trait.modifier.fast_analyst.intel")])
	if not success and trait_id == "calm_under_pressure":
		_append_unique_modifiers(applied_modifiers, [_modifier("agent", "agent_trait.modifier.calm.failure")])
	if (success or near_miss) and bool(identity_modifier_before.get("active", false)):
		_append_unique_modifiers(applied_modifiers, [identity_modifier_before])

	var identity_revealed: bool = not identity_was_revealed and bool(region.get("tag_revealed", false))
	var identity_tag: String = String(region.get("hidden_tag", "")) if identity_revealed else ""
	if identity_revealed:
		GameState.add_resources({"intel": Balance.TAG_DISCOVERY_INTEL_REWARD})
		lines.append(L10n.t("resolve.identity_revealed", [
			String(region.get("name", region_id)),
			L10n.t(RegionTagRules.name_key(identity_tag)),
			Balance.TAG_DISCOVERY_INTEL_REWARD,
		]))
		applied_modifiers.append({
			"source": "identity",
			"text_key": "region_tag.discovery_reward",
			"args": [Balance.TAG_DISCOVERY_INTEL_REWARD],
		})
		TutorialManager.notify("identity_revealed")
	if (success or near_miss) and not is_equal_approx(agent_effect_mult, 1.0):
		var trait_key: String = "agent_trait.modifier.risk_averse.effect" if trait_id == "risk_averse" else "agent_trait.modifier.unstable.effect"
		_append_unique_modifiers(applied_modifiers, [_modifier("agent", trait_key)])

	# Fatigue and experience.
	agent["fatigue"] = clampi(int(agent["fatigue"]) + int(op.get("fatigue", 10)), 0, 100)
	agent["status"] = "Strained" if int(agent["fatigue"]) >= Balance.FATIGUE_STRAINED_THRESHOLD else "Ready"
	_grant_xp(agent, Balance.XP_SUCCESS if success else Balance.XP_FAIL, lines)

	GameState.stats["ops_run"] = int(GameState.stats.get("ops_run", 0)) + 1
	if success:
		GameState.stats["ops_won"] = int(GameState.stats.get("ops_won", 0)) + 1
	GameState.region_updated.emit(region_id)

	return {
		"success": success,
		"near_miss": near_miss,
		"chance": chance,
		"roll": roll,
		"op_name": op.get("name", op_id),
		"op_id": op_id,
		"region_name": region.get("name", region_id),
		"region_id": region_id,
		"agent_name": agent.get("name", agent_id),
		"agent_id": agent_id,
		"lines": lines,
		"preview": preview,
		"applied_modifiers": applied_modifiers,
		"identity_revealed": identity_revealed,
		"identity_tag": identity_tag,
		"identity_name_key": RegionTagRules.name_key(identity_tag) if identity_tag != "" else "",
		"identity_description_key": RegionTagRules.description_key(identity_tag) if identity_tag != "" else "",
		"cost_breakdown": costs.get("breakdown", {}),
		"heat_breakdown": preview.get("heat_breakdown", {}),
		"effect_breakdown": effect_breakdown,
		"changes": _snapshot_changes(before, _operation_snapshot(region)),
	}


func _apply_success(region: Dictionary, agent: Dictionary, op: Dictionary, agent_mult: float, outcome_mult: float, effect_breakdown: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	match op["id"]:
		"map_signals":
			region["intel_level"] = mini(3, int(region["intel_level"]) + 1)
			var map_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "intel")
			var map_agent_mult: float = agent_mult
			if agent.get("trait", "") == "fast_analyst":
				map_agent_mult *= Balance.TRAIT_FAST_ANALYST_INTEL_MULT
			var gain: float = float(Balance.OP_MAP_SIGNALS_INTEL) * map_agent_mult * map_identity_mult * outcome_mult
			var gained_intel: int = int(round(gain))
			GameState.add_resources({"intel": gained_intel})
			effect_breakdown.append(_effect("intel", Balance.OP_MAP_SIGNALS_INTEL, map_agent_mult, map_identity_mult, outcome_mult, gained_intel))
			lines.append(L10n.t("resolve.map_signals", [region["name"], int(region["intel_level"]), gained_intel]))
		"build_network":
			var network_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "network")
			var n: int = int(round(Balance.OP_BUILD_NETWORK_GAIN * agent_mult * network_identity_mult * outcome_mult))
			region["local_network"] = clampi(int(region["local_network"]) + n, 0, 100)
			effect_breakdown.append(_effect("local_network", Balance.OP_BUILD_NETWORK_GAIN, agent_mult, network_identity_mult, outcome_mult, n))
			lines.append(L10n.t("resolve.build_network", [region["name"], n, int(region["local_network"])]))
		"counter_influence":
			var counter_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "rival")
			var cut: int = int(round(Balance.OP_COUNTER_INFLUENCE_REDUCE * agent_mult * counter_identity_mult * outcome_mult))
			region["rival_influence"] = clampi(int(region["rival_influence"]) - cut, 0, 100)
			effect_breakdown.append(_effect("rival_influence", Balance.OP_COUNTER_INFLUENCE_REDUCE, agent_mult, counter_identity_mult, outcome_mult, -cut))
			lines.append(L10n.t("resolve.counter_influence", [region["name"], cut]))
		"stabilize":
			var stability_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "stability")
			var pressure_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "pressure")
			var s: int = int(round(Balance.OP_STABILIZE_GAIN * agent_mult * stability_identity_mult * outcome_mult))
			var pressure_cut: int = int(round(Balance.OP_STABILIZE_PRESSURE_CUT * pressure_identity_mult * outcome_mult))
			region["stability"] = clampi(int(region["stability"]) + s, 0, 100)
			region["public_pressure"] = clampi(int(region["public_pressure"]) - pressure_cut, 0, 100)
			effect_breakdown.append(_effect("stability", Balance.OP_STABILIZE_GAIN, agent_mult, stability_identity_mult, outcome_mult, s))
			effect_breakdown.append(_effect("public_pressure", Balance.OP_STABILIZE_PRESSURE_CUT, 1.0, pressure_identity_mult, outcome_mult, -pressure_cut))
			lines.append(L10n.t("resolve.stabilize", [region["name"], s, pressure_cut]))
		"reduce_heat":
			var heat_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "heat")
			var h: int = int(round(Balance.OP_REDUCE_HEAT_AMOUNT * agent_mult * heat_identity_mult * outcome_mult))
			GameState.add_resources({"heat": -h, "cover": Balance.OP_REDUCE_HEAT_COVER})
			effect_breakdown.append(_effect("heat", Balance.OP_REDUCE_HEAT_AMOUNT, agent_mult, heat_identity_mult, outcome_mult, -h))
			lines.append(L10n.t("resolve.reduce_heat", [h, Balance.OP_REDUCE_HEAT_COVER]))
		"trace_cell":
			var base_exposure: float = float(Balance.OP_TRACE_EXPOSURE_BASE) + float(region["local_network"]) * Balance.OP_TRACE_EXPOSURE_NETWORK_BONUS
			var exposure: int = int(round(base_exposure * agent_mult * outcome_mult))
			GameState.add_resources({"rival_exposure": exposure})
			region["rival_influence"] = clampi(int(region["rival_influence"]) - Balance.OP_TRACE_RIVAL_CUT, 0, 100)
			effect_breakdown.append(_effect("rival_exposure", base_exposure, agent_mult, 1.0, outcome_mult, exposure))
			lines.append(L10n.t("resolve.trace_cell", [region["name"], exposure]))
		"containment":
			var containment_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "stability")
			var st: int = int(round(Balance.OP_CONTAIN_STABILITY * agent_mult * containment_identity_mult * outcome_mult))
			var rival_cut: int = int(round(Balance.OP_CONTAIN_RIVAL_CUT * containment_identity_mult * outcome_mult))
			region["stability"] = clampi(int(region["stability"]) + st, 0, 100)
			region["rival_influence"] = clampi(int(region["rival_influence"]) - rival_cut, 0, 100)
			effect_breakdown.append(_effect("stability", Balance.OP_CONTAIN_STABILITY, agent_mult, containment_identity_mult, outcome_mult, st))
			effect_breakdown.append(_effect("rival_influence", Balance.OP_CONTAIN_RIVAL_CUT, 1.0, containment_identity_mult, outcome_mult, -rival_cut))
			lines.append(L10n.t("resolve.containment", [region["name"], st, rival_cut]))
		"deep_analysis":
			region["tag_revealed"] = true
			region["intel_level"] = 3
			lines.append(L10n.t("resolve.deep_analysis", [region["name"], L10n.t(RegionTagRules.name_key(String(region["hidden_tag"])))]))
		"quiet_audit":
			var audit_identity_mult: float = RegionTagRules.effect_multiplier(region, op, "trust")
			var t: int = int(round(Balance.OP_QUIET_AUDIT_TRUST * agent_mult * audit_identity_mult * outcome_mult))
			GameState.add_resources({"trust": t})
			region["public_pressure"] = clampi(int(region["public_pressure"]) - Balance.OP_QUIET_AUDIT_PRESSURE_CUT, 0, 100)
			effect_breakdown.append(_effect("trust", Balance.OP_QUIET_AUDIT_TRUST, agent_mult, audit_identity_mult, outcome_mult, t))
			lines.append(L10n.t("resolve.quiet_audit", [t, region["name"]]))
	return lines


func _apply_failure(region: Dictionary, agent: Dictionary, op: Dictionary, scale: float) -> Array[String]:
	var lines: Array[String] = []
	var rate := Balance.FAIL_PENALTY_RATE[GameState.difficulty] * scale
	if agent.get("trait", "") == "calm_under_pressure":
		rate *= Balance.TRAIT_CALM_FAIL_MULT
	# Cover can absorb part of a failure.
	if GameState.cover >= Balance.OP_FAIL_COVER_ABSORB:
		GameState.add_resources({"cover": -Balance.OP_FAIL_COVER_ABSORB})
		rate *= 0.5
		lines.append(L10n.t("resolve.cover_absorb", [Balance.OP_FAIL_COVER_ABSORB]))
	var heat_hit := int(round(Balance.OP_FAIL_HEAT_BONUS * rate))
	var trust_hit := int(round(Balance.OP_FAIL_TRUST_HIT * rate))
	var stab_hit := int(round(Balance.OP_FAIL_STABILITY_HIT * rate))
	GameState.add_resources({"heat": heat_hit, "trust": -trust_hit})
	region["stability"] = clampi(int(region["stability"]) - stab_hit, 0, 100)
	lines.append(L10n.t("resolve.failure", [heat_hit, trust_hit, region["name"], stab_hit]))
	if op.get("covert", false):
		region["surveillance"] = clampi(int(region["surveillance"]) + 5, 0, 100)
		lines.append(L10n.t("resolve.surveillance_tightened", [region["name"]]))
	return lines


func _effect_multiplier(agent: Dictionary) -> float:
	match agent.get("trait", ""):
		"risk_averse":
			return Balance.TRAIT_RISK_AVERSE_EFFECT_MULT
		"unstable_contact":
			return Balance.TRAIT_UNSTABLE_EFFECT_MULT
	return 1.0


func _grant_xp(agent: Dictionary, xp: int, lines: Array[String]) -> void:
	agent["xp"] = int(agent["xp"]) + xp
	var needed := int(agent["level"]) * Balance.XP_PER_LEVEL
	if int(agent["xp"]) >= needed and int(agent["level"]) < Balance.LEVEL_MAX:
		agent["xp"] = int(agent["xp"]) - needed
		agent["level"] = int(agent["level"]) + 1
		# Level up sharpens the agent's strongest skill.
		var best_key := "analysis"
		for key in ["analysis", "fieldcraft", "diplomacy", "technical", "resolve"]:
			if int(agent[key]) > int(agent[best_key]):
				best_key = key
		agent[best_key] = mini(Balance.SKILL_MAX, int(agent[best_key]) + 1)
		lines.append(L10n.t("resolve.level_up", [agent["name"], int(agent["level"]), L10n.t("skill.%s" % best_key)]))


# ---------- Turn advancement ----------

## Runs world upkeep after the player's operation cycle (or a passed turn).
## Returns {lines, event, end}.
func advance_turn(acted_agent_id: String = "") -> Dictionary:
	var lines: Array[String] = []
	var economy_lines: Array[String] = []
	var world_lines: Array[String] = []
	var before: Dictionary = _campaign_snapshot()
	var applied_modifiers: Array[Dictionary] = []
	var extra_event_chance := 0.0
	if acted_agent_id != "":
		var acted: Dictionary = GameState.get_agent(acted_agent_id)
		if acted.get("trait", "") == "unstable_contact":
			extra_event_chance = Balance.TRAIT_UNSTABLE_EVENT_BONUS
			applied_modifiers.append(_modifier("agent", "agent_trait.modifier.unstable.event"))

	# Income and upkeep.
	var outlook: Dictionary = turn_outlook()
	var income: int = int(outlook["income"])
	var upkeep: int = int(outlook["upkeep"])
	var trade_income: int = int(outlook["trade_income"])
	GameState.add_resources({"funds": income - upkeep})
	var budget_line: String = L10n.t("resolve.budget_cycle", [income, upkeep])
	lines.append(budget_line)
	economy_lines.append(budget_line)
	if trade_income > 0:
		var trade_line: String = L10n.t("resolve.trade_hub_income", [trade_income])
		lines.append(trade_line)
		economy_lines.append(trade_line)
		applied_modifiers.append({
			"source": "identity",
			"tag": "Trade Hub",
			"text_key": "region_tag.modifier.trade_hub.income",
			"args": [trade_income],
		})

	# Passive heat decay.
	if GameState.heat > 0:
		var heat_decay: int = mini(GameState.heat, Balance.HEAT_DECAY_PER_TURN)
		GameState.add_resources({"heat": -heat_decay})
		var heat_line: String = L10n.t("resolve.passive_heat", [heat_decay])
		lines.append(heat_line)
		economy_lines.append(heat_line)

	# Resting agents recover.
	for a in GameState.agents:
		if a["id"] != acted_agent_id and int(a["fatigue"]) > 0:
			a["fatigue"] = maxi(0, int(a["fatigue"]) - Balance.FATIGUE_RECOVERY_PER_TURN)
			a["status"] = "Strained" if int(a["fatigue"]) >= Balance.FATIGUE_STRAINED_THRESHOLD else "Ready"

	# Rival network grows and spreads.
	GameState.rival_momentum = clampf(
		GameState.rival_momentum + Balance.RIVAL_MOMENTUM_GROWTH * Balance.RIVAL_SPREAD_RATE[GameState.difficulty],
		0.0, float(Balance.RIVAL_MOMENTUM_MAX))
	var spread_lines: Array[String] = _spread_rival()
	lines.append_array(spread_lines)
	world_lines.append_array(spread_lines)

	# Rival-held regions erode; collapses cascade pressure to neighbors.
	var collapse_lines: Array[String] = _erode_and_collapse()
	lines.append_array(collapse_lines)
	world_lines.append_array(collapse_lines)

	# Global exposure creep from heat and rival momentum.
	var exposure_gain := (GameState.heat / Balance.HEAT_TO_EXPOSURE + GameState.rival_momentum / Balance.MOMENTUM_TO_EXPOSURE) \
		* Balance.EXPOSURE_RATE[GameState.difficulty]
	GameState.add_resources({"global_exposure": exposure_gain})
	var exposure_line: String = L10n.t("resolve.exposure_pressure", [exposure_gain])
	lines.append(exposure_line)
	world_lines.append(exposure_line)

	if GameState.funds < 0:
		var overdrawn_line: String = L10n.t("resolve.overdrawn")
		lines.append(overdrawn_line)
		world_lines.append(overdrawn_line)

	GameState.turn += 1
	var end := GameState.check_end_conditions()
	var event: Dictionary = {}
	if not end["over"]:
		event = EventData.pick_event(GameState, extra_event_chance)
	return {
		"lines": lines,
		"economy_lines": economy_lines,
		"world_lines": world_lines,
		"event": event,
		"end": end,
		"economy": {
			"income": income,
			"upkeep": upkeep,
			"trade_income": trade_income,
			"budget_change": income - upkeep,
			"heat_change": int(outlook["heat_change"]),
			"exposure_gain": exposure_gain,
		},
		"applied_modifiers": applied_modifiers,
		"changes": _snapshot_changes(before, _campaign_snapshot()),
	}


func _spread_rival() -> Array[String]:
	var lines: Array[String] = []
	var live: Array = GameState.active_regions()
	if live.is_empty():
		return lines
	# Prefer spreading from strongholds into their neighbors.
	var sources := live.filter(func(r): return int(r["rival_influence"]) >= 50)
	var targets: Array = []
	for src in sources:
		for nid in RegionData.neighbors_of(src["id"]):
			var n: Dictionary = GameState.get_region(nid)
			if not n.is_empty() and not n["collapsed"]:
				targets.append(n)
	if targets.is_empty():
		targets = live
	targets = RandomService.shuffled(targets).slice(0, Balance.RIVAL_SPREAD_TARGETS)
	var amount := int(round(Balance.RIVAL_SPREAD_BASE * (0.5 + GameState.rival_momentum / 100.0) \
		* Balance.RIVAL_SPREAD_RATE[GameState.difficulty]))
	for t in targets:
		t["rival_influence"] = clampi(int(t["rival_influence"]) + amount, 0, 100)
		GameState.region_updated.emit(t["id"])
	if amount > 0 and not targets.is_empty():
		var names := ", ".join(targets.map(func(t): return String(t["name"])))
		lines.append(L10n.t("resolve.rival_spread", [names]))
	return lines


func _erode_and_collapse() -> Array[String]:
	var lines: Array[String] = []
	for r in GameState.active_regions():
		if int(r["rival_influence"]) >= Balance.RIVAL_STABILITY_EROSION_THRESHOLD:
			r["stability"] = clampi(int(r["stability"]) - Balance.RIVAL_STABILITY_EROSION, 0, 100)
			r["public_pressure"] = clampi(int(r["public_pressure"]) + Balance.RIVAL_PRESSURE_GAIN, 0, 100)
		if int(r["stability"]) < Balance.COLLAPSE_STABILITY_THRESHOLD:
			GameState.collapse_region(r)
			GameState.add_resources({"global_exposure": Balance.COLLAPSE_EXPOSURE_SPIKE})
			lines.append(L10n.t("resolve.region_collapsed", [r["name"]]))
			for nid in RegionData.neighbors_of(r["id"]):
				var n: Dictionary = GameState.get_region(nid)
				if not n.is_empty() and not n["collapsed"]:
					n["stability"] = clampi(int(n["stability"]) - Balance.COLLAPSE_NEIGHBOR_STABILITY_HIT, 0, 100)
					GameState.region_updated.emit(nid)
	return lines


func _component(text_key: String, value: Variant, source: String) -> Dictionary:
	return {"text_key": text_key, "value": float(value), "source": source}


func _modifier(source: String, text_key: String, args: Array = []) -> Dictionary:
	return {"source": source, "text_key": text_key, "args": args}


func _trait_preview_modifiers(agent: Dictionary, op: Dictionary) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	match String(agent.get("trait", "")):
		"fast_analyst":
			if String(op.get("id", "")) == "map_signals":
				modifiers.append(_modifier("agent", "agent_trait.modifier.fast_analyst.intel"))
		"risk_averse":
			modifiers.append(_modifier("agent", "agent_trait.modifier.risk_averse.effect"))
		"calm_under_pressure":
			modifiers.append(_modifier("agent", "agent_trait.modifier.calm.failure"))
		"unstable_contact":
			modifiers.append(_modifier("agent", "agent_trait.modifier.unstable.effect"))
	return modifiers


func _effect(effect_id: String, base: float, agent_mult: float, identity_mult: float, outcome_mult: float, final_value: int) -> Dictionary:
	var direction: int = -1 if final_value < 0 else 1
	var without_identity: int = int(round(base * agent_mult * outcome_mult)) * direction
	return {
		"effect_id": effect_id,
		"base": base,
		"agent_multiplier": agent_mult,
		"identity_multiplier": identity_mult,
		"outcome_multiplier": outcome_mult,
		"identity_delta": final_value - without_identity,
		"final": final_value,
	}


func _append_unique_modifiers(target: Array[Dictionary], source: Array) -> void:
	for modifier_variant in source:
		var modifier: Dictionary = modifier_variant
		var key: String = String(modifier.get("text_key", ""))
		var exists: bool = false
		for current in target:
			if String(current.get("text_key", "")) == key and key != "":
				exists = true
				break
		if not exists:
			target.append(modifier.duplicate(true))


func _operation_snapshot(region: Dictionary) -> Dictionary:
	return {
		"funds": GameState.funds,
		"intel": GameState.intel,
		"trust": GameState.trust,
		"heat": GameState.heat,
		"cover": GameState.cover,
		"rival_exposure": GameState.rival_exposure,
		"global_exposure": GameState.global_exposure,
		"region_stability": float(region.get("stability", 0)),
		"region_rival": float(region.get("rival_influence", 0)),
		"region_pressure": float(region.get("public_pressure", 0)),
		"local_network": float(region.get("local_network", 0)),
		"intel_level": float(region.get("intel_level", 0)),
	}


func _campaign_snapshot() -> Dictionary:
	return {
		"funds": GameState.funds,
		"intel": GameState.intel,
		"trust": GameState.trust,
		"heat": GameState.heat,
		"cover": GameState.cover,
		"rival_exposure": GameState.rival_exposure,
		"global_exposure": GameState.global_exposure,
		"rival_momentum": GameState.rival_momentum,
		"world_stability": GameState.world_stability(),
		"collapsed_regions": GameState.collapsed_count(),
	}


func _snapshot_changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	for key_variant in before.keys():
		var key: String = String(key_variant)
		if not after.has(key):
			continue
		var before_value: float = float(before[key])
		var after_value: float = float(after[key])
		if not is_equal_approx(before_value, after_value):
			changes[key] = {"before": before_value, "after": after_value, "delta": after_value - before_value}
	return changes
