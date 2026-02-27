@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"find_nodes_by_type": _find_nodes_by_type,
		"find_signal_connections": _find_signal_connections,
		"batch_set_property": _batch_set_property,
		"find_node_references": _find_node_references,
		"get_scene_dependencies": _get_scene_dependencies,
		"cross_scene_set_property": _cross_scene_set_property,
	}


func _find_nodes_by_type(params: Dictionary) -> Dictionary:
	var result := require_string(params, "type")
	if result[1] != null:
		return result[1]
	var type_name: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var recursive: bool = optional_bool(params, "recursive", true)
	var matches: Array = []
	_search_by_type(root, type_name, recursive, matches)

	return success({"type": type_name, "matches": matches, "count": matches.size()})


func _search_by_type(node: Node, type_name: String, recursive: bool, matches: Array) -> void:
	if node.is_class(type_name) or node.get_class() == type_name:
		var root := get_edited_root()
		matches.append({
			"name": node.name,
			"path": str(root.get_path_to(node)),
			"type": node.get_class(),
		})
	if recursive:
		for child in node.get_children():
			_search_by_type(child, type_name, recursive, matches)


func _find_signal_connections(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var signal_filter: String = optional_string(params, "signal_name", "")
	var node_filter: String = optional_string(params, "node_path", "")

	var connections: Array = []
	_collect_signals(root, root, signal_filter, node_filter, connections)

	return success({"connections": connections, "count": connections.size()})


func _collect_signals(node: Node, root: Node, signal_filter: String, node_filter: String, connections: Array) -> void:
	var node_path := str(root.get_path_to(node))

	if node_filter.is_empty() or node_path.contains(node_filter):
		for sig_info in node.get_signal_list():
			var sig_name: String = sig_info["name"]
			if not signal_filter.is_empty() and not sig_name.contains(signal_filter):
				continue
			for conn in node.get_signal_connection_list(sig_name):
				connections.append({
					"source": node_path,
					"signal": sig_name,
					"target": str(root.get_path_to(conn["callable"].get_object())),
					"method": conn["callable"].get_method(),
				})

	for child in node.get_children():
		_collect_signals(child, root, signal_filter, node_filter, connections)


func _batch_set_property(params: Dictionary) -> Dictionary:
	var result := require_string(params, "type")
	if result[1] != null:
		return result[1]
	var type_name: String = result[0]

	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var property: String = result2[0]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")
	var value = params["value"]

	# Parse value string
	if value is String:
		var s: String = value
		var expr := Expression.new()
		if expr.parse(s) == OK:
			var parsed = expr.execute()
			if parsed != null:
				value = parsed

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var affected: Array = []
	_batch_set_recursive(root, root, type_name, property, value, affected)

	return success({"property": property, "affected": affected, "count": affected.size()})


func _batch_set_recursive(node: Node, root: Node, type_name: String, property: String, value: Variant, affected: Array) -> void:
	if node.is_class(type_name) or node.get_class() == type_name:
		if property in node:
			node.set(property, value)
			affected.append(str(root.get_path_to(node)))
	for child in node.get_children():
		_batch_set_recursive(child, root, type_name, property, value, affected)


func _find_node_references(params: Dictionary) -> Dictionary:
	var result := require_string(params, "pattern")
	if result[1] != null:
		return result[1]
	var pattern: String = result[0]

	# Search through all .tscn and .gd files for references
	var matches: Array = []
	_search_files_for_pattern("res://", pattern, matches, 100)

	return success({"pattern": pattern, "matches": matches, "count": matches.size()})


func _search_files_for_pattern(path: String, pattern: String, matches: Array, max_results: int) -> void:
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
			_search_files_for_pattern(full_path, pattern, matches, max_results)
		elif file_name.get_extension() in ["tscn", "gd", "tres", "gdshader"]:
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				if content.contains(pattern):
					# Find line numbers
					var lines := content.split("\n")
					var line_matches: Array = []
					for i in lines.size():
						if lines[i].contains(pattern):
							line_matches.append(i + 1)
							if line_matches.size() >= 5:
								break
					matches.append({
						"file": full_path,
						"lines": line_matches,
					})

		file_name = dir.get_next()
	dir.list_dir_end()


func _cross_scene_set_property(params: Dictionary) -> Dictionary:
	var result := require_string(params, "type")
	if result[1] != null:
		return result[1]
	var type_name: String = result[0]

	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var property: String = result2[0]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")
	var value = params["value"]

	# Parse value string
	if value is String:
		var expr := Expression.new()
		if expr.parse(value) == OK:
			var parsed = expr.execute()
			if parsed != null:
				value = parsed

	var path_filter: String = optional_string(params, "path_filter", "res://")
	var exclude_addons: bool = optional_bool(params, "exclude_addons", true)

	var scenes_affected: Array = []
	var total_nodes: int = 0
	var scene_files: Array = []
	_collect_scene_files(path_filter, scene_files, exclude_addons)

	for scene_path: String in scene_files:
		var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		if instance == null:
			continue

		var affected_nodes: Array = []
		_cross_scene_set_recursive(instance, instance, type_name, property, value, affected_nodes)

		if not affected_nodes.is_empty():
			# Pack and save
			var new_packed := PackedScene.new()
			new_packed.pack(instance)
			ResourceSaver.save(new_packed, scene_path)
			scenes_affected.append({
				"scene": scene_path,
				"nodes": affected_nodes,
				"count": affected_nodes.size(),
			})
			total_nodes += affected_nodes.size()

		instance.free()

	# Rescan filesystem so editor picks up changes
	if not scenes_affected.is_empty():
		get_editor().get_resource_filesystem().scan()

	return success({
		"type": type_name,
		"property": property,
		"scenes_affected": scenes_affected,
		"total_scenes": scenes_affected.size(),
		"total_nodes": total_nodes,
	})


func _collect_scene_files(path: String, files: Array, exclude_addons: bool) -> void:
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
			if exclude_addons and file_name == "addons":
				file_name = dir.get_next()
				continue
			_collect_scene_files(full_path, files, exclude_addons)
		elif file_name.get_extension() == "tscn":
			files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _cross_scene_set_recursive(node: Node, root: Node, type_name: String, property: String, value: Variant, affected: Array) -> void:
	if node.is_class(type_name) or node.get_class() == type_name:
		if property in node:
			node.set(property, value)
			affected.append(str(root.get_path_to(node)))
	for child in node.get_children():
		_cross_scene_set_recursive(child, root, type_name, property, value, affected)


func _get_scene_dependencies(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("File '%s'" % path)

	var deps := ResourceLoader.get_dependencies(path)
	var dependencies: Array = []
	for dep: String in deps:
		# Format: "path::type"
		var parts := dep.split("::")
		dependencies.append({
			"path": parts[0] if parts.size() > 0 else dep,
			"type": parts[2] if parts.size() > 2 else "",
		})

	return success({"path": path, "dependencies": dependencies, "count": dependencies.size()})
