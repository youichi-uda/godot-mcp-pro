@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_editor_errors": _get_editor_errors,
		"get_output_log": _get_output_log,
		"get_editor_screenshot": _get_editor_screenshot,
		"get_game_screenshot": _get_game_screenshot,
		"execute_editor_script": _execute_editor_script,
		"clear_output": _clear_output,
		"reload_plugin": _reload_plugin,
		"reload_project": _reload_project,
		"get_signals": _get_signals,
		"compare_screenshots": _compare_screenshots,
		"set_auto_dismiss": _set_auto_dismiss,
		"get_editor_camera": _get_editor_camera,
		"set_editor_camera": _set_editor_camera,
		"get_unsaved_state": _get_unsaved_state,
		"save_all": _save_all,
	}


func _get_editor_errors(params: Dictionary) -> Dictionary:
	var errors: Array = []
	var max_lines: int = optional_int(params, "max_lines", 50)
	var base: Control = get_editor().get_base_control()

	# 1. Read from the editor's Output panel (EditorLog RichTextLabel)
	#    This captures runtime errors, warnings, and print output
	var editor_log: Node = base.find_child("Output", true, false)
	if editor_log:
		var rtl: RichTextLabel = _find_rtl(editor_log)
		if rtl:
			var content: String = rtl.get_parsed_text()
			var lines: PackedStringArray = content.split("\n")
			var start: int = maxi(0, lines.size() - max_lines)
			for i in range(start, lines.size()):
				var line: String = lines[i]
				if line.contains("ERROR") or line.contains("SCRIPT ERROR") or line.contains("Parse Error") or line.contains("WARNING"):
					errors.append(line.strip_edges())

	# 2. (Removed.) Earlier versions inferred "compile errors" from lines with a
	#    red-ish background in the first CodeEdit found under the ScriptEditor.
	#    That paired the focused tab's path with another tab's line numbers and
	#    text, and flagged warning highlights as errors (issue #40). Step 3 reads
	#    the analyzer panels of every open editor, which is the real source.
	var script_errors: Array = []
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()

	# 3. Read from script editor error/warning panels (GDScript analyzer messages)
	#    Each open script editor has a VSplitContainer with two RichTextLabels:
	#    child[1] = warnings panel, child[2] = errors panel
	var analyzer_errors: Array = []
	if script_editor:
		# Paired through get_open_script_editor_pairs(): pairing the raw arrays
		# by index attributed messages to the wrong file after a text tab.
		for pair: Dictionary in get_open_script_editor_pairs():
			var editor_node: Node = pair["editor"]
			var script_path: String = pair["path"]
			var vsplit: VSplitContainer = null
			for c in editor_node.get_children():
				if c is VSplitContainer:
					vsplit = c as VSplitContainer
					break
			if vsplit == null:
				continue
			var children: Array = vsplit.get_children()
			# child[1] = warnings panel (RichTextLabel)
			if children.size() > 1 and children[1] is RichTextLabel:
				var text: String = (children[1] as RichTextLabel).get_parsed_text().strip_edges()
				if not text.is_empty():
					for line in text.split("\n"):
						var stripped: String = line.strip_edges()
						if stripped.is_empty() or stripped == "[Ignore]":
							continue
						# Remove leading "[Ignore]" prefix from warning lines
						stripped = stripped.trim_prefix("[Ignore]")
						var prefix: String = "WARNING: %s:" % script_path if not script_path.is_empty() else "WARNING: "
						analyzer_errors.append(prefix + stripped)
			# child[2] = errors panel (RichTextLabel)
			if children.size() > 2 and children[2] is RichTextLabel:
				var text: String = (children[2] as RichTextLabel).get_parsed_text().strip_edges()
				if not text.is_empty():
					for line in text.split("\n"):
						var stripped: String = line.strip_edges()
						if stripped.is_empty():
							continue
						var prefix: String = "SCRIPT ERROR: %s:" % script_path if not script_path.is_empty() else "SCRIPT ERROR: "
						analyzer_errors.append(prefix + stripped)

	# 4. Read from the debugger Errors tab (runtime errors/warnings)
	#    Path: ScriptEditorDebugger > TabContainer > "Errors" VBoxContainer > Tree
	var debugger_errors: Array = []
	var base2: Control = get_editor().get_base_control()
	if base2:
		var queue: Array[Node] = [base2]
		while not queue.is_empty():
			var node := queue.pop_front()
			if node.get_class() == "ScriptEditorDebugger":
				# Find TabContainer inside the debugger
				for child in node.get_children():
					if child is TabContainer:
						var tab_container := child as TabContainer
						for tab_idx in range(tab_container.get_tab_count()):
							var tab_control: Control = tab_container.get_tab_control(tab_idx)
							if tab_control is VBoxContainer and tab_control.name.begins_with("Errors"):
								# Find Tree inside the Errors tab
								for vchild in tab_control.get_children():
									if vchild is Tree:
										var tree := vchild as Tree
										var root_item: TreeItem = tree.get_root()
										if root_item:
											var item: TreeItem = root_item.get_first_child()
											while item:
												var col0: String = item.get_text(0).strip_edges()
												var col1: String = item.get_text(1).strip_edges()
												if not col0.is_empty() or not col1.is_empty():
													var msg: String = col0
													if not col1.is_empty():
														msg += " " + col1 if not msg.is_empty() else col1
													debugger_errors.append("DEBUGGER: " + msg)
												# Also check child items (expanded error details)
												var sub: TreeItem = item.get_first_child()
												while sub:
													var sub0: String = sub.get_text(0).strip_edges()
													var sub1: String = sub.get_text(1).strip_edges()
													if not sub0.is_empty() or not sub1.is_empty():
														var sub_msg: String = sub0
														if not sub1.is_empty():
															sub_msg += " " + sub1 if not sub_msg.is_empty() else sub1
														debugger_errors.append("DEBUGGER:   " + sub_msg)
													sub = sub.get_next()
												item = item.get_next()
								break  # Found Errors tab, stop searching tabs
						break  # Found TabContainer, stop searching debugger children
				break  # Found ScriptEditorDebugger, stop BFS
			for child in node.get_children():
				queue.append(child)

	# Fallback: read from log file if Output panel not accessible
	if errors.size() == 0 and script_errors.size() == 0 and analyzer_errors.size() == 0 and debugger_errors.size() == 0:
		var log_path := "user://logs/godot.log"
		if FileAccess.file_exists(log_path):
			var file := FileAccess.open(log_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var lines := content.split("\n")
				var start: int = maxi(0, lines.size() - max_lines)
				for i in range(start, lines.size()):
					var line: String = lines[i]
					if line.contains("ERROR") or line.contains("SCRIPT ERROR"):
						errors.append(line.strip_edges())

	errors.append_array(script_errors)
	errors.append_array(analyzer_errors)
	errors.append_array(debugger_errors)
	return success({"errors": errors, "count": errors.size()})


func _get_output_log(params: Dictionary) -> Dictionary:
	var max_lines: int = optional_int(params, "max_lines", 100)
	var filter: String = optional_string(params, "filter", "")
	var base: Control = get_editor().get_base_control()

	var editor_log: Node = base.find_child("Output", true, false)
	if editor_log == null:
		# Fallback: read from log file
		var log_path := "user://logs/godot.log"
		if not FileAccess.file_exists(log_path):
			return error_internal("Output panel not found and no log file available")
		var file := FileAccess.open(log_path, FileAccess.READ)
		if file == null:
			return error_internal("Cannot read log file")
		var content := file.get_as_text()
		file.close()
		var lines := content.split("\n")
		var start: int = maxi(0, lines.size() - max_lines)
		var output_lines: Array = []
		for i in range(start, lines.size()):
			var line: String = lines[i]
			if filter.is_empty() or line.contains(filter):
				output_lines.append(line)
		return success({"lines": output_lines, "count": output_lines.size(), "source": "log_file"})

	var rtl: RichTextLabel = _find_rtl(editor_log)
	if rtl == null:
		return error_internal("Could not find RichTextLabel in Output panel")

	var content: String = rtl.get_parsed_text()
	var all_lines: PackedStringArray = content.split("\n")
	var start: int = maxi(0, all_lines.size() - max_lines)
	var output_lines: Array = []
	for i in range(start, all_lines.size()):
		var line: String = all_lines[i]
		if filter.is_empty() or line.contains(filter):
			output_lines.append(line)

	return success({"lines": output_lines, "count": output_lines.size(), "source": "output_panel"})


func _find_rtl(node: Node, depth: int = 0) -> RichTextLabel:
	if depth > 6:
		return null
	if node is RichTextLabel:
		return node as RichTextLabel
	for child in node.get_children():
		var found: RichTextLabel = _find_rtl(child, depth + 1)
		if found:
			return found
	return null


func _get_editor_screenshot(params: Dictionary) -> Dictionary:
	# Capture the editor's main viewport - no await to avoid timeout
	var base_control: Control = get_editor().get_base_control()
	if base_control == null:
		return error_internal("Could not access editor base control")

	var viewport: Viewport = base_control.get_viewport()
	if viewport == null:
		return error_internal("Could not access editor viewport")

	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		return error_internal("Could not get viewport texture")

	var image: Image = texture.get_image()
	if image == null:
		return error_internal("Could not get image from viewport")

	var save_path: String = params.get("save_path", "")
	if save_path != "":
		var abs_path := _resolve_save_path(save_path)
		var err := image.save_png(abs_path)
		if err != OK:
			return error_internal("Failed to save screenshot: %s" % error_string(err))
		return success({
			"saved_path": save_path,
			"width": image.get_width(),
			"height": image.get_height(),
			"format": "png",
		})

	var png_buffer := image.save_png_to_buffer()
	var base64 := Marshalls.raw_to_base64(png_buffer)

	return success({
		"image_base64": base64,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": "png",
	})


func _get_game_screenshot(params: Dictionary) -> Dictionary:
	var ei := get_editor()
	if not ei.is_playing_scene():
		return error(-32000, "No scene is currently playing", {"suggestion": "Use play_scene first"})

	# Communicate with the game process via file system
	var user_dir := get_game_user_dir()
	var request_path := user_dir + "/mcp_screenshot_request"
	var screenshot_path := user_dir + "/mcp_screenshot.png"

	# Clean up any stale screenshot file
	if FileAccess.file_exists(screenshot_path):
		DirAccess.remove_absolute(screenshot_path)

	# Create the request file to signal the game process
	# The game only checks that the file exists; the content names the
	# requesting editor so cleanup elsewhere leaves it alone.
	if write_file_atomic(request_path, JSON.stringify({"editor_pid": OS.get_process_id()})) != OK:
		return error_internal("Could not create screenshot request file")

	# Poll for the screenshot file (max 3 seconds, 0.1s interval)
	var attempts := 30
	while attempts > 0:
		await get_tree().create_timer(0.1).timeout
		if FileAccess.file_exists(screenshot_path):
			break
		attempts -= 1

	if not FileAccess.file_exists(screenshot_path):
		# Clean up request file if it still exists
		if FileAccess.file_exists(request_path):
			DirAccess.remove_absolute(request_path)
		return error(-32000, "Screenshot timed out", {
			"suggestion": "Ensure the game is running and MCPScreenshot autoload is active",
		})

	# Load the PNG file
	var image := Image.new()
	var err := image.load(screenshot_path)
	if err != OK:
		DirAccess.remove_absolute(screenshot_path)
		return error_internal("Failed to load screenshot: %s" % error_string(err))

	# Clean up temp file
	DirAccess.remove_absolute(screenshot_path)

	var save_path_param: String = params.get("save_path", "")
	if save_path_param != "":
		var abs_path := _resolve_save_path(save_path_param)
		var save_err := image.save_png(abs_path)
		if save_err != OK:
			return error_internal("Failed to save screenshot: %s" % error_string(save_err))
		return success({
			"saved_path": save_path_param,
			"width": image.get_width(),
			"height": image.get_height(),
			"format": "png",
		})

	var png_buffer := image.save_png_to_buffer()
	var base64 := Marshalls.raw_to_base64(png_buffer)

	return success({
		"image_base64": base64,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": "png",
	})


func _resolve_save_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _execute_editor_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "code")
	if result[1] != null:
		return result[1]
	var code: String = result[0]
	var allow_unsafe_editor_io: bool = optional_bool(params, "allow_unsafe_editor_io", false)
	var unsafe_guard := _guard_editor_script_file_io(code, allow_unsafe_editor_io)
	if not unsafe_guard.is_empty():
		return unsafe_guard

	# Wrap user code in a @tool script.
	# The wrapper returns a sentinel rather than _mcp_output, so a caller that
	# never returns anything of its own does not get the printed output echoed
	# back a second time as an escaped string in return_value.
	var wrapped_code := """@tool
extends Node

var _mcp_output: Array = []
# Read back through `self` below, so a same-named local in the caller's code
# cannot shadow it.
var _mcp_sentinel := RefCounted.new()

func _mcp_print(value: Variant) -> void:
	_mcp_output.append(str(value))

func run() -> Variant:
	# User code begins
%s
	# User code ends
	return self._mcp_sentinel
""" % _indent_code(code)

	# Create a temporary script
	var script := GDScript.new()
	script.source_code = wrapped_code
	var err := script.reload()

	if err != OK:
		return error(-32002, "Script compilation failed", {
			"error": error_string(err),
			"code": wrapped_code,
		})

	# Create temp node and execute
	var temp_node := Node.new()
	temp_node.set_script(script)
	add_child(temp_node)

	var output: Variant = null

	# Execute with error handling
	if temp_node.has_method("run"):
		output = temp_node.run()

	# The script may have torn the plugin down (restart_editor, disabling the
	# plugin, reload_project): this command object and temp_node are then
	# already freed, and touching them only raises "previously freed" errors.
	if not is_instance_valid(self):
		return {}
	if not is_instance_valid(temp_node) or not is_inside_tree():
		return success({"output": [], "note": "The script shut the plugin down (for example restart_editor), so no output could be collected."})

	var mcp_output: Array = []
	var raw_output: Variant = temp_node.get("_mcp_output")
	if raw_output is Array:
		mcp_output = raw_output

	# Read the sentinel before freeing the node that owns it.
	var sentinel: Variant = temp_node.get("_mcp_sentinel")

	# Cleanup
	temp_node.queue_free()

	# Suppress only the sentinel. An explicit `return null` from the caller's
	# code is a real return value and stays distinguishable from no return.
	# The sentinel is an object identity rather than a magic string, because
	# any string a caller might return is a legitimate result.
	var payload := {"output": mcp_output}
	if not (output is RefCounted and output == sentinel):
		payload["return_value"] = str(output) if output != null else null
	return success(payload)


