@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const COMMANDS_PATH := "user://mcp_input_commands"
## How long to wait for the game to consume the previous payload.
const COMMAND_CONSUME_TIMEOUT_SEC := 1.0


func get_commands() -> Dictionary:
	return {
		"simulate_key": _simulate_key,
		"simulate_mouse_click": _simulate_mouse_click,
		"simulate_mouse_move": _simulate_mouse_move,
		"simulate_action": _simulate_action,
		"simulate_sequence": _simulate_sequence,
	}


func _simulate_key(params: Dictionary) -> Dictionary:
	var result := require_string(params, "keycode")
	if result[1] != null:
		return result[1]
	var keycode: String = result[0]

	var pressed: bool = optional_bool(params, "pressed", true)
	var shift: bool = optional_bool(params, "shift", false)
	var ctrl: bool = optional_bool(params, "ctrl", false)
	var alt: bool = optional_bool(params, "alt", false)

	var event := {
		"type": "key",
		"keycode": keycode,
		"pressed": pressed,
		"shift": shift,
		"ctrl": ctrl,
		"alt": alt,
	}
	# hold_sec: the game releases the key itself this long after the press is
	# actually dispatched. Timing it on the MCP side instead breaks when the
	# press waits in the game's queue behind a running sequence: press and
	# release would then land one frame apart.
	var hold_sec: float = optional_float(params, "hold_sec", 0.0)
	if hold_sec > 0.0:
		if not pressed:
			return error_invalid_params("hold_sec needs pressed=true")
		if is_nan(hold_sec) or is_inf(hold_sec) or hold_sec > 600.0:
			return error_invalid_params("hold_sec must be a finite number of seconds up to 600")
		event["hold_sec"] = hold_sec
	var write_result: Dictionary = await _write_payload([event])
	if not write_result.is_empty():
		return write_result
	# hold_supported tells the MCP server this addon releases held keys
	# itself; an older addon lacks it, and the server then releases on a timer.
	return success({"sent": true, "event": event, "hold_supported": true})


func _simulate_mouse_click(params: Dictionary) -> Dictionary:
	var button: int = optional_int(params, "button", 1)  # MOUSE_BUTTON_LEFT
	var pressed: bool = optional_bool(params, "pressed", true)
	var double_click: bool = optional_bool(params, "double_click", false)
	var auto_release: bool = optional_bool(params, "auto_release", true)
	var x: float = optional_float(params, "x", 0.0)
	var y: float = optional_float(params, "y", 0.0)

	var press_event := {
		"type": "mouse_button",
		"button": button,
		"pressed": pressed,
		"double_click": double_click,
		"position": {"x": x, "y": y},
	}

	# Auto-release: send press + release in sequence so UI buttons actually fire
	if pressed and auto_release:
		var release_event := press_event.duplicate()
		release_event["pressed"] = false
		var sequence_data := {
			"sequence_events": [press_event, release_event],
			"frame_delay": 1,
		}
		var write_err: Dictionary = await _write_payload(sequence_data)
		if not write_err.is_empty():
			return write_err
		return success({"sent": true, "event": press_event, "auto_release": true})

	var err: Dictionary = await _write_payload([press_event])
	if not err.is_empty():
		return err
	return success({"sent": true, "event": press_event})


func _simulate_mouse_move(params: Dictionary) -> Dictionary:
	var x: float = optional_float(params, "x", 0.0)
	var y: float = optional_float(params, "y", 0.0)
	var rel_x: float = optional_float(params, "relative_x", 0.0)
	var rel_y: float = optional_float(params, "relative_y", 0.0)
	var button_mask: int = optional_int(params, "button_mask", 0)
	var unhandled_explicit: bool = params.has("unhandled")
	var unhandled: bool = optional_bool(params, "unhandled", false)

	var event := {
		"type": "mouse_motion",
		"position": {"x": x, "y": y},
		"relative": {"x": rel_x, "y": rel_y},
		"button_mask": button_mask,
	}
	# Auto-enable unhandled for drag motions (camera-pan use case) ONLY when
	# the caller did NOT explicitly pass an "unhandled" key. If they passed
	# one — true or false — honor it. This lets UI drag-and-drop tests opt
	# back into normal GUI dispatch by passing unhandled: false explicitly.
	if unhandled_explicit:
		event["unhandled"] = unhandled
	elif button_mask > 0:
		event["unhandled"] = true
	var write_result: Dictionary = await _write_payload([event])
	if not write_result.is_empty():
		return write_result
	return success({"sent": true, "event": event})


func _simulate_action(params: Dictionary) -> Dictionary:
	var result := require_string(params, "action")
	if result[1] != null:
		return result[1]
	var action_name: String = result[0]

	var pressed: bool = optional_bool(params, "pressed", true)
	var strength: float = optional_float(params, "strength", 1.0)

	var event := {
		"type": "action",
		"action": action_name,
		"pressed": pressed,
		"strength": strength,
	}
	var write_result: Dictionary = await _write_payload([event])
	if not write_result.is_empty():
		return write_result
	return success({"sent": true, "event": event})


func _simulate_sequence(params: Dictionary) -> Dictionary:
	if not params.has("events") or not params["events"] is Array:
		return error_invalid_params("Missing required parameter: events (Array)")

	var events: Array = params["events"]
	if events.is_empty():
		return error_invalid_params("Events array is empty")

	var frame_delay: int = optional_int(params, "frame_delay", 1)

	for entry: Variant in events:
		# Typed iteration would raise on a non-Dictionary entry, and `as String`
		# raises on a non-String type — both abort before any response is sent.
		if not entry is Dictionary:
			return error_invalid_params("Each sequence event must be an object, got %s" % type_string(typeof(entry)))
		var event_data: Dictionary = entry
		if not event_data.has("type") or not event_data["type"] is String or (event_data["type"] as String).is_empty():
			return error_invalid_params("Invalid event in sequence: %s" % str(event_data))

	if frame_delay <= 0:
		# All events in one frame - write as plain array
		var flat_err: Dictionary = await _write_payload(events)
		if not flat_err.is_empty():
			return flat_err
	else:
		# Sequence with frame delay - game side handles timing
		var sequence_data := {
			"sequence_events": events,
			"frame_delay": frame_delay,
		}
		var seq_err: Dictionary = await _write_payload(sequence_data)
		if not seq_err.is_empty():
			return seq_err

	return success({"sent": true, "event_count": events.size(), "frame_delay": frame_delay})


## Writes one command payload for the running game's MCPInputService.
##
## The game polls this single file once per frame, reads it and deletes it.
## Two tool calls in quick succession (simulate_key then simulate_mouse_click)
## used to overwrite the first payload before the game had read it, silently
## dropping that input. Wait for the previous payload to be consumed first;
## if it is still there after the grace period (game paused, not running, or
## stalled), overwrite it as before so a stale file cannot block input forever.
func _write_payload(payload: Variant) -> Dictionary:
	await await_input_payload_consumed(COMMANDS_PATH, COMMAND_CONSUME_TIMEOUT_SEC)
	var file := FileAccess.open(COMMANDS_PATH, FileAccess.WRITE)
	if file == null:
		return error_internal("Failed to write commands: %s" % error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(payload))
	file.close()
	return {}
