@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Test automation framework tools.
## Editor-side orchestration + runtime assertions via file-based IPC.


func get_commands() -> Dictionary:
	return {
		"run_test_scenario": _run_test_scenario,
		"assert_node_state": _assert_node_state,
		"assert_screen_text": _assert_screen_text,
		"run_stress_test": _run_stress_test,
		"get_test_report": _get_test_report,
	}


# ── Internal test result accumulator ──────────────────────────────────────────

var _test_results: Array[Dictionary] = []


# ── Commands ──────────────────────────────────────────────────────────────────

func _run_test_scenario(params: Dictionary) -> Dictionary:
	## Execute a test scenario: optionally play a scene, run a sequence of steps
	## (input simulation, waits, assertions, screenshots), return pass/fail results.
	##
	## Steps array: [{type: "input"|"wait"|"assert"|"screenshot", ...params}]
	##   - input: {type:"input", action:str, pressed:bool} or {type:"input", keycode:str}
	##   - wait: {type:"wait", seconds:float} or {type:"wait", node_path:str, timeout:float}
	##   - assert: {type:"assert", node_path:str, property:str, expected:val, operator:str}
	##   - screenshot: {type:"screenshot"} — captures a frame for visual inspection

	if not params.has("steps") or not params["steps"] is Array:
		return error_invalid_params("Missing required parameter: steps (Array)")

	var steps: Array = params["steps"]
	if steps.is_empty():
		return error_invalid_params("Steps array is empty")

	var scene_path: String = optional_string(params, "scene_path")
	var ei := get_editor()

	# Play scene if requested
	if not scene_path.is_empty():
		if ei.is_playing_scene():
			ei.stop_playing_scene()
			await get_tree().create_timer(0.5).timeout

		if scene_path == "main":
			ei.play_main_scene()
		elif scene_path == "current":
			ei.play_current_scene()
		else:
			if not FileAccess.file_exists(scene_path):
				return error_not_found("Scene file '%s'" % scene_path)
			ei.play_custom_scene(scene_path)

		# Wait for game to start
		await get_tree().create_timer(1.0).timeout

	# Verify game is running
	if not ei.is_playing_scene():
		return error(-32000, "No scene is currently playing", {
			"suggestion": "Provide scene_path or use play_scene first"
		})

	var results: Array[Dictionary] = []
	var pass_count: int = 0
	var fail_count: int = 0
	var error_count: int = 0

	for i in steps.size():
		var step: Dictionary = steps[i]
		if not step.has("type"):
			results.append({"step": i, "error": "Missing 'type' field"})
			error_count += 1
			continue

		var step_type: String = str(step["type"])
		var step_result: Dictionary = {"step": i, "type": step_type}

		match step_type:
			"input":
				var input_result := await _execute_input_step(step)
				step_result.merge(input_result)

			"wait":
				var wait_result := await _execute_wait_step(step)
				step_result.merge(wait_result)

			"assert":
				var assert_result := await _execute_assert_step(step)
				step_result.merge(assert_result)
				if assert_result.get("passed", false):
					pass_count += 1
				else:
					fail_count += 1

			"screenshot":
				var screenshot_result := await _send_game_command("capture_frames", {
					"count": 1,
					"frame_interval": 1,
					"half_resolution": optional_bool(step, "half_resolution", true),
				}, 5.0)
				if screenshot_result.has("result"):
					step_result["captured"] = true
				else:
					step_result["captured"] = false
					step_result["error"] = "Screenshot capture failed"
					error_count += 1

			_:
				step_result["error"] = "Unknown step type: %s" % step_type
				error_count += 1

		results.append(step_result)

		# Check if game crashed between steps
		if not ei.is_playing_scene():
			results.append({"step": i + 1, "error": "Game stopped unexpectedly"})
			error_count += 1
			break

	var summary := {
		"total_steps": steps.size(),
		"completed_steps": results.size(),
		"assertions_passed": pass_count,
		"assertions_failed": fail_count,
		"errors": error_count,
		"all_passed": fail_count == 0 and error_count == 0,
		"results": results,
	}

	# Store results for get_test_report
	_test_results.append_array(results)

	return success(summary)


func _assert_node_state(params: Dictionary) -> Dictionary:
	## Assert a node's property equals expected value in the running game.
	## Supports operators: eq, neq, gt, lt, gte, lte, contains, type_is.
	## Returns pass/fail with actual value.

	var path_result := require_string(params, "node_path")
	if path_result[1] != null:
		return path_result[1]

	var prop_result := require_string(params, "property")
	if prop_result[1] != null:
		return prop_result[1]

	if not params.has("expected"):
		return error_invalid_params("Missing required parameter: expected")

	var operator: String = optional_string(params, "operator", "eq")
	var valid_operators := ["eq", "neq", "gt", "lt", "gte", "lte", "contains", "type_is"]
	if operator not in valid_operators:
		return error_invalid_params("Invalid operator '%s'. Valid: %s" % [operator, str(valid_operators)])

	var result := await _send_game_command("assert_node_state", {
		"node_path": path_result[0],
		"property": prop_result[0],
		"expected": params["expected"],
		"operator": operator,
	}, 5.0)

	# Store for test report
	if result.has("result"):
		_test_results.append(result["result"])

	return result