func _guard_editor_script_file_io(code: String, allow_unsafe_editor_io: bool) -> Dictionary:
	if allow_unsafe_editor_io:
		return {}
	var compact := code.replace(" ", "").replace("\t", "").replace("\n", "")
	var unsafe_patterns: Array[String] = []
	if compact.contains("ResourceSaver.save("):
		unsafe_patterns.append("ResourceSaver.save")
	if compact.contains("ProjectSettings.save("):
		unsafe_patterns.append("ProjectSettings.save")
	if compact.contains("ConfigFile.save("):
		unsafe_patterns.append("ConfigFile.save")
	if compact.contains("FileAccess.open(") and _contains_any(compact, ["FileAccess.WRITE", "FileAccess.READ_WRITE", "FileAccess.WRITE_READ"]):
		unsafe_patterns.append("FileAccess.open WRITE")
	if _contains_any(compact, ["DirAccess.remove_absolute(", "DirAccess.rename_absolute(", "DirAccess.copy_absolute(", "DirAccess.make_dir_absolute(", "DirAccess.make_dir_recursive_absolute("]):
		unsafe_patterns.append("DirAccess filesystem mutation")
	if unsafe_patterns.is_empty():
		return {}
	return error_conflict(
		"Refusing to execute editor script with direct file/resource write APIs",
		{
			"unsafe_patterns": unsafe_patterns,
			"open_scenes": get_open_scene_paths(),
			"suggestion": "Use dedicated MCP commands and save_scene for editor-owned resources, or pass allow_unsafe_editor_io=true only when no open editor resource can be overwritten.",
			"note": "This is a text match on the submitted source, meant to catch accidents. It is not a security boundary: a dynamically built call, or a destructive API not on the list, is not caught.",
		}
	)


