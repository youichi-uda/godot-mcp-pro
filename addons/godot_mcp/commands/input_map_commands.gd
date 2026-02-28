@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_input_actions": _get_input_actions,
		"set_input_action": _set_input_action,
	}


func _get_input_actions(params: Dictionary) -> Dictionary:
	var filter: String = optional_string(params, "filter", "")
	var include_builtin: bool = optional_bool(params, "include_builtin", false)

	var actions: Dictionary = {}
	for action: StringName in InputMap.get_actions():
		var action_str := str(action)
		# Skip built-in UI actions unless requested
		if not include_builtin and action_str.begins_with("ui_"):
			continue
		# Apply filter
		if not filter.is_empty() and not action_str.contains(filter):
			continue

		var events: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(_serialize_event(event))

		actions[action_str] = {
			"deadzone": InputMap.action_get_deadzone(action),
			"events": events,
		}

	return success({"actions": actions, "count": actions.size()})


func _set_input_action(params: Dictionary) -> Dictionary:
	var result := require_string(params, "action")
	if result[1] != null:
		return result[1]
	var action_name: String = result[0]

	if not params.has("events") or not params["events"] is Array:
		return error_invalid_params("'events' array is required")
	var event_defs: Array = params["events"]

	var deadzone: float = float(params.get("deadzone", 0.5))

	# Build the events array
	var events: Array[InputEvent] = []
	for event_def in event_defs:
		if not event_def is Dictionary:
			continue
		var event := _parse_event(event_def)
		if event != null:
			events.append(event)

	# Save to ProjectSettings
	var setting_value := {
		"deadzone": deadzone,
		"events": events,
	}

	ProjectSettings.set_setting("input/" + action_name, setting_value)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	# Also update the runtime InputMap
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)
	else:
		InputMap.action_set_deadzone(action_name, deadzone)
		InputMap.action_erase_events(action_name)
	for event in events:
		InputMap.action_add_event(action_name, event)

	return success({
		"action": action_name,
		"deadzone": deadzone,
		"events_count": events.size(),
		"saved": true,
	})


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		var info := {
			"type": "key",
			"keycode": OS.get_keycode_string(key_event.keycode) if key_event.keycode != KEY_NONE else "",
			"physical_keycode": OS.get_keycode_string(key_event.physical_keycode) if key_event.physical_keycode != KEY_NONE else "",
		}
		if key_event.ctrl_pressed: info["ctrl"] = true
		if key_event.shift_pressed: info["shift"] = true
		if key_event.alt_pressed: info["alt"] = true
		if key_event.meta_pressed: info["meta"] = true
		return info
	elif event is InputEventMouseButton:
		var mb_event: InputEventMouseButton = event
		return {
			"type": "mouse_button",
			"button_index": mb_event.button_index,
		}
	elif event is InputEventJoypadButton:
		var jb_event: InputEventJoypadButton = event
		return {
			"type": "joypad_button",
			"button_index": jb_event.button_index,
		}
	elif event is InputEventJoypadMotion:
		var jm_event: InputEventJoypadMotion = event
		return {
			"type": "joypad_motion",
			"axis": jm_event.axis,
			"axis_value": jm_event.axis_value,
		}
	return {"type": event.get_class()}


func _parse_event(def: Dictionary) -> InputEvent:
	var type: String = def.get("type", "")
	match type:
		"key":
			var event := InputEventKey.new()
			var keycode_str: String = def.get("keycode", "")
			if not keycode_str.is_empty():
				event.keycode = OS.find_keycode_from_string(keycode_str)
			var phys_str: String = def.get("physical_keycode", "")
			if not phys_str.is_empty():
				event.physical_keycode = OS.find_keycode_from_string(phys_str)
			event.ctrl_pressed = def.get("ctrl", false)
			event.shift_pressed = def.get("shift", false)
			event.alt_pressed = def.get("alt", false)
			event.meta_pressed = def.get("meta", false)
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = int(def.get("button_index", 1))
			return event
		"joypad_button":
			var event := InputEventJoypadButton.new()
			event.button_index = int(def.get("button_index", 0))
			return event
		"joypad_motion":
			var event := InputEventJoypadMotion.new()
			event.axis = int(def.get("axis", 0))
			event.axis_value = float(def.get("axis_value", 1.0))
			return event
	return null
