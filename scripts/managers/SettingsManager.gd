extends Node
## SettingsManager.gd - user preferences persisted via ConfigFile.

signal settings_changed

const SETTINGS_PATH := "user://lysrith_settings.cfg"

var music_volume: float = 0.6
var sfx_volume: float = 0.8
var haptics_enabled: bool = true
var large_text: bool = false
var reduce_motion: bool = false
var tutorial_completed: bool = false
var language_code: String = "en"


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = float(cfg.get_value("audio", "music_volume", 0.6))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", 0.8))
	haptics_enabled = bool(cfg.get_value("input", "haptics", true))
	large_text = bool(cfg.get_value("display", "large_text", false))
	reduce_motion = bool(cfg.get_value("display", "reduce_motion", false))
	language_code = String(cfg.get_value("display", "language_code", "en"))
	tutorial_completed = bool(cfg.get_value("progress", "tutorial_completed", false))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("input", "haptics", haptics_enabled)
	cfg.set_value("display", "large_text", large_text)
	cfg.set_value("display", "reduce_motion", reduce_motion)
	cfg.set_value("display", "language_code", language_code)
	cfg.set_value("progress", "tutorial_completed", tutorial_completed)
	cfg.save(SETTINGS_PATH)
	settings_changed.emit()


## Font scale used by UITheme so every label respects the text size setting.
func text_scale() -> float:
	return 1.18 if large_text else 1.0


func vibrate(duration_ms: int = 25) -> void:
	if haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func reset_all_data() -> void:
	SaveManager.delete_save()
	tutorial_completed = false
	save_settings()