func _contains_any(value: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if value.contains(needle):
			return true
	return false


func _indent_code(code: String) -> String:
	var lines := code.split("\n")
	var indented: PackedStringArray = []
	for line in lines:
		indented.append("\t" + line)
	return "\n".join(indented)


func _clear_output(params: Dictionary) -> Dictionary:
	print("\n".repeat(50))
	return success({"cleared": true})


func _reload_plugin(params: Dictionary) -> Dictionary:
	# Disable and re-enable this plugin to reload all scripts
	var plugin_name := "godot_mcp"
	var ei := get_editor()

	# Send success BEFORE reloading (connection will briefly drop)
	# Use call_deferred so the response is sent first
	_deferred_reload_plugin.call_deferred(ei, plugin_name)
	return success({"reloading": true, "message": "Plugin will reload momentarily. Connection will briefly drop and auto-reconnect."})


func _deferred_reload_plugin(ei: EditorInterface, plugin_name: String) -> void:
	ei.set_plugin_enabled(plugin_name, false)
	ei.set_plugin_enabled(plugin_name, true)
	print("[MCP] Plugin reloaded")


func _reload_project(params: Dictionary) -> Dictionary:
	# Rescan filesystem and reload changed scripts
	var ei := get_editor()
	ei.get_resource_filesystem().scan()

	return success({"reloaded": true, "message": "Filesystem rescanned."})


func _get_signals(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path)

	var signals: Array = []
	for sig in node.get_signal_list():
		var sig_info: Dictionary = {
			"name": sig["name"],
			"args": [],
		}
		for arg in sig["args"]:
			sig_info["args"].append({"name": arg["name"], "type": arg["type"]})

		# Get connections for this signal
		var connections: Array = []
		for conn in node.get_signal_connection_list(sig["name"]):
			connections.append({
				"target": str(root.get_path_to(conn["callable"].get_object())),
				"method": conn["callable"].get_method(),
			})
		sig_info["connections"] = connections
		signals.append(sig_info)

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"signals": signals,
		"count": signals.size(),
	})


