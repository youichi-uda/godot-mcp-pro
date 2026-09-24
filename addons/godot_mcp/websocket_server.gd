@tool
extends Node

## Multi-connection WebSocket client.
## Connects to multiple Node.js MCP server instances on ports 6505-6514.
## Each Claude Code session gets its own port; Godot talks to all of them.
## Ports 6505-6509: MCP servers (stdio), 6510-6514: CLI tool connections.

signal client_connected()
signal client_disconnected()
signal message_received(text: String)
signal command_executed(method: String, success: bool)
signal command_completed(method: String, success: bool, response: String, source_port: int)

var command_router: Node

const BASE_PORT := 6505
const MAX_PORT := 6514
const RECONNECT_INTERVAL := 3.0
const BUFFER_SIZE := 16 * 1024 * 1024  # 16MB
const PING_INTERVAL := 5.0  # send ping every N seconds while connected
const INACTIVITY_TIMEOUT := 30.0  # force-close if no message received for N seconds
const HANDSHAKE_TIMEOUT := 10.0  # give up on a socket stuck CONNECTING/CLOSING
## Optional, opt-in. See SECURITY.md — this defends against other users on a
## shared machine and against cross-project mix-ups, NOT against a process
## running as you, which can read the token file just as a real server does.
const TOKEN_PATH := "user://mcp_auth_token"
const TOKEN_SETTING := "godot_mcp_pro/require_connection_token"
const AUTH_TIMEOUT := 5.0  # close a peer that has not authenticated in time

# Per-port connection state
var _peers: Dictionary = {}  # port -> WebSocketPeer
var _connected: Dictionary = {}  # port -> bool
var _timers: Dictionary = {}  # port -> float (reconnect countdown)
var _connect_times: Dictionary = {}  # port -> float (elapsed seconds since connect)
var _last_activity: Dictionary = {}  # port -> float (seconds since last received message)
var _ping_timers: Dictionary = {}  # port -> float (seconds since last sent ping)
var _stale_ports: Dictionary = {}  # port -> bool (heartbeat timeout flag, exposed to UI)
var _handshake_timers: Dictionary = {}  # port -> float (seconds stuck CONNECTING/CLOSING)
var _authed: Dictionary = {}  # port -> bool (token accepted, or auth not required)
var _auth_timers: Dictionary = {}  # port -> float (seconds awaiting auth)
var _auth_token: String = ""  # empty when the token requirement is off
var _running: bool = false


func start_server() -> void:
	_running = true
	_auth_token = _prepare_auth_token()
	for p in range(BASE_PORT, MAX_PORT + 1):
		_connected[p] = false
		_timers[p] = 0.0
		_try_connect(p)
	print("[MCP] Connecting to ports %d-%d" % [BASE_PORT, MAX_PORT])


func stop_server() -> void:
	_running = false
	for p in _peers:
		var ws: WebSocketPeer = _peers[p]
		if ws:
			ws.close(1000, "Plugin shutting down")
	_peers.clear()
	_connected.clear()
	_timers.clear()
	_connect_times.clear()
	_last_activity.clear()
	_ping_timers.clear()
	_stale_ports.clear()
	_handshake_timers.clear()
	_authed.clear()
	_auth_timers.clear()
	print("[MCP] WebSocket client stopped")


func get_client_count() -> int:
	var count: int = 0
	for p in _connected:
		if _connected[p]:
			count += 1
	return count


func get_connected_ports() -> Array[int]:
	var ports: Array[int] = []
	for p: int in _connected:
		if _connected[p]:
			ports.append(p)
	return ports


func get_port_connect_time(port: int) -> float:
	return _connect_times.get(port, -1.0)


func get_port_idle_time(port: int) -> float:
	return _last_activity.get(port, -1.0)


func is_port_stale(port: int) -> bool:
	return _stale_ports.get(port, false)


