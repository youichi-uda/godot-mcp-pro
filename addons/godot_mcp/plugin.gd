@tool
extends EditorPlugin

const _MCP_AUTOLOADS: Array[Array] = [
	["autoload/MCPScreenshot", "res://addons/godot_mcp/mcp_screenshot_service.gd"],
	["autoload/MCPInputService", "res://addons/godot_mcp/mcp_input_service.gd"],
	["autoload/MCPGameInspector", "res://addons/godot_mcp/mcp_game_inspector_service.gd"],
]

const _MCP_TEMP_FILES: Array[String] = [
	"mcp_game_request",
	"mcp_game_response",
	"mcp_input_commands",
	"mcp_screenshot_request",
]

var websocket_server: Node
var command_router: Node
var status_panel: Control

func _enter_tree() -> void:
	# Create command router
	command_router = preload("res://addons/godot_mcp/command_router.gd").new()
	command_router.name = "MCPCommandRouter"
	command_router.editor_plugin = self
	add_child(command_router)

	# Create WebSocket server
	websocket_server = preload("res://addons/godot_mcp/websocket_server.gd").new()
	websocket_server.name = "MCPWebSocketServer"
	websocket_server.command_router = command_router
	add_child(websocket_server)

	# Create status panel
	var panel_scene: PackedScene = preload("res://addons/godot_mcp/ui/status_panel.tscn")
	status_panel = panel_scene.instantiate()
	add_control_to_bottom_panel(status_panel, "MCP Server")
	status_panel.call_deferred("setup", websocket_server)

	# Inject MCP autoloads into project settings
	_inject_autoloads()

	websocket_server.start_server()
	print("[MCP] Godot MCP Pro v1.0.0 started (ports 6505-6509)")


func _exit_tree() -> void:
	# Remove MCP autoloads and clean up temp files
	_remove_autoloads()
	_cleanup_temp_files()

	if websocket_server:
		websocket_server.stop_server()

	if status_panel:
		remove_control_from_bottom_panel(status_panel)
		status_panel.queue_free()

	if command_router:
		command_router.queue_free()

	if websocket_server:
		websocket_server.queue_free()

	print("[MCP] Godot MCP Pro stopped")


func _inject_autoloads() -> void:
	var changed := false
	for entry: Array in _MCP_AUTOLOADS:
		var key: String = entry[0]
		var script: String = entry[1]
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, "*" + script)
			changed = true
	if changed:
		ProjectSettings.save()


func _remove_autoloads() -> void:
	var changed := false
	for entry: Array in _MCP_AUTOLOADS:
		var key: String = entry[0]
		if ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, null)
			changed = true
	if changed:
		ProjectSettings.save()


func _cleanup_temp_files() -> void:
	var user_dir := OS.get_user_data_dir()
	for filename: String in _MCP_TEMP_FILES:
		var path := user_dir + "/" + filename
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# Also clean up screenshot image
	var screenshot_path := user_dir + "/mcp_screenshot.png"
	if FileAccess.file_exists(screenshot_path):
		DirAccess.remove_absolute(screenshot_path)
