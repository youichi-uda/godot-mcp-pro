@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_project_info": _get_project_info,
		"get_filesystem_tree": _get_filesystem_tree,
		"search_files": _search_files,
		"search_in_files": _search_in_files,
		"get_project_settings": _get_project_settings,
		"set_project_setting": _set_project_setting,
		"uid_to_project_path": _uid_to_project_path,
		"project_path_to_uid": _project_path_to_uid,
		"add_autoload": _add_autoload,
		"remove_autoload": _remove_autoload,
	}


func _get_project_info(params: Dictionary) -> Dictionary:
	var info := {}
	info["project_name"] = ProjectSettings.get_setting("application/config/name", "")
	info["godot_version"] = Engine.get_version_info()
	info["project_path"] = ProjectSettings.globalize_path("res://")
	info["main_scene"] = ProjectSettings.get_setting("application/run/main_scene", "")

	# Viewport settings
	info["viewport_width"] = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	info["viewport_height"] = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	info["window_width"] = ProjectSettings.get_setting("display/window/size/window_width_override", 0)
	info["window_height"] = ProjectSettings.get_setting("display/window/size/window_height_override", 0)

	# Rendering
	info["renderer"] = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")

	# Autoloads
	var autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("autoload/"):
			autoloads[name.substr(9)] = ProjectSettings.get_setting(name)
	info["autoloads"] = autoloads

	return success(info)


func _get_filesystem_tree(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var filter: String = optional_string(params, "filter", "")  # e.g. "*.gd", "*.tscn"
	var max_depth: int = optional_int(params, "max_depth", 10)

	var tree := _scan_directory(path, filter, max_depth, 0)
	return success({"tree": tree})


func _scan_directory(path: String, filter: String, max_depth: int, depth: int) -> Dictionary:
	var result := {"name": path.get_file(), "path": path, "type": "directory"}

	if depth >= max_depth:
		return result

	var dir := DirAccess.open(path)
	if dir == null:
		return result

	var children: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			children.append(_scan_directory(full_path, filter, max_depth, depth + 1))
		else:
			if filter.is_empty() or file_name.match(filter):
				children.append({
					"name": file_name,
					"path": full_path,
					"type": "file",
				})

		file_name = dir.get_next()

	dir.list_dir_end()

	if not children.is_empty():
		result["children"] = children

	return result


func _search_files(params: Dictionary) -> Dictionary:
	var result := require_string(params, "query")
	if result[1] != null:
		return result[1]
	var query: String = result[0]

	var path: String = optional_string(params, "path", "res://")
	var file_type: String = optional_string(params, "file_type", "")  # e.g. "gd", "tscn"
	var max_results: int = optional_int(params, "max_results", 50)

	var matches: Array = []
	_search_recursive(path, query, file_type, matches, max_results)

	return success({"matches": matches, "count": matches.size()})


func _search_recursive(path: String, query: String, file_type: String, matches: Array, max_results: int) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty() and matches.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			_search_recursive(full_path, query, file_type, matches, max_results)
		else:
			# Check file type filter
			if not file_type.is_empty() and file_name.get_extension() != file_type:
				file_name = dir.get_next()
				continue

			# Fuzzy match: check if query is contained in filename (case insensitive)
			if file_name.to_lower().contains(query.to_lower()):
				matches.append(full_path)
			# Also check glob pattern
			elif file_name.match(query):
				matches.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


func _get_project_settings(params: Dictionary) -> Dictionary:
	var section: String = optional_string(params, "section", "")
	var key: String = optional_string(params, "key", "")

	# If specific key requested
	if not key.is_empty():
		if ProjectSettings.has_setting(key):
			var value = ProjectSettings.get_setting(key)
			return success({"key": key, "value": str(value), "type": typeof(value)})
		else:
			return error_not_found("Setting '%s'" % key)

	# If section requested, return all settings in that section
	var settings := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if section.is_empty() or name.begins_with(section):
			settings[name] = str(ProjectSettings.get_setting(name))

	return success({"settings": settings, "count": settings.size()})


func _set_project_setting(params: Dictionary) -> Dictionary:
	var result := require_string(params, "key")
	if result[1] != null:
		return result[1]
	var key: String = result[0]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")

	var value = params["value"]

	# Type conversion for common patterns
	if value is String:
		var s: String = value
		# Try to parse typed values from string
		if s.begins_with("Vector2("):
			var expr := Expression.new()
			if expr.parse(s) == OK:
				var parsed = expr.execute()
				if parsed is Vector2:
					value = parsed
		elif s == "true":
			value = true
		elif s == "false":
			value = false
		elif s.is_valid_int():
			value = s.to_int()
		elif s.is_valid_float():
			value = s.to_float()

	ProjectSettings.set_setting(key, value)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"key": key,
		"value": str(ProjectSettings.get_setting(key)),
		"saved": true,
	})


