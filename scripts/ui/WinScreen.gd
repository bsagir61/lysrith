extends Control
## WinScreen.gd - victory presentation and run summary.


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_XL * 2)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_L)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_M)
	margin.add_child(vbox)

	vbox.add_child(UITheme.title("NETWORK EXPOSED", UITheme.FS_HUGE, UITheme.SAFE))
	var reason := UITheme.label(String(GameState.last_end.get("reason", "Victory.")), UITheme.FS_BODY, UITheme.TEXT)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reason)
	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))
	vbox.add_child(_summary_card())
	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))

	var again := UITheme.button("NEW CAMPAIGN", "primary")
	again.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/NewGameSetup.tscn"))
	vbox.add_child(again)
	var menu := UITheme.button("MAIN MENU", "ghost", true)
	menu.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	vbox.add_child(menu)


func _summary_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(box)
	var s: Dictionary = GameState.stats
	var rows := [
		"Turns survived: %d" % GameState.turn,
		"Operations run: %d (%d successful)" % [int(s.get("ops_run", 0)), int(s.get("ops_won", 0))],
		"Events faced: %d" % int(s.get("events_faced", 0)),
		"Regions lost: %d" % int(s.get("regions_lost", 0)),
		"Posture: %s" % Balance.difficulty_name(GameState.difficulty),
	]
	for r in rows:
		box.add_child(UITheme.label(r, UITheme.FS_SMALL, UITheme.TEXT_DIM))
	return panel
