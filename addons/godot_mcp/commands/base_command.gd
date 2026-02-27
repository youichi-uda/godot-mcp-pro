@tool
extends Node

var editor_plugin: EditorPlugin


## Override in subclasses: return {"method_name": Callable}
func get_commands() -> Dictionary:
	return {}


## Helper: return a success result
func success(data: Dictionary = {}) -> Dictionary:
	return {"result": data}


## Helper: return an error
func error(code: int, message: String, data: Dictionary = {}) -> Dictionary:
	var err := {"code": code, "message": message}
	if not data.is_empty():
		err["data"] = data
	return {"error": err}


## Error codes
func error_not_found(what: String, suggestion: String = "") -> Dictionary:
	var data := {}
	if suggestion:
		data["suggestion"] = suggestion
	return error(-32001, "%s not found" % what, data)


func error_invalid_params(message: String) -> Dictionary:
	return error(-32602, message)


func error_no_scene() -> Dictionary:
	return error(-32000, "No scene is currently open", {"suggestion": "Use open_scene to open a scene first"})


func error_internal(message: String) -> Dictionary:
	return error(-32603, "Internal error: %s" % message)


## Get required string param
func require_string(params: Dictionary, key: String) -> Array:
	if not params.has(key) or not params[key] is String or (params[key] as String).is_empty():
		return [null, error_invalid_params("Missing required parameter: %s" % key)]
	return [params[key] as String, null]


## Get optional string param with default
func optional_string(params: Dictionary, key: String, default: String = "") -> String:
	if params.has(key) and params[key] is String:
		return params[key] as String
	return default


## Get optional bool param with default
func optional_bool(params: Dictionary, key: String, default: bool = false) -> bool:
	if params.has(key) and params[key] is bool:
		return params[key] as bool
	return default


## Get optional int param with default
func optional_int(params: Dictionary, key: String, default: int = 0) -> int:
	if params.has(key):
		return int(params[key])
	return default


## Get the game process's user data directory.
## OS.get_user_data_dir() is cached at editor startup and won't reflect
## project name changes made to project.godot while the editor is running.
## The game process reads the name from disk, so we must do the same.
func get_game_user_dir() -> String:
	var cached_dir := OS.get_user_data_dir()
	var cfg := ConfigFile.new()
	var err := cfg.load(ProjectSettings.globalize_path("res://project.godot"))
	if err != OK:
		return cached_dir
	var disk_name = cfg.get_value("application", "config/name", "")
	if disk_name.is_empty():
		return cached_dir
	var base_dir := cached_dir.get_base_dir()
	var game_dir := base_dir.path_join(str(disk_name))
	# Ensure the directory exists (game may not have created it yet)
	if not DirAccess.dir_exists_absolute(game_dir):
		DirAccess.make_dir_recursive_absolute(game_dir)
	return game_dir


## Get EditorInterface
func get_editor() -> EditorInterface:
	return editor_plugin.get_editor_interface()


## Get the edited scene root
func get_edited_root() -> Node:
	return get_editor().get_edited_scene_root()


## Get UndoRedo
func get_undo_redo() -> EditorUndoRedoManager:
	return editor_plugin.get_undo_redo()


## Find node by path in edited scene
func find_node_by_path(node_path: String) -> Node:
	var root := get_edited_root()
	if root == null:
		return null
	if node_path == "." or node_path == root.name:
		return root
	# Try relative from root
	if root.has_node(node_path):
		return root.get_node(node_path)
	# Try with root name prefix stripped
	if node_path.begins_with(root.name + "/"):
		var rel := node_path.substr(root.name.length() + 1)
		if root.has_node(rel):
			return root.get_node(rel)
	return null