func _uid_to_project_path(params: Dictionary) -> Dictionary:
	var result := require_string(params, "uid")
	if result[1] != null:
		return result[1]
	var uid_str: String = result[0]

	# Use ResourceUID to convert
	var uid := ResourceUID.text_to_id(uid_str)
	if uid == ResourceUID.INVALID_ID:
		return error_invalid_params("Invalid UID format: %s" % uid_str)

	if not ResourceUID.has_id(uid):
		return error_not_found("UID '%s'" % uid_str)

	var path := ResourceUID.get_id_path(uid)
	return success({"uid": uid_str, "path": path})


func _project_path_to_uid(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not ResourceLoader.exists(path):
		return error_not_found("Resource at '%s'" % path)

	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return error(-32001, "No UID assigned to '%s'" % path)

	var uid_str := ResourceUID.id_to_text(uid)
	return success({"path": path, "uid": uid_str})


const _TEXT_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres", "cfg", "godot", "gdshader", "md", "txt", "json"]

func _search_in_files(params: Dictionary) -> Dictionary:
	var result := require_string(params, "query")
	if result[1] != null:
		return result[1]
	var query: String = result[0]

	var path: String = optional_string(params, "path", "res://")
	var max_results: int = optional_int(params, "max_results", 50)
	var use_regex: bool = optional_bool(params, "regex", false)
	var file_type: String = optional_string(params, "file_type", "")

	var regex: RegEx = null
	if use_regex:
		regex = RegEx.new()
		var err := regex.compile(query)
		if err != OK:
			return error_invalid_params("Invalid regex pattern: %s" % error_string(err))

	var matches: Array = []
	_search_in_files_recursive(path, query, regex, file_type, matches, max_results)

	return success({"matches": matches, "count": matches.size(), "query": query})


func _search_in_files_recursive(path: String, query: String, regex: RegEx, file_type: String, matches: Array, max_results: int) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty() and matches.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			# Skip addons and .godot directories
			if file_name != "addons" and file_name != ".godot":
				_search_in_files_recursive(full_path, query, regex, file_type, matches, max_results)
		else:
			var ext := file_name.get_extension()
			# Filter by file type if specified, otherwise use text extensions
			if not file_type.is_empty():
				if ext != file_type:
					file_name = dir.get_next()
					continue
			elif ext not in _TEXT_EXTENSIONS:
				file_name = dir.get_next()
				continue

			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var lines := content.split("\n")
				for i in range(lines.size()):
					if matches.size() >= max_results:
						break
					var line: String = lines[i]
					var matched := false
					if regex != null:
						matched = regex.search(line) != null
					else:
						matched = line.contains(query)
					if matched:
						matches.append({
							"file": full_path,
							"line": i + 1,
							"text": line.strip_edges(),
						})

		file_name = dir.get_next()

	dir.list_dir_end()


func _add_autoload(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var autoload_name: String = result[0]

	var result2 := require_string(params, "path")
	if result2[1] != null:
		return result2[1]
	var autoload_path: String = result2[0]

	if not FileAccess.file_exists(autoload_path):
		return error_not_found("File '%s'" % autoload_path)

	# Check if already exists
	var setting_key := "autoload/" + autoload_name
	if ProjectSettings.has_setting(setting_key):
		return error(-32000, "Autoload '%s' already exists" % autoload_name, {
			"current_value": str(ProjectSettings.get_setting(setting_key)),
			"suggestion": "Use remove_autoload first to replace it",
		})

	# Autoload format: "*res://path.gd" (the * prefix means it's a singleton)
	ProjectSettings.set_setting(setting_key, "*" + autoload_path)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"name": autoload_name,
		"path": autoload_path,
		"added": true,
	})


func _remove_autoload(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var autoload_name: String = result[0]

	var setting_key := "autoload/" + autoload_name
	if not ProjectSettings.has_setting(setting_key):
		return error_not_found("Autoload '%s'" % autoload_name)

	var old_value: String = str(ProjectSettings.get_setting(setting_key))
	ProjectSettings.clear(setting_key)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"name": autoload_name,
		"old_path": old_value,
		"removed": true,
	})