func _load_image_from_param(value: String, label: String) -> Array:
	## Returns [Image, null] on success or [null, error_dict] on failure.
	## Accepts a file path (res://, user://) or raw base64 PNG data.
	var img := Image.new()
	if value.begins_with("res://") or value.begins_with("user://"):
		var err := img.load(value)
		if err != OK:
			return [null, error_invalid_params("Failed to load %s from path '%s': %s" % [label, value, error_string(err)])]
		return [img, null]
	# Treat as base64 PNG
	var buf := Marshalls.base64_to_raw(value)
	var err := img.load_png_from_buffer(buf)
	if err != OK:
		return [null, error_invalid_params("Failed to decode %s from base64: %s" % [label, error_string(err)])]
	return [img, null]


func _compare_screenshots(params: Dictionary) -> Dictionary:
	var result := require_string(params, "image_a")
	if result[1] != null:
		return result[1]
	var image_a_value: String = result[0]

	var result2 := require_string(params, "image_b")
	if result2[1] != null:
		return result2[1]
	var image_b_value: String = result2[0]

	var threshold: int = optional_int(params, "threshold", 10)

	# Load images (from path or base64)
	var load_a := _load_image_from_param(image_a_value, "image_a")
	if load_a[1] != null:
		return load_a[1]
	var img_a: Image = load_a[0]

	var load_b := _load_image_from_param(image_b_value, "image_b")
	if load_b[1] != null:
		return load_b[1]
	var img_b: Image = load_b[0]

	if img_a.get_size() != img_b.get_size():
		return error_invalid_params("Image sizes differ: %s vs %s" % [str(img_a.get_size()), str(img_b.get_size())])

	var width := img_a.get_width()
	var height := img_a.get_height()
	var diff_image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	var changed_pixels: int = 0
	var total_pixels: int = width * height

	for y in height:
		for x in width:
			var ca: Color = img_a.get_pixel(x, y)
			var cb: Color = img_b.get_pixel(x, y)
			var dr := absi(int(ca.r8) - int(cb.r8))
			var dg := absi(int(ca.g8) - int(cb.g8))
			var db := absi(int(ca.b8) - int(cb.b8))
			var max_diff := maxi(dr, maxi(dg, db))
			if max_diff > threshold:
				changed_pixels += 1
				# Red highlight for changed pixels
				diff_image.set_pixel(x, y, Color(1, 0, 0, clampf(float(max_diff) / 255.0, 0.3, 1.0)))
			else:
				# Dim version of original
				diff_image.set_pixel(x, y, Color(ca.r * 0.3, ca.g * 0.3, ca.b * 0.3, 1.0))

	var diff_percentage: float = (float(changed_pixels) / float(total_pixels)) * 100.0
	var identical: bool = changed_pixels == 0

	# Encode diff image
	var diff_png := diff_image.save_png_to_buffer()
	var diff_base64 := Marshalls.raw_to_base64(diff_png)

	return success({
		"identical": identical,
		"changed_pixels": changed_pixels,
		"total_pixels": total_pixels,
		"diff_percentage": snappedf(diff_percentage, 0.01),
		"threshold": threshold,
		"width": width,
		"height": height,
		"diff_image_base64": diff_base64,
	})


func _get_editor_camera(_params: Dictionary) -> Dictionary:
	var vp3d := EditorInterface.get_editor_viewport_3d()
	var cam := vp3d.get_camera_3d() if vp3d else null
	if not cam:
		return error(-32000, "No 3D editor camera found", {
			"suggestion": "Make sure a 3D scene is open in the editor",
		})
	var pos := cam.global_position
	var rot := cam.rotation_degrees
	var payload := {
		"position": {"x": pos.x, "y": pos.y, "z": pos.z},
		"rotation_degrees": {"x": rot.x, "y": rot.y, "z": rot.z},
		"fov": cam.fov,
		"near": cam.near,
		"far": cam.far,
	}
	var snap := _get_snap_3d()
	if not snap.is_empty():
		payload["snap_3d"] = snap
	return success(payload)


