## Autoload injected by Godot MCP Pro plugin at runtime.
## Handles runtime game inspection: scene tree, node properties, frame capture, property monitoring.
extends Node

const REQUEST_PATH := "user://mcp_game_request"
const RESPONSE_PATH := "user://mcp_game_response"

enum State { IDLE, CAPTURING_FRAMES, MONITORING, RECORDING, MOVING_TO }

var _state: State = State.IDLE
var _pending_command: bool = false  # Crash recovery flag

# Frame capture state
var _capture_frames_remaining: int = 0
var _capture_frame_interval: int = 1
var _capture_frame_counter: int = 0
var _capture_half_res: bool = true
var _captured_images: Array = []  # Array of base64 strings
var _capture_node_path: String = ""  # Optional node to track per frame
var _capture_node_props: Array = []  # Properties to snapshot per frame
var _capture_frame_data: Array = []  # Array of per-frame node snapshots

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

# Move-to state
var _moveto_target: Vector3 = Vector3.ZERO
var _moveto_player: Node3D = null
var _moveto_camera_pivot: Node3D = null
var _moveto_arrival_radius: float = 1.5
var _moveto_timeout: float = 15.0
var _moveto_elapsed: float = 0.0
var _moveto_run: bool = false
var _moveto_look_at: bool = true
var _moveto_keys_held: Array = []  # Track injected keys for guaranteed release


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Crash recovery: if a command was in progress but never wrote a response
	if _pending_command and not FileAccess.file_exists(REQUEST_PATH) and not FileAccess.file_exists(RESPONSE_PATH):
		push_warning("[MCP] Recovered from crashed command — writing error response")
		_pending_command = false
		_state = State.IDLE
		# Signal editor plugin to auto-press debugger Continue
		var flag := FileAccess.open("user://mcp_debugger_continue", FileAccess.WRITE)
		if flag:
			flag.close()
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
		State.MOVING_TO:
			_process_move_to(_delta)


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
		"find_nearby_nodes":
			_cmd_find_nearby_nodes(params)
		"navigate_to":
			_cmd_navigate_to(params)
		"move_to":
			_cmd_move_to(params)
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
	if named_only and (node.name as String).begins_with("@"):
		return false
	if not type_filter.is_empty() and not node.is_class(type_filter):
		return false
	if not script_filter.is_empty():
		var script: Script = node.get_script()
		if script == null:
			return false
		if not script.resource_path.to_lower().contains(script_filter.to_lower()):
			return false
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
	_pending_command = false  # Async command — don't trigger crash recovery
	var count: int = clampi(params.get("count", 5), 1, 30)
	var interval: int = maxi(params.get("frame_interval", 10), 1)
	_capture_half_res = params.get("half_resolution", true)

	# Optional node_data tracking
	_capture_node_path = ""
	_capture_node_props = []
	_capture_frame_data.clear()
	var node_data: Dictionary = params.get("node_data", {})
	if not node_data.is_empty():
		_capture_node_path = node_data.get("node_path", "")
		_capture_node_props = node_data.get("properties", [])

	_captured_images.clear()
	_capture_frames_remaining = count
	_capture_frame_interval = interval
	_capture_frame_counter = 0
	_state = State.CAPTURING_FRAMES
	_capture_one_frame()


func _process_capture() -> void:
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

	# Snapshot node properties if tracking
	if not _capture_node_path.is_empty() and not _capture_node_props.is_empty():
		var snap := {}
		var node := get_tree().root.get_node_or_null(_capture_node_path)
		if node:
			for prop_name in _capture_node_props:
				var val = node.get(prop_name)
				snap[prop_name] = _serialize_value(val)
		_capture_frame_data.append(snap)

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

	var response := {
		"frames": _captured_images,
		"count": _captured_images.size(),
		"width": w,
		"height": h,
		"half_resolution": _capture_half_res,
	}
	if not _capture_frame_data.is_empty():
		response["frame_data"] = _capture_frame_data
	_write_response(response)
	_captured_images.clear()
	_capture_frame_data.clear()


