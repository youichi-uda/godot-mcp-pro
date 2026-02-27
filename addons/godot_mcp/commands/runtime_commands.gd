@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Editor-side commands for runtime game inspection.
## Communicates with MCPGameInspector autoload via file-based IPC.


func get_commands() -> Dictionary:
	return {
		"get_game_scene_tree": _get_game_scene_tree,
		"get_game_node_properties": _get_game_node_properties,
		"set_game_node_property": _set_game_node_property,
		"capture_frames": _capture_frames,
		"monitor_properties": _monitor_properties,
		"execute_game_script": _execute_game_script,
		"start_recording": _start_recording,
		"stop_recording": _stop_recording,
		"replay_recording": _replay_recording,
		"find_nodes_by_script": _find_nodes_by_script,
		"get_autoload": _get_autoload,
		"batch_get_properties": _batch_get_properties,
		"find_ui_elements": _find_ui_elements,
		"click_button_by_text": _click_button_by_text,
		"wait_for_node": _wait_for_node,
	}


func _get_game_scene_tree(params: Dictionary) -> Dictionary:
	var max_depth: int = optional_int(params, "max_depth", -1)
	var cmd_params := {"max_depth": max_depth}

	var script_filter: String = optional_string(params, "script_filter")
	if not script_filter.is_empty():
		cmd_params["script_filter"] = script_filter

	var type_filter: String = optional_string(params, "type_filter")
	if not type_filter.is_empty():
		cmd_params["type_filter"] = type_filter

	var named_only: bool = optional_bool(params, "named_only", false)
	if named_only:
		cmd_params["named_only"] = true

	return await _send_game_command("get_scene_tree", cmd_params)


func _get_game_node_properties(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]

	var cmd_params := {"node_path": result[0]}
	# Optional property filter
	if params.has("properties") and params["properties"] is Array:
		cmd_params["properties"] = params["properties"]

	return await _send_game_command("get_node_properties", cmd_params)


func _set_game_node_property(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]

	var prop_result := require_string(params, "property")
	if prop_result[1] != null:
		return prop_result[1]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")

	return await _send_game_command("set_node_property", {
		"node_path": result[0],
		"property": prop_result[0],
		"value": params["value"],
	})


func _execute_game_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "code")
	if result[1] != null:
		return result[1]

	return await _send_game_command("execute_script", {
		"code": result[0],
	}, 10.0)


func _capture_frames(params: Dictionary) -> Dictionary:
	var count: int = optional_int(params, "count", 5)
	var frame_interval: int = optional_int(params, "frame_interval", 10)
	var half_resolution: bool = optional_bool(params, "half_resolution", true)

	# Dynamic timeout: allow enough time for frame capture
	# At 60fps, 30 frames * 10 interval = 300 frames = 5 seconds + overhead
	var estimated_seconds: float = (count * frame_interval) / 60.0 + 2.0
	var timeout := minf(estimated_seconds, 25.0)

	return await _send_game_command("capture_frames", {
		"count": count,
		"frame_interval": frame_interval,
		"half_resolution": half_resolution,
	}, timeout)


func _monitor_properties(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]

	if not params.has("properties") or not params["properties"] is Array:
		return error_invalid_params("'properties' array is required")

	var frame_count: int = optional_int(params, "frame_count", 60)
	var frame_interval: int = optional_int(params, "frame_interval", 1)

	# Dynamic timeout
	var estimated_seconds: float = (frame_count * frame_interval) / 60.0 + 2.0
	var timeout := minf(estimated_seconds, 25.0)

	return await _send_game_command("monitor_properties", {
		"node_path": result[0],
		"properties": params["properties"],
		"frame_count": frame_count,
		"frame_interval": frame_interval,
	}, timeout)


func _start_recording(params: Dictionary) -> Dictionary:
	return await _send_game_command("start_recording", {})


func _stop_recording(params: Dictionary) -> Dictionary:
	return await _send_game_command("stop_recording", {}, 5.0)


func _replay_recording(params: Dictionary) -> Dictionary:
	if not params.has("events") or not params["events"] is Array:
		return error_invalid_params("'events' array is required")
	var speed: float = float(params.get("speed", 1.0))

	# Calculate timeout based on event duration
	var max_time_ms: int = 0
	for event_data: Dictionary in params["events"]:
		var t: int = int(event_data.get("time_ms", 0))
		if t > max_time_ms:
			max_time_ms = t
	var timeout := (max_time_ms / 1000.0 / speed) + 5.0

	return await _send_game_command("replay_recording", {
		"events": params["events"],
		"speed": speed,
	}, minf(timeout, 120.0))


