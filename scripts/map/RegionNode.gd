class_name RegionNode
extends Node2D
## RegionNode.gd - visual for one map region. Pure presentation:
## reads a region dictionary snapshot via update_state() and draws it.

const RADIUS := 58.0
const TAP_RADIUS := 92.0

var region_id: String = ""
var region_name: String = ""
var selected: bool = false

var _stability: float = 100.0
var _rival: float = 0.0
var _intel_level: int = 0
var _collapsed: bool = false
var _tag_revealed: bool = false
var _network: float = 0.0
var _opportunity: float = 0.0
var _pulse_t: float = 0.0
var _ripple_t: float = -1.0


func setup(id: String, display_name: String, pos: Vector2) -> void:
	region_id = id
	region_name = display_name
	position = pos


func update_state(r: Dictionary) -> void:
	_stability = float(r.get("stability", 0))
	_rival = float(r.get("rival_influence", 0))
	_intel_level = int(r.get("intel_level", 0))
	_collapsed = bool(r.get("collapsed", false))
	_tag_revealed = bool(r.get("tag_revealed", false))
	_network = float(r.get("local_network", 0))
	_opportunity = float(r.get("opportunity", 0))
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


## Cyan scan ripple when the player acts here.
func play_ripple() -> void:
	if SettingsManager.reduce_motion:
		return
	_ripple_t = 0.0


func _process(delta: float) -> void:
	if SettingsManager.reduce_motion:
		return
	_pulse_t += delta
	if _ripple_t >= 0.0:
		_ripple_t += delta
		if _ripple_t > 1.0:
			_ripple_t = -1.0
	if _needs_pulse() or _ripple_t >= 0.0 or selected:
		queue_redraw()


func _needs_pulse() -> bool:
	var known_rival_crisis: bool = _intel_level >= 1 and _rival >= 65.0
	return not _collapsed and (known_rival_crisis or _stability < 40.0)


func _draw() -> void:
	var state_color := _state_color()
	var pulse := 1.0
	if _needs_pulse() and not SettingsManager.reduce_motion:
		pulse = 0.75 + 0.25 * sin(_pulse_t * 4.0)

	# Soft outer glow.
	if _intel_level >= 2 and _opportunity >= Balance.ASSESS_PROMISING_OPPORTUNITY_AT and not _collapsed:
		draw_circle(Vector2.ZERO, RADIUS + 24.0, Color(UITheme.SAFE.r, UITheme.SAFE.g, UITheme.SAFE.b, 0.05))
	draw_circle(Vector2.ZERO, RADIUS + 16.0, Color(state_color.r, state_color.g, state_color.b, 0.06 * pulse))
	draw_circle(Vector2.ZERO, RADIUS + 6.0, Color(state_color.r, state_color.g, state_color.b, 0.10 * pulse))
	# Body.
	draw_circle(Vector2.ZERO, RADIUS, Color(UITheme.CARD.r, UITheme.CARD.g, UITheme.CARD.b, 0.92))
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 48, Color(state_color.r, state_color.g, state_color.b, 0.85 * pulse), 2.0, true)

	if _collapsed:
		_draw_cracks()
	else:
		# Stability ring: arc length maps to stability.
		var sweep := TAU * (_stability / 100.0)
		if sweep > 0.05:
			draw_arc(Vector2.ZERO, RADIUS - 9.0, -PI / 2.0, -PI / 2.0 + sweep, 40,
				Color(state_color.r, state_color.g, state_color.b, 0.55), 3.0, true)
		# Rival presence: inner red core grows with influence.
		if _intel_level >= 1 and _rival > 8.0:
			var core := 6.0 + (_rival / 100.0) * 22.0
			draw_circle(Vector2.ZERO, core, Color(UITheme.DANGER.r, UITheme.DANGER.g, UITheme.DANGER.b, 0.30 + 0.25 * (_rival / 100.0)))
		# Local network: small cyan dots orbiting.
		var net_dots := int(_network / 25.0)
		for i in net_dots:
			var ang := TAU * float(i) / 4.0 + PI / 4.0
			draw_circle(Vector2(cos(ang), sin(ang)) * (RADIUS - 18.0), 4.0,
				Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.8))

	# Intel pips under the node.
	for i in 3:
		var px := -18.0 + i * 18.0
		var filled := i < _intel_level
		var c := UITheme.ACCENT if filled else UITheme.EDGE_BRIGHT
		draw_circle(Vector2(px, RADIUS + 16.0), 4.5, Color(c.r, c.g, c.b, 0.9 if filled else 0.5))

	# Selection ring.
	if selected:
		var sel_pulse := 1.0 if SettingsManager.reduce_motion else 0.7 + 0.3 * sin(_pulse_t * 6.0)
		draw_arc(Vector2.ZERO, RADIUS + 12.0, 0, TAU, 48,
			Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.9 * sel_pulse), 3.0, true)
	elif _needs_pulse():
		_draw_warning_marker(state_color)

	# A single neutral marker confirms that an identity is known without
	# adding tag-specific clutter or revealing an unrevealed identity.
	if _tag_revealed and not _collapsed:
		_draw_identity_marker()

	# Scan ripple.
	if _ripple_t >= 0.0:
		var rr := RADIUS + _ripple_t * 90.0
		draw_arc(Vector2.ZERO, rr, 0, TAU, 48,
			Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.6 * (1.0 - _ripple_t)), 2.0, true)

	# Name label.
	var font := ThemeDB.fallback_font
	var fsize := UITheme.fs(UITheme.FS_TINY)
	var display := region_name
	var text_color := UITheme.TEXT if not _collapsed else UITheme.COLLAPSED
	draw_string(font, Vector2(-95, RADIUS + 42.0), display,
		HORIZONTAL_ALIGNMENT_CENTER, 190, fsize, text_color)
	if _collapsed:
		draw_string(font, Vector2(-95, RADIUS + 66.0), "[" + L10n.t("map.lost_short") + "]",
			HORIZONTAL_ALIGNMENT_CENTER, 190, UITheme.fs(UITheme.FS_MICRO), UITheme.COLLAPSED)


