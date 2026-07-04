extends Control
## HowToPlayScreen.gd - plain-language rules reference.

const SECTIONS: Array = [
	["YOUR GOAL",
		"You direct the Lysrith Directorate, a fictional intelligence bureau. Expose the hidden rival network - push RIVAL NETWORK EXPOSURE to 100 - before the world slides into irreversible crisis."],
	["HOW A TURN WORKS",
		"Each turn: tap a region, pick an agent, pick an operation. The operation resolves, the world reacts, and the rival network spreads a little further. Short runs, meaningful choices."],
	["INTEL",
		"Intel is your analytical currency. Map Signals earns it. Deep Analysis and some events spend it. Higher region Intel Levels improve your odds there."],
	["HEAT",
		"Heat is how visible your bureau is. Every operation adds some. High Heat feeds Global Exposure and invites hostile events. Run Reduce Heat before it burns you."],
	["RIVAL NETWORK EXPOSURE",
		"Your victory meter. Trace Rival Cell raises it. Building a Local Network in a region first makes traces there stronger and safer."],
	["WHY REGIONS COLLAPSE",
		"Rival influence erodes a region's stability each turn. When stability hits zero the region collapses - permanently. Five collapses end the campaign. Stabilize or contain regions before it is too late."],
	["AGENTS",
		"Each agent excels at different work: analysts map signals, field observers build networks, specialists trace cells. Fatigue lowers odds - rotate your roster. Traits change how agents behave."],
	["HOW TO WIN",
		"Scout early with Map Signals. Build networks in promising regions. Keep Heat and Trust healthy. Then trace, trace, trace."],
	["HOW TO LOSE",
		"Global Exposure at 100. Agency Trust at 0. Five collapsed regions. Or staying broke one turn after the insolvency warning. The world does not wait for you."],
]


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

	vbox.add_child(UITheme.title("HOW TO PLAY"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UITheme.SPACE_M)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	for section in SECTIONS:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UITheme.card_style())
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", UITheme.SPACE_XS)
		panel.add_child(inner)
		inner.add_child(UITheme.label(section[0], UITheme.FS_BODY, UITheme.ACCENT))
		inner.add_child(UITheme.label(section[1], UITheme.FS_SMALL, UITheme.TEXT))
		content.add_child(panel)

	var back := UITheme.button("BACK", "ghost", true)
	back.pressed.connect(func() -> void:
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn"))
	vbox.add_child(back)