# ── monitor_properties ────────────────────────────────────────────────────────

func _cmd_monitor_properties(params: Dictionary) -> void:
	_pending_command = false  # Async command — don't trigger crash recovery
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
	_sample_one_frame()


func _process_monitor() -> void:
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
	if typeof(raw) == target_type:
		return raw

	# Handle Dictionary → Vector2/Vector3/Color conversion
	if raw is Dictionary:
		var dict: Dictionary = raw
		match target_type:
			TYPE_VECTOR3:
				return Vector3(
					float(dict.get("x", 0)),
					float(dict.get("y", 0)),
					float(dict.get("z", 0))
				)
			TYPE_VECTOR3I:
				return Vector3i(
					int(dict.get("x", 0)),
					int(dict.get("y", 0)),
					int(dict.get("z", 0))
				)
			TYPE_VECTOR2:
				return Vector2(
					float(dict.get("x", 0)),
					float(dict.get("y", 0))
				)
			TYPE_VECTOR2I:
				return Vector2i(
					int(dict.get("x", 0)),
					int(dict.get("y", 0))
				)
			TYPE_COLOR:
				return Color(
					float(dict.get("r", 0)),
					float(dict.get("g", 0)),
					float(dict.get("b", 0)),
					float(dict.get("a", 1))
				)
		return raw

	if raw is String:
		var raw_str: String = raw
		if raw_str.begins_with("#"):
			return Color.html(raw_str)

		var expr := Expression.new()
		var err := expr.parse(raw_str)
		if err == OK:
			var result: Variant = expr.execute()
			if not expr.has_execute_failed():
				return result
		return raw_str

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


# ── find_nearby_nodes ─────────────────────────────────────────────────────────

func _cmd_find_nearby_nodes(params: Dictionary) -> void:
	var radius: float = float(params.get("radius", 20.0))
	var max_results: int = int(params.get("max_results", 10))
	var type_filter: String = params.get("type_filter", "")
	var group_filter: String = params.get("group_filter", "")

	# Resolve origin position
	var origin := Vector3.ZERO
	var position_param: Variant = params.get("position", null)
	if position_param is String:
		# node_path — use its global_position
		var origin_node := get_node_or_null(NodePath(position_param as String))
		if origin_node == null:
			_write_response({"error": "Origin node not found: %s" % position_param})
			return
		if origin_node is Node3D:
			origin = (origin_node as Node3D).global_position
		elif origin_node is Node2D:
			var pos2d: Vector2 = (origin_node as Node2D).global_position
			origin = Vector3(pos2d.x, pos2d.y, 0)
		else:
			_write_response({"error": "Origin node is not Node2D or Node3D: %s" % position_param})
			return
	elif position_param is Dictionary:
		var dict: Dictionary = position_param
		origin = Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
	elif position_param == null:
		_write_response({"error": "'position' is required (node_path string or {x,y,z} object)"})
		return

	var root := get_tree().current_scene
	if root == null:
		_write_response({"error": "No current scene"})
		return

	# Collect all spatial nodes within radius
	var candidates: Array = []
	_find_nearby_recursive(root, origin, radius, type_filter, group_filter, candidates)

	# Sort by distance
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"]
	)

	# Limit results
	if candidates.size() > max_results:
		candidates.resize(max_results)

	_write_response({
		"origin": {"x": origin.x, "y": origin.y, "z": origin.z},
		"radius": radius,
		"nodes": candidates,
		"count": candidates.size(),
	})


