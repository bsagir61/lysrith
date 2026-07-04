extends Control
## BootScene.gd - brief branded boot, then hands off to the main menu.

var _elapsed: float = 0.0
var _mark: Control


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.SPACE_S)
	center.add_child(vbox)
	var t := UITheme.title("LYSRITH", UITheme.FS_HUGE)
	vbox.add_child(t)
	var sub := UITheme.label("SILENT CARTOGRAPHY", UITheme.FS_SMALL, UITheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	_mark = t
	if not SettingsManager.reduce_motion:
		t.modulate.a = 0.0
		sub.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(t, "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(sub, "modulate:a", 1.0, 0.7)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.4 or (SettingsManager.reduce_motion and _elapsed >= 0.2):
		set_process(false)
		UITransitions.change_scene("res://scenes/menus/MainMenu.tscn")