func _assert_screen_text(params: Dictionary) -> Dictionary:
	## Assert that specific text is visible on screen.
	## Uses find_ui_elements internally to check all visible UI text.

	var text_result := require_string(params, "text")
	if text_result[1] != null:
		return text_result[1]

	var expected_text: String = text_result[0]
	var partial: bool = optional_bool(params, "partial", true)
	var case_sensitive: bool = optional_bool(params, "case_sensitive", true)

	# Use find_ui_elements to get all visible UI text
	var ui_result := await _send_game_command("find_ui_elements", {})
	if ui_result.has("error"):
		return ui_result

	var elements: Array = []
	if ui_result.has("result") and ui_result["result"].has("elements"):
		elements = ui_result["result"]["elements"]

	var found := false
	var matched_element: Dictionary = {}
	var all_texts: Array[String] = []

	for element: Dictionary in elements:
		var element_text: String = str(element.get("text", ""))
		if element_text.is_empty():
			continue
		all_texts.append(element_text)

		var search_text := expected_text
		var compare_text := element_text
		if not case_sensitive:
			search_text = search_text.to_lower()
			compare_text = compare_text.to_lower()

		if partial:
			if compare_text.contains(search_text):
				found = true
				matched_element = element
				break
		else:
			if compare_text == search_text:
				found = true
				matched_element = element
				break

	var assertion := {
		"passed": found,
		"expected_text": expected_text,
		"partial": partial,
		"case_sensitive": case_sensitive,
	}

	if found:
		assertion["matched_element"] = {
			"text": matched_element.get("text", ""),
			"type": matched_element.get("type", ""),
			"path": matched_element.get("path", ""),
		}
	else:
		assertion["visible_texts"] = all_texts

	# Store for test report
	_test_results.append(assertion)

	return success(assertion)


func _run_stress_test(params: Dictionary) -> Dictionary:
	## Run rapid random inputs for N seconds and check for crashes.
	## Returns frame count, timing, and any errors from game output.

	var duration: float = float(params.get("duration", 5.0))
	if duration <= 0 or duration > 60:
		return error_invalid_params("Duration must be between 0 and 60 seconds")

	var ei := get_editor()
	if not ei.is_playing_scene():
		return error(-32000, "No scene is currently playing", {
			"suggestion": "Use play_scene first"
		})

	# Record initial error count from log
	var initial_errors := _count_log_errors()

	# Generate random input events
	var actions := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]
	# Add common game actions if specified
	var custom_actions: Array = params.get("actions", [])
	for action in custom_actions:
		actions.append(str(action))

	var events_sent: int = 0
	var start_time := Time.get_ticks_msec()
	var duration_ms := int(duration * 1000.0)

	while Time.get_ticks_msec() - start_time < duration_ms:
		if not ei.is_playing_scene():
			var elapsed := (Time.get_ticks_msec() - start_time) / 1000.0
			return success({
				"completed": false,
				"crashed": true,
				"elapsed_seconds": elapsed,
				"events_sent": events_sent,
				"error": "Game stopped during stress test",
			})

		# Send a batch of random inputs
		var batch: Array = []
		for j in 3:
			var action_name: String = actions[randi() % actions.size()]
			batch.append({
				"type": "action",
				"action": action_name,
				"pressed": true,
				"strength": 1.0,
			})
			batch.append({
				"type": "action",
				"action": action_name,
				"pressed": false,
				"strength": 0.0,
			})

		# Write input commands directly (same as input_commands)
		var json := JSON.stringify({
			"sequence_events": batch,
			"frame_delay": 1,
		})
		var file := FileAccess.open("user://mcp_input_commands", FileAccess.WRITE)
		if file:
			file.store_string(json)
			file.close()
			events_sent += batch.size()

		await get_tree().create_timer(0.1).timeout

	var elapsed := (Time.get_ticks_msec() - start_time) / 1000.0
	var final_errors := _count_log_errors()
	var new_errors := final_errors - initial_errors

	# Check if game is still running
	var still_running := ei.is_playing_scene()

	return success({
		"completed": true,
		"crashed": not still_running,
		"duration_seconds": elapsed,
		"events_sent": events_sent,
		"new_errors": new_errors,
		"game_still_running": still_running,
	})


