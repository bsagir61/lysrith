extends Node
## SaveManager.gd - local save/load of the campaign as JSON in user://.
## The save is a straight serialization of GameState.to_dict().

const SAVE_PATH := "user://lysrith_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if not GameState.campaign_active:
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write save file")
		return false
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("regions"):
		push_error("SaveManager: save file is corrupt")
		return false
	GameState.from_dict(parsed)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
