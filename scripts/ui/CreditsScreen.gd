extends Control
## CreditsScreen.gd - credits and content statement.


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

	vbox.add_child(UITheme.title("CREDITS"))
	vbox.add_child(UITheme.spacer(UITheme.SPACE_M))

	var lines := [
		["LYSRITH: SILENT CARTOGRAPHY", UITheme.ACCENT],
		["Design, code and procedural visuals\ncreated for this project.", UITheme.TEXT],
		["Built with Godot Engine 4.x\n(godotengine.org - MIT license)", UITheme.TEXT_DIM],
		["All regions, agents, organizations and events\nare entirely fictional and abstract.\nNo real countries, agencies, or persons\nare depicted or referenced.", UITheme.TEXT_DIM],
		["Audio tones generated procedurally in-project.", UITheme.TEXT_DIM],
	]
	for entry in lines:
		var l := UITheme.label(entry[0], UITheme.FS_SMALL, entry[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(l)
		vbox.add_child(UITheme.spacer(UITheme.SPACE_S))

	vbox.add_child(UITheme.spacer(UITheme.SPACE_L))
	var back := UITheme.button("BACK", "ghost", true)
	back.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	vbox.add_child(back)