func _try_connect(p: int) -> void:
	var ws := WebSocketPeer.new()
	ws.outbound_buffer_size = BUFFER_SIZE
	ws.inbound_buffer_size = BUFFER_SIZE
	var err := ws.connect_to_url("ws://127.0.0.1:%d" % p)
	if err == OK:
		_peers[p] = ws
	else:
		_peers[p] = null


func _process(delta: float) -> void:
	if not _running:
		return

	for p in range(BASE_PORT, MAX_PORT + 1):
		var ws: WebSocketPeer = _peers.get(p)

		# No peer - try reconnect on timer
		if ws == null:
			_timers[p] = _timers.get(p, 0.0) + delta
			if _timers[p] >= RECONNECT_INTERVAL:
				_timers[p] = 0.0
				_try_connect(p)
			continue

		ws.poll()
		var state := ws.get_ready_state()

		match state:
			WebSocketPeer.STATE_OPEN:
				_handshake_timers[p] = 0.0
				if not _connected.get(p, false):
					_connected[p] = true
					_connect_times[p] = 0.0
					_last_activity[p] = 0.0
					_ping_timers[p] = 0.0
					_stale_ports[p] = false
					_timers[p] = 0.0
					# With no token required this is true immediately, so the
					# whole mechanism is inert for existing setups.
					_authed[p] = _auth_token.is_empty()
					_auth_timers[p] = 0.0
					if not _authed[p]:
						ws.send_text(JSON.stringify({
							"jsonrpc": "2.0",
							"method": "auth_required",
							"params": {"scheme": "shared-token"},
						}))
					print_verbose("[MCP] Connected on port %d" % p)
					client_connected.emit()
				else:
					_connect_times[p] = _connect_times.get(p, 0.0) + delta
					_last_activity[p] = _last_activity.get(p, 0.0) + delta
					_ping_timers[p] = _ping_timers.get(p, 0.0) + delta

				var received_any := false
				while ws.get_available_packet_count() > 0:
					var packet := ws.get_packet()
					var text := packet.get_string_from_utf8()
					received_any = true
					_dispatch_message(text, p)

				if received_any:
					_last_activity[p] = 0.0
					if _stale_ports.get(p, false):
						_stale_ports[p] = false
						print("[MCP] Port %d recovered from stale state" % p)

				# Force-close if no message received for INACTIVITY_TIMEOUT.
				# The MCP server pings every 10s, so 30s of silence means the
				# connection is half-open and reconnect is the only way out.
				if _last_activity.get(p, 0.0) > INACTIVITY_TIMEOUT:
					push_warning("[MCP] Port %d silent for %.1fs — forcing reconnect" % [p, _last_activity[p]])
					_stale_ports[p] = true
					ws.close(4000, "Heartbeat timeout")
					_connected[p] = false
					_peers[p] = null
					_timers[p] = 0.0
					client_disconnected.emit()
					continue

				if not _authed.get(p, true):
					_auth_timers[p] = _auth_timers.get(p, 0.0) + delta
					if _auth_timers[p] >= AUTH_TIMEOUT:
						push_warning("[MCP] Port %d did not authenticate within %.0fs — closing" % [p, AUTH_TIMEOUT])
						ws.close(4001, "Authentication required")
						_connected[p] = false
						_peers[p] = null
						_timers[p] = 0.0
						client_disconnected.emit()
						continue

				# Send periodic ping so the server can detect our death too,
				# and so any reply resets our own inactivity timer.
				if _ping_timers.get(p, 0.0) >= PING_INTERVAL:
					_ping_timers[p] = 0.0
					ws.send_text(JSON.stringify({"jsonrpc": "2.0", "method": "ping", "params": {}}))

			WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CONNECTING:
				# Neither state resolves on its own if the far end went away
				# mid-handshake or mid-close. Without a deadline the port sits
				# in limbo for the rest of the session and never reconnects.
				_handshake_timers[p] = _handshake_timers.get(p, 0.0) + delta
				if _handshake_timers[p] >= HANDSHAKE_TIMEOUT:
					_handshake_timers[p] = 0.0
					# Most ports in the range simply have no server on them, so
					# this is the normal steady state — log it only at verbose
					# level rather than filling the Output panel every 10s.
					print_verbose("[MCP] Port %d stuck in %s for %.0fs — dropping the peer" % [
						p, "CLOSING" if state == WebSocketPeer.STATE_CLOSING else "CONNECTING", HANDSHAKE_TIMEOUT
					])
					_connected[p] = false
					_peers[p] = null
					_timers[p] = 0.0

			WebSocketPeer.STATE_CLOSED:
				if _connected.get(p, false):
					_connected[p] = false
					print_verbose("[MCP] Disconnected from port %d" % p)
					client_disconnected.emit()
				_peers[p] = null
				_timers[p] = 0.0
				_last_activity[p] = 0.0
				_ping_timers[p] = 0.0
				_handshake_timers[p] = 0.0


