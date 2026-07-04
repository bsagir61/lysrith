class_name AgentPortrait
extends Control
## AgentPortrait.gd - procedural abstract agent portrait.
## Simple silhouette + gradient + frame, deterministic per agent id.
## No external art assets.

var agent_id: String = ""

var _hue: float = 0.5


func _init(id: String = "") -> void:
	agent_id = id
	_hue = float(abs(id.hash()) % 360) / 360.0
	custom_minimum_size = Vector2(132, 132)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var tint := Color.from_hsv(_hue, 0.25, 0.55)
	# Frame.
	var frame_rect := Rect2(0, 0, w, h)
	draw_rect(frame_rect, Color(UITheme.CARD.r, UITheme.CARD.g, UITheme.CARD.b, 1.0))
	# Vertical gradient wash.
	var steps := 12
	for i in steps:
		var t := float(i) / steps
		var c := Color(tint.r, tint.g, tint.b, 0.05 + 0.14 * (1.0 - t))
		draw_rect(Rect2(2, 2 + t * (h - 4), w - 4, (h - 4) / steps + 1), c)
	# Silhouette: head and shoulders.
	var cx := w * 0.5
	var sil := Color(0.05, 0.08, 0.12, 0.95)
	draw_circle(Vector2(cx, h * 0.38), w * 0.185, sil)
	var pts := PackedVector2Array([
		Vector2(cx - w * 0.34, h * 0.95),
		Vector2(cx - w * 0.26, h * 0.66),
		Vector2(cx, h * 0.58),
		Vector2(cx + w * 0.26, h * 0.66),
		Vector2(cx + w * 0.34, h * 0.95),
	])
	draw_colored_polygon(pts, sil)
	# Identity accent: a thin scan line unique-ish per agent.
	var line_y := h * (0.25 + 0.5 * fmod(_hue * 7.31, 1.0))
	draw_line(Vector2(4, line_y), Vector2(w - 4, line_y),
		Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.35), 1.0)
	# Border.
	draw_rect(frame_rect, Color(UITheme.EDGE_BRIGHT.r, UITheme.EDGE_BRIGHT.g, UITheme.EDGE_BRIGHT.b, 0.9), false, 1.5)
