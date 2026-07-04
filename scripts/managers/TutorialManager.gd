extends Node
## TutorialManager.gd - linear first-run tutorial flow.
## GameScene reports player actions via notify(); this manager decides
## when to advance and what guidance text to show. Fully skippable.

signal step_changed(text: String)
signal tutorial_finished

## Each step: text shown in the tutorial banner + the action that advances it.
## Steps with advance "tap" continue when the banner itself is tapped.
const STEPS: Array = [
	{"advance": "region_selected", "text": "Welcome, Director. Tap any region node on the map to open its dossier."},
	{"advance": "region_read", "text": "This is the region dossier. Stability, Rival Influence and Surveillance decide how risky work here will be. Tap PLAN OPERATION."},
	{"advance": "roster_opened", "text": "Every operation needs an agent. This is your roster."},
	{"advance": "agent_selected", "text": "Each agent is better at some work than others. Select any agent to continue."},
	{"advance": "map_signals_selected", "text": "Operations show cost, odds and Heat before you commit. Choose MAP SIGNALS - the safest way to learn a region."},
	{"advance": "operation_resolved", "text": "Confirm the operation and read the debrief."},
	{"advance": "tap", "text": "INTEL is your analytical currency. Spend it on Deep Analysis and predictions. Earn it by mapping signals. (Tap to continue)"},
	{"advance": "tap", "text": "HEAT is how visible you are. High Heat feeds Global Exposure and triggers hostile events. Cool it down before it burns you. (Tap to continue)"},
	{"advance": "tap", "text": "RIVAL NETWORK EXPOSURE is your victory meter. Build local networks, then run Trace Rival Cell to push it to 100. (Tap to continue)"},
	{"advance": "tap", "text": "The rest is judgment. Watch the map, spend carefully, and expose them before the world unravels. Good luck, Director. (Tap to finish)"},
]

var active: bool = false
var step_index: int = 0


func should_run() -> bool:
	return not SettingsManager.tutorial_completed and not GameState.tutorial_done


func start() -> void:
	active = true
	step_index = 0
	step_changed.emit(current_text())


func current_text() -> String:
	if step_index < STEPS.size():
		return STEPS[step_index]["text"]
	return ""


## GameScene calls this with an action id whenever the player does something.
func notify(action: String) -> void:
	if not active or step_index >= STEPS.size():
		return
	if STEPS[step_index]["advance"] == action:
		step_index += 1
		if step_index >= STEPS.size():
			_finish()
		else:
			step_changed.emit(current_text())


func skip() -> void:
	if active:
		_finish()


func _finish() -> void:
	active = false
	GameState.tutorial_done = true
	SettingsManager.tutorial_completed = true
	SettingsManager.save_settings()
	tutorial_finished.emit()
