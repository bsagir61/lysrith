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

	vbox.add_child(UITheme.title(L10n.t("win.title"), UITheme.FS_HUGE, UITheme.SAFE))
	var reason := UITheme.label(String(GameState.last_end.get("reason", L10n.t("win.fallback"))), UITheme.FS_BODY, UITheme.TEXT)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reason)
	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))
	vbox.add_child(_summary_card())
	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))

	var again := UITheme.button(L10n.t("end.new_campaign"), "primary")
	again.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/NewGameSetup.tscn"))
	vbox.add_child(again)
	var menu := UITheme.button(L10n.t("common.main_menu"), "ghost", true)
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
		L10n.t("end.turns", [GameState.turn]),
		L10n.t("end.ops", [int(s.get("ops_run", 0)), int(s.get("ops_won", 0))]),
		L10n.t("end.events", [int(s.get("events_faced", 0))]),
		L10n.t("end.regions", [int(s.get("regions_lost", 0))]),
		L10n.t("end.posture", [L10n.t("difficulty.%d.name" % GameState.difficulty)]),
	]
	for r in rows:
		box.add_child(UITheme.label(r, UITheme.FS_SMALL, UITheme.TEXT_DIM))
	return panel
