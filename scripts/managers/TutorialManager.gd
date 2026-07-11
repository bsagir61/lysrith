extends Node
## TutorialManager.gd - linear first-run tutorial flow.
## GameScene reports player actions via notify(); this manager decides
## when to advance and what guidance text to show. Fully skippable.

signal step_changed(text: String)
signal context_hint(text: String)
signal tutorial_finished

## Each step: localization key shown in the tutorial banner + the action that advances it.
## Steps with advance "tap" continue when the banner itself is tapped.
const STEPS: Array = [
	{"advance": "region_selected", "text_key": "tutorial.region"},
	{"advance": "region_read", "text_key": "tutorial.region_read"},
	{"advance": "roster_opened", "text_key": "tutorial.roster"},
	{"advance": "agent_selected", "text_key": "tutorial.agent"},
	{"advance": "map_signals_selected", "text_key": "tutorial.map_signals"},
	{"advance": "operation_resolved", "text_key": "tutorial.resolve"},
	{"advance": "tap", "text_key": "tutorial.intel_identity"},
	{"advance": "tap", "text_key": "tutorial.heat_network"},
	{"advance": "tap", "text_key": "tutorial.rival"},
	{"advance": "tap", "text_key": "tutorial.finish"},
]

var active: bool = false
var step_index: int = 0
var _identity_hint_shown: bool = false
var _context_active: bool = false


func should_run() -> bool:
	return not SettingsManager.tutorial_completed and not GameState.tutorial_done


func start() -> void:
	active = true
	step_index = 0
	_identity_hint_shown = false
	_context_active = false
	step_changed.emit(current_text())


func current_text() -> String:
	if step_index < STEPS.size():
		return L10n.t(String(STEPS[step_index]["text_key"]))
	return ""


## GameScene calls this with an action id whenever the player does something.
func notify(action: String) -> void:
	if not active or step_index >= STEPS.size():
		return
	if action == "identity_revealed" and not _identity_hint_shown:
		_identity_hint_shown = true
		_context_active = true
		context_hint.emit(L10n.t("tutorial.identity_revealed"))
		return
	if _context_active and action == "tap":
		_context_active = false
		step_changed.emit(current_text())
		return
	if STEPS[step_index]["advance"] == action:
		step_index += 1
		if step_index >= STEPS.size():
			_finish()
		elif not _context_active:
			step_changed.emit(current_text())


func skip() -> void:
	if active:
		_finish()


func _finish() -> void:
	active = false
	_context_active = false
	GameState.tutorial_done = true
	SettingsManager.tutorial_completed = true
	SettingsManager.save_settings()
	tutorial_finished.emit()
