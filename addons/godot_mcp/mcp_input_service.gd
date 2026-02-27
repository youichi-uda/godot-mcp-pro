## Autoload injected by Godot MCP Pro plugin at runtime.
## Monitors for input commands from the editor and dispatches them as Input events.
extends Node

const COMMANDS_PATH := "user://mcp_input_commands"

var _sequence_queue: Array = []  # Array of event dicts
var _sequence_frame_delay: int = 0
var _sequence_frames_waited: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Process queued sequence events
	if not _sequence_queue.is_empty():
		_process_sequence_tick()

	# Check for new commands from file
	if FileAccess.file_exists(COMMANDS_PATH):
		_process_commands()


func _process_commands() -> void:
	var file := FileAccess.open(COMMANDS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(COMMANDS_PATH)

	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_warning("[MCP Input] Failed to parse input commands JSON")
		return

	# Check if this is a sequence command (dict with "events" and "frame_delay")
	if parsed is Dictionary and parsed.has("sequence_events"):
		_start_sequence(parsed)
		return

	# Otherwise treat as immediate event(s)
	var events: Array = parsed if parsed is Array else [parsed]
	for event_data: Dictionary in events:
		var event := _create_event(event_data)
		if event != null:
			Input.parse_input_event(event)


func _start_sequence(data: Dictionary) -> void:
	_sequence_queue = data.get("sequence_events", []).duplicate()
	_sequence_frame_delay = data.get("frame_delay", 1)
	_sequence_frames_waited = 0
	# Dispatch first event immediately
	if not _sequence_queue.is_empty():
		_dispatch_next_sequence_event()


func _process_sequence_tick() -> void:
	_sequence_frames_waited += 1
	if _sequence_frames_waited >= _sequence_frame_delay:
		_sequence_frames_waited = 0
		_dispatch_next_sequence_event()


func _dispatch_next_sequence_event() -> void:
	if _sequence_queue.is_empty():
		return
	var event_data: Dictionary = _sequence_queue.pop_front()
	var event := _create_event(event_data)
	if event != null:
		Input.parse_input_event(event)


func _create_event(data: Dictionary) -> InputEvent:
	var type: String = data.get("type", "")
	match type:
		"key":
			return _create_key_event(data)
		"mouse_button":
			return _create_mouse_button_event(data)
		"mouse_motion":
			return _create_mouse_motion_event(data)
		"action":
			return _create_action_event(data)
		_:
			push_warning("[MCP Input] Unknown event type: %s" % type)
			return null


## Convert viewport coordinates to window coordinates for Input.parse_input_event().
## Godot applies viewport.get_final_transform() to mouse events internally,
## so we must pass window-space coordinates (pre-transform).
func _viewport_to_window(viewport_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return viewport_pos
	var xform := vp.get_final_transform()
	return xform * viewport_pos


func _create_key_event(data: Dictionary) -> InputEventKey:
	var event := InputEventKey.new()
	var keycode_str: String = data.get("keycode", "")
	if keycode_str.begins_with("KEY_"):
		var constant_value = ClassDB.class_get_integer_constant("@GlobalScope", keycode_str)
		if constant_value != 0:
			event.keycode = constant_value
		else:
			event.keycode = OS.find_keycode_from_string(keycode_str.substr(4))
	else:
		event.keycode = OS.find_keycode_from_string(keycode_str)
	event.pressed = data.get("pressed", true)
	event.shift_pressed = data.get("shift", false)
	event.ctrl_pressed = data.get("ctrl", false)
	event.alt_pressed = data.get("alt", false)
	return event


func _create_mouse_button_event(data: Dictionary) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = data.get("button", MOUSE_BUTTON_LEFT)
	event.pressed = data.get("pressed", true)
	event.double_click = data.get("double_click", false)
	var pos: Dictionary = data.get("position", {})
	var viewport_pos := Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	var window_pos := _viewport_to_window(viewport_pos)
	event.position = window_pos
	event.global_position = window_pos
	return event


func _create_mouse_motion_event(data: Dictionary) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	var pos: Dictionary = data.get("position", {})
	var viewport_pos := Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	var window_pos := _viewport_to_window(viewport_pos)
	event.position = window_pos
	event.global_position = window_pos
	var rel: Dictionary = data.get("relative", {})
	# Scale relative movement by the same transform (scale only, no offset)
	var vp := get_viewport()
	if vp:
		var scale := vp.get_final_transform().get_scale()
		event.relative = Vector2(rel.get("x", 0.0), rel.get("y", 0.0)) * scale
	else:
		event.relative = Vector2(rel.get("x", 0.0), rel.get("y", 0.0))
	return event


func _create_action_event(data: Dictionary) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = data.get("action", "")
	event.pressed = data.get("pressed", true)
	event.strength = data.get("strength", 1.0)
	return event
