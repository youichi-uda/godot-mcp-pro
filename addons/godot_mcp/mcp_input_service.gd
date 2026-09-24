## Autoload injected by Godot MCP Pro plugin at runtime.
## Monitors for input commands from the editor and dispatches them as Input events.
extends Node

const COMMANDS_PATH := "user://mcp_input_commands"

var _sequence_queue: Array = []  # Array of event dicts
## Payloads that arrived while a sequence was still running, in order. Each is
## {"events": Array, "frame_delay": int}; frame_delay <= 0 means "dispatch all
## events in one frame", so every payload keeps the timing it was sent with.
var _payload_queue: Array = []
var _sequence_frame_delay: int = 0
var _sequence_frames_waited: int = 0


func _ready() -> void:
	# Editor-driven service only — disable it in exported builds rather than
	# stat'ing user:// every frame in players' games.
	if not OS.has_feature("editor") or OS.has_environment("GODOT_MCP_HEADLESS_CHILD"):
		process_mode = Node.PROCESS_MODE_DISABLED
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Process queued sequence events; start the next queued payload only on a
	# later frame, so a sequence's last event (e.g. a click's release) and the
	# next payload's first event never land in the same frame.
	if not _sequence_queue.is_empty():
		_process_sequence_tick()
	elif not _payload_queue.is_empty():
		_run_payload(_payload_queue.pop_front())

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

	# A sequence command is {"sequence_events": [...], "frame_delay": n};
	# anything else is one or more events for the same frame.
	var payload: Dictionary
	if parsed is Dictionary and parsed.has("sequence_events"):
		payload = {"events": parsed.get("sequence_events", []), "frame_delay": int(parsed.get("frame_delay", 1))}
	else:
		payload = {"events": parsed if parsed is Array else [parsed], "frame_delay": 0}

	if _sequence_queue.is_empty() and _payload_queue.is_empty():
		_run_payload(payload)
	else:
		# Something is still in flight (e.g. a click's press/release pair).
		# Replacing it would drop its remaining events — a lost release leaves
		# the button held — and dispatching now would overtake it. Queue the
		# whole payload so it runs afterwards with its own timing.
		_payload_queue.append(payload)


func _run_payload(payload: Dictionary) -> void:
	var events: Array = payload.get("events", [])
	if int(payload.get("frame_delay", 0)) > 0:
		_start_sequence({"sequence_events": events, "frame_delay": payload["frame_delay"]})
		return
	for event_data: Variant in events:
		if not event_data is Dictionary:
			continue
		var event := _create_event(event_data)
		if event != null:
			_dispatch_event(event, event_data)


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
		_dispatch_event(event, event_data)


## Dispatch an input event using the appropriate method.
## Mouse drag motions (button_mask > 0) auto-promote to push_input to bypass
## GUI consumption and reach _unhandled_input — needed for camera-pan use
## cases where UI Controls would otherwise swallow drag events. But for UI
## drag-and-drop *testing* we want events to reach the GUI dispatcher so
## hit-testing and _get_drag_data / _drop_data fire. So: respect an explicit
## "unhandled": false in the event payload — only auto-promote when the
## caller did NOT pass an "unhandled" key. Default behavior preserved.
func _dispatch_event(event: InputEvent, event_data: Dictionary = {}) -> void:
	_dispatch_now(event, event_data)
	# A timed hold (simulate_key duration): release it relative to the moment
	# the press really went out, in real seconds regardless of time_scale.
	var hold: float = float(event_data.get("hold_sec", 0.0))
	if hold > 0.0 and event is InputEventKey and (event as InputEventKey).pressed:
		var release_data := event_data.duplicate()
		release_data["pressed"] = false
		release_data.erase("hold_sec")
		get_tree().create_timer(hold, true, false, true).timeout.connect(
			func() -> void:
				var release := _create_event(release_data)
				if release != null:
					_dispatch_now(release, release_data)
		)


