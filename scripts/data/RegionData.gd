extends Node
## RegionData.gd - loads static region definitions (names, map layout, links, tag pool).
## Runtime region state lives in GameState; this file is read-only content.

var regions: Array = []          # [{id, name, pos:[x,y]}]
var links: Array = []            # [[id_a, id_b], ...]
var hidden_tags: Array = []      # tag name pool

var _by_id: Dictionary = {}


func _ready() -> void:
	var parsed: Dictionary = _load_json("res://data/regions.json")
	regions = parsed.get("regions", [])
	links = parsed.get("links", [])
	hidden_tags = parsed.get("hidden_tags", [])
	for r in regions:
		_by_id[r["id"]] = r


func get_def(region_id: String) -> Dictionary:
	return _by_id.get(region_id, {})


func neighbors_of(region_id: String) -> Array[String]:
	var out: Array[String] = []
	for link in links:
		if link[0] == region_id:
			out.append(String(link[1]))
		elif link[1] == region_id:
			out.append(String(link[0]))
	return out


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("RegionData: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
