class_name MapController
extends Node2D
## MapController.gd - builds and updates the abstract world map.
## Handles only visuals and tap selection. No game rules live here.

signal region_tapped(region_id: String)

const DESIGN_RECT := Rect2(0.0, 320.0, 1080.0, 1130.0)
const FIT_PADDING := 14.0
const DUPLICATE_INPUT_WINDOW_MSEC := 120
const DUPLICATE_INPUT_DISTANCE := 16.0

var _region_nodes: Dictionary = {}   # id -> RegionNode
var _lines: Array[SignalLine] = []
var _line_pairs: Array = []          # parallel array of [id_a, id_b]
var _selected_id: String = ""
var _last_activation_msec: int = -DUPLICATE_INPUT_WINDOW_MSEC
var _last_activation_position: Vector2 = Vector2(-10000.0, -10000.0)
var input_locked: bool = false


func _ready() -> void:
	_build_lines()
	_build_regions()
	refresh_all()
	GameState.region_updated.connect(_on_region_updated)


func _build_regions() -> void:
	for def in RegionData.regions:
		var node := RegionNode.new()
		node.setup(def["id"], L10n.region_name(def["id"]), Vector2(def["pos"][0], def["pos"][1]))
		add_child(node)
		_region_nodes[def["id"]] = node


func _build_lines() -> void:
	for link in RegionData.links:
		var a: Dictionary = RegionData.get_def(link[0])
		var b: Dictionary = RegionData.get_def(link[1])
		if a.is_empty() or b.is_empty():
			continue
		var line := SignalLine.new()
		line.setup(Vector2(a["pos"][0], a["pos"][1]), Vector2(b["pos"][0], b["pos"][1]))
		add_child(line)
		_lines.append(line)
		_line_pairs.append([link[0], link[1]])


func refresh_all() -> void:
	for id in _region_nodes:
		var r: Dictionary = GameState.get_region(id)
		if not r.is_empty():
			_region_nodes[id].update_state(r)
	_refresh_lines()


func _refresh_lines() -> void:
	for i in _lines.size():
		var pair: Array = _line_pairs[i]
		var ra: Dictionary = GameState.get_region(pair[0])
		var rb: Dictionary = GameState.get_region(pair[1])
		var active := false
		if not ra.is_empty() and not rb.is_empty():
			var a_known: bool = int(ra.get("intel_level", 0)) >= 1
			var b_known: bool = int(rb.get("intel_level", 0)) >= 1
			active = (a_known and int(ra.get("rival_influence", 0)) >= 50) \
				or (b_known and int(rb.get("rival_influence", 0)) >= 50)
		_lines[i].set_rival_active(active)


func _on_region_updated(region_id: String) -> void:
	var node: RegionNode = _region_nodes.get(region_id)
	if node != null:
		var r: Dictionary = GameState.get_region(region_id)
		if not r.is_empty():
			node.update_state(r)
	_refresh_lines()


func select_region(region_id: String) -> void:
	if _selected_id != "" and _region_nodes.has(_selected_id):
		_region_nodes[_selected_id].set_selected(false)
	_selected_id = region_id
	if _region_nodes.has(region_id):
		_region_nodes[region_id].set_selected(true)


func clear_selection() -> void:
	select_region("")


func play_scan(region_id: String) -> void:
	var node: RegionNode = _region_nodes.get(region_id)
	if node != null:
		node.play_ripple()


func fit_to_rect(target_size: Vector2) -> void:
	if target_size.x <= 1.0 or target_size.y <= 1.0:
		return
	var usable_width: float = maxf(target_size.x - FIT_PADDING * 2.0, 1.0)
	var usable_height: float = maxf(target_size.y - FIT_PADDING * 2.0, 1.0)
	var fit_scale: float = minf(usable_width / DESIGN_RECT.size.x, usable_height / DESIGN_RECT.size.y)
	scale = Vector2.ONE * fit_scale
	position = (target_size - DESIGN_RECT.size * fit_scale) * 0.5 - DESIGN_RECT.position * fit_scale
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	var pointer_position: Vector2
	if event is InputEventScreenTouch and event.pressed:
		pointer_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer_position = event.position
	else:
		return
	if _is_duplicate_activation(pointer_position):
		return
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * pointer_position
	var best_id := ""
	var best_dist := RegionNode.TAP_RADIUS
	for id in _region_nodes:
		var d: float = _region_nodes[id].position.distance_to(local_position)
		if d < best_dist:
			best_dist = d
			best_id = id
	if best_id == "":
		return
	_last_activation_msec = Time.get_ticks_msec()
	_last_activation_position = pointer_position
	get_viewport().set_input_as_handled()
	region_tapped.emit(best_id)


func _is_duplicate_activation(pointer_position: Vector2) -> bool:
	var elapsed: int = Time.get_ticks_msec() - _last_activation_msec
	return elapsed <= DUPLICATE_INPUT_WINDOW_MSEC \
		and pointer_position.distance_to(_last_activation_position) <= DUPLICATE_INPUT_DISTANCE


func _draw() -> void:
	# Subtle cartographic grid behind the region nodes.
	var grid := Color(UITheme.EDGE.r, UITheme.EDGE.g, UITheme.EDGE.b, 0.22)
	var top := 360.0
	var bottom := 1420.0
	for i in range(0, 12):
		var x := 40.0 + i * 92.0
		draw_line(Vector2(x, top), Vector2(x, bottom), grid, 1.0)
	for j in range(0, 12):
		var y := top + j * 92.0
		draw_line(Vector2(40, y), Vector2(1040, y), grid, 1.0)
	# Faint frame corners for the intelligence-room feel.
	var frame := Color(UITheme.ACCENT_DIM.r, UITheme.ACCENT_DIM.g, UITheme.ACCENT_DIM.b, 0.5)
	var corners: Array[Vector2] = [Vector2(40, top), Vector2(1040, top), Vector2(40, bottom), Vector2(1040, bottom)]
	for c in corners:
		var dx := 24.0 if c.x < 500 else -24.0
		var dy := 24.0 if c.y < 800 else -24.0
		draw_line(c, c + Vector2(dx, 0), frame, 2.0)
		draw_line(c, c + Vector2(0, dy), frame, 2.0)