## params may legitimately be absent on the auth message.
func params_or_empty(msg_dict: Dictionary) -> Dictionary:
	var raw: Variant = msg_dict.get("params", {})
	return raw if raw is Dictionary else {}


## Returns the token to require, or "" when the requirement is off (the
## default). Enabling it is opt-in via project setting or environment variable,
## so no existing client configuration changes behaviour.
func _prepare_auth_token() -> String:
	var required := false
	if ProjectSettings.has_setting(TOKEN_SETTING):
		required = bool(ProjectSettings.get_setting(TOKEN_SETTING))
	if OS.has_environment("GODOT_MCP_REQUIRE_TOKEN"):
		var env := OS.get_environment("GODOT_MCP_REQUIRE_TOKEN").strip_edges().to_lower()
		required = env != "" and env != "0" and env != "false"
	if not required:
		# Do not leave a stale token behind to confuse a later session.
		if FileAccess.file_exists(TOKEN_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TOKEN_PATH))
		return ""

	var token := _random_token()
	var file := FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[MCP] Connection token required but %s could not be written; refusing every connection." % TOKEN_PATH)
		return token
	file.store_string(token)
	file.close()
	print("[MCP] Connection token required. Servers must read %s (see SECURITY.md)." % ProjectSettings.globalize_path(TOKEN_PATH))
	return token


func _random_token() -> String:
	var bytes := PackedByteArray()
	for _i in 32:
		bytes.append(randi() % 256)
	return Marshalls.raw_to_base64(bytes)


func _send_to_port(p: int, text: String) -> bool:
	var ws: WebSocketPeer = _peers.get(p)
	if ws == null or not _connected.get(p, false):
		return false
	var err := ws.send_text(text)
	if err != OK:
		# A dropped response looks identical to a slow command from the other
		# end, so the caller waits out its timeout with no idea why. Say it
		# here at least.
		push_error("[MCP] Failed to send response on port %d: %s" % [p, error_string(err)])
		return false
	return true


func send_message(text: String) -> void:
	# Broadcast to all connected peers
	for p in _peers:
		_send_to_port(p, text)


