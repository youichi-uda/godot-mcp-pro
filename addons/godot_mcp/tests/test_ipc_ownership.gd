extends SceneTree

## Logic tests for the game-side IPC ownership rules and diagnostics.
##
## Run inside a scratch project that has the addon installed (its own
## user:// directory — NOT a project a live editor is using, whose IPC files
## these tests write and consume):
##
##   godot --headless --path <scratch-project> \
##         --script res://addons/godot_mcp/tests/test_ipc_ownership.gd \
##         -- --editor-pid 424242
##
## The user argument --editor-pid 424242 stands in for the argument the
## editor passes to a played game, so "own" requests name pid 424242 and
## "foreign" ones name 999999. Exits 0 when every check passes, 1 otherwise.
##
## What is covered (see the incident report in SECURITY.md, "Other processes
## on the same project"):
##  - requests naming another editor are left in place, not consumed;
##  - requests without an editor pid (older editors) stay permissive;
##  - an accepted screenshot request ALWAYS produces an outcome file naming
##    the answering pid (ok with a PNG, or ok=false with a reason) instead of
##    the old silent disappearance;
##  - every game-command response names the answering pid (game_pid);
##  - capture_frames accounts for null-image frames instead of truncating
##    silently;
##  - input payloads naming another editor are not dispatched here.

const OWN_PID := 424242
const FOREIGN_PID := 999999

