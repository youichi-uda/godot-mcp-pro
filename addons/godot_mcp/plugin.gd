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
	print("[MCP] Godot MCP Pro v1.4.0 started (ports 6505-6509)")


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


func _process(_delta: float) -> void:
	# Check if game inspector requested debugger continue
	var flag_path := OS.get_user_data_dir() + "/mcp_debugger_continue"
	if FileAccess.file_exists(flag_path):
		DirAccess.remove_absolute(flag_path)
		_try_debugger_continue()


func _try_debugger_continue() -> void:
	# Last resort: find and press the debugger Continue button to unstick the game
	var base: Node = EditorInterface.get_base_control()
	var continue_btn := _find_debugger_continue_button(base)
	if continue_btn and continue_btn.visible and not continue_btn.disabled:
		continue_btn.emit_signal("pressed")
		push_warning("[MCP] Auto-pressed debugger Continue button")
	else:
		push_warning("[MCP] Could not find debugger Continue button")


func _find_debugger_continue_button(node: Node) -> Button:
	# Search for the Continue button in ScriptEditorDebugger
	if node is Button:
		var btn: Button = node
		if btn.tooltip_text.contains("Continue") or btn.text == "Continue":
			return btn
	for child in node.get_children():
		var found: Button = _find_debugger_continue_button(child)
		if found:
			return found
	return null


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
