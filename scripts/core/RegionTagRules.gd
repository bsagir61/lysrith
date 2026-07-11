class_name RegionTagRules
extends RefCounted
## Pure rules for revealed regional identities. Stable English tag strings are
## save identifiers; presentation always goes through localization keys.


static func is_active(region: Dictionary) -> bool:
	return bool(region.get("tag_revealed", false)) and String(region.get("hidden_tag", "")) != ""


static func tag_id(region: Dictionary) -> String:
	return String(region.get("hidden_tag", "")) if is_active(region) else ""


static func chance_bonus(region: Dictionary, op: Dictionary) -> int:
	if not is_active(region):
		return 0
	var op_id: String = String(op.get("id", ""))
	match tag_id(region):
		"Signal Corridor":
			if op_id == "trace_cell":
				return Balance.TAG_SIGNAL_TRACE_CHANCE
			if op_id == "map_signals":
				return Balance.TAG_SIGNAL_MAP_CHANCE
		"Old Alliance":
			if op_id == "stabilize":
				return Balance.TAG_OLD_ALLIANCE_STABILIZE_CHANCE
		"Diplomatic Junction":
			if String(op.get("skill", "")) == "diplomacy":
				return Balance.TAG_DIPLOMATIC_CHANCE
	return 0


static func funds_cost_multiplier(region: Dictionary, _op: Dictionary) -> float:
	if is_active(region) and tag_id(region) == "Financial Gate":
		return Balance.TAG_FINANCIAL_FUNDS_MULT
	return 1.0


static func funds_cost_adjustment(region: Dictionary, op: Dictionary) -> int:
	if is_active(region) and tag_id(region) == "Diplomatic Junction" and String(op.get("id", "")) == "quiet_audit":
		return -Balance.TAG_DIPLOMATIC_AUDIT_FUNDS_DISCOUNT
	return 0


static func intel_cost_adjustment(region: Dictionary, op: Dictionary) -> int:
	if is_active(region) and tag_id(region) == "Research Node" and String(op.get("id", "")) == "deep_analysis":
		return -Balance.TAG_RESEARCH_DEEP_INTEL_DISCOUNT
	return 0


static func heat_adjustment(region: Dictionary, op: Dictionary) -> int:
	if is_active(region) and tag_id(region) == "Black Market Route" and String(op.get("id", "")) == "build_network":
		return Balance.TAG_BLACK_MARKET_HEAT
	return 0


static func effect_multiplier(region: Dictionary, op: Dictionary, effect_id: String = "primary") -> float:
	if not is_active(region):
		return 1.0
	var op_id: String = String(op.get("id", ""))
	match tag_id(region):
		"Media Core":
			if op_id == "reduce_heat" and effect_id == "heat":
				return Balance.TAG_MEDIA_REDUCE_HEAT_MULT
		"Border Zone":
			if op_id in ["counter_influence", "containment"]:
				return Balance.TAG_BORDER_EFFECT_MULT
		"Research Node":
			if op_id == "map_signals" and effect_id == "intel":
				return Balance.TAG_RESEARCH_MAP_INTEL_MULT
		"Civil Pressure Zone":
			if op_id == "stabilize":
				if effect_id == "stability":
					return Balance.TAG_CIVIL_STABILITY_MULT
				if effect_id == "pressure":
					return Balance.TAG_CIVIL_PRESSURE_MULT
		"Old Alliance":
			if op_id == "quiet_audit" and effect_id == "trust":
				return Balance.TAG_OLD_ALLIANCE_TRUST_MULT
		"Black Market Route":
			if op_id == "build_network" and effect_id == "network":
				return Balance.TAG_BLACK_MARKET_NETWORK_MULT
	return 1.0


static func passive_income_bonus(regions: Array) -> int:
	var bonus: int = 0
	for region_variant in regions:
		var region: Dictionary = region_variant
		if not bool(region.get("collapsed", false)) and is_active(region) and tag_id(region) == "Trade Hub":
			bonus += Balance.TAG_TRADE_HUB_INCOME
	return mini(bonus, Balance.TAG_TRADE_HUB_INCOME_CAP)


static func affects_operation(region: Dictionary, op: Dictionary) -> bool:
	return bool(modifier_data(region, op).get("active", false))


static func modifier_data(region: Dictionary, op: Dictionary) -> Dictionary:
	if not is_active(region):
		return {"active": false}
	var tag: String = tag_id(region)
	var op_id: String = String(op.get("id", ""))
	var text_key: String = ""
	match tag:
		"Media Core":
			if op_id == "reduce_heat":
				text_key = "region_tag.modifier.media_core.reduce_heat"
		"Border Zone":
			if op_id in ["counter_influence", "containment"]:
				text_key = "region_tag.modifier.border_zone.operation"
		"Research Node":
			if op_id == "map_signals":
				text_key = "region_tag.modifier.research_node.map"
			elif op_id == "deep_analysis":
				text_key = "region_tag.modifier.research_node.analysis"
		"Financial Gate":
			if int(op.get("cost_funds", 0)) > 0:
				text_key = "region_tag.modifier.financial_gate.operation"
		"Civil Pressure Zone":
			if op_id == "stabilize":
				text_key = "region_tag.modifier.civil_pressure.stabilize"
		"Signal Corridor":
			if op_id == "trace_cell":
				text_key = "region_tag.modifier.signal_corridor.trace"
			elif op_id == "map_signals":
				text_key = "region_tag.modifier.signal_corridor.map"
		"Old Alliance":
			if op_id == "quiet_audit":
				text_key = "region_tag.modifier.old_alliance.audit"
			elif op_id == "stabilize":
				text_key = "region_tag.modifier.old_alliance.stabilize"
		"Black Market Route":
			if op_id == "build_network":
				text_key = "region_tag.modifier.black_market.network"
		"Diplomatic Junction":
			if String(op.get("skill", "")) == "diplomacy":
				text_key = "region_tag.modifier.diplomatic.operation"
	if text_key == "":
		return {"active": false}
	return {
		"active": true,
		"source": "identity",
		"tag": tag,
		"kind": "identity",
		"text_key": text_key,
		"name_key": name_key(tag),
	}


static func name_key(tag: String) -> String:
	return "region_tag.%s.name" % _slug(tag)


static func description_key(tag: String) -> String:
	return "region_tag.%s.description" % _slug(tag)


static func recommended_operation_id(region: Dictionary) -> String:
	if not is_active(region):
		return ""
	match tag_id(region):
		"Trade Hub": return "build_network"
		"Media Core": return "reduce_heat"
		"Border Zone": return "counter_influence"
		"Research Node": return "map_signals"
		"Financial Gate": return "trace_cell"
		"Civil Pressure Zone": return "stabilize"
		"Signal Corridor": return "trace_cell"
		"Old Alliance": return "quiet_audit"
		"Black Market Route": return "build_network"
		"Diplomatic Junction": return "quiet_audit"
	return ""


static func _slug(tag: String) -> String:
	return tag.to_lower().replace(" ", "_")
