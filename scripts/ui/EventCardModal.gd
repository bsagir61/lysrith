extends Control
## EventCardModal.gd - dossier-style event card. The player must choose;
## there is no dismissing an event without consequences.

signal choice_made(choice_index: int)

var _card: PanelContainer
var _content: VBoxContainer
var _event: Dictionary = {}


func _ready() -> void:
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.EDGE_BRIGHT))
	_card.custom_minimum_size = Vector2(940, 0)
	center.add_child(_card)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", UITheme.SPACE_S)
	_card.add_child(_content)


func open(event: Dictionary) -> void:
	_event = event
	_rebuild()
	visible = true
	AudioManager.play_event()
	SettingsManager.vibrate(40)
	if not SettingsManager.reduce_motion:
		_card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_card, "modulate:a", 1.0, UITheme.ANIM_MED)


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()

	var tone := String(_event.get("tone", "world"))
	var tone_color: Color = {
		"pressure": UITheme.WARN, "internal": UITheme.ACCENT_DIM,
		"rival": UITheme.DANGER, "world": UITheme.TEXT_DIM,
		"opportunity": UITheme.SAFE,
	}.get(tone, UITheme.TEXT_DIM)

	# Dossier strip.
	var strip := UITheme.label("INCOMING REPORT  ·  " + tone.to_upper(), 22, tone_color)
	_content.add_child(strip)
	_content.add_child(UITheme.hseparator())
	_content.add_child(UITheme.label(String(_event["title"]).to_upper(), UITheme.FS_LARGE, UITheme.TEXT))
	_content.add_child(UITheme.label(String(_event["desc"]), UITheme.FS_SMALL, UITheme.TEXT_DIM))
	_content.add_child(UITheme.spacer(UITheme.SPACE_XS))

	var choices: Array = _event.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := UITheme.button(String(choice["text"]), "ghost")
		btn.pressed.connect(_on_choice.bind(i))
		_content.add_child(btn)
		var note := UITheme.label(String(choice.get("note", "")), 22, UITheme.TEXT_DIM)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(note)


func _on_choice(index: int) -> void:
	visible = false
	choice_made.emit(index)
