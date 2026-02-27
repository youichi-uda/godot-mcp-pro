@tool
extends VBoxContainer

var websocket_server: Node = null

const MAX_LOG_ENTRIES := 100
const COLOR_CONNECTED := Color(0, 1, 0)
const COLOR_DISCONNECTED := Color(1, 0, 0)
const COLOR_SUCCESS := Color(0.6, 1, 0.6)
const COLOR_ERROR := Color(1, 0.6, 0.6)

var _status_icon: Label
var _status_label: Label
var _client_count: Label
var _log_container: VBoxContainer


func _ready() -> void:
	_status_icon = $Header/StatusIcon
	_status_label = $Header/StatusLabel
	_client_count = $Header/ClientCount
	_log_container = $LogScroll/LogContainer


func setup(ws_server: Node) -> void:
	websocket_server = ws_server
	if websocket_server:
		websocket_server.client_connected.connect(_on_client_connected)
		websocket_server.client_disconnected.connect(_on_client_disconnected)
		websocket_server.command_executed.connect(_on_command_executed)


func _process(_delta: float) -> void:
	if websocket_server:
		var count: int = websocket_server.get_client_count()
		_client_count.text = "Clients: %d" % count
		if count > 0:
			_status_icon.add_theme_color_override("font_color", COLOR_CONNECTED)
			_status_label.text = "MCP Server: Connected"
		else:
			_status_icon.add_theme_color_override("font_color", COLOR_DISCONNECTED)
			_status_label.text = "MCP Server: Waiting for connection..."


func _on_client_connected() -> void:
	_add_log("Client connected", COLOR_CONNECTED)


func _on_client_disconnected() -> void:
	_add_log("Client disconnected", COLOR_DISCONNECTED)


func _on_command_executed(method: String, ok: bool) -> void:
	var color := COLOR_SUCCESS if ok else COLOR_ERROR
	var status_text := "OK" if ok else "ERROR"
	_add_log("[%s] %s" % [status_text, method], color)


func _add_log(text: String, color: Color = Color.WHITE) -> void:
	if _log_container == null:
		return
	var label := Label.new()
	var time_str := Time.get_time_string_from_system()
	label.text = "[%s] %s" % [time_str, text]
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 12)
	_log_container.add_child(label)

	# Limit log entries
	while _log_container.get_child_count() > MAX_LOG_ENTRIES:
		var old: Node = _log_container.get_child(0)
		_log_container.remove_child(old)
		old.queue_free()
