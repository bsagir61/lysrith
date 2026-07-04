extends Node
## GameState.gd - single source of truth for the current campaign.
## Holds resources, global meters, region states, agent states and event
## history. Contains no UI code and no operation resolution logic.

signal resources_changed
signal region_updated(region_id: String)
signal game_ended(won: bool, reason: String)

# ---------- Campaign meta ----------
var difficulty: int = Balance.Difficulty.STANDARD
var turn: int = 1
var campaign_seed: int = 0
var campaign_active: bool = false
var game_over: bool = false
var tutorial_done: bool = false

# ---------- Resources ----------
var intel: int = 0
var funds: int = 0
var trust: int = 0
var heat: int = 0
var cover: int = 0
var funds_warning: bool = false

# ---------- Global meters ----------
var global_exposure: float = 0.0
var rival_momentum: float = 0.0
var rival_exposure: float = 0.0

# ---------- Collections ----------
var regions: Array = []        # runtime region dictionaries
var agents: Array = []         # runtime agent dictionaries
var event_history: Array = []  # [{id, turn, choice}]

# ---------- Run statistics (for debrief / end screens) ----------
var stats: Dictionary = {}
# Set once when the campaign ends; read by Win/Loss screens.
var last_end: Dictionary = {}


func new_campaign(new_difficulty: int) -> void:
	difficulty = new_difficulty
	campaign_seed = RandomService.randomize_seed()
	turn = 1
	game_over = false
	campaign_active = true
	funds_warning = false
	intel = Balance.START_INTEL[difficulty]
	funds = Balance.START_FUNDS[difficulty]
	trust = Balance.START_TRUST[difficulty]
	heat = Balance.START_HEAT[difficulty]
	cover = Balance.START_COVER[difficulty]
	global_exposure = 0.0
	rival_momentum = float(Balance.RIVAL_MOMENTUM_START)
	rival_exposure = 0.0
	event_history = []
	stats = {"ops_run": 0, "ops_won": 0, "events_faced": 0, "regions_lost": 0}
	_generate_regions()
	_generate_agents()
	resources_changed.emit()


func _generate_regions() -> void:
	regions = []
	var tag_pool: Array = RandomService.shuffled(RegionData.hidden_tags)
	for i in RegionData.regions.size():
		var def: Dictionary = RegionData.regions[i]
		var tag: String
		if i < tag_pool.size():
			tag = tag_pool[i]
		else:
			tag = RandomService.pick(RegionData.hidden_tags)
		regions.append({
			"id": def["id"],
			"name": def["name"],
			"stability": RandomService.rand_int(Balance.GEN_STABILITY_MIN, Balance.GEN_STABILITY_MAX),
			"surveillance": RandomService.rand_int(Balance.GEN_SURVEILLANCE_MIN, Balance.GEN_SURVEILLANCE_MAX),
			"rival_influence": RandomService.rand_int(Balance.GEN_RIVAL_MIN, Balance.GEN_RIVAL_MAX),
			"public_pressure": RandomService.rand_int(Balance.GEN_PRESSURE_MIN, Balance.GEN_PRESSURE_MAX),
			"intel_level": 0,
			"local_network": 0,
			"opportunity": RandomService.rand_int(Balance.GEN_OPPORTUNITY_MIN, Balance.GEN_OPPORTUNITY_MAX),
			"collapsed": false,
			"hidden_tag": tag,
			"tag_revealed": false,
		})
	# A few regions begin as rival hotspots so the early map has direction.
	var hotspots: Array = RandomService.shuffled(regions).slice(0, Balance.GEN_SEED_RIVAL_HOTSPOTS)
	for r in hotspots:
		r["rival_influence"] = mini(100, int(r["rival_influence"]) + Balance.GEN_HOTSPOT_RIVAL_BONUS)


func _generate_agents() -> void:
	agents = []
	for def in AgentData.agents:
		agents.append({
			"id": def["id"],
			"name": def["name"],
			"role": def["role"],
			"analysis": int(def["analysis"]),
			"fieldcraft": int(def["fieldcraft"]),
			"diplomacy": int(def["diplomacy"]),
			"technical": int(def["technical"]),
			"resolve": int(def["resolve"]),
			"fatigue": 0,
			"level": 1,
			"xp": 0,
			"trait": def["trait"],
			"status": "Ready",
		})


# ---------- Lookups ----------
func get_region(region_id: String) -> Dictionary:
	for r in regions:
		if r["id"] == region_id:
			return r
	return {}


func get_agent(agent_id: String) -> Dictionary:
	for a in agents:
		if a["id"] == agent_id:
			return a
	return {}


func active_regions() -> Array:
	return regions.filter(func(r): return not r["collapsed"])


