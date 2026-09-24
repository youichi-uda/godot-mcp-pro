@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const NodeUtils := preload("res://addons/godot_mcp/utils/node_utils.gd")
const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")


func get_commands() -> Dictionary:
	return {
		"get_scene_tree": _get_scene_tree,
		"get_scene_file_content": _get_scene_file_content,
		"create_scene": _create_scene,
		"open_scene": _open_scene,
		"delete_scene": _delete_scene,
		"add_scene_instance": _add_scene_instance,
		"play_scene": _play_scene,
		"stop_scene": _stop_scene,
		"save_scene": _save_scene,
		"get_scene_exports": _get_scene_exports,
	}


func _get_scene_tree(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var max_depth: int = optional_int(params, "max_depth", -1)
	var tree := NodeUtils.get_node_tree(root, root, max_depth)
	return success({"scene_path": root.scene_file_path, "tree": tree})


func _get_scene_file_content(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Scene file '%s'" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read file: %s" % error_string(FileAccess.get_open_error()))

	var content := file.get_as_text()
	file.close()
	return success({"path": path, "content": content, "size": content.length()})


func _create_scene(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	var guard := guard_offline_scene_save(path)
	if not guard.is_empty():
		return guard

	var root_type: String = optional_string(params, "root_type", "Node2D")
	var root_name: String = optional_string(params, "root_name", "")

	# Validate root type exists
	if not ClassDB.class_exists(root_type):
		return error_invalid_params("Unknown node type: %s" % root_type)
	# class_exists() is true for Resources and abstract classes too. Assigning
	# either into a typed Node local raises — which aborts the handler and
	# leaves the caller with no response at all.
	if not ClassDB.is_parent_class(root_type, "Node"):
		return error_invalid_params("'%s' is not a Node type, so it cannot be a scene root" % root_type)
	if not ClassDB.can_instantiate(root_type):
		return error_invalid_params("'%s' is abstract and cannot be instantiated" % root_type)

	var force: bool = optional_bool(params, "force", false)
	if not force and FileAccess.file_exists(path):
		return error_conflict(
			"Scene '%s' already exists" % path,
			{"path": path, "suggestion": "Pass force=true to overwrite it, or choose another path."}
		)

	# Create the scene
	var root: Node = ClassDB.instantiate(root_type)
	if root == null:
		return error_internal("Could not instantiate '%s'" % root_type)
	if root_name.is_empty():
		root_name = path.get_file().get_basename()
	root.name = root_name

	var scene := PackedScene.new()
	var err := scene.pack(root)
	root.queue_free()

	if err != OK:
		return error_internal("Failed to pack scene: %s" % error_string(err))

	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	err = ResourceSaver.save(scene, path)
	if err != OK:
		return error_internal("Failed to save scene: %s" % error_string(err))

	# Refresh filesystem
	EditorInterface.get_resource_filesystem().scan()

	return success({"path": path, "root_type": root_type, "root_name": root_name})


func _open_scene(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Scene file '%s'" % path)

	EditorInterface.open_scene_from_path(path)
	return success({"path": path, "opened": true})


func _delete_scene(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Scene file '%s'" % path)

	# The tool is delete_scene, but nothing checked that the target was one —
	# a mistyped path would permanently delete a script, an image, or
	# project.godot, with no undo.
	if not is_scene_resource_path(path):
		return error_invalid_params(
			"'%s' is not a scene file (.tscn or .scn). delete_scene will not delete other files." % path
		)

	if is_scene_path_open(path):
		return error_conflict(
			"Refusing to delete '%s' while it is open in the editor" % normalize_project_path(path),
			{"suggestion": "Close the scene tab first."}
		)

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		return error_internal("Failed to delete scene: %s" % error_string(err))

	# Also remove .import file if exists
	var import_path := path + ".import"
	if FileAccess.file_exists(import_path):
		DirAccess.remove_absolute(import_path)

	EditorInterface.get_resource_filesystem().scan()
	return success({"path": path, "deleted": true})


func _add_scene_instance(params: Dictionary) -> Dictionary:
	var result := require_string(params, "scene_path")
	if result[1] != null:
		return result[1]
	var scene_path: String = result[0]

	var parent_path: String = optional_string(params, "parent_path", ".")
	var instance_name: String = optional_string(params, "name", "")

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	if not FileAccess.file_exists(scene_path):
		return error_not_found("Scene file '%s'" % scene_path)

	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path, "Use get_scene_tree to see available nodes")

	# load() happily returns whatever the file actually is; assigning a Script
	# or a Texture into a typed PackedScene local raises rather than erroring.
	var loaded: Variant = load(scene_path)
	if loaded == null:
		return error_internal("Failed to load scene: %s" % scene_path)
	if not loaded is PackedScene:
		return error_invalid_params(
			"'%s' is a %s, not a PackedScene" % [scene_path, loaded.get_class() if loaded is Object else type_string(typeof(loaded))]
		)
	var packed: PackedScene = loaded

	var instance := packed.instantiate()
	if not instance_name.is_empty():
		instance.name = instance_name

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add scene instance")
	undo_redo.add_do_method(parent, "add_child", instance)
	undo_redo.add_do_method(instance, "set_owner", root)
	undo_redo.add_do_reference(instance)
	undo_redo.add_undo_method(parent, "remove_child", instance)
	undo_redo.commit_action()

	NodeUtils.set_owner_recursive(instance, root)

	return success({
		"node_path": str(root.get_path_to(instance)),
		"scene_path": scene_path,
		"name": instance.name,
	})


func _play_scene(params: Dictionary) -> Dictionary:
	var mode: String = optional_string(params, "mode", "main")  # "main", "current", or path

	# Validate first: a bad request must not touch the running game's
	# pending input.
	if mode != "main" and mode != "current":
		if not FileAccess.file_exists(mode):
			return error_not_found("Scene file '%s'" % mode)
		var ext := mode.get_extension().to_lower()
		if ext != "tscn" and ext != "scn":
			return error_invalid_params("'%s' is not a scene file (.tscn/.scn)" % mode)

	# Playing while a game runs restarts it synchronously, so the plugin never
	# sees a stop. End the old session here: invalidate waiting writers and
	# remove the input/requests it left unread.
	if EditorInterface.is_playing_scene():
		bump_play_session()
		_cleanup_input_files()
		_cleanup_inspector_files()

	# Starting a game can save scenes and scripts first ("save before
	# running"); protect buffers against a failed implicit save.
	protect_script_buffers_before_save()
	match mode:
		"main":
			EditorInterface.play_main_scene()
		"current":
			EditorInterface.play_current_scene()
		_:
			# Treat as scene path
			if not FileAccess.file_exists(mode):
				return error_not_found("Scene file '%s'" % mode)
			EditorInterface.play_custom_scene(mode)

	# Report what actually happened: a scene that fails to launch leaves
	# nothing playing.
	var playing := EditorInterface.is_playing_scene()
	if not playing:
		return error(-32000, "The scene did not start", {"mode": mode, "suggestion": "Check the Output panel for the reason (e.g. no main scene set, or a script error)."})
	return success({"playing": true, "mode": mode})


func _stop_scene(_params: Dictionary) -> Dictionary:
	if not EditorInterface.is_playing_scene():
		return success({"stopped": false, "message": "No scene is currently playing"})

	# Invalidate waiting writers now: a play_scene queued right behind this
	# call would otherwise start a new game before the plugin's next frame
	# notices the stop, and they would publish into it.
	bump_play_session()
	EditorInterface.stop_playing_scene()

	# Clean up temp files
	_cleanup_screenshot_files()
	_cleanup_input_files()
	_cleanup_inspector_files()

	return success({"stopped": true})


func _save_scene(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var path: String = optional_string(params, "path", "")
	if path.is_empty():
		path = root.scene_file_path

	if path.is_empty():
		return error_invalid_params("No save path specified and scene has no existing path")

	var normalized_path := normalize_project_path(path)
	if is_scene_path_open(normalized_path) and not is_active_scene_path(normalized_path):
		return error_conflict(
			"Refusing to save inactive open scene '%s' from the active editor scene" % normalized_path,
			{
				"path": normalized_path,
				"active_scene": normalize_project_path(root.scene_file_path),
				"open_scenes": get_open_scene_paths(),
				"suggestion": "Open the target scene tab before saving it, or close it before offline edits.",
			}
		)

	var dir_path := normalized_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err: int
	var save_method: String
	# Saving a scene also saves modified script buffers; protect them in case
	# that write fails (see protect_script_buffers_before_save).
	protect_script_buffers_before_save()
	var was_playing := EditorInterface.is_playing_scene()
	if root.scene_file_path.is_empty() or not paths_match(normalize_project_path(root.scene_file_path), normalized_path):
		EditorInterface.save_scene_as(normalized_path)
		# save_scene_as() returns nothing, so success was simply assumed and
		# reported. Check that the file actually appeared instead.
		save_method = "EditorInterface.save_scene_as"
		err = OK if FileAccess.file_exists(normalized_path) else ERR_FILE_CANT_WRITE
	else:
		err = EditorInterface.save_scene()
		save_method = "EditorInterface.save_scene"
	# If saving stopped a running game, end its session (see handle_implicit_stop).
	handle_implicit_stop(was_playing)
	if err != OK:
		return error_internal("Failed to save scene via %s: %s" % [save_method, error_string(err)])

	return success({"path": normalized_path, "saved": true, "method": save_method})


func _get_scene_exports(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Scene file '%s'" % path)

	var packed: PackedScene = load(path)
	if packed == null:
		return error_internal("Failed to load scene: %s" % path)

	var instance: Node = packed.instantiate()
	if instance == null:
		return error_internal("Failed to instantiate scene: %s" % path)

	var nodes_data: Array = []
	_collect_exports_recursive(instance, instance, nodes_data)

	instance.queue_free()

	return success({
		"path": path,
		"nodes": nodes_data,
		"count": nodes_data.size(),
	})


func _collect_exports_recursive(node: Node, root: Node, nodes_data: Array) -> void:
	var script: Script = node.get_script()
	if script != null:
		var exports: Dictionary = {}
		for prop_info in script.get_script_property_list():
			var usage: int = prop_info["usage"]
			if (usage & PROPERTY_USAGE_EDITOR) and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				var prop_name: String = prop_info["name"]
				exports[prop_name] = {
					"value": PropertyParser.serialize_value(node.get(prop_name)),
					"type": prop_info["type"],
					"hint": prop_info.get("hint", 0),
					"hint_string": prop_info.get("hint_string", ""),
				}
		if not exports.is_empty():
			var node_path := "." if node == root else str(root.get_path_to(node))
			nodes_data.append({
				"node_path": node_path,
				"node_name": node.name,
				"node_type": node.get_class(),
				"script_path": script.resource_path,
				"exports": exports,
			})

	for child in node.get_children():
		_collect_exports_recursive(child, root, nodes_data)


func _cleanup_screenshot_files() -> void:
	var user_dir := get_game_user_dir()
	var request_path := user_dir + "/mcp_screenshot_request"
	var screenshot_path := user_dir + "/mcp_screenshot.png"
	remove_ipc_file_if_owned(request_path)
	if FileAccess.file_exists(screenshot_path):
		DirAccess.remove_absolute(screenshot_path)


func _cleanup_input_files() -> void:
	var user_dir := get_game_user_dir()
	# The input writer uses this editor's user:// (see write_input_payload);
	# check both it and the game's directory, removing only our own payload.
	remove_ipc_file_if_owned(INPUT_COMMANDS_PATH)
	remove_ipc_file_if_owned(user_dir + "/mcp_input_commands")


func _cleanup_inspector_files() -> void:
	var user_dir := get_game_user_dir()
	var request_path := user_dir + "/mcp_game_request"
	var response_path := user_dir + "/mcp_game_response"
	remove_ipc_file_if_owned(request_path)
	remove_ipc_file_if_owned(response_path)
