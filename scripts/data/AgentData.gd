extends Node
## AgentData.gd - static agent roster definitions and trait descriptions.
## Runtime agent state (fatigue, xp, level) lives in GameState.

var agents: Array = []
var traits: Dictionary = {}

var _by_id: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open("res://data/agents.json", FileAccess.READ)
	if f == null:
		push_error("AgentData: cannot open agents.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		agents = parsed.get("agents", [])
		traits = parsed.get("traits", {})
	for a in agents:
		_by_id[a["id"]] = a


func get_def(agent_id: String) -> Dictionary:
	return _by_id.get(agent_id, {})


func trait_name(trait_id: String) -> String:
	return L10n.t("agent_trait.%s.name" % trait_id)


func trait_desc(trait_id: String) -> String:
	return L10n.t("agent_trait.%s.description" % trait_id)