## The 3D viewport's snap settings (EditorInterface, Godot 4.6+). Returns {}
## on older versions, where the snap state is not exposed, so the key is
## simply omitted rather than reported with guessed values.
func _get_snap_3d() -> Dictionary:
	if not EditorInterface.has_method("is_node_3d_snap_enabled"):
		return {}
	return {
		"enabled": EditorInterface.call("is_node_3d_snap_enabled"),
		"translate": EditorInterface.call("get_node_3d_translate_snap"),
		"rotate_degrees": EditorInterface.call("get_node_3d_rotate_snap"),
		"scale_percent": EditorInterface.call("get_node_3d_scale_snap"),
	}


func _set_editor_camera(params: Dictionary) -> Dictionary:
	var vp3d := EditorInterface.get_editor_viewport_3d()
	var cam := vp3d.get_camera_3d() if vp3d else null
	if not cam:
		return error(-32000, "No 3D editor camera found", {
			"suggestion": "Make sure a 3D scene is open in the editor",
		})

	# Set position
	if params.has("position"):
		var p: Dictionary = params["position"]
		cam.global_position = Vector3(
			float(p.get("x", cam.global_position.x)),
			float(p.get("y", cam.global_position.y)),
			float(p.get("z", cam.global_position.z)),
		)

	# Set rotation
	if params.has("rotation_degrees"):
		var r: Dictionary = params["rotation_degrees"]
		cam.rotation_degrees = Vector3(
			float(r.get("x", cam.rotation_degrees.x)),
			float(r.get("y", cam.rotation_degrees.y)),
			float(r.get("z", cam.rotation_degrees.z)),
		)

	# Look at target (overrides rotation if set)
	if params.has("look_at"):
		var t: Dictionary = params["look_at"]
		cam.look_at(Vector3(float(t.get("x", 0)), float(t.get("y", 0)), float(t.get("z", 0))))

	# Set FOV
	if params.has("fov"):
		cam.fov = optional_float(params, "fov")

	var pos := cam.global_position
	var rot := cam.rotation_degrees
	return success({
		"position": {"x": pos.x, "y": pos.y, "z": pos.z},
		"rotation_degrees": {"x": rot.x, "y": rot.y, "z": rot.z},
		"fov": cam.fov,
	})


## Reports which open scenes and scripts hold unsaved changes. The scene and
## script lists come from Godot 4.7 APIs; on older versions they are null
## (unknown), never an empty list that would read as "all saved".
func _get_unsaved_state(_params: Dictionary) -> Dictionary:
	return success(_collect_unsaved_state())


func _collect_unsaved_state() -> Dictionary:
	var open_scripts: Array = []
	var script_editor := EditorInterface.get_script_editor()
	if script_editor != null:
		for open_resource in script_editor.get_open_scripts():
			if open_resource is Resource and not (open_resource as Resource).resource_path.is_empty():
				open_scripts.append(normalize_project_path((open_resource as Resource).resource_path))

	# get_open_scene_roots() is Godot 4.5+; a static call is a parse error on
	# 4.4 that would stop the whole addon from loading, so resolve it by name.
	var untitled_scenes := 0
	if EditorInterface.has_method("get_open_scene_roots"):
		for scene_root in EditorInterface.call("get_open_scene_roots"):
			if scene_root is Node and (scene_root as Node).scene_file_path.is_empty():
				untitled_scenes += 1

	var state := {
		"unsaved_scenes": get_unsaved_scene_paths(),
		"unsaved_scripts": get_unsaved_script_paths(),
		"open_scenes": get_open_scene_paths(),
		"open_scripts": open_scripts,
		"godot_version": get_godot_version_string(),
	}
	if untitled_scenes > 0:
		state["untitled_open_scenes"] = untitled_scenes
	# Buffers whose text is not what is on disk, whatever Godot's modified
	# flag says (a failed save clears the flag but keeps the edits unsaved).
	state["buffers_differ_from_disk"] = get_buffers_differing_from_disk()
	var notes: Array = []
	if state["unsaved_scenes"] == null:
		notes.append("unsaved_scenes requires Godot 4.7+ (EditorInterface.get_unsaved_scenes). null means unknown, not clean.")
	if state["unsaved_scripts"] == null:
		notes.append("unsaved_scripts requires Godot 4.7+ (ScriptEditor.get_unsaved_files). null means unknown, not clean.")
	if not notes.is_empty():
		state["notes"] = notes
	return state


## Saves every open scene (EditorInterface.save_all_scenes, all versions) and
## every modified script-editor buffer (ScriptEditor.save_all_scripts, 4.7+),
## then reports what was unsaved before and what is still unsaved afterwards.
## Scenes whose last save_all verifiably failed, with the file's md5 at the
## time: {path: md5}. An entry lasts until the file changes on disk.
static var _failed_scene_saves := {}


func _ready() -> void:
	# Listen for scene closes from the moment this handler exists: failed
	# save records are static and survive a plugin reload, so the listener
	# must not depend on a failure having happened in this instance.
	if editor_plugin != null and editor_plugin.has_signal("scene_closed") and not editor_plugin.is_connected("scene_closed", _on_scene_closed_clear_failure):
		editor_plugin.connect("scene_closed", _on_scene_closed_clear_failure)


