## Autoload injected by Godot MCP Pro plugin at runtime.
## Handles runtime game inspection: scene tree, node properties, frame capture, property monitoring.
extends Node

const REQUEST_PATH := "user://mcp_game_request"
const RESPONSE_PATH := "user://mcp_game_response"

enum State { IDLE, CAPTURING_FRAMES, MONITORING, RECORDING }

var _state: State = State.IDLE
var _pending_command: bool = false  # Crash recovery flag

# Frame capture state
var _capture_frames_remaining: int = 0
var _capture_frame_interval: int = 1
var _capture_frame_counter: int = 0
var _capture_half_res: bool = true
var _captured_images: Array = []  # Array of base64 strings

# Recording state
var _recording_events: Array = []
var _recording_start_msec: int = 0

# Monitor state
var _monitor_node_path: String = ""
var _monitor_properties: Array = []
var _monitor_frames_remaining: int = 0
var _monitor_frame_interval: int = 1
var _monitor_frame_counter: int = 0
var _monitor_timeline: Array = []  # Array of sample dicts


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Crash recovery: if a command was in progress but never wrote a response
	if _pending_command and not FileAccess.file_exists(REQUEST_PATH) and not FileAccess.file_exists(RESPONSE_PATH):
		push_warning("[MCP] Recovered from crashed command — writing error response")
		_pending_command = false
		_state = State.IDLE
		_write_response({"error": "Command crashed (runtime error). Check Godot debugger."})
		return

	match _state:
		State.IDLE:
			if FileAccess.file_exists(REQUEST_PATH):
				_handle_request()
		State.CAPTURING_FRAMES:
			_process_capture()
		State.MONITORING:
			_process_monitor()
		State.RECORDING:
			if FileAccess.file_exists(REQUEST_PATH):
				_handle_request()


# ── Request handling ──────────────────────────────────────────────────────────