func _get_test_report(params: Dictionary) -> Dictionary:
	## Collect and format results from accumulated assertions into a test report.
	## Returns pass count, fail count, and detailed results.

	var clear: bool = optional_bool(params, "clear", true)

	var pass_count: int = 0
	var fail_count: int = 0
	var details: Array[Dictionary] = []

	for result: Dictionary in _test_results:
		var passed: bool = result.get("passed", false)
		if passed:
			pass_count += 1
		else:
			fail_count += 1
		details.append(result)

	var report := {
		"total": _test_results.size(),
		"passed": pass_count,
		"failed": fail_count,
		"pass_rate": ("%.1f%%" % (100.0 * pass_count / _test_results.size())) if not _test_results.is_empty() else "N/A",
		"all_passed": fail_count == 0 and not _test_results.is_empty(),
		"details": details,
	}

	if clear:
		_test_results.clear()

	return success(report)


# ── Step Executors (for run_test_scenario) ────────────────────────────────────

func _execute_input_step(step: Dictionary) -> Dictionary:
	## Execute an input step: simulate action or key press.
	var events: Array = []

	if step.has("action"):
		var pressed: bool = step.get("pressed", true) as bool
		events.append({
			"type": "action",
			"action": str(step["action"]),
			"pressed": pressed,
			"strength": float(step.get("strength", 1.0)),
		})
		# Auto-release if pressed
		if pressed and step.get("auto_release", true):
			events.append({
				"type": "action",
				"action": str(step["action"]),
				"pressed": false,
				"strength": 0.0,
			})
	elif step.has("keycode"):
		var pressed: bool = step.get("pressed", true) as bool
		events.append({
			"type": "key",
			"keycode": str(step["keycode"]),
			"pressed": pressed,
			"shift": step.get("shift", false),
			"ctrl": step.get("ctrl", false),
			"alt": step.get("alt", false),
		})
	else:
		return {"error": "Input step requires 'action' or 'keycode'"}

	var json := JSON.stringify({
		"sequence_events": events,
		"frame_delay": int(step.get("frame_delay", 1)),
	})
	var file := FileAccess.open("user://mcp_input_commands", FileAccess.WRITE)
	if file == null:
		return {"error": "Failed to write input commands"}
	file.store_string(json)
	file.close()

	return {"sent": true, "event_count": events.size()}


func _execute_wait_step(step: Dictionary) -> Dictionary:
	## Execute a wait step: wait for seconds or wait for a node to appear.
	if step.has("node_path"):
		var timeout: float = float(step.get("timeout", 5.0))
		var result := await _send_game_command("wait_for_node", {
			"node_path": str(step["node_path"]),
			"timeout": timeout,
			"poll_frames": int(step.get("poll_frames", 5)),
		}, timeout + 2.0)
		if result.has("error"):
			return {"error": "Wait for node failed: %s" % str(result["error"])}
		return {"waited_for": str(step["node_path"]), "found": true}
	else:
		var seconds: float = float(step.get("seconds", 1.0))
		await get_tree().create_timer(seconds).timeout
		return {"waited_seconds": seconds}


func _execute_assert_step(step: Dictionary) -> Dictionary:
	## Execute an assertion step within a scenario.
	if step.has("text"):
		# Screen text assertion
		var ui_result := await _send_game_command("find_ui_elements", {})
		if ui_result.has("error"):
			return {"passed": false, "error": "Could not get UI elements"}

		var elements: Array = []
		if ui_result.has("result") and ui_result["result"].has("elements"):
			elements = ui_result["result"]["elements"]

		var expected_text: String = str(step["text"])
		var partial: bool = step.get("partial", true) as bool
		for element: Dictionary in elements:
			var element_text: String = str(element.get("text", ""))
			if partial and element_text.contains(expected_text):
				return {"passed": true, "type": "screen_text", "expected": expected_text, "found_in": element_text}
			elif not partial and element_text == expected_text:
				return {"passed": true, "type": "screen_text", "expected": expected_text, "found_in": element_text}

		return {"passed": false, "type": "screen_text", "expected": expected_text, "error": "Text not found on screen"}

	elif step.has("node_path") and step.has("property"):
		# Node state assertion
		var result := await _send_game_command("assert_node_state", {
			"node_path": str(step["node_path"]),
			"property": str(step["property"]),
			"expected": step.get("expected", null),
			"operator": str(step.get("operator", "eq")),
		}, 5.0)
		if result.has("result"):
			return result["result"]
		elif result.has("error"):
			return {"passed": false, "error": str(result["error"])}
		return {"passed": false, "error": "Unknown assertion error"}

	else:
		return {"passed": false, "error": "Assert step requires 'text' or 'node_path'+'property'"}


# ── IPC Helper ────────────────────────────────────────────────────────────────

func _send_game_command(command: String, params: Dictionary = {}, timeout_sec: float = 5.0) -> Dictionary:
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
		# Try to auto-resume the debugger
		if ei.is_playing_scene():
			_try_debugger_continue()
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


# ── Utility ───────────────────────────────────────────────────────────────────

func _count_log_errors() -> int:
	var count: int = 0
	var log_path := "user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		var file := FileAccess.open(log_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var lines := content.split("\n")
			for line: String in lines:
				if line.contains("ERROR") or line.contains("SCRIPT ERROR"):
					count += 1
	return count