func _on_scene_closed_clear_failure(filepath: String) -> void:
	var target := normalize_project_path(filepath)
	for sp: String in _failed_scene_saves.keys():
		if paths_match(normalize_project_path(sp), target):
			_failed_scene_saves.erase(sp)


## Drops failed-save records that no longer apply: the scene was closed
## (its edits discarded) or its file changed on disk.
func _prune_failed_scene_saves() -> void:
	var open_now: Array = []
	for op in EditorInterface.get_open_scenes():
		open_now.append(normalize_project_path(str(op)))
	for sp: String in _failed_scene_saves.keys():
		if not open_now.has(normalize_project_path(sp)) or not FileAccess.file_exists(sp) or FileAccess.get_md5(sp) != _failed_scene_saves[sp]:
			_failed_scene_saves.erase(sp)


func _save_all(params: Dictionary) -> Dictionary:
	var save_scenes := optional_bool(params, "scenes", true)
	var save_scripts := optional_bool(params, "scripts", true)
	if not save_scenes and not save_scripts:
		return error_invalid_params("Nothing to save: both 'scenes' and 'scripts' are false")

	var script_editor := EditorInterface.get_script_editor()
	var can_save_scripts := script_editor != null and script_editor.has_method("save_all_scripts")
	if save_scripts and not save_scenes and not can_save_scripts:
		return error_requires_godot("save_all with scripts=true", "4.7")

	var before := _collect_unsaved_state()
	var notes: Array = []
	var script_md5_rewritten: Array = []

	# A built-in script ("res://level.tscn::GDScript_x") can only be saved by
	# saving its scene, which save_all_scripts() does — including every other
	# unsaved edit in that scene. With scenes=false that would save exactly
	# what the caller asked to leave alone, so refuse instead.
	if save_scripts and not save_scenes:
		# Any OPEN built-in script counts, not only modified ones: Godot formats
		# buffers (e.g. trim trailing whitespace on save) before deciding what
		# is dirty, so a clean built-in script can still become dirty and take
		# its whole scene with it.
		var built_in: Array = []
		for pair: Dictionary in get_open_script_editor_pairs():
			if str(pair["path"]).contains("::"):
				built_in.append(pair["path"])
		if before["unsaved_scripts"] is Array:
			for s in before["unsaved_scripts"]:
				if str(s).contains("::") and not built_in.has(s):
					built_in.append(s)
		if not built_in.is_empty():
			return error_conflict(
				"Refusing to save scripts only: built-in scripts are open, and saving them saves their whole scene",
				{
					"built_in_scripts": built_in,
					"suggestion": "Call save_all with scenes=true (or save_scene for those scenes) to keep the edits, or save only file-based scripts by closing the scene tabs first.",
				}
			)

	# Godot's scene save also saves every modified script-editor buffer (the
	# script editor plugin's save_external_data), so scenes=true with
	# scripts=false would write exactly what the caller asked to keep.
	if save_scenes and not save_scripts:
		var unsaved_scripts: Variant = before["unsaved_scripts"]
		if unsaved_scripts is Array and not (unsaved_scripts as Array).is_empty():
			return error_conflict(
				"Refusing to save scenes only: Godot also saves modified script buffers when it saves scenes",
				{
					"unsaved_scripts": unsaved_scripts,
					"suggestion": "Save everything with save_all (scripts=true), or discard the script edits first (close_script with discard_unsaved=true).",
				}
			)
		if unsaved_scripts == null:
			notes.append("Godot saves modified script-editor buffers whenever it saves scenes, so scripts=false cannot keep them unsaved. This Godot version cannot report which buffers are modified.")


	# Register every buffer whose edits are not on disk as protected BEFORE
	# saving: Godot clears the modified flag even when the write fails, and
	# this handler awaits a frame before it can verify. A reload arriving in
	# that window (another MCP session) would otherwise see a "clean" buffer
	# and replace it. Buffers that do get saved drop out of the registry on
	# their own, since protection ends once a buffer matches disk.
	protect_script_buffers_before_save()

	# Collect the scenes Godot reports as written (EditorPlugin.scene_saved):
	# a scene that needed saving but never shows up here was not saved, even
	# if a failed write left no dirty flag behind. (File mtime/content cannot
	# tell: a same-second save of unchanged content leaves both as they were.)
	var saved_scenes: Array = []
	var on_scene_saved := func(fp: String) -> void:
		saved_scenes.append(normalize_project_path(fp))
	var can_track_saves: bool = editor_plugin != null and editor_plugin.has_signal("scene_saved")
	# scene_saved is emitted even when the write fails (verified on 4.7.2
	# with a read-only .tscn), so it only proves a MISSING save. Also check
	# up front which scene files cannot be opened for writing at all.
	var unwritable_scenes: Array = []
	var scene_md5_before := {}
	if save_scenes and before["unsaved_scenes"] is Array:
		for sp in before["unsaved_scenes"]:
			var spath := str(sp)
			if spath.is_empty() or not FileAccess.file_exists(spath):
				continue
			scene_md5_before[normalize_project_path(spath)] = FileAccess.get_md5(spath)
			var probe := FileAccess.open(spath, FileAccess.READ_WRITE)
			if probe == null:
				unwritable_scenes.append(normalize_project_path(spath))
				continue
			probe.close()
			# Godot saves through a temp file next to the scene ("safe
			# save"), so the directory must be writable too.
			var dir_probe_path := spath.get_base_dir().path_join(".mcp_write_probe_%d" % OS.get_process_id())
			var dir_probe := FileAccess.open(dir_probe_path, FileAccess.WRITE)
			if dir_probe == null:
				unwritable_scenes.append(normalize_project_path(spath))
			else:
				dir_probe.close()
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dir_probe_path))
	if can_track_saves:
		editor_plugin.connect("scene_saved", on_scene_saved)

	if save_scenes:
		_prune_failed_scene_saves()
		if not _failed_scene_saves.is_empty():
			notes.append("Scenes whose earlier save failed stay reported as not saved until their file on disk changes (Godot no longer marks them modified): %s. Make any edit to them and save again." % ", ".join(PackedStringArray(_failed_scene_saves.keys())))
		# Untitled scenes have no path to save to; Godot skips them (and may
		# show a "could not save" warning), so point at save_scene instead.
		if before.get("untitled_open_scenes", 0) > 0:
			notes.append("%d open scene(s) have never been saved and have no path; save_all cannot save them. Use save_scene with a path." % before["untitled_open_scenes"])
		# Godot's scene save also runs the script editor's save, which formats
		# open buffers first (trim final newlines / convert indent are on by
		# default) and writes any that the formatting changed. That cannot be
		# prevented from here, so with scripts=false measure it and say so.
		var script_md5_before := {}
		if not save_scripts:
			for pair: Dictionary in get_open_script_editor_pairs():
				var sp: String = pair["path"]
				if not sp.is_empty() and not sp.contains("::") and FileAccess.file_exists(sp):
					script_md5_before[sp] = FileAccess.get_md5(sp)
		var was_playing := get_editor().is_playing_scene()
		EditorInterface.save_all_scenes()
		# save_all_scenes() stops a running game (verified on 4.7.2).
		handle_implicit_stop(was_playing)
		if not script_md5_before.is_empty():
			var rewritten: Array = []
			for sp: String in script_md5_before:
				if FileAccess.get_md5(sp) != script_md5_before[sp]:
					rewritten.append(normalize_project_path(sp))
			if not rewritten.is_empty():
				notes.append("Godot rewrote these open scripts while saving scenes (save-time formatting such as trimming final newlines or converting indentation, per Editor Settings > Text Editor > Behavior > Files): %s" % ", ".join(PackedStringArray(rewritten)))
				script_md5_rewritten = rewritten

	var scripts_saved: Variant = false
	if save_scripts:
		if can_save_scripts:
			# The buffers are written as they are: a script whose file changed
			# on disk after its buffer was edited is overwritten by the buffer.
			# save_all_scripts() reports nothing; the flag is set from the
			# verified state below.
			script_editor.call("save_all_scripts")
			scripts_saved = true
		else:
			scripts_saved = null
			notes.append("Saving script-editor buffers requires Godot 4.7+ (ScriptEditor.save_all_scripts); scripts were not saved (running %s)." % get_godot_version_string())

	# Saving emits resource_saved and filesystem updates on the same frame;
	# let them settle before measuring what is still unsaved.
	await get_tree().process_frame
	if can_track_saves and editor_plugin.is_connected("scene_saved", on_scene_saved):
		editor_plugin.disconnect("scene_saved", on_scene_saved)
	var after := _collect_unsaved_state()

	# Derive the flags from what is actually still unsaved: Godot's save calls
	# report no status, and a read-only file or a failing saver leaves the
	# resource unsaved while the call itself "succeeds".
	var failed := {}
	var scenes_saved: Variant = save_scenes
	if save_scenes:
		# Everything still unsaved counts, not only what was unsaved before:
		# save-time formatting can dirty a built-in script (and so its scene)
		# during this very save. Scenes that were unsaved must also have been
		# rewritten on disk, since a failed write may leave no flag behind.
		var still: Array = _all_unsaved(after["unsaved_scenes"])
		# The write probes are only provisional: on Unix a read-only file in a
		# writable directory is still replaced by Godot's safe save (temp file
		# + rename). Count such a scene as failed only if its bytes did not
		# change.
		for sp: String in unwritable_scenes:
			var changed: bool = scene_md5_before.has(sp) and FileAccess.file_exists(sp) and FileAccess.get_md5(sp) != scene_md5_before[sp]
			if not changed and not still.has(sp):
				still.append(sp)
		if can_track_saves and before["unsaved_scenes"] is Array:
			for sp in before["unsaved_scenes"]:
				var spath := normalize_project_path(str(sp))
				if not spath.is_empty() and not saved_scenes.has(spath) and not still.has(spath):
					still.append(spath)
		# A scene whose save failed earlier is no longer flagged dirty (Godot
		# clears the flag either way), so a retry would skip it and look
		# successful. Keep reporting it until its file actually changes.
		_prune_failed_scene_saves()
		for sp: String in _failed_scene_saves.keys():
			if not still.has(sp):
				still.append(sp)
		if after["unsaved_scenes"] == null:
			scenes_saved = null
		elif not still.is_empty():
			scenes_saved = false
			failed["scenes"] = still
			for sp in still:
				var fp := str(sp)
				if FileAccess.file_exists(fp) and not _failed_scene_saves.has(fp):
					_failed_scene_saves[fp] = scene_md5_before.get(fp, FileAccess.get_md5(fp))
			# Closing a scene discards its unsaved edits, so its failure record
			# must go too, even if it is reopened later with the same file.
			if editor_plugin != null and editor_plugin.has_signal("scene_closed") and not editor_plugin.is_connected("scene_closed", _on_scene_closed_clear_failure):
				editor_plugin.connect("scene_closed", _on_scene_closed_clear_failure)
	if save_scripts and scripts_saved == true:
		var still_scripts: Array = _all_unsaved(after["unsaved_scripts"])
		# Built-in scripts are saved inside their scene, and Godot clears their
		# modified flag even when that scene write failed. Compare each open
		# built-in buffer with the source actually stored in the scene file.
		for pair: Dictionary in get_open_script_editor_pairs():
			var bpath: String = pair["path"]
			if not bpath.contains("::") or still_scripts.has(bpath):
				continue
			var base_editor: Control = (pair["editor"] as ScriptEditorBase).get_base_editor()
			if not base_editor is TextEdit:
				continue
			var parts := bpath.split("::", true, 1)
			var on_disk: Variant = _builtin_script_source_on_disk(parts[0], parts[1])
			if on_disk is String:
				if (on_disk as String).replace("\r\n", "\n") != (base_editor as TextEdit).text.replace("\r\n", "\n"):
					still_scripts.append(bpath)
			elif before["unsaved_scripts"] is Array and (before["unsaved_scripts"] as Array).has(bpath):
				# It had edits to save and they cannot be confirmed on disk;
				# do not report that as saved.
				still_scripts.append(bpath)
		# Godot clears a script's modified flag even when the write failed
		# (read-only file, verified on 4.7.2), and a buffer left over from an
		# earlier failed save is no longer flagged at all. So verify EVERY
		# open file-backed buffer against disk, not only the flagged ones.
		for spath: String in get_buffers_differing_from_disk():
			if not still_scripts.has(spath):
				still_scripts.append(spath)
		if after["unsaved_scripts"] == null:
			scripts_saved = null
		elif not still_scripts.is_empty():
			scripts_saved = false
			failed["scripts"] = still_scripts
			# Godot now reports these clean; remember them so a reload
			# cannot silently replace the unsaved edits with disk contents.
			record_failed_script_saves(still_scripts)

	var payload := {
		"scenes_saved": scenes_saved,
		"scripts_saved": scripts_saved,
		"scripts_rewritten_by_scene_save": script_md5_rewritten,
		"before": {
			"unsaved_scenes": before["unsaved_scenes"],
			"unsaved_scripts": before["unsaved_scripts"],
		},
		"remaining": {
			"unsaved_scenes": after["unsaved_scenes"],
			"unsaved_scripts": after["unsaved_scripts"],
		},
		"godot_version": after["godot_version"],
	}
	if after.has("notes"):
		notes.append_array(after["notes"])
	if not notes.is_empty():
		payload["notes"] = notes
	if not failed.is_empty():
		payload["failed_to_save"] = failed
		payload["suggestion"] = "Godot could not save these (read-only file, missing folder, or a saver error). Check the Output panel, fix the cause, and call save_all again."
		return error(-32000, "save_all could not save everything it was asked to", payload)
	return success(payload)