func collapsed_count() -> int:
	var n := 0
	for r in regions:
		if r["collapsed"]:
			n += 1
	return n


func world_stability() -> float:
	var live := active_regions()
	if live.is_empty():
		return 0.0
	var total := 0.0
	for r in live:
		total += float(r["stability"])
	return total / float(live.size())


func recent_event_ids(window: int) -> Array:
	var out: Array = []
	for entry in event_history:
		if int(entry["turn"]) > turn - window:
			out.append(entry["id"])
	return out


# ---------- Mutations ----------
func add_resources(delta: Dictionary) -> void:
	intel = maxi(0, intel + int(delta.get("intel", 0)))
	funds = funds + int(delta.get("funds", 0))
	trust = clampi(trust + int(delta.get("trust", 0)), 0, 100)
	heat = clampi(heat + int(delta.get("heat", 0)), 0, 100)
	cover = clampi(cover + int(delta.get("cover", 0)), 0, 100)
	global_exposure = clampf(global_exposure + float(delta.get("global_exposure", 0)), 0.0, 100.0)
	rival_momentum = clampf(rival_momentum + float(delta.get("rival_momentum", 0)), 0.0, float(Balance.RIVAL_MOMENTUM_MAX))
	rival_exposure = clampf(rival_exposure + float(delta.get("rival_exposure", 0)), 0.0, 100.0)
	resources_changed.emit()


