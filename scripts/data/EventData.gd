extends Node
## EventData.gd - loads event cards and evaluates trigger conditions
## against the current GameState. Picking respects a cooldown window
## so cards do not repeat back to back.

var events: Array = []

var _by_id: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open("res://data/events.json", FileAccess.READ)
	if f == null:
		push_error("EventData: cannot open events.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		events = parsed.get("events", [])
	for e in events:
		_by_id[e["id"]] = e


func get_def(event_id: String) -> Dictionary:
	return _by_id.get(event_id, {})


## Returns an eligible event dictionary, or {} when none should fire.
## state is the GameState autoload (untyped so custom members resolve).
func pick_event(state, extra_chance: float = 0.0) -> Dictionary:
	var chance: float = minf(
		Balance.EVENT_BASE_CHANCE + state.heat * Balance.EVENT_HEAT_FACTOR + extra_chance,
		Balance.EVENT_CHANCE_MAX
	)
	if RandomService.rand_float() > chance:
		return {}
	var recent: Array = state.recent_event_ids(Balance.EVENT_COOLDOWN_TURNS)
	var pool: Array = []
	for e in events:
		if e["id"] in recent:
			continue
		if _trigger_ok(e.get("trigger", {"type": "always"}), state):
			pool.append(e)
	if pool.is_empty():
		return {}
	return RandomService.pick(pool)


func _trigger_ok(trigger: Dictionary, state) -> bool:
	var t: String = trigger.get("type", "always")
	var v: float = float(trigger.get("value", 0))
	match t:
		"always":
			return true
		"heat_min":
			return state.heat >= v
		"heat_max":
			return state.heat <= v
		"turn_min":
			return state.turn >= v
		"trust_max":
			return state.trust <= v
		"exposure_min":
			return state.global_exposure >= v
		"intel_min":
			return state.intel >= v
		"funds_max":
			return state.funds <= v
		"momentum_min":
			return state.rival_momentum >= v
		"collapsed_min":
			return state.collapsed_count() >= int(v)
		"rival_exposure_min":
			return state.rival_exposure >= v
		"rival_exposure_max":
			return state.rival_exposure <= v
		"stability_low":
			for r in state.regions:
				if not r["collapsed"] and r["stability"] <= v:
					return true
			return false
	return false