## Source of built-in GDScript `sub_id` as stored in the text scene at
## `scene_path` (the script/source string of its [sub_resource]), or null
## when it cannot be read (binary .scn, missing block). Godot writes the
## source with only \\ and \" escaped; newlines are literal.
func _builtin_script_source_on_disk(scene_path: String, sub_id: String) -> Variant:
	if not FileAccess.file_exists(scene_path):
		return null
	if not scene_path.ends_with(".tscn"):
		return _builtin_script_source_from_load(scene_path, sub_id)
	var text := FileAccess.get_file_as_string(scene_path)
	var header := '[sub_resource type="GDScript" id="%s"]' % sub_id
	var at := text.find(header)
	if at == -1:
		return null
	var next_section := text.find("\n[", at + header.length())
	var key := 'script/source = "'
	var src_at := text.find(key, at)
	if src_at == -1 or (next_section != -1 and src_at > next_section):
		return null
	var i := src_at + key.length()
	var out := ""
	while i < text.length():
		var ch := text[i]
		if ch == "\\" and i + 1 < text.length():
			out += text[i + 1]
			i += 2
			continue
		if ch == '"':
			return out
		out += ch
		i += 1
	return null


## Binary scenes (.scn) and anything the text parser cannot read: load the
## scene fresh from disk, bypassing the resource cache (which still holds
## the edited, unsaved script), and find the built-in script by its scene
## unique id among the node properties.
func _builtin_script_source_from_load(scene_path: String, sub_id: String) -> Variant:
	var ps := ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if ps == null:
		return null
	var state := ps.get_state()
	for n in state.get_node_count():
		for pi in state.get_node_property_count(n):
			var v: Variant = state.get_node_property_value(n, pi)
			if v is Script and (v as Resource).resource_scene_unique_id == sub_id:
				return (v as Script).source_code
	return null


## Every non-empty entry of an unsaved list (null = unknown yields []).
## Untitled scenes have no path and are reported separately.
func _all_unsaved(after_list: Variant) -> Array:
	var out: Array = []
	if after_list is Array:
		for entry in after_list:
			if not str(entry).is_empty():
				out.append(entry)
	return out


## Entries that were unsaved before and are still unsaved after. Either list
## may be null (unknown on older Godot), which yields [].
func _still_unsaved(before_list: Variant, after_list: Variant) -> Array:
	var out: Array = []
	if not before_list is Array or not after_list is Array:
		return out
	for entry in after_list:
		# Untitled scenes have no path and are reported separately.
		if str(entry).is_empty():
			continue
		if (before_list as Array).has(entry):
			out.append(entry)
	return out


func _set_auto_dismiss(params: Dictionary) -> Dictionary:
	var enabled: bool = params.get("enabled", true)
	editor_plugin.auto_dismiss_dialogs = enabled
	return success({
		"auto_dismiss": enabled,
		"message": "Auto-dismiss dialogs %s" % ("enabled" if enabled else "disabled"),
	})
