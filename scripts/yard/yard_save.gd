class_name YardSave
extends RefCounted

const PATH := "user://yard_save_v3.json"

static func write(state: YardState, path: String = PATH) -> Error:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state.snapshot(),"\t",true,true))
	file.flush(); file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))

static func load_into(state: YardState, path: String = PATH, legacy_path: String = "user://save_v1.json") -> String:
	var source := path if FileAccess.file_exists(path) else legacy_path
	if not FileAccess.file_exists(source): return ""
	var file := FileAccess.open(source,FileAccess.READ)
	if file==null: return "存档读取失败"
	var parser := JSON.new()
	var ok := parser.parse(file.get_as_text())==OK and parser.data is Dictionary
	if ok: ok = state.restore(parser.data) if source==path else state.import_legacy(parser.data)
	if not ok:
		var backup := DirAccess.copy_absolute(ProjectSettings.globalize_path(source),ProjectSettings.globalize_path(source+".corrupt-backup"))
		return "存档已备份，工坊从新开局" if backup==OK else "存档读取异常，备份失败；原文件未改动"
	return "旧工坊已接续" if source!=path else ""
