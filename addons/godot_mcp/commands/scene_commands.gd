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
	var tree := NodeUtils.get_node_tree(root, max_depth)
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

	var root_type: String = optional_string(params, "root_type", "Node2D")
	var root_name: String = optional_string(params, "root_name", "")

	# Validate root type exists
	if not ClassDB.class_exists(root_type):
		return error_invalid_params("Unknown node type: %s" % root_type)

	# Create the scene
	var root: Node = ClassDB.instantiate(root_type)
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
	get_editor().get_resource_filesystem().scan()

	return success({"path": path, "root_type": root_type, "root_name": root_name})


func _open_scene(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Scene file '%s'" % path)

	get_editor().open_scene_from_path(path)
	return success({"path": path, "opened": true})


func _delete_scene(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Scene file '%s'" % path)

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		return error_internal("Failed to delete scene: %s" % error_string(err))

	# Also remove .import file if exists
	var import_path := path + ".import"
	if FileAccess.file_exists(import_path):
		DirAccess.remove_absolute(import_path)

	get_editor().get_resource_filesystem().scan()
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

	var packed: PackedScene = load(scene_path)
	if packed == null:
		return error_internal("Failed to load scene: %s" % scene_path)

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
	var ei := get_editor()

	match mode:
		"main":
			ei.play_main_scene()
		"current":
			ei.play_current_scene()
		_:
			# Treat as scene path
			if not FileAccess.file_exists(mode):
				return error_not_found("Scene file '%s'" % mode)
			ei.play_custom_scene(mode)

	return success({"playing": true, "mode": mode})


func _stop_scene(params: Dictionary) -> Dictionary:
	var ei := get_editor()
	if not ei.is_playing_scene():
		return success({"stopped": false, "message": "No scene is currently playing"})

	ei.stop_playing_scene()

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

	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return error_internal("Failed to pack scene: %s" % error_string(err))

	err = ResourceSaver.save(scene, path)
	if err != OK:
		return error_internal("Failed to save scene: %s" % error_string(err))

	return success({"path": path, "saved": true})


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
	if FileAccess.file_exists(request_path):
		DirAccess.remove_absolute(request_path)
	if FileAccess.file_exists(screenshot_path):
		DirAccess.remove_absolute(screenshot_path)


func _cleanup_input_files() -> void:
	var user_dir := get_game_user_dir()
	var commands_path := user_dir + "/mcp_input_commands"
	if FileAccess.file_exists(commands_path):
		DirAccess.remove_absolute(commands_path)


func _cleanup_inspector_files() -> void:
	var user_dir := get_game_user_dir()
	var request_path := user_dir + "/mcp_game_request"
	var response_path := user_dir + "/mcp_game_response"
	if FileAccess.file_exists(request_path):
		DirAccess.remove_absolute(request_path)
	if FileAccess.file_exists(response_path):
		DirAccess.remove_absolute(response_path)