## Applies an event-choice effect dictionary. Returns readable summary lines.
## Negative consequences are scaled by difficulty event severity.
func apply_effects(effects: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var severity: float = Balance.EVENT_SEVERITY[difficulty]
	var res_delta := {}
	for key in ["intel", "funds", "trust", "heat", "cover", "global_exposure", "rival_momentum", "rival_exposure"]:
		if effects.has(key):
			var val := float(effects[key])
			if _is_harmful(key, val):
				val = val * severity
			res_delta[key] = int(round(val))
			lines.append(_describe_delta(key, res_delta[key]))
	if not res_delta.is_empty():
		add_resources(res_delta)

	var target: Dictionary = _random_active_region()
	if not target.is_empty():
		if effects.has("region_stability"):
			var v := int(round(float(effects["region_stability"]) * (severity if float(effects["region_stability"]) < 0 else 1.0)))
			target["stability"] = clampi(int(target["stability"]) + v, 0, 100)
			lines.append("%s stability %s%d" % [target["name"], "+" if v >= 0 else "", v])
			region_updated.emit(target["id"])
		if effects.has("region_rival"):
			var v2 := int(round(float(effects["region_rival"]) * (severity if float(effects["region_rival"]) > 0 else 1.0)))
			target["rival_influence"] = clampi(int(target["rival_influence"]) + v2, 0, 100)
			lines.append("%s rival influence %s%d" % [target["name"], "+" if v2 >= 0 else "", v2])
			region_updated.emit(target["id"])
		if effects.has("region_pressure"):
			var v3 := int(effects["region_pressure"])
			target["public_pressure"] = clampi(int(target["public_pressure"]) + v3, 0, 100)
			lines.append("%s public pressure %s%d" % [target["name"], "+" if v3 >= 0 else "", v3])
			region_updated.emit(target["id"])
		if effects.has("region_rival_reveal"):
			target["intel_level"] = maxi(int(target["intel_level"]), 2)
			lines.append("Rival presence in %s charted (Intel Level 2)" % target["name"])
			region_updated.emit(target["id"])
		if effects.has("reveal_tag"):
			var hidden := regions.filter(func(r): return not r["tag_revealed"] and not r["collapsed"])
			if not hidden.is_empty():
				var reg: Dictionary = RandomService.pick(hidden)
				reg["tag_revealed"] = true
				lines.append("%s identified as: %s" % [reg["name"], reg["hidden_tag"]])
				region_updated.emit(reg["id"])

	if effects.has("all_stability"):
		var v4 := int(round(float(effects["all_stability"]) * (severity if float(effects["all_stability"]) < 0 else 1.0)))
		for r in active_regions():
			r["stability"] = clampi(int(r["stability"]) + v4, 0, 100)
		lines.append("All regions stability %s%d" % ["+" if v4 >= 0 else "", v4])
	if effects.has("agent_fatigue"):
		var a: Dictionary = RandomService.pick(agents)
		a["fatigue"] = clampi(int(a["fatigue"]) + int(effects["agent_fatigue"]), 0, 100)
		lines.append("%s fatigue +%d" % [a["name"], int(effects["agent_fatigue"])])
	if effects.has("agent_rest"):
		var tired := agents.filter(func(ag): return int(ag["fatigue"]) > 0)
		if not tired.is_empty():
			var a2: Dictionary = RandomService.pick(tired)
			a2["fatigue"] = maxi(0, int(a2["fatigue"]) - int(effects["agent_rest"]))
			lines.append("%s recovers (-%d fatigue)" % [a2["name"], int(effects["agent_rest"])])
	if effects.has("all_agent_rest"):
		for a3 in agents:
			a3["fatigue"] = maxi(0, int(a3["fatigue"]) - int(effects["all_agent_rest"]))
		lines.append("All agents recover %d fatigue" % int(effects["all_agent_rest"]))

	resources_changed.emit()
	return lines


func record_event(event_id: String, choice_index: int) -> void:
	event_history.append({"id": event_id, "turn": turn, "choice": choice_index})
	stats["events_faced"] = int(stats.get("events_faced", 0)) + 1


func collapse_region(region: Dictionary) -> void:
	region["collapsed"] = true
	region["stability"] = 0
	stats["regions_lost"] = int(stats.get("regions_lost", 0)) + 1
	region_updated.emit(region["id"])


## Checks every end condition. Emits game_ended once when the run ends.
func check_end_conditions() -> Dictionary:
	if game_over:
		return {"over": true}
	var won := false
	var reason := ""
	if rival_exposure >= Balance.WIN_RIVAL_EXPOSURE:
		won = true
		reason = "The rival network has been fully exposed. Its structure is public, its cover gone."
	elif global_exposure >= Balance.LOSS_GLOBAL_EXPOSURE:
		reason = "Global Exposure reached the point of no return. The crisis is now irreversible."
	elif trust <= Balance.LOSS_TRUST:
		reason = "Agency Trust collapsed. The Directorate has been dissolved by emergency decree."
	elif collapsed_count() >= Balance.COLLAPSE_LIMIT:
		reason = "Five regions have collapsed. The map you were protecting no longer exists."
	elif funds < 0 and funds_warning:
		reason = "The Directorate is insolvent. Operations ceased; the rival moves unopposed."
	else:
		if funds < 0:
			funds_warning = true
		else:
			funds_warning = false
		return {"over": false}
	game_over = true
	campaign_active = false
	last_end = {"won": won, "reason": reason}
	game_ended.emit(won, reason)
	return {"over": true, "won": won, "reason": reason}


# ---------- Serialization ----------
func to_dict() -> Dictionary:
	return {
		"version": 1,
		"difficulty": difficulty,
		"turn": turn,
		"seed": campaign_seed,
		"tutorial_done": tutorial_done,
		"intel": intel, "funds": funds, "trust": trust, "heat": heat, "cover": cover,
		"funds_warning": funds_warning,
		"global_exposure": global_exposure,
		"rival_momentum": rival_momentum,
		"rival_exposure": rival_exposure,
		"regions": regions.duplicate(true),
		"agents": agents.duplicate(true),
		"event_history": event_history.duplicate(true),
		"stats": stats.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	difficulty = int(d.get("difficulty", Balance.Difficulty.STANDARD))
	turn = int(d.get("turn", 1))
	campaign_seed = int(d.get("seed", 0))
	RandomService.reseed(campaign_seed + turn)
	tutorial_done = bool(d.get("tutorial_done", false))
	intel = int(d.get("intel", 0))
	funds = int(d.get("funds", 0))
	trust = int(d.get("trust", 0))
	heat = int(d.get("heat", 0))
	cover = int(d.get("cover", 0))
	funds_warning = bool(d.get("funds_warning", false))
	global_exposure = float(d.get("global_exposure", 0))
	rival_momentum = float(d.get("rival_momentum", 0))
	rival_exposure = float(d.get("rival_exposure", 0))
	regions = d.get("regions", [])
	agents = d.get("agents", [])
	event_history = d.get("event_history", [])
	stats = d.get("stats", {})
	game_over = false
	campaign_active = true
	resources_changed.emit()


# ---------- Helpers ----------
func _random_active_region() -> Dictionary:
	var live := active_regions()
	if live.is_empty():
		return {}
	return RandomService.pick(live)


func _is_harmful(key: String, val: float) -> bool:
	match key:
		"heat", "global_exposure", "rival_momentum":
			return val > 0
		"intel", "funds", "trust", "cover", "rival_exposure":
			return val < 0
	return false


func _describe_delta(key: String, val: int) -> String:
	var names := {
		"intel": "Intel", "funds": "Funds", "trust": "Trust", "heat": "Heat",
		"cover": "Cover", "global_exposure": "Global Exposure",
		"rival_momentum": "Rival Momentum", "rival_exposure": "Rival Exposure",
	}
	return "%s %s%d" % [names.get(key, key), "+" if val >= 0 else "", val]
