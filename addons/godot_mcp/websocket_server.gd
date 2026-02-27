@tool
extends Node

## Multi-connection WebSocket client.
## Connects to multiple Node.js MCP server instances on ports 6505-6509.
## Each Claude Code session gets its own port; Godot talks to all of them.

signal client_connected()
signal client_disconnected()
signal message_received(text: String)
signal command_executed(method: String, success: bool)

var command_router: Node

const BASE_PORT := 6505
const MAX_PORT := 6509
const RECONNECT_INTERVAL := 3.0
const BUFFER_SIZE := 16 * 1024 * 1024  # 16MB

# Per-port connection state
var _peers: Dictionary = {}  # port -> WebSocketPeer
var _connected: Dictionary = {}  # port -> bool
var _timers: Dictionary = {}  # port -> float (reconnect countdown)
var _running: bool = false


func start_server() -> void:
	_running = true
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
	print("[MCP] WebSocket client stopped")


func get_client_count() -> int:
	var count: int = 0
	for p in _connected:
		if _connected[p]:
			count += 1
	return count


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
				if not _connected.get(p, false):
					_connected[p] = true
					_timers[p] = 0.0
					print("[MCP] Connected on port %d" % p)
					client_connected.emit()

				while ws.get_available_packet_count() > 0:
					var packet := ws.get_packet()
					var text := packet.get_string_from_utf8()
					_dispatch_message(text, p)

			WebSocketPeer.STATE_CLOSING:
				pass

			WebSocketPeer.STATE_CLOSED:
				if _connected.get(p, false):
					_connected[p] = false
					print("[MCP] Disconnected from port %d" % p)
					client_disconnected.emit()
				_peers[p] = null
				_timers[p] = 0.0

			WebSocketPeer.STATE_CONNECTING:
				pass


func _send_to_port(p: int, text: String) -> void:
	var ws: WebSocketPeer = _peers.get(p)
	if ws and _connected.get(p, false):
		ws.send_text(text)


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

	if msg_dict.get("method") == "ping":
		_send_to_port(source_port, JSON.stringify({"jsonrpc": "2.0", "method": "pong", "params": {}}))
		return

	if msg_dict.get("method") == "pong":
		return

	var id: Variant = msg_dict.get("id")
	var method: String = msg_dict.get("method", "")
	var params: Dictionary = msg_dict.get("params", {})

	if method.is_empty():
		_send_response(source_port, id, null, {"code": -32600, "message": "Missing method"})
		return

	if not command_router:
		_send_response(source_port, id, null, {"code": -32603, "message": "No command router"})
		return

	_execute_command.call_deferred(source_port, id, method, params)


func _execute_command(source_port: int, id: Variant, method: String, params: Dictionary) -> void:
	var cmd_result: Dictionary = await command_router.execute(method, params)
	if cmd_result.has("error"):
		_send_response(source_port, id, null, cmd_result["error"])
		command_executed.emit(method, false)
	else:
		_send_response(source_port, id, cmd_result.get("result", {}), null)
		command_executed.emit(method, true)


func _send_response(source_port: int, id: Variant, result: Variant, err: Variant) -> void:
	var response: Dictionary = {"jsonrpc": "2.0", "id": id}
	if err != null:
		response["error"] = err
	else:
		response["result"] = result if result != null else {}
	_send_to_port(source_port, JSON.stringify(response))
