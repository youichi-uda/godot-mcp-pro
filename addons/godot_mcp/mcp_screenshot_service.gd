## Autoload injected by Godot MCP Pro plugin at runtime.
## Monitors for screenshot requests from the editor and captures the game viewport.
extends Node

const REQUEST_PATH := "user://mcp_screenshot_request"
const SCREENSHOT_PATH := "user://mcp_screenshot.png"
## Written next to the PNG so the editor can tell "no process answered at all"
## from "a process took the request but could not produce an image" — and,
## either way, WHICH process answered. Without it, a second Godot process of
## the same project (a manually started test run, a leftover play session)
## used to consume the request, fail silently, and leave the editor to report
## a meaningless generic timeout.
const RESULT_PATH := "user://mcp_screenshot_result"
## How often, and over what total span, to retry a viewport image that comes
## back null before reporting the capture as failed. One retry cycle covers a
## frame that had not been presented yet at the moment of the request.
const IMAGE_ATTEMPTS := 5
const IMAGE_ATTEMPT_DELAY_SEC := 0.05

## editor pid this game was started by (--editor-pid), cached; -1 = not looked
## up yet, 0 = absent (manual run, or a Godot that does not pass it).
var _editor_pid_cached := -1
## Request text last left in place because it names another editor; kept so it
## is not re-read and re-judged on every frame while it waits for its owner.
var _ignored_request_text := ""


func _ready() -> void:
	# This service only exists to serve the editor-driven MCP workflow. In an
	# exported game it would poll user:// every frame for nothing, so shut it
	# down entirely there.
	if not OS.has_feature("editor") or OS.has_environment("GODOT_MCP_HEADLESS_CHILD"):
		process_mode = Node.PROCESS_MODE_DISABLED
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not FileAccess.file_exists(REQUEST_PATH):
		return
	var file := FileAccess.open(REQUEST_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	if text == _ignored_request_text:
		return  # already judged as another editor's; waiting for its owner
	var request_editor_pid := _editor_pid_from_text(text)
	if not _owns_request(request_editor_pid):
		_ignored_request_text = text
		return
	_ignored_request_text = ""
	_take_screenshot(request_editor_pid)


func _take_screenshot(request_editor_pid: int) -> void:
	# Delete request file immediately to avoid re-triggering
	DirAccess.remove_absolute(REQUEST_PATH)

	# A headless process has no display to render: probing the viewport only
	# spams dummy-renderer errors before failing. Say so directly instead.
	if DisplayServer.get_name() == "headless":
		_write_result({
			"ok": false,
			"reason": "this process runs on the headless display server and cannot render a screenshot",
			"hint": "A game played from the editor has a display; this process is not it.",
		}, request_editor_pid)
		return

	var attempts := 0
	var image: Image = null
	var viewport := get_viewport()
	if viewport != null:
		while attempts < IMAGE_ATTEMPTS:
			# Wait for a frame so the viewport has a fully rendered image
			# process_always=true (default) so the timer ticks even when tree is paused
			await get_tree().create_timer(IMAGE_ATTEMPT_DELAY_SEC).timeout
			attempts += 1
			image = viewport.get_texture().get_image()
			if image != null:
				break

	if image != null:
		image.save_png(SCREENSHOT_PATH)
		_write_result({"ok": true}, request_editor_pid)
		return

	# Never a bare return here: the request is already consumed, so staying
	# silent makes the editor time out with no trace of who lost it.
	var reason := "the viewport had no rendered image to save"
	if viewport == null:
		reason = "there was no viewport to capture"
	_write_result({
		"ok": false,
		"reason": "%s after %d attempt(s) over %.2fs" % [reason, attempts, attempts * IMAGE_ATTEMPT_DELAY_SEC],
		"hint": "A headless or never-drawn process cannot produce screenshots.",
	}, request_editor_pid)


## Publishes the capture outcome atomically (temp file + rename) so the
## editor, which polls for this file, never reads it half-written.
func _write_result(fields: Dictionary, request_editor_pid: int) -> void:
	var data := fields.duplicate()
	data["pid"] = OS.get_process_id()
	# Lets an editor's cleanup tell its own result file from another's when
	# several editors share one user:// directory.
	if request_editor_pid > 0:
		data["editor_pid"] = request_editor_pid
	var json := JSON.stringify(data)
	var tmp := RESULT_PATH + ".tmp_%d" % Time.get_ticks_usec()
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("[MCP] Could not write screenshot result file")
		return
	file.store_string(json)
	file.close()
	if FileAccess.file_exists(RESULT_PATH):
		DirAccess.remove_absolute(RESULT_PATH)
	DirAccess.rename_absolute(tmp, RESULT_PATH)


## editor pid named in a request file, or 0 when the file carries none.
static func _editor_pid_from_text(text: String) -> int:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var raw: Variant = parsed.get("editor_pid")
		if raw is int or raw is float:
			return int(raw)
	return 0


## The editor that started this process, from the `--editor-pid <pid>` /
## `--editor-pid=<pid>` argument the editor passes to a played game. Manual
## runs (a test harness, `godot --path ... res://scene.tscn`) have none.
func _own_editor_pid() -> int:
	if _editor_pid_cached != -1:
		return _editor_pid_cached
	var pid := 0
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for i in args.size():
		var arg := str(args[i])
		if arg.begins_with("--editor-pid="):
			pid = int(arg.substr("--editor-pid=".length()))
		elif arg == "--editor-pid" and i + 1 < args.size():
			pid = int(str(args[i + 1]))
	_editor_pid_cached = pid if pid > 0 else 0
	return _editor_pid_cached


## Whether this process should serve a request naming `request_editor_pid`.
## A request from another editor belongs to one of that editor's processes:
## leave it in place for them instead of consuming it here. 0 on either side
## means "unknown" and stays permissive — an older editor sends no pid, and a
## Godot that does not pass --editor-pid must keep working.
func _owns_request(request_editor_pid: int) -> bool:
	var own := _own_editor_pid()
	return own == 0 or request_editor_pid <= 0 or own == request_editor_pid
