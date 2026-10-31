class_name StompSave
extends RefCounted

const PATH := "user://save_v1.json"

static func write(state: StompState, path: String = PATH) -> Error:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state.snapshot(), "\t",true,true))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))

static func read_into(state: StompState, path: String = PATH) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "存档无法读取；本次从新车库开始。"
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return "存档格式损坏；已安全开始新试玩。"
	var parsed = parser.data
	if not parsed is Dictionary or not state.restore(parsed):
		return "存档格式损坏或版本不兼容；已安全开始新试玩。"
	return ""
