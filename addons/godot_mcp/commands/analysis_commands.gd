@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"find_unused_resources": _find_unused_resources,
		"analyze_signal_flow": _analyze_signal_flow,
		"analyze_scene_complexity": _analyze_scene_complexity,
		"find_script_references": _find_script_references,
		"detect_circular_dependencies": _detect_circular_dependencies,
		"get_project_statistics": _get_project_statistics,
	}


# =============================================================================
# find_unused_resources
# =============================================================================

## Scan project for resources not referenced by any .tscn, .gd, or .tres file.
func _find_unused_resources(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var include_addons: bool = optional_bool(params, "include_addons", false)

	# Step 1: Collect all resource files
	var resource_extensions: Array = ["tres", "tscn", "png", "jpg", "jpeg", "svg",
		"wav", "ogg", "mp3", "ttf", "otf", "gdshader", "material",
		"theme", "stylebox", "font", "anim"]
	var all_resources: Array = []
	_collect_files_by_ext(path, resource_extensions, all_resources, include_addons)

	# Step 2: Collect all referencing files (.tscn, .gd, .tres)
	var ref_extensions: Array = ["tscn", "gd", "tres", "cfg", "godot"]
	var ref_files: Array = []
	_collect_files_by_ext(path, ref_extensions, ref_files, include_addons)

	# Step 3: Build a set of all referenced paths
	var referenced: Dictionary = {}  # path -> true
	for ref_file in ref_files:
		var content := _read_file_text(ref_file as String)
		if content.is_empty():
			continue
		# Find res:// paths in file content
		var idx := 0
		while idx < content.length():
			var found := content.find("res://", idx)
			if found == -1:
				break
			# Extract the path (up to quote, space, or end of line)
			var end := found + 6
			while end < content.length():
				var c := content[end]
				if c == '"' or c == "'" or c == ' ' or c == '\n' or c == '\r' or c == ')' or c == ']' or c == '}':
					break
				end += 1
			var ref_path := content.substr(found, end - found)
			referenced[ref_path] = true
			idx = end

	# Step 4: Find unreferenced resources
	var unused: Array = []
	for res_path in all_resources:
		var p: String = res_path
		if not referenced.has(p):
			# Also check without uid:// prefix variants — some references use uid
			unused.append(p)

	return success({
		"unused_resources": unused,
		"unused_count": unused.size(),
		"total_resources_scanned": all_resources.size(),
		"total_files_checked": ref_files.size(),
	})


# =============================================================================
# analyze_signal_flow
# =============================================================================

## Map all signal connections in the currently edited scene.
func _analyze_signal_flow(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var nodes_data: Array = []
	_collect_signal_data(root, root, nodes_data)

	return success({
		"scene": root.scene_file_path,
		"nodes": nodes_data,
		"total_nodes": nodes_data.size(),
	})


func _collect_signal_data(node: Node, root: Node, out: Array) -> void:
	var node_path := str(root.get_path_to(node))
	var signals_emitted: Array = []
	var signals_connected_to: Array = []

	# Get all signals this node defines
	for sig in node.get_signal_list():
		var sig_name: String = sig["name"]
		var connections := node.get_signal_connection_list(sig_name)
		if connections.size() > 0:
			var targets: Array = []
			for conn in connections:
				var callable: Callable = conn["callable"]
				var target_node: Node = callable.get_object() as Node
				var target_path := ""
				if target_node != null:
					target_path = str(root.get_path_to(target_node))
				targets.append({
					"target_node": target_path,
					"method": callable.get_method(),
				})
				# Also record on the target side
				signals_connected_to.append({
					"from_node": node_path,
					"signal": sig_name,
					"method": callable.get_method(),
				})
			signals_emitted.append({
				"signal": sig_name,
				"targets": targets,
			})

	# Only include nodes that have signal activity
	if signals_emitted.size() > 0 or signals_connected_to.size() > 0:
		out.append({
			"name": node.name,
			"path": node_path,
			"type": node.get_class(),
			"signals_emitted": signals_emitted,
			"signals_connected_to": signals_connected_to,
		})

	for child in node.get_children():
		_collect_signal_data(child, root, out)


# =============================================================================
# analyze_scene_complexity
# =============================================================================

## Analyze a scene's complexity: node count, depth, types, scripts, potential issues.
func _analyze_scene_complexity(params: Dictionary) -> Dictionary:
	var scene_path: String = optional_string(params, "path", "")

	var root: Node = null
	if scene_path.is_empty():
		root = get_edited_root()
		if root == null:
			return error_no_scene()
		scene_path = root.scene_file_path
	else:
		if not ResourceLoader.exists(scene_path):
			return error_not_found("Scene '%s'" % scene_path)
		var packed := ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			return error_internal("Failed to load scene: %s" % scene_path)
		root = packed.instantiate()

	var total_nodes := 0
	var max_depth := 0
	var types: Dictionary = {}  # class_name -> count
	var scripts_attached: Array = []
	var resources_used: Dictionary = {}  # resource path -> count
	var issues: Array = []

	_analyze_node(root, root, 0, total_nodes, max_depth, types, scripts_attached, resources_used)

	# Count totals from recursive walk
	total_nodes = _count_nodes_recursive(root)
	max_depth = _get_max_depth(root, 0)

	# Detect potential issues
	if total_nodes > 1000:
		issues.append({"severity": "warning", "message": "Scene has %d nodes (>1000). Consider splitting into sub-scenes." % total_nodes})
	elif total_nodes > 500:
		issues.append({"severity": "info", "message": "Scene has %d nodes (>500). Monitor performance." % total_nodes})

	if max_depth > 15:
		issues.append({"severity": "warning", "message": "Max nesting depth is %d (>15). Deep hierarchies can be hard to maintain." % max_depth})
	elif max_depth > 10:
		issues.append({"severity": "info", "message": "Max nesting depth is %d (>10)." % max_depth})

	# If we instantiated the scene ourselves, free it
	if not scene_path.is_empty() and root != get_edited_root():
		root.queue_free()

	return success({
		"scene_path": scene_path,
		"total_nodes": total_nodes,
		"max_depth": max_depth,
		"nodes_by_type": types,
		"scripts_attached": scripts_attached,
		"unique_resource_count": resources_used.size(),
		"issues": issues,
	})


func _analyze_node(node: Node, root: Node, depth: int,
		total_nodes: int, max_depth: int,
		types: Dictionary, scripts: Array, resources: Dictionary) -> void:
	var type_name := node.get_class()
	types[type_name] = types.get(type_name, 0) + 1

	if node.get_script() != null:
		var script: Script = node.get_script()
		var script_path := script.resource_path
		if not script_path.is_empty():
			scripts.append({
				"node": str(root.get_path_to(node)),
				"script": script_path,
			})

	for child in node.get_children():
		_analyze_node(child, root, depth + 1, total_nodes, max_depth, types, scripts, resources)


func _count_nodes_recursive(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count


func _get_max_depth(node: Node, current_depth: int) -> int:
	var max_d := current_depth
	for child in node.get_children():
		var child_depth := _get_max_depth(child, current_depth + 1)
		if child_depth > max_d:
			max_d = child_depth
	return max_d


# =============================================================================
# find_script_references
# =============================================================================

## Find all places where a given script, class_name, or resource path is used.
func _find_script_references(params: Dictionary) -> Dictionary:
	var result := require_string(params, "query")
	if result[1] != null:
		return result[1]
	var query: String = result[0]

	var path: String = optional_string(params, "path", "res://")
	var include_addons: bool = optional_bool(params, "include_addons", false)

	var search_extensions: Array = ["tscn", "gd", "tres", "cfg", "godot"]
	var search_files: Array = []
	_collect_files_by_ext(path, search_extensions, search_files, include_addons)

	var references: Array = []
	for file_path in search_files:
		var fp: String = file_path
		var content := _read_file_text(fp)
		if content.is_empty():
			continue

		var lines := content.split("\n")
		var line_num := 0
		for line in lines:
			line_num += 1
			var l: String = line
			if l.contains(query):
				references.append({
					"file": fp,
					"line": line_num,
					"content": l.strip_edges(),
				})

	return success({
		"query": query,
		"references": references,
		"reference_count": references.size(),
		"files_searched": search_files.size(),
	})


# =============================================================================
# detect_circular_dependencies
# =============================================================================

## Check for circular scene dependencies (.tscn files referencing each other).
func _detect_circular_dependencies(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var include_addons: bool = optional_bool(params, "include_addons", false)

	# Step 1: Collect all .tscn files
	var tscn_files: Array = []
	_collect_files_by_ext(path, ["tscn"], tscn_files, include_addons)

	# Step 2: Build dependency graph: scene_path -> [referenced_scene_paths]
	var dep_graph: Dictionary = {}  # String -> Array[String]
	for tscn_path in tscn_files:
		var tp: String = tscn_path
		var content := _read_file_text(tp)
		if content.is_empty():
			continue

		var deps: Array = []
		for line in content.split("\n"):
			var l: String = line
			# Match [ext_resource ... path="res://..." ...] lines that reference .tscn
			if l.begins_with("[ext_resource") and ".tscn" in l:
				var path_start := l.find('path="')
				if path_start == -1:
					continue
				path_start += 6  # len('path="')
				var path_end := l.find('"', path_start)
				if path_end == -1:
					continue
				var ref_path := l.substr(path_start, path_end - path_start)
				if ref_path.ends_with(".tscn"):
					deps.append(ref_path)
		dep_graph[tp] = deps

	# Step 3: Detect cycles using DFS
	var cycles: Array = []
	var visited: Dictionary = {}  # path -> "unvisited" | "visiting" | "visited"
	for scene in dep_graph:
		visited[scene] = "unvisited"

	for scene in dep_graph:
		if visited[scene] == "unvisited":
			var path_stack: Array = []
			_dfs_detect_cycle(scene as String, dep_graph, visited, path_stack, cycles)

	return success({
		"scenes_checked": tscn_files.size(),
		"circular_dependencies": cycles,
		"has_circular": cycles.size() > 0,
		"dependency_graph": dep_graph,
	})


func _dfs_detect_cycle(node: String, graph: Dictionary, visited: Dictionary,
		path_stack: Array, cycles: Array) -> void:
	visited[node] = "visiting"
	path_stack.append(node)

	if graph.has(node):
		var deps: Array = graph[node]
		for dep in deps:
			var d: String = dep
			if not visited.has(d):
				# Scene referenced but not in our graph (might not exist or outside scope)
				continue
			if visited[d] == "visiting":
				# Found a cycle — extract it from the stack
				var cycle_start := path_stack.find(d)
				var cycle: Array = path_stack.slice(cycle_start)
				cycle.append(d)  # Close the cycle
				cycles.append(cycle)
			elif visited[d] == "unvisited":
				_dfs_detect_cycle(d, graph, visited, path_stack, cycles)

	path_stack.pop_back()
	visited[node] = "visited"


# =============================================================================
# get_project_statistics
# =============================================================================

## Overall project stats: file counts, script lines, scenes, resources, autoloads, plugins.
func _get_project_statistics(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var include_addons: bool = optional_bool(params, "include_addons", false)

	var file_counts: Dictionary = {}  # extension -> count
	var total_script_lines := 0
	var scene_count := 0
	var resource_count := 0
	var total_files := 0

	_collect_statistics(path, include_addons, file_counts)

	# Extract internal counters and remove them from the visible dict
	total_script_lines = int(file_counts.get("_total_script_lines", 0))
	scene_count = int(file_counts.get("_scene_count", 0))
	resource_count = int(file_counts.get("_resource_count", 0))
	total_files = int(file_counts.get("_total_files", 0))
	file_counts.erase("_total_script_lines")
	file_counts.erase("_scene_count")
	file_counts.erase("_resource_count")
	file_counts.erase("_total_files")

	# Autoloads
	var autoloads: Dictionary = {}
	for prop in ProjectSettings.get_property_list():
		var prop_name: String = prop["name"]
		if prop_name.begins_with("autoload/"):
			autoloads[prop_name.substr(9)] = str(ProjectSettings.get_setting(prop_name))

	# Enabled plugins
	var plugins: Array = []
	var plugin_cfg_path := "res://addons"
	var enabled_plugins: PackedStringArray = ProjectSettings.get_setting(
		"editor_plugins/enabled", PackedStringArray()
	)
	var plugin_dir := DirAccess.open(plugin_cfg_path)
	if plugin_dir != null:
		plugin_dir.list_dir_begin()
		var dir_name := plugin_dir.get_next()
		while not dir_name.is_empty():
			if plugin_dir.current_is_dir() and not dir_name.begins_with("."):
				var cfg_path := plugin_cfg_path.path_join(dir_name).path_join("plugin.cfg")
				if FileAccess.file_exists(cfg_path):
					var plugin_path := "res://addons/%s/plugin.cfg" % dir_name
					plugins.append({
						"name": dir_name,
						"enabled": plugin_path in enabled_plugins,
					})
			dir_name = plugin_dir.get_next()
		plugin_dir.list_dir_end()

	return success({
		"file_counts_by_extension": file_counts,
		"total_files": total_files,
		"total_script_lines": total_script_lines,
		"scene_count": scene_count,
		"resource_count": resource_count,
		"autoloads": autoloads,
		"plugins": plugins,
	})


func _collect_statistics(path: String, include_addons: bool,
		file_counts: Dictionary) -> void:
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
			if file_name == "addons" and not include_addons:
				file_name = dir.get_next()
				continue
			_collect_statistics(full_path, include_addons, file_counts)
		else:
			var ext := file_name.get_extension().to_lower()
			file_counts[ext] = file_counts.get(ext, 0) + 1

			if ext == "gd":
				var content := _read_file_text(full_path)
				var line_count := content.count("\n") + 1 if not content.is_empty() else 0
				# We can't modify int params, so we store in the dict
				file_counts["_total_script_lines"] = file_counts.get("_total_script_lines", 0) + line_count

			if ext == "tscn":
				file_counts["_scene_count"] = file_counts.get("_scene_count", 0) + 1

			if ext in ["tres", "material", "theme", "stylebox", "font"]:
				file_counts["_resource_count"] = file_counts.get("_resource_count", 0) + 1

			file_counts["_total_files"] = file_counts.get("_total_files", 0) + 1

		file_name = dir.get_next()

	dir.list_dir_end()


# =============================================================================
# Shared helpers
# =============================================================================

## Recursively collect files matching given extensions.
func _collect_files_by_ext(path: String, extensions: Array, out: Array, include_addons: bool) -> void:
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
			if file_name == "addons" and not include_addons:
				file_name = dir.get_next()
				continue
			_collect_files_by_ext(full_path, extensions, out, include_addons)
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in extensions:
				out.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## Read a file's text content. Returns empty string on failure.
func _read_file_text(file_path: String) -> String:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content
