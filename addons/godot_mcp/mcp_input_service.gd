## Autoload injected by Godot MCP Pro plugin at runtime.
## Monitors for input commands from the editor and dispatches them as Input events.
extends Node

const COMMANDS_PATH := "user://mcp_input_commands"

var _sequence_queue: Array = []  # Array of event dicts
## Payloads that arrived while a sequence was still running, in order. Each is
## {"events": Array, "frame_delay": int}; frame_delay <= 0 means "dispatch all
## events in one frame", so every payload keeps the timing it was sent with.
var _payload_queue: Array = []
## ack_id of the running sequence, written as user://mcp_input_ack_<id> once
## its last event has been dispatched ("" = nobody is waiting).
var _sequence_ack_id := ""
## Timed key holds waiting for their release (see _dispatch_event).
var _pending_releases: Array = []

## cancel_group of the running sequence (run_stress_test tags its batches so
## a cancellation only ever touches its own input).
var _sequence_group := ""
## Frame in which the running sequence started: its first event went out
## then, so the tick must not send the second one in that same frame.
var _sequence_started_frame := -1
## Inputs a cancel_group has pressed and not yet released, as
## {group: {input_key: true}}. Cancellation releases exactly these: queued
## releases of a batch that never started prove nothing was pressed.
var _group_held := {}
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
	_sweep_input_acks()


static func _is_valid_ack_id(ack_id: String) -> bool:
	if ack_id.is_empty() or ack_id.length() > 40:
		return false
	for ch in ack_id:
		if not (ch == "_" or (ch >= "0" and ch <= "9")):
			return false
	return true


## Removes release acknowledgements nobody will read: an ack written after the
## editor stopped waiting (timeout, paused game). Only ones older than the
## longest possible wait are removed, so an ack another editor sharing
## user:// is still waiting for is left alone.
const _ACK_MAX_AGE_SEC := 900


static func _sweep_input_acks() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var now := int(Time.get_unix_time_from_system())
	for f in dir.get_files():
		if f.begins_with("mcp_input_ack_"):
			var modified := FileAccess.get_modified_time("user://" + f)
			if modified > 0 and now - modified > _ACK_MAX_AGE_SEC:
				dir.remove(f)


func _process(_delta: float) -> void:
	_process_pending_releases()
	# Read new commands first, so a cancellation takes effect before the
	# running sequence dispatches another event this frame.
	if FileAccess.file_exists(COMMANDS_PATH):
		_process_commands()

	# Process queued sequence events; start the next queued payload only on a
	# later frame, so a sequence's last event (e.g. a click's release) and the
	# next payload's first event never land in the same frame.
	if not _sequence_queue.is_empty():
		if _sequence_started_frame != Engine.get_process_frames():
			_process_sequence_tick()
	elif not _payload_queue.is_empty():
		_run_payload(_payload_queue.pop_front())


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

	if parsed is Dictionary:
		# Plain events arrive wrapped as {"events": [...]}. (Input left over
		# from an earlier play session is removed by the editor plugin when
		# that game stops; comparing timestamps with this autoload's start
		# wrongly dropped input sent while the game was still starting up.)
		if parsed.has("events") and not parsed.has("sequence_events") and not parsed.has("cancel_input_queue"):
			parsed = parsed["events"]

	# Cancellation (run_stress_test): drop the queued input of ONE group (the
	# caller's own payloads; other input sharing the queue is left alone) and
	# deliver every release that input still owed, so nothing stays held.
	if parsed is Dictionary and parsed.get("cancel_input_queue", false):
		var group := str(parsed.get("cancel_group", ""))
		var pending: Array = []
		if not group.is_empty():
			if _sequence_group == group:
				# Only the running sequence can have delivered presses.
				pending.append_array(_sequence_queue)
				_sequence_queue.clear()
				_sequence_ack_id = ""
				_sequence_group = ""
			# Queued payloads of the group never started: drop them without
			# dispatching anything (their releases would release input that
			# something else is holding).
			var kept: Array = []
			for queued: Variant in _payload_queue:
				if not (queued is Dictionary and str(queued.get("cancel_group", "")) == group):
					kept.append(queued)
			_payload_queue = kept
		# Presses already handed to Input may still sit in its buffer
		# (accumulated input): deliver them first, then release exactly what
		# this group pressed and has not released yet.
		Input.flush_buffered_events()
		var held: Dictionary = _group_held.get(group, {})
		for ev: Variant in pending:
			if not ev is Dictionary:
				continue
			var ev_data: Dictionary = ev
			if bool(ev_data.get("pressed", true)):
				continue
			var k := _input_key(ev_data)
			if k.is_empty() or not held.has(k):
				continue
			held.erase(k)
			var rel := _create_event(ev_data)
			if rel != null:
				_dispatch_now(rel, ev_data)
		_group_held.erase(group)
		Input.flush_buffered_events()
		_write_input_ack(str(parsed.get("ack_id", "")))
		return

	# A sequence command is {"sequence_events": [...], "frame_delay": n};
	# anything else is one or more events for the same frame.
	var payload: Dictionary
	if parsed is Dictionary and parsed.has("sequence_events"):
		payload = {"events": parsed.get("sequence_events", []), "frame_delay": int(parsed.get("frame_delay", 1)), "ack_id": str(parsed.get("ack_id", "")), "cancel_group": str(parsed.get("cancel_group", ""))}
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
	var ack_id := str(payload.get("ack_id", ""))
	if int(payload.get("frame_delay", 0)) > 0:
		_sequence_ack_id = ack_id
		_sequence_group = str(payload.get("cancel_group", ""))
		_start_sequence({"sequence_events": events, "frame_delay": payload["frame_delay"]})
		return
	for event_data: Variant in events:
		if not event_data is Dictionary:
			continue
		var event := _create_event(event_data)
		if event != null:
			_dispatch_event(event, event_data)


