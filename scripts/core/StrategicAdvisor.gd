class_name StrategicAdvisor
extends RefCounted
## Pure advisory rules. Recommendations are derived from visible information
## and never select or execute an operation.


static func recommendations(region: Dictionary, context: Dictionary = {}) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if region.is_empty() or bool(region.get("collapsed", false)):
		return candidates
	var intel_level: int = int(region.get("intel_level", 0))
	var stability: int = int(region.get("stability", 0))
	var network: int = int(region.get("local_network", 0))
	if intel_level < 2:
		_add(candidates, "map_signals", "advisor.map_signals", 100 - intel_level * 8)
	if stability < Balance.ADVISOR_STABILITY_AT:
		_add(candidates, "stabilize", "advisor.stabilize", 96)
	if int(context.get("heat", 0)) >= Balance.ADVISOR_HIGH_HEAT_AT:
		_add(candidates, "reduce_heat", "advisor.reduce_heat", 92)
	if intel_level >= 1 and int(region.get("rival_influence", 0)) >= Balance.ADVISOR_RIVAL_AT:
		_add(candidates, "counter_influence", "advisor.counter_influence", 88)
	if not bool(region.get("tag_revealed", false)) and intel_level >= 2:
		_add(candidates, "deep_analysis", "advisor.deep_analysis", 84)
	if network < Balance.ADVISOR_LOW_NETWORK_BELOW:
		_add(candidates, "build_network", "advisor.build_network", 72)
	if network >= Balance.ADVISOR_TRACE_NETWORK_AT:
		_add(candidates, "trace_cell", "advisor.trace_cell", 70)
	var identity_op: String = RegionTagRules.recommended_operation_id(region)
	if identity_op != "":
		_add(candidates, identity_op, "advisor.identity.%s" % RegionTagRules.tag_id(region).to_lower().replace(" ", "_"), 82)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"]))
	var result: Array[Dictionary] = []
	for i in mini(candidates.size(), Balance.ADVISOR_MAX_RECOMMENDATIONS):
		result.append(candidates[i])
	return result


static func _add(items: Array[Dictionary], op_id: String, text_key: String, priority: int) -> void:
	for item in items:
		if String(item.get("op_id", "")) == op_id:
			if priority > int(item.get("priority", 0)):
				item["text_key"] = text_key
				item["priority"] = priority
			return
	items.append({"op_id": op_id, "text_key": text_key, "priority": priority})
