## Autoload injected by Godot MCP Pro plugin at runtime.
## Monitors for screenshot requests from the editor and captures the game viewport.
extends Node

const REQUEST_PATH := "user://mcp_screenshot_request"
const SCREENSHOT_PATH := "user://mcp_screenshot.png"


func _process(_delta: float) -> void:
	if FileAccess.file_exists(REQUEST_PATH):
		_take_screenshot()


func _take_screenshot() -> void:
	# Delete request file immediately to avoid re-triggering
	DirAccess.remove_absolute(REQUEST_PATH)

	# Wait one frame so the viewport has a fully rendered image
	await get_tree().process_frame

	var viewport := get_viewport()
	if viewport == null:
		return

	var image := viewport.get_texture().get_image()
	if image == null:
		return

	image.save_png(SCREENSHOT_PATH)
