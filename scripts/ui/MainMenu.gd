extends Control
## MainMenu.gd - entry hub. Continue is dimmed when no save exists.


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_XL * 2)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_XL)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	margin.add_child(vbox)

	var title := UITheme.title("LYSRITH", UITheme.FS_HUGE)
	vbox.add_child(title)
	var sub := UITheme.label("SILENT CARTOGRAPHY", UITheme.FS_SMALL, UITheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	vbox.add_child(UITheme.spacer(UITheme.SPACE_XL))

	var new_btn := UITheme.button("NEW GAME", "primary")
	new_btn.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/NewGameSetup.tscn"))
	vbox.add_child(new_btn)

	var continue_btn := UITheme.button("CONTINUE", "ghost")
	if SaveManager.has_save():
		continue_btn.pressed.connect(_on_continue)
	else:
		continue_btn.disabled = true
		continue_btn.modulate.a = 0.55
	vbox.add_child(continue_btn)

	var how_btn := UITheme.button("HOW TO PLAY", "ghost")
	how_btn.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/HowToPlayScreen.tscn"))
	vbox.add_child(how_btn)

	var settings_btn := UITheme.button("SETTINGS", "ghost")
	settings_btn.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/SettingsScreen.tscn"))
	vbox.add_child(settings_btn)

	var credits_btn := UITheme.button("CREDITS", "ghost")
	credits_btn.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/CreditsScreen.tscn"))
	vbox.add_child(credits_btn)

	# Exit only where the platform expects it.
	if not OS.has_feature("web") and not OS.has_feature("ios"):
		var exit_btn := UITheme.button("EXIT", "ghost", true)
		exit_btn.pressed.connect(func() -> void: get_tree().quit())
		vbox.add_child(exit_btn)

	vbox.add_child(UITheme.spacer(UITheme.SPACE_L))
	var footer := UITheme.label("A fictional intelligence simulation. v1.0", 20, UITheme.TEXT_DIM)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(footer)


func _on_continue() -> void:
	if SaveManager.load_game():
		UITransitions.change_scene("res://scenes/game/GameScene.tscn")