var _failures: int = 0
var _checks: int = 0
var _screenshot_svc: Node
var _inspector_svc: Node
var _input_svc: Node


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	_cleanup_ipc_files()
	# The services' _ready() disables them when the process does not look like
	# an editor session; these tests drive the polling logic directly, so they
	# are force-enabled whatever the host process looks like.
	_screenshot_svc = _force_enabled_service("res://addons/godot_mcp/mcp_screenshot_service.gd")
	_inspector_svc = _force_enabled_service("res://addons/godot_mcp/mcp_game_inspector_service.gd")
	_input_svc = _force_enabled_service("res://addons/godot_mcp/mcp_input_service.gd")
	await process_frame

	# T1: --editor-pid from the command line is what "own" requests are
	# matched against, in every service.
	_check("T1 own editor pid parsed", _screenshot_svc._own_editor_pid() == OWN_PID)
	_check("T1 inspector own editor pid", _inspector_svc._own_editor_pid() == OWN_PID)
	_check("T1 input own editor pid", _input_svc._own_editor_pid() == OWN_PID)

	# T2: a screenshot request naming another editor is not consumed.
	_write_file("user://mcp_screenshot_request", JSON.stringify({"editor_pid": FOREIGN_PID}))
	await _idle(0.6)
	_check("T2 foreign screenshot request left in place", FileAccess.file_exists("user://mcp_screenshot_request"))
	_check("T2 no screenshot outcome", not FileAccess.file_exists("user://mcp_screenshot_result"))
	_cleanup_ipc_files()

	# T3: an accepted screenshot request always reports an outcome naming the
	# answering process. Headless hosts cannot render, which is exactly the
	# path that used to vanish silently — so assert the invariant, not ok.
	_write_file("user://mcp_screenshot_request", JSON.stringify({"editor_pid": OWN_PID}))
	var outcome := await _await_file("user://mcp_screenshot_result", 2.0)
	_check("T3 screenshot outcome written", outcome)
	_check("T3 screenshot request consumed", not FileAccess.file_exists("user://mcp_screenshot_request"))
	if outcome:
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://mcp_screenshot_result"))
		_check("T3 outcome names answering pid", int(report.get("pid", 0)) == OS.get_process_id())
		var ok := bool(report.get("ok", false))
		if ok:
			_check("T3 success produced a PNG", FileAccess.file_exists("user://mcp_screenshot.png"))
		else:
			_check("T3 failure produced no PNG", not FileAccess.file_exists("user://mcp_screenshot.png"))
			_check("T3 failure carries a reason", str(report.get("reason", "")).length() > 10)
		DirAccess.remove_absolute("user://mcp_screenshot_result")
	_cleanup_ipc_files()

	# T4: a game command naming another editor is not consumed, not answered.
	_write_file("user://mcp_game_request", JSON.stringify({
		"command": "get_scene_tree", "params": {}, "request_id": "t4", "editor_pid": FOREIGN_PID,
	}))
	await _idle(0.6)
	_check("T4 foreign game request left in place", FileAccess.file_exists("user://mcp_game_request"))
	_check("T4 no response written", not FileAccess.file_exists("user://mcp_game_response"))
	_cleanup_ipc_files()

	# T5: an own game command is answered by this process, naming its pid.
	_write_file("user://mcp_game_request", JSON.stringify({
		"command": "get_scene_tree", "params": {}, "request_id": "t5", "editor_pid": OWN_PID,
	}))
	var answered := await _await_file("user://mcp_game_response", 2.0)
	_check("T5 own game request answered", answered)
	if answered:
		var response: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://mcp_game_response"))
		_check("T5 response names game_pid", int(response.get("game_pid", 0)) == OS.get_process_id())
		_check("T5 response echoes request_id", str(response.get("request_id", "")) == "t5")
		DirAccess.remove_absolute("user://mcp_game_response")
	_cleanup_ipc_files()

	# T6: a request without an editor pid (an older editor) stays permissive.
	_write_file("user://mcp_game_request", JSON.stringify({
		"command": "get_scene_tree", "params": {}, "request_id": "t6",
	}))
	answered = await _await_file("user://mcp_game_response", 2.0)
	_check("T6 legacy request (no editor pid) answered", answered)
	_cleanup_ipc_files()

	# T7: input naming another editor is not dispatched here.
	_write_file("user://mcp_input_commands", JSON.stringify({
		"events": [{"type": "action", "action": "ui_cancel", "pressed": true}],
		"editor_pid": FOREIGN_PID,
	}))
	await _idle(0.6)
	_check("T7 foreign input payload left in place", FileAccess.file_exists("user://mcp_input_commands"))
	_cleanup_ipc_files()

	# T8: own input is consumed (dispatched) by this process.
	_write_file("user://mcp_input_commands", JSON.stringify({
		"events": [{"type": "action", "action": "ui_cancel", "pressed": true}],
		"editor_pid": OWN_PID,
	}))
	var consumed := not await _file_stays("user://mcp_input_commands", 1.0)
	_check("T8 own input payload consumed", consumed)
	_cleanup_ipc_files()

	# T9: capture_frames accounts for null-image samples instead of stopping
	# silently. count + null_images must cover every requested sample.
	_write_file("user://mcp_game_request", JSON.stringify({
		"command": "capture_frames",
		"params": {"count": 3, "frame_interval": 1},
		"request_id": "t9", "editor_pid": OWN_PID,
	}))
	answered = await _await_file("user://mcp_game_response", 3.0)
	var t9_ok := false
	if answered:
		var cap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://mcp_game_response"))
		var frames: int = cap.get("count", -1)
		var nulls: int = cap.get("null_images", 0)
		t9_ok = frames + nulls == 3 and int(cap.get("game_pid", 0)) == OS.get_process_id()
		DirAccess.remove_absolute("user://mcp_game_response")
	_check("T9 capture samples all accounted for (frames + null_images)", t9_ok)
	_cleanup_ipc_files()

	print("")
	print("RESULT: %d/%d checks passed" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


func _force_enabled_service(script_path: String) -> Node:
	var node: Node = (load(script_path) as GDScript).new()
	root.add_child(node)
	# _ready() may have disabled the service for this process shape; the
	# polling logic under test is what matters here.
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	node.set_process(true)
	return node


func _check(name: String, passed: bool) -> void:
	_checks += 1
	if passed:
		print("PASS %s" % name)
	else:
		_failures += 1
		print("FAIL %s" % name)


func _write_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()


## True if `path` still exists after `seconds` of idle waiting.
func _file_stays(path: String, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		if not FileAccess.file_exists(path):
			return false
	return FileAccess.file_exists(path)


## Waits until `path` exists, up to `seconds`. True when it appeared.
func _await_file(path: String, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(path):
			return true
		await create_timer(0.05).timeout
	return FileAccess.file_exists(path)


func _idle(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout


func _cleanup_ipc_files() -> void:
	for name: String in [
		"mcp_screenshot_request", "mcp_screenshot.png", "mcp_screenshot_result",
		"mcp_game_request", "mcp_game_response", "mcp_input_commands",
	]:
		var path := "user://" + name
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
