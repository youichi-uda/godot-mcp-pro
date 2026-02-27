@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_editor_errors": _get_editor_errors,
		"get_editor_screenshot": _get_editor_screenshot,
		"get_game_screenshot": _get_game_screenshot,
		"execute_editor_script": _execute_editor_script,
		"clear_output": _clear_output,
		"reload_plugin": _reload_plugin,
		"reload_project": _reload_project,
		"get_signals": _get_signals,
		"compare_screenshots": _compare_screenshots,
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

	# 2. Check the script editor for compile errors (red background lines)
	#    These don't appear in the Output panel
	var script_errors: Array = []
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	if script_editor:
		var current_script: Script = script_editor.get_current_script()
		var ce: CodeEdit = _find_code_edit(script_editor)
		if ce and current_script:
			var script_path: String = current_script.resource_path
			for i in range(ce.get_line_count()):
				var bg: Color = ce.get_line_background_color(i)
				if bg.r > 0.8 and bg.a > 0:  # Red-ish background = error
					var line_text: String = ce.get_line(i).strip_edges()
					script_errors.append("COMPILE ERROR: %s:%d - %s" % [script_path, i + 1, line_text])

	# Fallback: read from log file if Output panel not accessible
	if errors.size() == 0 and script_errors.size() == 0:
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
	return success({"errors": errors, "count": errors.size()})


func _find_code_edit(node: Node, depth: int = 0) -> CodeEdit:
	if depth > 8:
		return null
	if node is CodeEdit:
		return node as CodeEdit
	for child in node.get_children():
		var found: CodeEdit = _find_code_edit(child, depth + 1)
		if found:
			return found
	return null


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
	var req := FileAccess.open(request_path, FileAccess.WRITE)
	if req == null:
		return error_internal("Could not create screenshot request file")
	req.close()

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

	var png_buffer := image.save_png_to_buffer()
	var base64 := Marshalls.raw_to_base64(png_buffer)

	# Clean up
	DirAccess.remove_absolute(screenshot_path)

	return success({
		"image_base64": base64,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": "png",
	})


func _execute_editor_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "code")
	if result[1] != null:
		return result[1]
	var code: String = result[0]

	# Wrap user code in a @tool script
	var wrapped_code := """@tool
extends Node

var _mcp_output: Array = []

func _mcp_print(value: Variant) -> void:
	_mcp_output.append(str(value))

func run() -> Variant:
	# User code begins
%s
	# User code ends
	return _mcp_output
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

	var mcp_output: Array = []
	var raw_output: Variant = temp_node.get("_mcp_output")
	if raw_output is Array:
		mcp_output = raw_output

	# Cleanup
	temp_node.queue_free()

	return success({
		"output": mcp_output,
		"return_value": str(output) if output != null else null,
	})


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