func _dispatch_now(event: InputEvent, event_data: Dictionary = {}) -> void:
	var force_unhandled: bool
	if event_data.has("unhandled"):
		force_unhandled = bool(event_data.get("unhandled"))
	else:
		force_unhandled = event is InputEventMouseMotion and event.button_mask != 0
	if force_unhandled:
		var vp := get_viewport()
		if vp:
			vp.push_input(event, true)
		else:
			Input.parse_input_event(event)
	else:
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


## Device id that real keyboard / mouse events carry on the running engine.
##
## Godot 4.7 gives keyboard and mouse their own ids (InputEvent.DEVICE_ID_KEYBOARD
## = 16, DEVICE_ID_MOUSE = 32; ids 0-15 are joypads), and InputMap only matches
## an event whose device equals the mapped event's (or the mapping's "all
## devices" -1). A synthetic key left on device 0 would look like joypad 0: it
## would miss every keyboard-mapped action and fool game code that filters on
## event.device. Resolved by name because referencing the constants directly is
## a parse error on 4.5/4.6 — which would break the user's game — and there
## keyboard/mouse events use device 0, so 0 keeps the old behaviour.
static func _input_device_id(constant_name: String) -> int:
	if ClassDB.class_has_integer_constant("InputEvent", constant_name):
		return ClassDB.class_get_integer_constant("InputEvent", constant_name)
	return 0


func _create_key_event(data: Dictionary) -> InputEventKey:
	var event := InputEventKey.new()
	event.device = _input_device_id("DEVICE_ID_KEYBOARD")
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


func _extract_position(data: Dictionary) -> Vector2:
	# Support nested {"position": {"x": ..., "y": ...}} or flat {"x": ..., "y": ...}
	var pos = data.get("position", null)
	if pos is Dictionary:
		return Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	return Vector2(data.get("x", 0.0), data.get("y", 0.0))


func _create_mouse_button_event(data: Dictionary) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.device = _input_device_id("DEVICE_ID_MOUSE")
	event.button_index = data.get("button", MOUSE_BUTTON_LEFT)
	event.pressed = data.get("pressed", true)
	event.double_click = data.get("double_click", false)
	var window_pos := _viewport_to_window(_extract_position(data))
	event.position = window_pos
	event.global_position = window_pos
	return event


func _create_mouse_motion_event(data: Dictionary) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.device = _input_device_id("DEVICE_ID_MOUSE")
	var window_pos := _viewport_to_window(_extract_position(data))
	event.position = window_pos
	event.global_position = window_pos
	# Support nested {"relative": {"x": ..., "y": ...}} or flat {"relative_x": ..., "relative_y": ...}
	var rel_x: float = 0.0
	var rel_y: float = 0.0
	var rel = data.get("relative", null)
	if rel is Dictionary:
		rel_x = float(rel.get("x", 0.0))
		rel_y = float(rel.get("y", 0.0))
	else:
		rel_x = float(data.get("relative_x", 0.0))
		rel_y = float(data.get("relative_y", 0.0))
	# Scale relative movement by the same transform (scale only, no offset)
	var vp := get_viewport()
	if vp:
		var scale := vp.get_final_transform().get_scale()
		event.relative = Vector2(rel_x, rel_y) * scale
	else:
		event.relative = Vector2(rel_x, rel_y)
	# Set button_mask so drag detection works (e.g. camera pan checks button_mask)
	var button_mask: int = int(data.get("button_mask", 0))
	event.button_mask = button_mask
	return event


func _create_action_event(data: Dictionary) -> InputEventAction:
	# Left at the default device 0 on purpose: an InputEventAction is matched
	# by action name, not through InputMap's per-device lookup, so its device
	# does not affect is_action_pressed(). simulate_action keeps its behaviour.
	var event := InputEventAction.new()
	event.action = data.get("action", "")
	event.pressed = data.get("pressed", true)
	event.strength = data.get("strength", 1.0)
	return event
