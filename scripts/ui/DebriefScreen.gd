extends Control
## DebriefScreen.gd - post-operation report overlay with staggered lines
## and animated meter counters (old value -> new value).

signal dismissed

var _card: PanelContainer
var _content: VBoxContainer


func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.EDGE_BRIGHT))
	_card.custom_minimum_size = Vector2(960, 0)
	center.add_child(_card)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", UITheme.SPACE_S)
	_card.add_child(_content)


## kind: "success" | "fail" | "neutral"
## before: snapshot of meters taken before resolution (for counters).
func open(title_text: String, kind: String, lines: Array, before: Dictionary) -> void:
	for child in _content.get_children():
		child.queue_free()

	var accent: Color = {"success": UITheme.SAFE, "fail": UITheme.DANGER, "neutral": UITheme.ACCENT}.get(kind, UITheme.ACCENT)
	_content.add_child(UITheme.label("OPERATION DEBRIEF", 22, UITheme.TEXT_DIM))
	_content.add_child(UITheme.label(title_text.to_upper(), UITheme.FS_LARGE, accent))
	_content.add_child(UITheme.hseparator())

	var line_labels: Array[Label] = []
	for line in lines:
		var l := UITheme.label("· " + String(line), UITheme.FS_SMALL, UITheme.TEXT)
		_content.add_child(l)
		line_labels.append(l)

	_content.add_child(UITheme.hseparator())
	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", UITheme.SPACE_S)
	_content.add_child(meters)
	_add_counter(meters, "EXPOSURE", float(before.get("global_exposure", 0)), GameState.global_exposure, UITheme.DANGER)
	_add_counter(meters, "RIVAL EXPOSED", float(before.get("rival_exposure", 0)), GameState.rival_exposure, UITheme.ACCENT)
	_add_counter(meters, "HEAT", float(before.get("heat", 0)), float(GameState.heat), UITheme.WARN)
	_add_counter(meters, "FUNDS", float(before.get("funds", 0)), float(GameState.funds), UITheme.TEXT)

	var cont := UITheme.button("CONTINUE", "primary")
	cont.pressed.connect(func() -> void:
		visible = false
		TutorialManager.notify("operation_resolved")
		dismissed.emit())
	_content.add_child(cont)

	visible = true
	if not SettingsManager.reduce_motion:
		for i in line_labels.size():
			var lbl := line_labels[i]
			lbl.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(0.12 * i)
			tween.tween_property(lbl, "modulate:a", 1.0, UITheme.ANIM_MED)


func _add_counter(parent: Container, caption: String, from_val: float, to_val: float, color: Color) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var cap := UITheme.label(caption, 20, UITheme.TEXT_DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var val := UITheme.label(str(int(from_val)), UITheme.FS_BODY, color)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(val)
	if SettingsManager.reduce_motion or is_equal_approx(from_val, to_val):
		val.text = str(int(to_val))
	else:
		var tween := create_tween()
		tween.tween_method(func(v: float) -> void: val.text = str(int(v)),
			from_val, to_val, 0.7)