func _start_sequence(data: Dictionary) -> void:
	_sequence_started_frame = Engine.get_process_frames()
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
		_track_group_input(_sequence_group, event_data)
	# Tell a waiting editor (run_stress_test) that the whole sequence is out.
	if _sequence_queue.is_empty() and not _sequence_ack_id.is_empty():
		_write_input_ack(_sequence_ack_id)
		_sequence_ack_id = ""


## Identity of an input for press/release pairing ("" when not trackable).
static func _input_key(ev: Dictionary) -> String:
	match str(ev.get("type", "")):
		"action":
			return "action:" + str(ev.get("action", ""))
		"key":
			return "key:" + str(ev.get("keycode", ""))
		"mouse_button":
			return "mouse:" + str(ev.get("button", 1))
	return ""


func _track_group_input(group: String, ev: Dictionary) -> void:
	if group.is_empty():
		return
	var k := _input_key(ev)
	if k.is_empty():
		return
	var held: Dictionary = _group_held.get(group, {})
	if bool(ev.get("pressed", true)):
		held[k] = true
	else:
		held.erase(k)
	if held.is_empty():
		_group_held.erase(group)
	else:
		_group_held[group] = held


static func _write_input_ack(ack_id: String) -> void:
	# Ids are generated by the addon as "<pid>_<usec>"; anything else (a path
	# separator, "..") could make this write land on another user:// file.
	if not _is_valid_ack_id(ack_id):
		return
	# Input.parse_input_event() only buffers the event (accumulated input);
	# the game sees it on the next flush. Deliver it now, so "done" means the
	# game has actually received the input.
	Input.flush_buffered_events()
	var ack := FileAccess.open("user://mcp_input_ack_%s" % ack_id, FileAccess.WRITE)
	if ack != null:
		ack.store_string("done")
		ack.close()


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
		# Deliver the press now so the hold is timed from when the game
		# actually receives it, not from when it entered Input's buffer (a
		# frame later at low frame rates).
		Input.flush_buffered_events()
		var release_data := event_data.duplicate()
		release_data["pressed"] = false
		release_data.erase("hold_sec")
		var ack_id := str(release_data.get("ack_id", ""))
		release_data.erase("ack_id")
		# Released from _process once the monotonic deadline has passed AND a
		# later frame has started. A SceneTreeTimer created during _process is
		# charged that frame's whole delta at once, so at low frame rates the
		# release landed in the press frame with no gameplay frame between.
		_pending_releases.append({
			"deadline_ms": Time.get_ticks_msec() + int(hold * 1000.0),
			"frame": Engine.get_process_frames(),
			"data": release_data,
			"ack_id": ack_id,
		})


func _process_pending_releases() -> void:
	if _pending_releases.is_empty():
		return
	var now := Time.get_ticks_msec()
	var frame := Engine.get_process_frames()
	var still: Array = []
	for pr: Dictionary in _pending_releases:
		if now < int(pr["deadline_ms"]) or frame <= int(pr["frame"]):
			still.append(pr)
			continue
		var data: Dictionary = pr["data"]
		var release := _create_event(data)
		if release != null:
			_dispatch_now(release, data)
		if not str(pr["ack_id"]).is_empty():
			# Tells the editor the hold is over (see input_commands.gd).
			_write_input_ack(str(pr["ack_id"]))
	_pending_releases = still


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