func _handle_request() -> void:
	var file := FileAccess.open(REQUEST_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(REQUEST_PATH)

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		_write_response({"error": "Invalid request JSON"})
		return

	# Abort any in-progress operation
	_state = State.IDLE
	_pending_command = true

	var command: String = parsed.get("command", "")
	var params: Dictionary = parsed.get("params", {})

	match command:
		"get_scene_tree":
			_cmd_get_scene_tree(params)
		"get_node_properties":
			_cmd_get_node_properties(params)
		"set_node_property":
			_cmd_set_node_property(params)
		"capture_frames":
			_cmd_capture_frames(params)
		"monitor_properties":
			_cmd_monitor_properties(params)
		"execute_script":
			_cmd_execute_script(params)
		"start_recording":
			_cmd_start_recording(params)
		"stop_recording":
			_cmd_stop_recording(params)
		"replay_recording":
			_cmd_replay_recording(params)
		"find_nodes_by_script":
			_cmd_find_nodes_by_script(params)
		"get_autoload":
			_cmd_get_autoload(params)
		"batch_get_properties":
			_cmd_batch_get_properties(params)
		"find_ui_elements":
			_cmd_find_ui_elements(params)
		"click_button_by_text":
			_cmd_click_button_by_text(params)
		"wait_for_node":
			_cmd_wait_for_node(params)
		"assert_node_state":
			_cmd_assert_node_state(params)
		_:
			_write_response({"error": "Unknown command: %s" % command})


# ── get_scene_tree ────────────────────────────────────────────────────────────

func _cmd_get_scene_tree(params: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var max_depth: int = params.get("max_depth", -1)
	var script_filter: String = params.get("script_filter", "")
	var type_filter: String = params.get("type_filter", "")
	var named_only: bool = params.get("named_only", false)

	var has_filter: bool = not script_filter.is_empty() or not type_filter.is_empty() or named_only

	if has_filter:
		var tree: Variant = _build_filtered_node_tree(root, max_depth, script_filter, type_filter, named_only)
		if tree == null:
			_write_response({"tree": null, "message": "No nodes matched the filter"})
		else:
			_write_response({"tree": tree})
	else:
		var tree := _build_node_tree(root, max_depth)
		_write_response({"tree": tree})


func _build_node_tree(node: Node, max_depth: int, current_depth: int = 0) -> Dictionary:
	var result := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	var script: Script = node.get_script()
	if script:
		result["script"] = script.resource_path

	if max_depth == -1 or current_depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			children.append(_build_node_tree(child, max_depth, current_depth + 1))
		if not children.is_empty():
			result["children"] = children

	return result


## Build a filtered tree. Returns null if this subtree has no matches.
func _build_filtered_node_tree(node: Node, max_depth: int, script_filter: String, type_filter: String, named_only: bool, current_depth: int = 0) -> Variant:
	var node_matches := _node_matches_filter(node, script_filter, type_filter, named_only)

	# Build children first to check if any descendant matches
	var matched_children: Array = []
	if max_depth == -1 or current_depth < max_depth:
		for child in node.get_children():
			var child_tree: Variant = _build_filtered_node_tree(child, max_depth, script_filter, type_filter, named_only, current_depth + 1)
			if child_tree != null:
				matched_children.append(child_tree)

	# Include this node if it matches or if any descendant matches
	if not node_matches and matched_children.is_empty():
		return null

	var result := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	var script: Script = node.get_script()
	if script:
		result["script"] = script.resource_path

	if not matched_children.is_empty():
		result["children"] = matched_children

	return result


func _node_matches_filter(node: Node, script_filter: String, type_filter: String, named_only: bool) -> bool:
	# Check named_only: exclude nodes with auto-generated names (starting with "@")
	if named_only and (node.name as String).begins_with("@"):
		return false

	# Check type_filter
	if not type_filter.is_empty() and not node.is_class(type_filter):
		return false

	# Check script_filter
	if not script_filter.is_empty():
		var script: Script = node.get_script()
		if script == null:
			return false
		if not script.resource_path.to_lower().contains(script_filter.to_lower()):
			return false

	# If no filters were active (all empty/false), the node doesn't "match" per se
	# But this function is only called when has_filter is true, so at least one filter is active
	return true


# ── get_node_properties ───────────────────────────────────────────────────────

func _cmd_get_node_properties(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_write_response({"error": "node_path is required"})
		return

	var node := get_node_or_null(NodePath(node_path))
	if node == null:
		_write_response({"error": "Node not found: %s" % node_path})
		return

	var filter: Array = params.get("properties", [])
	var props: Dictionary = {}

	if filter.is_empty():
		# Return all editor-visible properties
		for prop_info in node.get_property_list():
			var prop_name: String = prop_info["name"]
			var usage: int = prop_info["usage"]
			if not (usage & PROPERTY_USAGE_EDITOR):
				continue
			if prop_name.begins_with("_") or prop_name == "script":
				continue
			props[prop_name] = _serialize_value(node.get(prop_name))
	else:
		for prop_name: String in filter:
			var value: Variant = node.get(prop_name)
			props[prop_name] = _serialize_value(value)

	_write_response({
		"node_path": str(node.get_path()),
		"type": node.get_class(),
		"properties": props,
	})


# ── capture_frames ────────────────────────────────────────────────────────────

func _cmd_capture_frames(params: Dictionary) -> void:
	var count: int = clampi(params.get("count", 5), 1, 30)
	var interval: int = maxi(params.get("frame_interval", 10), 1)
	_capture_half_res = params.get("half_resolution", true)

	_captured_images.clear()
	_capture_frames_remaining = count
	_capture_frame_interval = interval
	_capture_frame_counter = 0
	_state = State.CAPTURING_FRAMES
	# Capture first frame immediately
	_capture_one_frame()


func _process_capture() -> void:
	# Check for abort (new request arrived)
	if FileAccess.file_exists(REQUEST_PATH):
		_state = State.IDLE
		_handle_request()
		return

	_capture_frame_counter += 1
	if _capture_frame_counter >= _capture_frame_interval:
		_capture_frame_counter = 0
		_capture_one_frame()


func _capture_one_frame() -> void:
	var viewport := get_viewport()
	if viewport == null:
		_finish_capture()
		return

	var image := viewport.get_texture().get_image()
	if image == null:
		_finish_capture()
		return

	if _capture_half_res:
		var new_size := image.get_size() / 2
		image.resize(new_size.x, new_size.y, Image.INTERPOLATE_BILINEAR)

	var png_buffer := image.save_png_to_buffer()
	_captured_images.append(Marshalls.raw_to_base64(png_buffer))

	_capture_frames_remaining -= 1
	if _capture_frames_remaining <= 0:
		_finish_capture()


func _finish_capture() -> void:
	_state = State.IDLE
	var viewport := get_viewport()
	var w := 0
	var h := 0
	if viewport:
		var size := viewport.get_visible_rect().size
		if _capture_half_res:
			size /= 2
		w = int(size.x)
		h = int(size.y)

	_write_response({
		"frames": _captured_images,
		"count": _captured_images.size(),
		"width": w,
		"height": h,
		"half_resolution": _capture_half_res,
	})
	_captured_images.clear()


# ── monitor_properties ────────────────────────────────────────────────────────

func _cmd_monitor_properties(params: Dictionary) -> void:
	_monitor_node_path = params.get("node_path", "")
	_monitor_properties = params.get("properties", [])
	if _monitor_node_path.is_empty() or _monitor_properties.is_empty():
		_write_response({"error": "node_path and properties are required"})
		return

	var frame_count: int = clampi(params.get("frame_count", 60), 1, 600)
	var interval: int = maxi(params.get("frame_interval", 1), 1)

	_monitor_timeline.clear()
	_monitor_frames_remaining = frame_count
	_monitor_frame_interval = interval
	_monitor_frame_counter = 0
	_state = State.MONITORING
	# Sample first frame immediately
	_sample_one_frame()


func _process_monitor() -> void:
	# Check for abort
	if FileAccess.file_exists(REQUEST_PATH):
		_state = State.IDLE
		_handle_request()
		return

	_monitor_frame_counter += 1
	if _monitor_frame_counter >= _monitor_frame_interval:
		_monitor_frame_counter = 0
		_sample_one_frame()


func _sample_one_frame() -> void:
	var sample: Dictionary = {}
	var node := get_node_or_null(NodePath(_monitor_node_path))

	if node == null:
		for prop_name: String in _monitor_properties:
			sample[prop_name] = null
	else:
		for prop_name: String in _monitor_properties:
			sample[prop_name] = _serialize_value(node.get(prop_name))

	_monitor_timeline.append(sample)

	_monitor_frames_remaining -= 1
	if _monitor_frames_remaining <= 0:
		_finish_monitor()


func _finish_monitor() -> void:
	_state = State.IDLE
	_write_response({
		"node_path": _monitor_node_path,
		"properties": _monitor_properties,
		"samples": _monitor_timeline,
		"sample_count": _monitor_timeline.size(),
		"frame_interval": _monitor_frame_interval,
	})
	_monitor_timeline.clear()


# ── set_node_property ─────────────────────────────────────────────────────────

func _cmd_set_node_property(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_write_response({"error": "node_path is required"})
		return

	var property: String = params.get("property", "")
	if property.is_empty():
		_write_response({"error": "property is required"})
		return

	if not params.has("value"):
		_write_response({"error": "value is required"})
		return

	var node := get_node_or_null(NodePath(node_path))
	if node == null:
		_write_response({"error": "Node not found: %s" % node_path})
		return

	var old_value: Variant = node.get(property)
	var raw_value: Variant = params.get("value")
	var parsed_value: Variant = _parse_value_for_type(raw_value, typeof(old_value))

	node.set(property, parsed_value)
	var new_value: Variant = node.get(property)

	_write_response({
		"node_path": str(node.get_path()),
		"property": property,
		"old_value": _serialize_value(old_value),
		"new_value": _serialize_value(new_value),
	})


func _parse_value_for_type(raw: Variant, target_type: int) -> Variant:
	# If the raw value is already the right type, return as-is
	if typeof(raw) == target_type:
		return raw

	# If raw is a string, try to parse it using Expression (handles Vector2(...), Color(...), etc.)
	if raw is String:
		var raw_str: String = raw

		# Handle hex color strings like "#ff0000"
		if raw_str.begins_with("#"):
			return Color.html(raw_str)

		# Try Expression evaluation for Godot type constructors
		var expr := Expression.new()
		var err := expr.parse(raw_str)
		if err == OK:
			var result: Variant = expr.execute()
			if not expr.has_execute_failed():
				return result

		# Fallback: return string as-is
		return raw_str

	# Numeric conversions
	if raw is float and target_type == TYPE_INT:
		return int(raw)
	if raw is int and target_type == TYPE_FLOAT:
		return float(raw)

	return raw


# ── execute_script ────────────────────────────────────────────────────────────

func _cmd_execute_script(params: Dictionary) -> void:
	var code: String = params.get("code", "")
	if code.is_empty():
		_write_response({"error": "code is required"})
		return

	# Wrap user code with error-safe helpers
	var wrapped := """extends Node

var _mcp_output: Array = []
var _mcp_error: String = ""

func _mcp_print(value: Variant) -> void:
	_mcp_output.append(str(value))

func _safe_get(node: Node, prop: String, default: Variant = null) -> Variant:
	if node == null:
		return default
	return node.get(prop) if prop in node else default

func run() -> Variant:
"""
	for line in code.split("\n"):
		wrapped += "\t" + line + "\n"
	wrapped += "\treturn _mcp_output\n"

	var script := GDScript.new()
	script.source_code = wrapped
	var err := script.reload()
	if err != OK:
		_write_response({"error": "Script compilation failed: %s" % error_string(err)})
		return

	var temp_node := Node.new()
	temp_node.set_script(script)
	get_tree().current_scene.add_child(temp_node)

	var output: Variant = null
	if temp_node.has_method("run"):
		output = temp_node.run()

	var mcp_output: Array = temp_node.get("_mcp_output") if temp_node.get("_mcp_output") is Array else []
	temp_node.queue_free()

	_write_response({
		"output": mcp_output,
		"return_value": str(output) if output != null else null,
	})


# ── find_nodes_by_script ──────────────────────────────────────────────────────

func _cmd_find_nodes_by_script(params: Dictionary) -> void:
	var script_name: String = params.get("script", "")
	if script_name.is_empty():
		_write_response({"error": "'script' is required"})
		return

	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var prop_filter: Array = params.get("properties", [])
	var matches: Array = []
	_find_nodes_by_script_recursive(root, script_name.to_lower(), prop_filter, matches)

	_write_response({"nodes": matches, "count": matches.size()})


func _find_nodes_by_script_recursive(node: Node, script_filter: String, prop_filter: Array, results: Array) -> void:
	var script: Script = node.get_script()
	if script and script.resource_path.to_lower().contains(script_filter):
		var entry := {
			"name": node.name,
			"path": str(node.get_path()),
			"type": node.get_class(),
			"script": script.resource_path,
		}
		var props: Dictionary = {}
		if prop_filter.is_empty():
			# Return all editor-visible script variables
			for prop_info in node.get_property_list():
				var prop_name: String = prop_info["name"]
				var usage: int = prop_info["usage"]
				if not (usage & PROPERTY_USAGE_EDITOR):
					continue
				if prop_name.begins_with("_") or prop_name == "script":
					continue
				props[prop_name] = _serialize_value(node.get(prop_name))
		else:
			for prop_name: String in prop_filter:
				props[prop_name] = _serialize_value(node.get(prop_name))
		entry["properties"] = props
		results.append(entry)

	for child in node.get_children():
		_find_nodes_by_script_recursive(child, script_filter, prop_filter, results)


# ── get_autoload ─────────────────────────────────────────────────────────────

func _cmd_get_autoload(params: Dictionary) -> void:
	var autoload_name: String = params.get("name", "")
	if autoload_name.is_empty():
		_write_response({"error": "'name' is required"})
		return

	var node := get_node_or_null(NodePath("/root/" + autoload_name))
	if node == null:
		_write_response({"error": "Autoload not found: %s" % autoload_name})
		return

	var prop_filter: Array = params.get("properties", [])
	var props: Dictionary = {}

	if prop_filter.is_empty():
		for prop_info in node.get_property_list():
			var prop_name: String = prop_info["name"]
			var usage: int = prop_info["usage"]
			if not (usage & PROPERTY_USAGE_EDITOR):
				continue
			if prop_name.begins_with("_") or prop_name == "script":
				continue
			props[prop_name] = _serialize_value(node.get(prop_name))
	else:
		for prop_name: String in prop_filter:
			props[prop_name] = _serialize_value(node.get(prop_name))

	var result := {
		"name": autoload_name,
		"path": str(node.get_path()),
		"type": node.get_class(),
		"properties": props,
	}
	var script: Script = node.get_script()
	if script:
		result["script"] = script.resource_path

	_write_response(result)


# ── batch_get_properties ─────────────────────────────────────────────────────

func _cmd_batch_get_properties(params: Dictionary) -> void:
	var nodes: Array = params.get("nodes", [])
	if nodes.is_empty():
		_write_response({"error": "'nodes' array is required"})
		return

	var results: Array = []
	for entry: Dictionary in nodes:
		var node_path: String = entry.get("path", "")
		var prop_filter: Array = entry.get("properties", [])

		if node_path.is_empty():
			results.append({"path": "", "properties": {}, "error": "Empty path"})
			continue

		var node := get_node_or_null(NodePath(node_path))
		if node == null:
			results.append({"path": node_path, "properties": {}, "error": "Node not found"})
			continue

		var props: Dictionary = {}
		if prop_filter.is_empty():
			for prop_info in node.get_property_list():
				var prop_name: String = prop_info["name"]
				var usage: int = prop_info["usage"]
				if not (usage & PROPERTY_USAGE_EDITOR):
					continue
				if prop_name.begins_with("_") or prop_name == "script":
					continue
				props[prop_name] = _serialize_value(node.get(prop_name))
		else:
			for prop_name: String in prop_filter:
				props[prop_name] = _serialize_value(node.get(prop_name))

		results.append({"path": node_path, "properties": props})

	_write_response({"nodes": results, "count": results.size()})


# ── find_ui_elements ─────────────────────────────────────────────────────────

func _cmd_find_ui_elements(params: Dictionary) -> void:
	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var type_filter: String = params.get("type_filter", "")
	var elements: Array = []
	_find_ui_recursive(root, type_filter, elements)
	_write_response({"elements": elements, "count": elements.size()})


func _find_ui_recursive(node: Node, type_filter: String, results: Array) -> void:
	if node is Control and node.visible:
		var ctrl: Control = node
		var entry: Dictionary = {}
		var include := false

		if ctrl is Button:
			var btn: Button = ctrl
			entry["type"] = "Button"
			entry["text"] = btn.text
			entry["disabled"] = btn.disabled
			include = true
		elif ctrl is Label:
			var lbl: Label = ctrl
			entry["type"] = "Label"
			entry["text"] = lbl.text
			include = true
		elif ctrl is LineEdit:
			var le: LineEdit = ctrl
			entry["type"] = "LineEdit"
			entry["text"] = le.text
			entry["placeholder"] = le.placeholder_text
			include = true
		elif ctrl is TextEdit:
			var te: TextEdit = ctrl
			entry["type"] = "TextEdit"
			entry["text"] = te.text.left(200)
			include = true
		elif ctrl is OptionButton:
			var ob: OptionButton = ctrl
			entry["type"] = "OptionButton"
			entry["text"] = ob.text
			entry["selected"] = ob.selected
			include = true
		elif ctrl is CheckBox:
			var cb: CheckBox = ctrl
			entry["type"] = "CheckBox"
			entry["text"] = cb.text
			entry["checked"] = cb.button_pressed
			include = true
		elif ctrl is HSlider or ctrl is VSlider:
			var sl: Range = ctrl
			entry["type"] = "HSlider" if ctrl is HSlider else "VSlider"
			entry["value"] = sl.value
			entry["min"] = sl.min_value
			entry["max"] = sl.max_value
			include = true

		if include:
			if not type_filter.is_empty() and entry.get("type", "") != type_filter:
				pass  # Skip non-matching types
			else:
				var rect := ctrl.get_global_rect()
				entry["name"] = str(ctrl.name)
				entry["path"] = str(ctrl.get_path())
				entry["rect"] = {
					"x": rect.position.x,
					"y": rect.position.y,
					"width": rect.size.x,
					"height": rect.size.y,
				}
				entry["center"] = {
					"x": rect.position.x + rect.size.x / 2.0,
					"y": rect.position.y + rect.size.y / 2.0,
				}
				results.append(entry)

	for child in node.get_children():
		_find_ui_recursive(child, type_filter, results)


# ── click_button_by_text ─────────────────────────────────────────────────────

func _cmd_click_button_by_text(params: Dictionary) -> void:
	var text: String = params.get("text", "")
	var partial: bool = params.get("partial", true)
	if text.is_empty():
		_write_response({"error": "'text' is required"})
		return

	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	var btn: Button = _find_button_by_text(root, text, partial)
	if btn == null:
		_write_response({"error": "No visible button found with text: '%s'" % text})
		return

	var rect := btn.get_global_rect()
	var center := rect.get_center()

	# Emit the pressed signal directly — more reliable than Input.parse_input_event
	# which doesn't always reach GUI Controls.
	btn.emit_signal("pressed")

	_write_response({
		"clicked": true,
		"button_text": btn.text,
		"button_path": str(btn.get_path()),
		"position": {"x": center.x, "y": center.y},
	})


func _find_button_by_text(node: Node, text: String, partial: bool) -> Button:
	if node is Button and node.visible:
		var btn: Button = node
		var btn_text := btn.text.to_lower().strip_edges()
		var search_text := text.to_lower().strip_edges()
		if partial and btn_text.contains(search_text):
			return btn
		elif not partial and btn_text == search_text:
			return btn

	for child in node.get_children():
		var found := _find_button_by_text(child, text, partial)
		if found != null:
			return found
	return null


# ── wait_for_node ────────────────────────────────────────────────────────────

func _cmd_wait_for_node(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_write_response({"error": "'node_path' is required"})
		return

	var timeout_sec: float = params.get("timeout", 5.0)
	var poll_interval: int = maxi(int(params.get("poll_frames", 5)), 1)

	var attempts := int(timeout_sec / (poll_interval / 60.0))
	var frame_counter := 0

	for i in attempts:
		var node := get_node_or_null(NodePath(node_path))
		if node != null:
			var result := {
				"found": true,
				"node_path": str(node.get_path()),
				"type": node.get_class(),
				"name": str(node.name),
			}
			var script: Script = node.get_script()
			if script:
				result["script"] = script.resource_path
			_write_response(result)
			return

		# Wait poll_interval frames
		for _f in poll_interval:
			await get_tree().process_frame

	_write_response({
		"found": false,
		"node_path": node_path,
		"error": "Node not found after %.1fs" % timeout_sec,
	})


# ── assert_node_state ────────────────────────────────────────────────────────

func _cmd_assert_node_state(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	var operator: String = params.get("operator", "eq")

	if node_path.is_empty() or property.is_empty():
		_write_response({"error": "'node_path' and 'property' are required"})
		return

	if not params.has("expected"):
		_write_response({"error": "'expected' is required"})
		return

	var expected = params["expected"]

	var node := get_node_or_null(NodePath(node_path))
	if node == null:
		_write_response({
			"passed": false,
			"error": "Node not found: %s" % node_path,
			"node_path": node_path,
			"property": property,
			"operator": operator,
		})
		return

	var actual = node.get(property)
	var actual_serialized = _serialize_value(actual)
	var passed := false

	match operator:
		"eq":
			passed = str(actual) == str(expected) or actual_serialized == expected
		"neq":
			passed = str(actual) != str(expected) and actual_serialized != expected
		"gt":
			passed = float(actual) > float(expected)
		"lt":
			passed = float(actual) < float(expected)
		"gte":
			passed = float(actual) >= float(expected)
		"lte":
			passed = float(actual) <= float(expected)
		"contains":
			passed = str(actual).contains(str(expected))
		"type_is":
			passed = node.get_class() == str(expected) or typeof(actual) == int(expected)
		_:
			_write_response({"error": "Unknown operator: %s" % operator})
			return

	_write_response({
		"passed": passed,
		"node_path": node_path,
		"property": property,
		"operator": operator,
		"expected": expected,
		"actual": actual_serialized,
	})


# ── Recording ────────────────────────────────────────────────────────────────

func _cmd_start_recording(_params: Dictionary) -> void:
	_recording_events.clear()
	_recording_start_msec = Time.get_ticks_msec()
	_state = State.RECORDING
	set_process_input(true)
	_write_response({"recording": true, "message": "Recording started"})


func _cmd_stop_recording(_params: Dictionary) -> void:
	set_process_input(false)
	_state = State.IDLE
	var events := _recording_events.duplicate()
	var duration_ms := Time.get_ticks_msec() - _recording_start_msec
	_write_response({
		"recording": false,
		"events": events,
		"event_count": events.size(),
		"duration_ms": duration_ms,
	})


func _cmd_replay_recording(params: Dictionary) -> void:
	var events: Array = params.get("events", [])
	if events.is_empty():
		_write_response({"error": "No events to replay"})
		return

	var speed: float = params.get("speed", 1.0)

	# Replay events with timing
	var start_msec := Time.get_ticks_msec()
	for event_data: Dictionary in events:
		var delay_ms: int = event_data.get("time_ms", 0)
		var adjusted_delay := int(delay_ms / speed)

		# Wait until the right time
		while Time.get_ticks_msec() - start_msec < adjusted_delay:
			await get_tree().process_frame

		var event := _reconstruct_event(event_data)
		if event != null:
			Input.parse_input_event(event)

	_write_response({
		"replayed": true,
		"event_count": events.size(),
		"speed": speed,
	})


func _input(event: InputEvent) -> void:
	if _state != State.RECORDING:
		return

	var time_ms := Time.get_ticks_msec() - _recording_start_msec
	var data: Dictionary = {"time_ms": time_ms}

	if event is InputEventKey:
		var key: InputEventKey = event
		data["type"] = "key"
		data["keycode"] = OS.get_keycode_string(key.keycode) if key.keycode != 0 else ""
		data["physical_keycode"] = OS.get_keycode_string(key.physical_keycode) if key.physical_keycode != 0 else ""
		data["pressed"] = key.pressed
		data["shift"] = key.shift_pressed
		data["ctrl"] = key.ctrl_pressed
		data["alt"] = key.alt_pressed
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		data["type"] = "mouse_button"
		data["button"] = mb.button_index
		data["pressed"] = mb.pressed
		data["position"] = {"x": mb.position.x, "y": mb.position.y}
		data["double_click"] = mb.double_click
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		data["type"] = "mouse_motion"
		data["position"] = {"x": mm.position.x, "y": mm.position.y}
		data["relative"] = {"x": mm.relative.x, "y": mm.relative.y}
	elif event is InputEventAction:
		var act: InputEventAction = event
		data["type"] = "action"
		data["action"] = act.action
		data["pressed"] = act.pressed
		data["strength"] = act.strength
	else:
		return  # Skip unsupported event types

	_recording_events.append(data)


func _reconstruct_event(data: Dictionary) -> InputEvent:
	var type: String = data.get("type", "")
	match type:
		"key":
			var event := InputEventKey.new()
			var keycode_str: String = data.get("keycode", "")
			if not keycode_str.is_empty():
				event.keycode = OS.find_keycode_from_string(keycode_str)
			event.pressed = data.get("pressed", true)
			event.shift_pressed = data.get("shift", false)
			event.ctrl_pressed = data.get("ctrl", false)
			event.alt_pressed = data.get("alt", false)
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = data.get("button", MOUSE_BUTTON_LEFT)
			event.pressed = data.get("pressed", true)
			event.double_click = data.get("double_click", false)
			var pos: Dictionary = data.get("position", {})
			event.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
			event.global_position = event.position
			return event
		"mouse_motion":
			var event := InputEventMouseMotion.new()
			var pos: Dictionary = data.get("position", {})
			event.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
			event.global_position = event.position
			var rel: Dictionary = data.get("relative", {})
			event.relative = Vector2(rel.get("x", 0.0), rel.get("y", 0.0))
			return event
		"action":
			var event := InputEventAction.new()
			event.action = data.get("action", "")
			event.pressed = data.get("pressed", true)
			event.strength = data.get("strength", 1.0)
			return event
	return null


# ── Helpers ───────────────────────────────────────────────────────────────────

func _write_response(data: Dictionary) -> void:
	_pending_command = false
	var json := JSON.stringify(data)
	var file := FileAccess.open(RESPONSE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()


func _serialize_value(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_VECTOR2:
			var v: Vector2 = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR2I:
			var v: Vector2i = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR3:
			var v: Vector3 = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_VECTOR3I:
			var v: Vector3i = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_RECT2:
			var r: Rect2 = value
			return {"x": r.position.x, "y": r.position.y, "width": r.size.x, "height": r.size.y}
		TYPE_COLOR:
			var c: Color = value
			return {"r": c.r, "g": c.g, "b": c.b, "a": c.a, "html": "#" + c.to_html()}
		TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			if value is Resource:
				var res: Resource = value
				return {"type": res.get_class(), "path": res.resource_path}
			return str(value)
		TYPE_ARRAY:
			var arr: Array = value
			var result: Array = []
			for item in arr:
				result.append(_serialize_value(item))
			return result
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var result: Dictionary = {}
			for key in dict:
				result[str(key)] = _serialize_value(dict[key])
			return result
		_:
			return value