## Synchronous dispatch - parse JSON, handle ping/pong, queue command execution
func _dispatch_message(text: String, source_port: int) -> void:
	message_received.emit(text)

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		_send_response(source_port, null, null, {"code": -32700, "message": "Parse error"})
		return

	var msg: Variant = json.data
	if not msg is Dictionary:
		_send_response(source_port, null, null, {"code": -32600, "message": "Invalid request"})
		return

	var msg_dict: Dictionary = msg

	var id: Variant = msg_dict.get("id")

	# Type-check the method before comparing it to anything. GDScript raises on
	# `42 == "ping"` rather than returning false, which aborted the whole
	# dispatch — so a request with a numeric method hung the caller until its
	# timeout instead of being told the request was malformed.
	var raw_method: Variant = msg_dict.get("method")
	if not (raw_method is String) or (raw_method as String).is_empty():
		_send_response(source_port, id, null, {"code": -32600, "message": "Missing or non-string method"})
		return
	var method: String = raw_method

	if method == "ping":
		# A ping carrying an id is a request and needs a correlated reply, or
		# the sender waits for a response that never comes.
		if id == null:
			_send_to_port(source_port, JSON.stringify({"jsonrpc": "2.0", "method": "pong", "params": {}}))
		else:
			_send_response(source_port, id, {"pong": true}, null)
		return

	if method == "pong":
		return

	# Token handshake. Answered before the authentication gate below, since it
	# is how a peer gets through that gate in the first place.
	if method == "auth":
		var supplied := str(params_or_empty(msg_dict).get("token", ""))
		if _auth_token.is_empty() or supplied == _auth_token:
			_authed[source_port] = true
			_send_response(source_port, id, {"authenticated": true}, null)
		else:
			push_warning("[MCP] Port %d presented a wrong token" % source_port)
			_send_response(source_port, id, null, {"code": -32001, "message": "Invalid token"})
		return

	# Everything else waits until the peer has proven it knows the token. When
	# no token is configured _authed is true from the moment we connect, so
	# this costs existing setups nothing.
	if not _authed.get(source_port, true):
		_send_response(source_port, id, null, {
			"code": -32001,
			"message": "This editor requires a connection token. Send {\"method\":\"auth\",\"params\":{\"token\":...}} first; the token is in user://mcp_auth_token. See SECURITY.md.",
		})
		return

	# Assigning a non-Dictionary straight into a typed local raises, which
	# aborts before any response is sent and leaves the caller waiting out its
	# full timeout for what is really a malformed request.
	var raw_params: Variant = msg_dict.get("params", {})
	if raw_params == null:
		raw_params = {}
	if not raw_params is Dictionary:
		_send_response(source_port, id, null, {
			"code": -32602,
			"message": "params must be an object, got %s" % type_string(typeof(raw_params)),
		})
		return
	var params: Dictionary = raw_params

	# A well-formed request carrying no id is a JSON-RPC notification: execute
	# it, but send nothing back. (Parse and invalid-request errors above still
	# answer with id:null, as the spec requires — there the id is unknowable
	# rather than deliberately absent.)
	if id == null:
		_execute_notification.call_deferred(method, params)
		return

	if not command_router:
		_send_response(source_port, id, null, {"code": -32603, "message": "No command router"})
		return

	_execute_command.call_deferred(source_port, id, method, params)


## Runs a notification: same dispatch, no response.
func _execute_notification(method: String, params: Dictionary) -> void:
	if not command_router:
		return
	var cmd_result: Dictionary = await command_router.execute(method, params)
	var ok: bool = not cmd_result.has("error")
	command_executed.emit(method, ok)


func _execute_command(source_port: int, id: Variant, method: String, params: Dictionary) -> void:
	var cmd_result: Dictionary = await command_router.execute(method, params)
	# A command can outlive the plugin (restart_editor, plugin disabled while
	# it awaited); there is no connection left to answer on.
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if cmd_result.has("error"):
		var err_data: Variant = cmd_result["error"]
		_send_response(source_port, id, null, err_data)
		var response_text := JSON.stringify(err_data)
		command_executed.emit(method, false)
		command_completed.emit(method, false, response_text, source_port)
	else:
		var result_data: Variant = cmd_result.get("result", {})
		_send_response(source_port, id, result_data, null)
		var response_text := JSON.stringify(result_data)
		command_executed.emit(method, true)
		command_completed.emit(method, true, response_text, source_port)


func _send_response(source_port: int, id: Variant, result: Variant, err: Variant) -> void:
	var response: Dictionary = {"jsonrpc": "2.0", "id": id}
	if err != null:
		response["error"] = err
	else:
		response["result"] = result if result != null else {}
	_send_to_port(source_port, JSON.stringify(response))
