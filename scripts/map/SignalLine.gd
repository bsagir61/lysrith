class_name SignalLine
extends Node2D
## SignalLine.gd - curved connection between two region nodes.
## Shows rival spread as thin red arcs with a traveling pulse.

var point_a: Vector2
var point_b: Vector2
var rival_active: bool = false

var _pulse_t: float = 0.0
var _points: PackedVector2Array = PackedVector2Array()


func setup(a: Vector2, b: Vector2) -> void:
	point_a = a
	point_b = b
	_build_curve()


func set_rival_active(v: bool) -> void:
	if rival_active != v:
		rival_active = v
		queue_redraw()


func _build_curve() -> void:
	# Quadratic bezier bowed perpendicular to the segment.
	var mid := (point_a + point_b) * 0.5
	var dir := (point_b - point_a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var ctrl := mid + perp * point_a.distance_to(point_b) * 0.12
	_points.clear()
	var steps := 20
	for i in steps + 1:
		var t := float(i) / steps
		var p := point_a.lerp(ctrl, t).lerp(ctrl.lerp(point_b, t), t)
		_points.append(p)
	queue_redraw()


func _process(delta: float) -> void:
	if rival_active and not SettingsManager.reduce_motion:
		_pulse_t = fmod(_pulse_t + delta * 0.5, 1.0)
		queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	var base := Color(UITheme.ACCENT_DIM.r, UITheme.ACCENT_DIM.g, UITheme.ACCENT_DIM.b, 0.30)
	if rival_active:
		base = Color(UITheme.DANGER.r, UITheme.DANGER.g, UITheme.DANGER.b, 0.40)
	draw_polyline(_points, base, 1.5, true)
	if rival_active and not SettingsManager.reduce_motion:
		# Traveling pulse dot along the arc.
		var idx := int(_pulse_t * (_points.size() - 1))
		draw_circle(_points[idx], 4.0, Color(UITheme.DANGER.r, UITheme.DANGER.g, UITheme.DANGER.b, 0.85))