func _find_nodes_by_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "script")
	if result[1] != null:
		return result[1]

	var cmd_params := {"script": result[0]}
	if params.has("properties") and params["properties"] is Array:
		cmd_params["properties"] = params["properties"]

	return await _send_game_command("find_nodes_by_script", cmd_params)


func _get_autoload(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]

	var cmd_params := {"name": result[0]}
	if params.has("properties") and params["properties"] is Array:
		cmd_params["properties"] = params["properties"]

	return await _send_game_command("get_autoload", cmd_params)


func _batch_get_properties(params: Dictionary) -> Dictionary:
	if not params.has("nodes") or not params["nodes"] is Array:
		return error_invalid_params("'nodes' array is required")

	return await _send_game_command("batch_get_properties", {
		"nodes": params["nodes"],
	})


func _find_ui_elements(params: Dictionary) -> Dictionary:
	var cmd_params := {}
	var type_filter: String = optional_string(params, "type_filter")
	if not type_filter.is_empty():
		cmd_params["type_filter"] = type_filter
	return await _send_game_command("find_ui_elements", cmd_params)


func _click_button_by_text(params: Dictionary) -> Dictionary:
	var result := require_string(params, "text")
	if result[1] != null:
		return result[1]

	var cmd_params := {"text": result[0]}
	var partial: bool = optional_bool(params, "partial", true)
	cmd_params["partial"] = partial

	return await _send_game_command("click_button_by_text", cmd_params)


func _wait_for_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]

	var timeout: float = float(params.get("timeout", 5.0))
	var poll_frames: int = optional_int(params, "poll_frames", 5)

	return await _send_game_command("wait_for_node", {
		"node_path": result[0],
		"timeout": timeout,
		"poll_frames": poll_frames,
	}, timeout + 2.0)


# ── IPC Helper ────────────────────────────────────────────────────────────────

func _send_game_command(command: String, params: Dictionary, timeout_sec: float = 5.0) -> Dictionary:
	var ei := get_editor()
	if not ei.is_playing_scene():
		return error(-32000, "No scene is currently playing", {"suggestion": "Use play_scene first"})

	var user_dir := get_game_user_dir()
	var request_path := user_dir + "/mcp_game_request"
	var response_path := user_dir + "/mcp_game_response"

	# Clean stale response
	if FileAccess.file_exists(response_path):
		DirAccess.remove_absolute(response_path)

	# Write request
	var request_data := JSON.stringify({"command": command, "params": params})
	var req := FileAccess.open(request_path, FileAccess.WRITE)
	if req == null:
		return error_internal("Could not create game request file")
	req.store_string(request_data)
	req.close()

	# Poll for response
	var attempts := int(timeout_sec / 0.1)
	while attempts > 0:
		await get_tree().create_timer(0.1).timeout
		if FileAccess.file_exists(response_path):
			break
		# Check if game is still running
		if not ei.is_playing_scene():
			if FileAccess.file_exists(request_path):
				DirAccess.remove_absolute(request_path)
			return error(-32000, "Game stopped during command execution")
		attempts -= 1

	if not FileAccess.file_exists(response_path):
		# Try to auto-resume the debugger (runtime error may have paused the game)
		if ei.is_playing_scene():
			_try_debugger_continue()
			# Give the game a chance to recover and write a response
			for _retry in 20:
				await get_tree().create_timer(0.1).timeout
				if FileAccess.file_exists(response_path):
					break

	if not FileAccess.file_exists(response_path):
		if FileAccess.file_exists(request_path):
			DirAccess.remove_absolute(request_path)
		return error(-32000, "Game command timed out after %.1fs" % timeout_sec, {
			"suggestion": "Ensure the game is running and MCPGameInspector autoload is active",
		})

	# Read response
	var file := FileAccess.open(response_path, FileAccess.READ)
	if file == null:
		return error_internal("Could not read game response file")
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(response_path)

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return error_internal("Invalid response JSON from game")

	if parsed.has("error"):
		return error(-32000, str(parsed["error"]))

	return success(parsed)


## Press the debugger "Continue" button to resume a paused game process.
func _try_debugger_continue() -> void:
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	var queue: Array[Node] = [base]
	while not queue.is_empty():
		var node := queue.pop_front()
		if node.get_class() == "ScriptEditorDebugger":
			var inner: Array[Node] = [node]
			while not inner.is_empty():
				var n := inner.pop_front()
				if n is Button and n.tooltip_text == "Continue":
					n.emit_signal("pressed")
					push_warning("[MCP] Auto-resumed debugger after runtime error")
					return
				for c in n.get_children():
					inner.append(c)
			return
		for child in node.get_children():
			queue.append(child)