func _state_color() -> Color:
	if _collapsed:
		return UITheme.COLLAPSED
	if (_intel_level >= 1 and _rival >= 65.0) or _stability < 25.0:
		return UITheme.DANGER
	if (_intel_level >= 1 and _rival >= 40.0) or _stability < 45.0:
		return UITheme.WARN
	if _intel_level == 0:
		return UITheme.EDGE_BRIGHT
	return UITheme.ACCENT


func _draw_cracks() -> void:
	# Desaturated cracked look for collapsed regions.
	var c := Color(UITheme.COLLAPSED.r, UITheme.COLLAPSED.g, UITheme.COLLAPSED.b, 0.8)
	var seeds: Array[float] = [0.3, 1.4, 2.6, 3.9, 5.1]
	for s in seeds:
		var a := Vector2(cos(s), sin(s)) * 8.0
		var b := Vector2(cos(s + 0.4), sin(s + 0.4)) * (RADIUS - 8.0)
		var mid := (a + b) * 0.5 + Vector2(cos(s * 3.0), sin(s * 2.0)) * 8.0
		draw_line(a, mid, c, 1.5, true)
		draw_line(mid, b, c, 1.5, true)


func _draw_warning_marker(color: Color) -> void:
	var font := ThemeDB.fallback_font
	var center := Vector2(RADIUS - 7.0, -RADIUS + 7.0)
	draw_circle(center, 11.0, Color(color.r, color.g, color.b, 0.82))
	draw_string(font, center + Vector2(-4.0, 7.0), "!",
		HORIZONTAL_ALIGNMENT_CENTER, 8, UITheme.fs(16), UITheme.BG_DEEP)


func _draw_identity_marker() -> void:
	var center := Vector2(-RADIUS + 9.0, -RADIUS + 9.0)
	var size: float = UITheme.MAP_IDENTITY_MARKER_SIZE
	var points := PackedVector2Array([
		center + Vector2(0, -size),
		center + Vector2(size, 0),
		center + Vector2(0, size),
		center + Vector2(-size, 0),
	])
	draw_colored_polygon(points, Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.68))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), UITheme.ACCENT, 1.5, true)