func _find_nearby_recursive(node: Node, origin: Vector3, radius: float, type_filter: String, group_filter: String, results: Array) -> void:
	var pos := Vector3.ZERO
	var is_spatial := false

	if node is Node3D:
		pos = (node as Node3D).global_position
		is_spatial = true
	elif node is Node2D:
		var pos2d: Vector2 = (node as Node2D).global_position
		pos = Vector3(pos2d.x, pos2d.y, 0)
		is_spatial = true

	if is_spatial:
		var diff := pos - origin
		var dist := diff.length()
		if dist <= radius:
			# Apply filters
			var passes := true
			if not type_filter.is_empty() and not node.is_class(type_filter):
				passes = false
			if not group_filter.is_empty() and not node.is_in_group(group_filter):
				passes = false

			if passes:
				var entry: Dictionary = {
					"node_path": str(node.get_path()),
					"name": str(node.name),
					"type": node.get_class(),
					"distance": snappedf(dist, 0.01),
					"global_position": {"x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01), "z": snappedf(pos.z, 0.01)},
					"direction": {"x": snappedf(diff.x, 0.01), "y": snappedf(diff.y, 0.01), "z": snappedf(diff.z, 0.01)},
				}
				var script: Script = node.get_script()
				if script:
					entry["script"] = script.resource_path
				results.append(entry)

	for child in node.get_children():
		_find_nearby_recursive(child, origin, radius, type_filter, group_filter, results)


# ── navigate_to ──────────────────────────────────────────────────────────────

func _cmd_navigate_to(params: Dictionary) -> void:
	# Resolve player position
	var player_path: String = params.get("player_path", "/root/Main/Player")
	var player := get_node_or_null(NodePath(player_path))
	if player == null:
		_write_response({"error": "Player not found: %s" % player_path})
		return

	var player_pos := Vector3.ZERO
	if player is Node3D:
		player_pos = (player as Node3D).global_position
	else:
		_write_response({"error": "Player is not Node3D: %s" % player_path})
		return

	# Resolve target position
	var target_param: Variant = params.get("target", null)
	var target_pos := Vector3.ZERO
	if target_param is String:
		var target_node := get_node_or_null(NodePath(target_param as String))
		if target_node == null:
			_write_response({"error": "Target node not found: %s" % target_param})
			return
		if target_node is Node3D:
			target_pos = (target_node as Node3D).global_position
		else:
			_write_response({"error": "Target is not Node3D: %s" % target_param})
			return
	elif target_param is Dictionary:
		var dict: Dictionary = target_param
		target_pos = Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
	else:
		_write_response({"error": "'target' is required (node_path string or {x,y,z} object)"})
		return

	# Calculate world direction (XZ plane for 3D movement)
	var world_dir := target_pos - player_pos
	var distance := world_dir.length()
	var flat_dir := Vector3(world_dir.x, 0, world_dir.z).normalized()

	# Find camera for relative direction
	var camera_path: String = params.get("camera_path", "")
	var camera: Camera3D = null
	if not camera_path.is_empty():
		var cam_node := get_node_or_null(NodePath(camera_path))
		if cam_node is Camera3D:
			camera = cam_node
	else:
		# Auto-detect: find Camera3D in scene
		camera = get_viewport().get_camera_3d()

	var suggested_keys: Array = []
	var camera_yaw_delta: float = 0.0
	var camera_forward := Vector3.ZERO

	if camera != null:
		# Camera forward (XZ plane)
		camera_forward = -camera.global_basis.z
		var cam_flat := Vector3(camera_forward.x, 0, camera_forward.z).normalized()
		var cam_right := Vector3(camera_forward.z, 0, -camera_forward.x).normalized()

		if flat_dir.length() > 0.01:
			# Project target direction onto camera axes
			var forward_dot := flat_dir.dot(cam_flat)
			var right_dot := flat_dir.dot(cam_right)

			# Suggest keys based on dominant direction
			if forward_dot > 0.3:
				suggested_keys.append("KEY_W")
			elif forward_dot < -0.3:
				suggested_keys.append("KEY_S")
			if right_dot > 0.3:
				suggested_keys.append("KEY_D")
			elif right_dot < -0.3:
				suggested_keys.append("KEY_A")

			# Calculate yaw rotation needed to face target directly (W only)
			var angle_to_target := atan2(flat_dir.x, flat_dir.z)
			var cam_yaw := atan2(cam_flat.x, cam_flat.z)
			camera_yaw_delta = angle_to_target - cam_yaw
			# Normalize to [-PI, PI]
			while camera_yaw_delta > PI:
				camera_yaw_delta -= TAU
			while camera_yaw_delta < -PI:
				camera_yaw_delta += TAU

	# Estimate walk duration (rough: assume ~5 units/sec movement speed)
	var move_speed: float = float(params.get("move_speed", 5.0))
	var estimated_duration := distance / move_speed if move_speed > 0 else 0.0

	# Convert yaw delta to approximate mouse relative_x pixels
	# Typical: 400px mouse movement ≈ PI radians
	var mouse_sensitivity_scale: float = 400.0 / PI
	var suggested_mouse_x := -camera_yaw_delta * mouse_sensitivity_scale

	_write_response({
		"distance": snappedf(distance, 0.01),
		"world_direction": {
			"x": snappedf(world_dir.x, 0.01),
			"y": snappedf(world_dir.y, 0.01),
			"z": snappedf(world_dir.z, 0.01),
		},
		"flat_direction": {
			"x": snappedf(flat_dir.x, 0.01),
			"z": snappedf(flat_dir.z, 0.01),
		},
		"suggested_keys": suggested_keys,
		"camera_rotation_delta": {
			"yaw_radians": snappedf(camera_yaw_delta, 0.001),
			"suggested_mouse_relative_x": snappedf(suggested_mouse_x, 1.0),
		},
		"estimated_duration": snappedf(estimated_duration, 0.1),
		"player_position": {"x": snappedf(player_pos.x, 0.01), "y": snappedf(player_pos.y, 0.01), "z": snappedf(player_pos.z, 0.01)},
		"target_position": {"x": snappedf(target_pos.x, 0.01), "y": snappedf(target_pos.y, 0.01), "z": snappedf(target_pos.z, 0.01)},
	})


# ── move_to ───────────────────────────────────────────────────────────────────

func _cmd_move_to(params: Dictionary) -> void:
	# Resolve player node
	var player_path: String = params.get("player_path", "/root/Main/Player")
	var player := get_node_or_null(NodePath(player_path))
	if player == null or not player is Node3D:
		_write_response({"error": "Player not found or not Node3D: %s" % player_path})
		return

	_moveto_player = player as Node3D

	# Resolve target position
	var target_param: Variant = params.get("target", null)
	if target_param is String:
		var target_node := get_node_or_null(NodePath(target_param as String))
		if target_node == null:
			_write_response({"error": "Target node not found: %s" % target_param})
			return
		if target_node is Node3D:
			_moveto_target = (target_node as Node3D).global_position
		else:
			_write_response({"error": "Target is not Node3D: %s" % target_param})
			return
	elif target_param is Dictionary:
		var dict: Dictionary = target_param
		_moveto_target = Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
	else:
		_write_response({"error": "'target' is required (node_path string or {x,y,z} object)"})
		return

	# Resolve camera pivot
	_moveto_camera_pivot = null
	var camera_path: String = params.get("camera_path", "")
	if not camera_path.is_empty():
		var cam_node := get_node_or_null(NodePath(camera_path))
		if cam_node is Node3D:
			_moveto_camera_pivot = cam_node as Node3D
	else:
		# Auto-detect: look for SpringArm3D child of player
		for child in _moveto_player.get_children():
			if child is SpringArm3D:
				_moveto_camera_pivot = child as Node3D
				break
		# Fallback: active Camera3D's parent
		if _moveto_camera_pivot == null:
			var cam := get_viewport().get_camera_3d()
			if cam != null and cam.get_parent() is Node3D and cam.get_parent() != get_tree().root:
				_moveto_camera_pivot = cam.get_parent() as Node3D

	# Read params
	_moveto_arrival_radius = float(params.get("arrival_radius", 1.5))
	_moveto_timeout = float(params.get("timeout", 15.0))
	_moveto_run = bool(params.get("run", false))
	_moveto_look_at = bool(params.get("look_at_target", true))
	_moveto_elapsed = 0.0
	_moveto_keys_held.clear()

	# Check if already at target
	var dist := _moveto_player.global_position.distance_to(_moveto_target)
	if dist <= _moveto_arrival_radius:
		_write_response({
			"success": true,
			"arrived": true,
			"final_distance": snappedf(dist, 0.01),
			"final_position": _serialize_value(_moveto_player.global_position),
			"target_position": _serialize_value(_moveto_target),
			"elapsed_time": 0.0,
		})
		return

	# Start walking — async state, don't trigger crash recovery
	_pending_command = false
	_state = State.MOVING_TO

	# Inject walk key
	_inject_key(KEY_W, true)
	if _moveto_run:
		_inject_key(KEY_SHIFT, true)


func _process_move_to(delta: float) -> void:
	# Check for abort (new command arrived)
	if FileAccess.file_exists(REQUEST_PATH):
		_finish_move_to(false, "Aborted by new command")
		_state = State.IDLE
		_handle_request()
		return

	_moveto_elapsed += delta

	# Timeout check
	if _moveto_elapsed >= _moveto_timeout:
		_finish_move_to(false, "Timeout after %.1fs" % _moveto_timeout)
		return

	# Safety: player freed
	if not is_instance_valid(_moveto_player):
		_finish_move_to(false, "Player node was freed")
		return

	var player_pos := _moveto_player.global_position
	var flat_target := Vector3(_moveto_target.x, player_pos.y, _moveto_target.z)
	var dist := player_pos.distance_to(flat_target)

	# Arrival check (XZ distance only, ignore Y)
	if dist <= _moveto_arrival_radius:
		_finish_move_to(true, "Arrived")
		return

	# Rotate camera pivot toward target
	if _moveto_look_at and _moveto_camera_pivot != null and is_instance_valid(_moveto_camera_pivot):
		var dir := flat_target - player_pos
		if dir.length_squared() > 0.01:
			var target_yaw := atan2(-dir.x, -dir.z)
			var current_yaw: float = _moveto_camera_pivot.rotation.y
			# Lerp toward target yaw (~10 rad/s)
			var yaw_diff := target_yaw - current_yaw
			# Normalize to [-PI, PI]
			while yaw_diff > PI:
				yaw_diff -= TAU
			while yaw_diff < -PI:
				yaw_diff += TAU
			var max_step := 10.0 * delta
			var step := clampf(yaw_diff, -max_step, max_step)
			_moveto_camera_pivot.rotation.y += step


func _finish_move_to(success: bool, message: String) -> void:
	# Release all held keys
	_release_all_keys()
	_state = State.IDLE

	var final_pos := Vector3.ZERO
	var final_dist := 0.0
	if is_instance_valid(_moveto_player):
		final_pos = _moveto_player.global_position
		final_dist = final_pos.distance_to(_moveto_target)

	_write_response({
		"success": success,
		"arrived": success,
		"message": message,
		"final_distance": snappedf(final_dist, 0.01),
		"final_position": _serialize_value(final_pos),
		"target_position": _serialize_value(_moveto_target),
		"elapsed_time": snappedf(_moveto_elapsed, 0.01),
	})


func _inject_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed:
		_moveto_keys_held.append(keycode)
	else:
		_moveto_keys_held.erase(keycode)


func _release_all_keys() -> void:
	for keycode: int in _moveto_keys_held.duplicate():
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = false
		Input.parse_input_event(event)
	_moveto_keys_held.clear()


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

	var start_msec := Time.get_ticks_msec()
	for event_data: Dictionary in events:
		var delay_ms: int = event_data.get("time_ms", 0)
		var adjusted_delay := int(delay_ms / speed)

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
		return

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
