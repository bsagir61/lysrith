extends Control
## DebriefScreen.gd - structured result overlay. It renders resolver records and
## before/after state; it contains no operation or identity formulas.

signal dismissed

const METRIC_ORDER: Array[String] = [
	"funds", "intel", "trust", "heat", "cover", "rival_exposure",
	"global_exposure", "region_stability", "region_rival", "region_pressure",
	"local_network", "intel_level", "rival_momentum", "world_stability",
	"collapsed_regions",
]

var _card: PanelContainer
var _content: VBoxContainer
var _animated_labels: Array[Label] = []


func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, UITheme.OVERLAY_OPACITY)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var margin := UITheme.safe_area_margin()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.EDGE_BRIGHT))
	_card.custom_minimum_size = Vector2(UITheme.MODAL_WIDTH, UITheme.MODAL_HEIGHT)
	center.add_child(_card)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UITheme.SPACE_S)
	_card.add_child(_content)


## kind: "success" | "near_miss" | "fail" | "neutral".
## context may contain structured result and advance dictionaries.
func open(title_text: String, kind: String, lines: Array, before: Dictionary, context: Dictionary = {}) -> void:
	_clear(_content)
	_animated_labels.clear()
	var accent: Color = {
		"success": UITheme.SAFE,
		"near_miss": UITheme.WARN,
		"fail": UITheme.DANGER,
		"neutral": UITheme.ACCENT,
	}.get(kind, UITheme.ACCENT)
	_content.add_child(UITheme.label(L10n.t("debrief.title"), UITheme.FS_TINY, UITheme.TEXT_DIM))
	_content.add_child(UITheme.label(title_text, UITheme.FS_BODY, accent))
	_content.add_child(UITheme.hseparator())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UITheme.SPACE_S)
	scroll.add_child(body)

	var result: Dictionary = context.get("result", {})
	var advance: Dictionary = context.get("advance", {})
	if not result.is_empty():
		_build_operation_report(body, result, advance)
	elif not advance.is_empty():
		_build_turn_report(body, advance)
	else:
		_add_line_section(body, L10n.t("debrief.section.effects"), lines, UITheme.TEXT)

	var cont := UITheme.button(L10n.t("common.continue"), "primary")
	cont.pressed.connect(func() -> void:
		visible = false
		TutorialManager.notify("operation_resolved")
		dismissed.emit())
	_content.add_child(cont)

	visible = true
	_animate_lines()


func _build_operation_report(parent: VBoxContainer, result: Dictionary, advance: Dictionary) -> void:
	var context_box := VBoxContainer.new()
	context_box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	context_box.add_child(UITheme.label(L10n.t("debrief.operation_context", [
		L10n.t("operation.%s.name" % String(result.get("op_id", ""))),
		result.get("region_name", ""),
		result.get("agent_name", ""),
	]), UITheme.FS_SMALL, UITheme.TEXT))
	context_box.add_child(UITheme.label(L10n.t("debrief.chance_roll", [
		int(result.get("chance", 0)), int(result.get("roll", 0)),
	]), UITheme.FS_TINY, UITheme.TEXT_DIM))
	parent.add_child(context_box)
	parent.add_child(UITheme.hseparator())

	_add_line_section(parent, L10n.t("debrief.section.effects"), result.get("lines", []), UITheme.TEXT)
	var modifier_lines: Array[String] = _modifier_lines(result, advance)
	if not modifier_lines.is_empty():
		_add_line_section(parent, L10n.t("debrief.section.modifiers"), modifier_lines, UITheme.ACCENT)
	if bool(result.get("identity_revealed", false)):
		var identity_key: String = String(result.get("identity_description_key", ""))
		if identity_key != "":
			_add_line_section(parent, L10n.t("debrief.section.identity"), [L10n.t(identity_key)], UITheme.SAFE)
	_build_turn_report(parent, advance)


func _build_turn_report(parent: VBoxContainer, advance: Dictionary) -> void:
	if advance.is_empty():
		return
	_add_line_section(parent, L10n.t("debrief.section.economy"), advance.get("economy_lines", []), UITheme.TEXT)
	_add_line_section(parent, L10n.t("debrief.section.world"), advance.get("world_lines", []), UITheme.TEXT_DIM)


