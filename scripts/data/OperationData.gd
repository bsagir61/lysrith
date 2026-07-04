extends Node
## OperationData.gd - static operation definitions loaded from operations.json.

var operations: Array = []

var _by_id: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open("res://data/operations.json", FileAccess.READ)
	if f == null:
		push_error("OperationData: cannot open operations.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		operations = parsed.get("operations", [])
	for op in operations:
		_by_id[op["id"]] = op


func get_def(op_id: String) -> Dictionary:
	return _by_id.get(op_id, {})
