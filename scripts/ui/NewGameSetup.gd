extends Control
## NewGameSetup.gd - difficulty selection before a fresh campaign.


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_right", UITheme.SPACE_L)
	margin.add_theme_constant_override("margin_top", UITheme.SPACE_XL)
	margin.add_theme_constant_override("margin_bottom", UITheme.SPACE_L)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_M)
	margin.add_child(vbox)

	vbox.add_child(UITheme.title("SELECT POSTURE"))
	var hint := UITheme.label("Choose how much the world will forgive.", UITheme.FS_SMALL, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))

	for d in 3:
		vbox.add_child(_difficulty_card(d))

	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))
	var back := UITheme.button("BACK", "ghost", true)
	back.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	vbox.add_child(back)


func _difficulty_card(d: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.card_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_XS)
	panel.add_child(vbox)
	var kinds: Array[String] = ["primary", "warn", "danger"]
	var colors: Array[Color] = [UITheme.ACCENT, UITheme.WARN, UITheme.DANGER]
	var kind: String = kinds[d]
	var color: Color = colors[d]
	vbox.add_child(UITheme.label(Balance.difficulty_name(d).to_upper(), UITheme.FS_LARGE, color))
	vbox.add_child(UITheme.label(Balance.DIFFICULTY_DESCS[d], UITheme.FS_SMALL, UITheme.TEXT_DIM))
	var btn := UITheme.button("BEGIN " + Balance.difficulty_name(d).to_upper(), kind, true)
	btn.pressed.connect(func() -> void: _start(d))
	vbox.add_child(btn)
	return panel


func _start(difficulty: int) -> void:
	GameState.new_campaign(difficulty)
	SaveManager.save_game()
	AudioManager.play_confirm()
	UITransitions.change_scene("res://scenes/game/GameScene.tscn")