func _modifier_lines(result: Dictionary, advance: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var seen: Dictionary = {}
	var modifiers: Array = result.get("applied_modifiers", []).duplicate(true)
	modifiers.append_array(advance.get("applied_modifiers", []))
	for modifier_variant in modifiers:
		var modifier: Dictionary = modifier_variant
		var text: String = _localized_modifier(modifier)
		if text != "" and not seen.has(text):
			seen[text] = true
			lines.append(text)
	for actual_line in _actual_identity_lines(result):
		if not seen.has(actual_line):
			seen[actual_line] = true
			lines.append(actual_line)
	return lines


func _actual_identity_lines(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var preview: Dictionary = result.get("preview", {})
	var chance_breakdown: Dictionary = preview.get("chance_breakdown", {})
	var chance_delta: float = _identity_component(chance_breakdown.get("components", []))
	if not is_zero_approx(chance_delta):
		lines.append(L10n.t("debrief.identity_delta.chance", [_signed_value(chance_delta, "%")]))
	var costs: Dictionary = result.get("cost_breakdown", {})
	for resource_id in ["funds", "intel", "trust"]:
		var resource_components: Array = costs.get(resource_id, [])
		var cost_delta: float = _identity_component(resource_components)
		if not is_zero_approx(cost_delta):
			lines.append(L10n.t("debrief.identity_delta.cost", [L10n.t("game.%s" % resource_id), _signed_value(cost_delta)]))
	var heat_breakdown: Dictionary = result.get("heat_breakdown", {})
	var heat_delta: float = _identity_component(heat_breakdown.get("components", []))
	if not is_zero_approx(heat_delta):
		lines.append(L10n.t("debrief.identity_delta.heat", [_signed_value(heat_delta)]))
	for effect_variant in result.get("effect_breakdown", []):
		var effect: Dictionary = effect_variant
		var effect_delta: int = int(effect.get("identity_delta", 0))
		if effect_delta != 0:
			lines.append(L10n.t("debrief.identity_delta.effect", [
				L10n.t("debrief.metric.%s" % String(effect.get("effect_id", ""))),
				_signed_value(effect_delta),
			]))
	return lines


func _identity_component(components: Array) -> float:
	for component_variant in components:
		var component: Dictionary = component_variant
		if String(component.get("source", "")) == "identity":
			return float(component.get("value", 0.0))
	return 0.0


func _add_line_section(parent: VBoxContainer, title_text: String, lines: Array, color: Color) -> void:
	if lines.is_empty():
		return
	parent.add_child(UITheme.section_header(title_text, UITheme.ACCENT))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	for line_variant in lines:
		var line_label := UITheme.label(String(line_variant), UITheme.FS_TINY, color)
		box.add_child(line_label)
		_animated_labels.append(line_label)
	parent.add_child(box)
	parent.add_child(UITheme.hseparator())


func _add_changes(parent: VBoxContainer, before: Dictionary, region_id: String) -> void:
	var changes: Array[Dictionary] = []
	for key in METRIC_ORDER:
		if not before.has(key):
			continue
		var from_value: float = float(before[key])
		var to_value: float = _current_value(key, region_id)
		if not is_equal_approx(from_value, to_value):
			changes.append({"key": key, "before": from_value, "after": to_value, "delta": to_value - from_value})
	if changes.is_empty():
		return
	parent.add_child(UITheme.section_header(L10n.t("debrief.section.changes"), UITheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.SPACE_S)
	grid.add_theme_constant_override("v_separation", UITheme.SPACE_S)
	parent.add_child(grid)
	for change in changes:
		grid.add_child(_change_card(change))


func _change_card(change: Dictionary) -> Control:
	var key: String = String(change["key"])
	var delta: float = float(change["delta"])
	var color: Color = _change_color(key, delta)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XXS)
	var caption := UITheme.label(L10n.t("debrief.metric.%s" % key), UITheme.FS_MICRO, UITheme.TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var value := UITheme.label("%s -> %s (%s)" % [
		_metric_value(float(change["before"])),
		_metric_value(float(change["after"])),
		_signed_metric(delta),
	], UITheme.FS_TINY, color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	return box


func _current_value(key: String, region_id: String) -> float:
	var region: Dictionary = GameState.get_region(region_id)
	match key:
		"funds": return GameState.funds
		"intel": return GameState.intel
		"trust": return GameState.trust
		"heat": return GameState.heat
		"cover": return GameState.cover
		"rival_exposure": return GameState.rival_exposure
		"global_exposure": return GameState.global_exposure
		"rival_momentum": return GameState.rival_momentum
		"world_stability": return GameState.world_stability()
		"collapsed_regions": return GameState.collapsed_count()
		"region_stability": return float(region.get("stability", 0))
		"region_rival": return float(region.get("rival_influence", 0))
		"region_pressure": return float(region.get("public_pressure", 0))
		"local_network": return float(region.get("local_network", 0))
		"intel_level": return float(region.get("intel_level", 0))
	return 0.0


func _change_color(key: String, delta: float) -> Color:
	var increase_is_bad: bool = key in [
		"heat", "global_exposure", "rival_momentum", "region_rival",
		"region_pressure", "collapsed_regions",
	]
	var favorable: bool = delta < 0.0 if increase_is_bad else delta > 0.0
	return UITheme.SAFE if favorable else UITheme.DANGER


func _localized_modifier(modifier: Dictionary) -> String:
	var key: String = String(modifier.get("text_key", ""))
	if key == "":
		return ""
	var args: Array = modifier.get("args", [])
	return L10n.t(key, args)


func _signed_value(value: float, suffix: String = "") -> String:
	var rounded_value: int = int(round(value))
	var prefix: String = "+" if rounded_value > 0 else ""
	return "%s%d%s" % [prefix, rounded_value, suffix]


func _metric_value(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value, round(value)) else "%.1f" % value


func _signed_metric(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return _signed_value(value)
	return "%s%.1f" % ["+" if value > 0.0 else "", value]


func _animate_lines() -> void:
	if SettingsManager.reduce_motion:
		return
	for i in _animated_labels.size():
		var line_label: Label = _animated_labels[i]
		line_label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(UITheme.ANIM_FAST * 0.5 * i)
		tween.tween_property(line_label, "modulate:a", 1.0, UITheme.ANIM_MED)


func _clear(parent: Node) -> void:
	for child_variant in parent.get_children():
		var child: Node = child_variant
		parent.remove_child(child)
		child.queue_free()
