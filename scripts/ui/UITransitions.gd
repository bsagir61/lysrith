extends CanvasLayer
## UITransitions.gd - scene fades and brief full-screen flashes.
## Respects the Reduce Motion accessibility setting.

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.04, 0.07, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	if SettingsManager.reduce_motion:
		get_tree().change_scene_to_file(path)
		_busy = false
		return
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, UITheme.ANIM_MED)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(path)
	)
	tween.tween_property(_fade, "modulate:a", 0.0, UITheme.ANIM_MED)
	tween.tween_callback(func() -> void:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
	)


## Brief tinted flash used for operation results.
func flash(color: Color, strength: float = 0.22) -> void:
	if SettingsManager.reduce_motion:
		return
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, strength)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, UITheme.ANIM_SLOW)
	tween.tween_callback(rect.queue_free)
