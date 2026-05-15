@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")


func get_commands() -> Dictionary:
	return {
		"find_nodes_by_type": _find_nodes_by_type,
		"find_signal_connections": _find_signal_connections,
		"batch_set_property": _batch_set_property,
		"batch_add_nodes": _batch_add_nodes,
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
	var changes: Array = []
	_batch_collect_property_changes(root, root, type_name, property, value, affected, changes)
	if not changes.is_empty():
		_apply_property_changes_with_undo(changes, property, "MCP: Batch set %s" % property)

	return success({"property": property, "affected": affected, "count": affected.size()})


func _batch_collect_property_changes(node: Node, root: Node, type_name: String, property: String, value: Variant, affected: Array, changes: Array) -> void:
	if node.is_class(type_name) or node.get_class() == type_name:
		if property in node:
			affected.append(str(root.get_path_to(node)))
			changes.append({
				"node": node,
				"old_value": node.get(property),
				"new_value": value,
			})
	for child in node.get_children():
		_batch_collect_property_changes(child, root, type_name, property, value, affected, changes)


func _batch_add_nodes(params: Dictionary) -> Dictionary:
	if not params.has("nodes") or not params["nodes"] is Array:
		return error_invalid_params("Missing required parameter: nodes (Array)")

	var nodes_data: Array = params["nodes"]
	if nodes_data.is_empty():
		return error_invalid_params("nodes array is empty")

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var created: Array = []
	var errors: Array = []

	for i: int in nodes_data.size():
		var entry: Dictionary = nodes_data[i]

		if not entry.has("type") or not entry["type"] is String:
			errors.append({"index": i, "error": "Missing or invalid 'type'"})
			continue

		var type: String = entry["type"]
		if not ClassDB.class_exists(type):
			errors.append({"index": i, "error": "Unknown node type: %s" % type})
			continue

		var parent_path: String = entry.get("parent_path", ".") if entry.has("parent_path") and entry["parent_path"] is String else "."
		var node_name: String = entry.get("name", "") if entry.has("name") and entry["name"] is String else ""
		var properties: Dictionary = entry.get("properties", {}) if entry.has("properties") and entry["properties"] is Dictionary else {}

		var parent := find_node_by_path(parent_path)
		if parent == null:
			errors.append({"index": i, "error": "Parent node '%s' not found" % parent_path})
			continue

		var node: Node = ClassDB.instantiate(type)
		if not node_name.is_empty():
			node.name = node_name

		for prop_name: String in properties:
			var prop_exists := false
			for prop in node.get_property_list():
				if prop["name"] == prop_name:
					prop_exists = true
					break
			if prop_exists:
				var current: Variant = node.get(prop_name)
				var target_type := typeof(current)
				node.set(prop_name, PropertyParser.parse_value(properties[prop_name], target_type))

		add_child_with_undo(parent, node, root, "MCP: Batch add %s" % type)

		created.append({
			"index": i,
			"type": type,
			"name": str(node.name),
			"parent": parent_path,
			"node_path": str(root.get_path_to(node)),
		})

	var result := {"created": created, "count": created.size()}
	if not errors.is_empty():
		result["errors"] = errors
	return success(result)


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
	var force: bool = optional_bool(params, "force", false)
	var dry_run: bool = optional_bool(params, "dry_run", not force)
	if not dry_run and not force:
		return error_invalid_params("cross_scene_set_property requires force=true when dry_run=false")

	var scenes_affected: Array = []
	var skipped_open_scenes: Array = []
	var total_nodes: int = 0
	var scene_files: Array = []
	_collect_scene_files(path_filter, scene_files, exclude_addons)

	for scene_path: String in scene_files:
		var normalized_scene_path := normalize_project_path(scene_path)

		if is_scene_path_open(normalized_scene_path):
			if is_active_scene_path(normalized_scene_path) and force and not dry_run:
				var root := get_edited_root()
				var live_changes: Array = []
				var live_affected_nodes: Array = []
				_cross_scene_collect_changes(root, root, type_name, property, value, live_affected_nodes, live_changes)
				if not live_changes.is_empty():
					_apply_property_changes_with_undo(live_changes, property, "MCP: Cross-scene set %s" % property)
					scenes_affected.append({
						"scene": normalized_scene_path,
						"nodes": live_affected_nodes,
						"count": live_affected_nodes.size(),
						"mode": "live_open_scene",
					})
					total_nodes += live_affected_nodes.size()
			else:
				var reason := "open scene skipped during dry_run" if dry_run else "open scene is not the active editor scene"
				skipped_open_scenes.append({"scene": normalized_scene_path, "reason": reason})
			continue

		var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		if instance == null:
			continue

		var affected_nodes: Array = []
		var changes: Array = []
		_cross_scene_collect_changes(instance, instance, type_name, property, value, affected_nodes, changes)

		if not changes.is_empty():
			if not dry_run:
				var guard := guard_offline_scene_save(normalized_scene_path)
				if guard != null:
					instance.free()
					return guard
				for change: Dictionary in changes:
					(change["node"] as Node).set(property, value)
			# Pack and save
				var new_packed := PackedScene.new()
				var pack_err := new_packed.pack(instance)
				if pack_err != OK:
					instance.free()
					return error_internal("Failed to pack scene '%s': %s" % [normalized_scene_path, error_string(pack_err)])
				var save_err := ResourceSaver.save(new_packed, normalized_scene_path)
				if save_err != OK:
					instance.free()
					return error_internal("Failed to save scene '%s': %s" % [normalized_scene_path, error_string(save_err)])
			scenes_affected.append({
				"scene": normalized_scene_path,
				"nodes": affected_nodes,
				"count": affected_nodes.size(),
				"mode": "dry_run" if dry_run else "offline_saved",
			})
			total_nodes += affected_nodes.size()

		instance.free()

	# Rescan filesystem so editor picks up changes
	if not scenes_affected.is_empty():
		get_editor().get_resource_filesystem().scan()

	return success({
		"type": type_name,
		"property": property,
		"dry_run": dry_run,
		"force": force,
		"scenes_affected": scenes_affected,
		"skipped_open_scenes": skipped_open_scenes,
		"total_scenes": scenes_affected.size(),
		"total_nodes": total_nodes,
		"message": "Dry run only. Re-run with force=true and dry_run=false to write closed scenes and live-edit the active open scene." if dry_run else "Changes applied.",
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


func _cross_scene_collect_changes(node: Node, root: Node, type_name: String, property: String, value: Variant, affected: Array, changes: Array) -> void:
	if node.is_class(type_name) or node.get_class() == type_name:
		if property in node:
			affected.append(str(root.get_path_to(node)))
			changes.append({
				"node": node,
				"old_value": node.get(property),
				"new_value": value,
			})
	for child in node.get_children():
		_cross_scene_collect_changes(child, root, type_name, property, value, affected, changes)


func _apply_property_changes_with_undo(changes: Array, property: String, action_name: String) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	for change: Dictionary in changes:
		var node: Node = change["node"]
		undo_redo.add_do_property(node, property, change["new_value"])
		undo_redo.add_undo_property(node, property, change["old_value"])
	undo_redo.commit_action()


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
