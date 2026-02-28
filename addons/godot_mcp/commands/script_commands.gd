@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"list_scripts": _list_scripts,
		"read_script": _read_script,
		"create_script": _create_script,
		"edit_script": _edit_script,
		"attach_script": _attach_script,
		"get_open_scripts": _get_open_scripts,
		"validate_script": _validate_script,
	}


func _list_scripts(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var recursive: bool = optional_bool(params, "recursive", true)

	var scripts: Array = []
	_find_scripts(path, recursive, scripts)

	return success({"scripts": scripts, "count": scripts.size()})


func _find_scripts(path: String, recursive: bool, scripts: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			if recursive:
				_find_scripts(full_path, recursive, scripts)
		elif file_name.get_extension() in ["gd", "cs", "gdshader"]:
			var info := {"path": full_path, "type": file_name.get_extension()}
			# Get basic file info
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				info["size"] = file.get_length()
				# Read first line for class/extends info
				var first_line := file.get_line().strip_edges()
				if first_line.begins_with("class_name "):
					info["class_name"] = first_line.substr(11).strip_edges()
				elif first_line.begins_with("extends "):
					info["extends"] = first_line.substr(8).strip_edges()
				file.close()
			scripts.append(info)

		file_name = dir.get_next()

	dir.list_dir_end()


func _read_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Script '%s'" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read script: %s" % error_string(FileAccess.get_open_error()))

	var content := file.get_as_text()
	var line_count := content.count("\n") + 1
	file.close()

	return success({
		"path": path,
		"content": content,
		"line_count": line_count,
		"size": content.length(),
	})


func _create_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	var content: String = optional_string(params, "content", "")
	var base_class: String = optional_string(params, "extends", "Node")
	var class_name_str: String = optional_string(params, "class_name", "")

	# Generate template if no content provided
	if content.is_empty():
		var lines: PackedStringArray = []
		if not class_name_str.is_empty():
			lines.append("class_name %s" % class_name_str)
		lines.append("extends %s" % base_class)
		lines.append("")
		lines.append("")
		lines.append("func _ready() -> void:")
		lines.append("\tpass")
		lines.append("")
		content = "\n".join(lines)

	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_internal("Cannot create script: %s" % error_string(FileAccess.get_open_error()))

	file.store_string(content)
	file.close()

	get_editor().get_resource_filesystem().scan()

	# Pre-load so the script is available immediately
	if ResourceLoader.exists(path):
		var script = load(path)
		if script is Script:
			script.reload(true)

	return success({"path": path, "created": true})


func _edit_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Script '%s'" % path)

	# Read current content
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read script: %s" % error_string(FileAccess.get_open_error()))

	var content := file.get_as_text()
	file.close()

	var old_content := content
	var changes_made := 0

	# Support search-and-replace
	if params.has("replacements") and params["replacements"] is Array:
		var replacements: Array = params["replacements"]
		for replacement in replacements:
			if replacement is Dictionary:
				var search: String = replacement.get("search", "")
				var replace: String = replacement.get("replace", "")
				if not search.is_empty():
					var use_regex: bool = replacement.get("regex", false)
					if use_regex:
						var regex := RegEx.new()
						var err := regex.compile(search)
						if err == OK:
							var new_content := regex.sub(content, replace, true)
							if new_content != content:
								content = new_content
								changes_made += 1
					else:
						if content.contains(search):
							content = content.replace(search, replace)
							changes_made += 1

	# Support full content replacement
	elif params.has("content"):
		content = str(params["content"])
		changes_made = 1

	# Support insert at line
	elif params.has("insert_at_line") and params.has("text"):
		var line_num: int = int(params["insert_at_line"])
		var text: String = str(params["text"])
		var lines := content.split("\n")
		line_num = clampi(line_num, 0, lines.size())
		lines.insert(line_num, text)
		content = "\n".join(lines)
		changes_made = 1

	if changes_made == 0:
		return success({"path": path, "changes_made": 0, "message": "No changes applied"})

	# Write back
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_internal("Cannot write script: %s" % error_string(FileAccess.get_open_error()))

	file.store_string(content)
	file.close()

	# Reload the script resource so the editor picks up changes immediately
	_reload_script(path)

	return success({"path": path, "changes_made": changes_made})


## Force-reload a script so the editor reflects disk changes immediately.
func _reload_script(path: String) -> void:
	# First, trigger a filesystem scan so Godot knows the file changed
	get_editor().get_resource_filesystem().scan()

	# If the script is already loaded in memory, reload it
	if ResourceLoader.exists(path):
		var script = load(path)
		if script is Script:
			script.reload(true)

	# If the script is open in the script editor, the reload above updates it.
	# But we also need to notify the editor to refresh its error indicators.
	get_editor().get_script_editor().notification(Control.NOTIFICATION_VISIBILITY_CHANGED)


func _attach_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "script_path")
	if result2[1] != null:
		return result2[1]
	var script_path: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not FileAccess.file_exists(script_path):
		return error_not_found("Script '%s'" % script_path)

	var script: Script = load(script_path)
	if script == null:
		return error_internal("Failed to load script: %s" % script_path)

	var old_script: Variant = node.get_script()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Attach script to %s" % node.name)
	undo_redo.add_do_method(node, "set_script", script)
	undo_redo.add_undo_method(node, "set_script", old_script)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"script_path": script_path,
		"attached": true,
	})


func _validate_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Script '%s'" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read script: %s" % error_string(FileAccess.get_open_error()))

	var source_code := file.get_as_text()
	file.close()

	var script := GDScript.new()
	script.source_code = source_code
	var err := script.reload()

	if err == OK:
		return success({"path": path, "valid": true, "message": "Script compiles successfully"})

	return success({
		"path": path,
		"valid": false,
		"error_code": err,
		"error_string": error_string(err),
		"message": "Compilation failed. Use get_output_log or get_editor_errors for details.",
	})


func _get_open_scripts(params: Dictionary) -> Dictionary:
	var script_editor := get_editor().get_script_editor()
	var open_scripts: Array = []

	for script_base in script_editor.get_open_scripts():
		var info := {
			"path": script_base.resource_path,
			"type": script_base.get_class(),
		}
		open_scripts.append(info)

	return success({"scripts": open_scripts, "count": open_scripts.size()})
