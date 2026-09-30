@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Runs the project in a separate headless Godot process and returns its output.
##
## This is the CI-shaped half of the toolset: projects whose test suites run as
## `godot --headless --path <project> res://tests/runner.tscn` were previously
## invisible to MCP, because every other tool talks to the live editor instead.
##
## The child process writes to a temp file via the platform shell rather than a
## pipe: a pipe's buffer fills up on verbose runs and deadlocks the child, and
## OS.execute() would block the whole editor until the run finished.

## Set in the child's environment so the MCP IPC autoloads disable themselves
## there. Referenced by mcp_screenshot_service.gd and its two siblings.
const HEADLESS_CHILD_ENV := "GODOT_MCP_HEADLESS_CHILD"

const _DEFAULT_TIMEOUT_SEC := 120.0
const _MAX_TIMEOUT_SEC := 900.0
const _POLL_INTERVAL_SEC := 0.25
## How long to wait for a killed process tree to actually disappear.
const _KILL_CONFIRM_SEC := 2.0
const _MAX_OUTPUT_CHARS := 100000
## Concurrent runs are possible — the router dispatches deferred commands and
## several MCP sessions can share one editor — so every run gets its own files.
var _run_counter := 0

class RunPaths:
	var log_path: String
	var exit_path: String
	var runner_path: String

	func _init(prefix: String, is_windows: bool) -> void:
		log_path = "%s.log" % prefix
		exit_path = "%s.exit" % prefix
		runner_path = "%s.bat" % prefix if is_windows else "%s.sh" % prefix

	func cleanup() -> void:
		for p: String in [log_path, exit_path, runner_path]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func get_commands() -> Dictionary:
	return {
		"run_headless_scene": _run_headless_scene,
		"run_headless_script": _run_headless_script,
		"get_godot_executable": _get_godot_executable,
		"run_gut_tests": _run_gut_tests,
	}


func _get_godot_executable(_params: Dictionary) -> Dictionary:
	return success({
		"executable": OS.get_executable_path(),
		"project_path": ProjectSettings.globalize_path("res://"),
		"platform": OS.get_name(),
	})


func _run_headless_scene(params: Dictionary) -> Dictionary:
	var result := require_string(params, "scene_path")
	if result[1] != null:
		return result[1]
	var scene_path: String = result[0]

	if not scene_path.begins_with("res://"):
		return error_invalid_params("scene_path must be a res:// path, got '%s'" % scene_path)
	if not FileAccess.file_exists(scene_path):
		return error_not_found("Scene '%s'" % scene_path)

	return await _run_headless(params, [scene_path], scene_path)


func _run_headless_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "script_path")
	if result[1] != null:
		return result[1]
	var script_path: String = result[0]

	if not script_path.begins_with("res://"):
		return error_invalid_params("script_path must be a res:// path, got '%s'" % script_path)
	if not FileAccess.file_exists(script_path):
		return error_not_found("Script '%s'" % script_path)

	return await _run_headless(params, ["--script", script_path], script_path)


# ── GUT test runner (issue #44) ───────────────────────────────────────────────

## GUT's documented command-line entry point. Checked for existence so a
## project without GUT gets a clear refusal instead of a child process that
## fails cryptically.
const _GUT_CMDLN := "res://addons/gut/gut_cmdln.gd"
## Per-run JUnit XML export path, so concurrent runs cannot clobber each other.
var _gut_run_counter := 0


## Runs the project's GUT (Godot Unit Testing) suite in a headless child
## process and returns structured results: pass/fail, totals, one suite per
## test script, each case with status and, for failures, GUT's message and
## detail (which carries the assertion and source line).
##
## GUT itself is used through its documented CLI, unmodified. The child runs
## through the same _run_headless machinery as run_headless_scene — timeout
## with process-tree kill, output capture, and the GODOT_MCP_HEADLESS_CHILD
## marker that keeps its MCP IPC services off, so a test run can never race
## the editor's played game for the user:// request files.
##
## GUT's exit code is the pass/fail signal (0 = all passed, 1 = anything
## failed; pending does not fail); a completed run with failing tests is a
## successful tool call whose result says so.
func _run_gut_tests(params: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(_GUT_CMDLN):
		return error_not_found(
			"GUT's command line script (%s)" % _GUT_CMDLN,
			"Install the GUT addon into this project, then call reload_project. See https://gut.readthedocs.io."
		)

	var gut_args: Array = ["-s", _GUT_CMDLN]

	# GUT refuses to run with no directories configured ("You do not have any
	# directories configured"); -gtest full paths select their own scripts, so
	# dirs are only required when no scripts were given. Resolution order:
	# explicit param, the project's .gutconfig.json, res://tests.
	var has_gutconfig := FileAccess.file_exists("res://.gutconfig.json")
	var ignore_config: bool = optional_bool(params, "ignore_config", false)
	var scripts: Array = _string_array_param(params, "scripts")
	var dirs: Array = _string_array_param(params, "dirs")
	if dirs.is_empty() and scripts.is_empty() and not (has_gutconfig and not ignore_config):
		if DirAccess.dir_exists_absolute("res://tests"):
			dirs = ["res://tests"]
		else:
			return error_invalid_params(
				"No test directories configured. Pass dirs (e.g. [\"res://tests/unit\"]) or scripts (full paths), create a .gutconfig.json, or add a res://tests directory."
			)
	for d: String in dirs:
		gut_args.append("-gdir=%s" % d)

	# -gtest is a list in GUT, so several exact scripts can be requested.
	for s: String in scripts:
		gut_args.append("-gtest=%s" % s)
	var select: String = optional_string(params, "select")
	if not select.is_empty():
		gut_args.append("-gselect=%s" % select)
	var unit_test_name: String = optional_string(params, "unit_test_name")
	if not unit_test_name.is_empty():
		gut_args.append("-gunit_test_name=%s" % unit_test_name)

	if optional_bool(params, "include_subdirs", true):
		gut_args.append("-ginclude_subdirs")
	if ignore_config:
		# "-gconfig=" (empty value) is GUT's documented way to load no config.
		gut_args.append("-gconfig=")

	# Plain text in raw_output, and never sit there without exiting: without
	# -gexit the child would wait until the timeout killed it.
	gut_args.append("-gdisable_colors")
	gut_args.append("-gexit")

	# Structured results come from GUT's JUnit XML export into a temp file
	# under user://, parsed and deleted afterwards whatever happened.
	var want_junit: bool = optional_bool(params, "junit", true)
	_gut_run_counter += 1
	var junit_path := "user://mcp_gut_junit_%d_%d.xml" % [OS.get_process_id(), _gut_run_counter]
	var junit_abs := ProjectSettings.globalize_path(junit_path)
	if FileAccess.file_exists(junit_abs):
		DirAccess.remove_absolute(junit_abs)
	if want_junit:
		gut_args.append("-gjunit_xml_file=%s" % junit_abs)

	var result: Dictionary = await _run_headless(params, gut_args, "GUT tests")

	# The JUnit file is this command's own temp file: read it before anything
	# else, then remove it — also on the error paths below.
	var parsed: Dictionary = {}
	if want_junit and FileAccess.file_exists(junit_abs):
		parsed = _parse_gut_junit(junit_abs)
		DirAccess.remove_absolute(junit_abs)

	if result.has("error"):
		return result
	var payload: Dictionary = result.get("result", {})

	var response: Dictionary = {
		"passed": bool(payload.get("success", false)),
		"exit_code": payload.get("exit_code", -1),
		"timed_out": payload.get("timed_out", false),
		"duration_sec": payload.get("duration_sec", 0.0),
		"command": payload.get("command", ""),
		"raw_output": payload.get("output", ""),
	}
	if not parsed.is_empty():
		response["totals"] = parsed["totals"]
		response["suites"] = parsed["suites"]
	elif want_junit:
		if payload.get("timed_out", false):
			response["junit_note"] = "No JUnit XML was written; the run was killed at the timeout before GUT finished."
		else:
			response["junit_note"] = "No JUnit XML could be read or parsed; rely on raw_output and exit_code."
	if payload.get("timed_out", false):
		response["suggestion"] = "Raise timeout_sec (up to 900) or narrow the run with dirs/scripts/select/unit_test_name."
	return success(response)


## Param value as an Array of Strings: a single string becomes a one-entry
## list; non-string entries are skipped rather than raising on caller input.
func _string_array_param(params: Dictionary, key: String) -> Array:
	var out: Array = []
	var raw: Variant = params.get(key, null)
	if raw is String:
		if not (raw as String).is_empty():
			out.append(raw)
	elif raw is Array:
		for entry: Variant in raw:
			if entry is String and not (entry as String).is_empty():
				out.append(entry)
	return out


## Parses GUT's JUnit XML export (GUT 9.x element and attribute names) into
## totals plus one suite per test script. Returns {} when the file cannot be
## opened or nothing was recognized; the caller then falls back to raw_output.
func _parse_gut_junit(path: String) -> Dictionary:
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		return {}
	var totals := {"tests": 0, "failures": 0, "skipped": 0}
	var suites: Array = []
	var suite: Dictionary = {}
	var case: Dictionary = {}
	var capture := ""  # "" = off, else the element whose CDATA is collected

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				if parser.is_empty():
					# A self-closing element never switches capture on.
					match parser.get_node_name():
						"testcase":
							case = _gut_case_from_attributes(parser)
							if not suite.is_empty():
								(suite["cases"] as Array).append(case)
					continue
				match parser.get_node_name():
					"testsuite":
						suite = {
							"script": parser.get_named_attribute_value_safe("name"),
							"tests": parser.get_named_attribute_value_safe("tests").to_int(),
							"failures": parser.get_named_attribute_value_safe("failures").to_int(),
							"skipped": parser.get_named_attribute_value_safe("skipped").to_int(),
							"time": parser.get_named_attribute_value_safe("time").to_float(),
							"cases": [],
						}
					"testcase":
						case = _gut_case_from_attributes(parser)
					"failure":
						capture = "failure"
						case["message"] = parser.get_named_attribute_value_safe("message")
					"skipped":
						capture = "skipped"
						case["message"] = parser.get_named_attribute_value_safe("message")
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if not capture.is_empty():
					# Godot's XMLParser delivers CDATA content through
					# get_node_name(), not get_node_data() (verified on 4.7.2).
					var chunk := parser.get_node_data()
					if chunk.is_empty():
						chunk = parser.get_node_name()
					case["detail"] = str(case.get("detail", "")) + chunk
			XMLParser.NODE_ELEMENT_END:
				match parser.get_node_name():
					"failure", "skipped":
						capture = ""
					"testcase":
						if not suite.is_empty() and not case.is_empty():
							(suite["cases"] as Array).append(case)
						case = {}
					"testsuite":
						if not suite.is_empty():
							suites.append(suite)
							totals["tests"] += int(suite["tests"])
							totals["failures"] += int(suite["failures"])
							totals["skipped"] += int(suite["skipped"])
						suite = {}
	if suites.is_empty():
		return {}
	totals["passing"] = int(totals["tests"]) - int(totals["failures"]) - int(totals["skipped"])
	return {"totals": totals, "suites": suites}


func _gut_case_from_attributes(parser: XMLParser) -> Dictionary:
	return {
		"name": parser.get_named_attribute_value_safe("name"),
		"status": parser.get_named_attribute_value_safe("status"),
		"time": parser.get_named_attribute_value_safe("time").to_float(),
	}


func _run_headless(params: Dictionary, target_args: Array, target: String, max_timeout_sec: float = _MAX_TIMEOUT_SEC, on_started: Callable = Callable()) -> Dictionary:
	var godot_bin := OS.get_executable_path()
	if godot_bin.is_empty():
		return error_internal("Could not determine the Godot executable path")

	var project_dir := ProjectSettings.globalize_path("res://")
	var timeout_sec: float = clampf(
		optional_float(params, "timeout_sec", _DEFAULT_TIMEOUT_SEC), 1.0, maxf(max_timeout_sec, 1.0)
	)

	var godot_args: Array = ["--headless", "--path", project_dir]
	godot_args.append_array(target_args)

	var quit_after: int = optional_int(params, "quit_after_frames", 0)
	if quit_after > 0:
		godot_args.append("--quit-after")
		godot_args.append(str(quit_after))

	var is_windows := OS.get_name() == "Windows"

	# Extra arguments for the project itself, after the `--` separator.
	var extra: Array = params.get("args", [])
	if extra is Array and not extra.is_empty():
		godot_args.append("--")
		for a: Variant in extra:
			var arg := str(a)
			if is_windows:
				# A batch file is line-oriented: a newline ends the command and
				# whatever follows runs as the next batch command. And there is
				# no escape for " inside a quoted batch string.
				if arg.contains('"'):
					return error_invalid_params(
						"Argument %s contains a double quote, which a Windows batch runner cannot represent." % arg
					)
				if arg.contains("\n") or arg.contains("\r"):
					return error_invalid_params(
						"Argument %s contains a line break, which would terminate the Windows batch command line." % arg
					)
			godot_args.append(arg)

	# Validate EVERY argument, not only the caller's extra args: target args
	# built from tool parameters (scene paths, export output paths, preset
	# names) end up on the same batch command line, and one embedded quote or
	# line break there would let the rest of the value run as a shell command.
	if is_windows:
		for a: Variant in godot_args:
			var arg := str(a)
			if arg.contains('"'):
				return error_invalid_params(
					"Argument %s contains a double quote, which a Windows batch runner cannot represent." % arg
				)
			if arg.contains("\n") or arg.contains("\r"):
				return error_invalid_params(
					"Argument %s contains a line break, which would terminate the Windows batch command line." % arg
				)

	_run_counter += 1
	var prefix := "user://mcp_headless_%d_%d" % [OS.get_process_id(), _run_counter]
	var paths := RunPaths.new(prefix, is_windows)
	paths.cleanup()

	var shell := _shell_invocation(godot_bin, godot_args, paths, is_windows)
	if shell.is_empty():
		# It may have written the runner before failing on the path check.
		paths.cleanup()
		return error_internal("Could not prepare the headless runner script under user://")

	var pid := OS.create_process(shell[0], shell[1])
	if pid <= 0:
		paths.cleanup()
		return error_internal("Failed to start headless Godot process")
	if on_started.is_valid():
		on_started.call(pid)

	# Measure against the clock rather than counting poll ticks: a stalled
	# editor frame makes a tick longer than _POLL_INTERVAL_SEC, and an
	# accumulator would then let the child run well past timeout_sec.
	var started_msec := Time.get_ticks_msec()
	var elapsed := 0.0
	var timed_out := false
	var kill_confirmed := true
	while OS.is_process_running(pid):
		await get_tree().create_timer(_POLL_INTERVAL_SEC).timeout
		elapsed = (Time.get_ticks_msec() - started_msec) / 1000.0
		if elapsed >= timeout_sec:
			# The child may have finished during the sleep above. Deciding from
			# the loop condition alone would report a successful run that
			# landed on the deadline as a timeout, and kill nothing.
			if not OS.is_process_running(pid):
				break
			timed_out = true
			_kill_process_tree(pid)
			kill_confirmed = await _await_process_exit(pid, _KILL_CONFIRM_SEC)
			break

	# A run that finished before the first poll never entered the loop, so take
	# the elapsed time here rather than leaving it at zero. On a timeout the
	# value is left as the deadline it hit, not the deadline plus the time
	# spent confirming the kill.
	if not timed_out:
		elapsed = (Time.get_ticks_msec() - started_msec) / 1000.0

	# Give the shell a moment to flush the redirect before reading it.
	await get_tree().create_timer(0.2).timeout

	var output := _read_text(paths.log_path)
	var truncated := false
	if output.length() > _MAX_OUTPUT_CHARS:
		output = output.substr(output.length() - _MAX_OUTPUT_CHARS)
		truncated = true

	var exit_code := -1
	var exit_text := _read_text(paths.exit_path).strip_edges()
	if exit_text.is_valid_int():
		exit_code = exit_text.to_int()

	paths.cleanup()

	var arg_strings := PackedStringArray()
	for a: Variant in godot_args:
		arg_strings.append(str(a))

	var payload := {
		"target": target,
		"command": "%s %s" % [godot_bin, " ".join(arg_strings)],
		"output": output,
		"exit_code": exit_code,
		"success": exit_code == 0 and not timed_out,
		"timed_out": timed_out,
		"duration_sec": snappedf(elapsed, 0.01),
	}
	if truncated:
		payload["output_truncated"] = true
		payload["note"] = "Output exceeded %d characters; only the tail is returned." % _MAX_OUTPUT_CHARS
	if timed_out:
		payload["kill_confirmed"] = kill_confirmed
		if kill_confirmed:
			payload["message"] = "Process exceeded timeout_sec=%s and was killed. Partial output is included." % str(timeout_sec)
		else:
			# Say so rather than claiming a kill that did not demonstrably happen.
			payload["message"] = "Process exceeded timeout_sec=%s and a kill was issued, but it was still running %ss later. It may survive this call — check for a stray Godot process. Partial output is included." % [
				str(timeout_sec), str(_KILL_CONFIRM_SEC)
			]

	return success(payload)


## Writes a runner script that redirects both streams to the log file and
## records the child's exit status in a second file, then returns the
## invocation for it.
##
## OS.create_process cannot capture output or an exit code on its own, and a
## pipe would deadlock a child that outprints the buffer before we read it.
## The command goes through a script file rather than an inline `-c` string
## because create_process re-quotes its arguments, which mangles a command line
## that already carries its own quoting — and paths with spaces are the norm on
## Windows and macOS.
func _shell_invocation(godot_bin: String, godot_args: Array, paths: RunPaths, is_windows: bool) -> Array:
	var native_log := _to_native(ProjectSettings.globalize_path(paths.log_path), is_windows)
	var native_exit := _to_native(ProjectSettings.globalize_path(paths.exit_path), is_windows)

	var command := _quote_arg(_to_native(godot_bin, is_windows), is_windows)
	for a: Variant in godot_args:
		command += " " + _quote_arg(str(a), is_windows)

	# The child runs the same editor binary and shares user://, so it would
	# otherwise pass the OS.has_feature("editor") check and start the MCP IPC
	# autoloads — which then race the editor's own play session for the
	# mcp_* request files. This marker tells the services to stand down.
	var body := ""
	if is_windows:
		# DisableDelayedExpansion matters when the machine has delayed expansion
		# on by default (a registry setting): a `!` in a path or argument would
		# otherwise be eaten or expanded.
		body = "@echo off\r\nsetlocal DisableDelayedExpansion\r\nset \"%s=1\"\r\n%s > %s 2>&1\r\necho %%errorlevel%% > %s\r\n" % [
			HEADLESS_CHILD_ENV, command, _quote_arg(native_log, true), _quote_arg(native_exit, true)
		]
	else:
		body = "#!/bin/sh\n%s=1\nexport %s\n%s > %s 2>&1\necho $? > %s\n" % [
			HEADLESS_CHILD_ENV, HEADLESS_CHILD_ENV,
			command, _quote_arg(native_log, false), _quote_arg(native_exit, false)
		]

	var file := FileAccess.open(paths.runner_path, FileAccess.WRITE)
	if file == null:
		return []
	file.store_string(body)
	file.close()

	var runner_native := _to_native(ProjectSettings.globalize_path(paths.runner_path), is_windows)
	if is_windows:
		# This path is parsed by cmd itself, where %VAR% is expanded regardless
		# of quoting and cannot be reliably escaped. Doubling only works inside
		# a batch file, not on cmd's own command line — so refuse rather than
		# run a command that means something else.
		if runner_native.contains("%"):
			push_error("[MCP] user:// path contains '%%', which cmd.exe would expand: %s" % runner_native)
			return []
		return ["cmd.exe", ["/c", runner_native]]
	return ["sh", [runner_native]]


## Quotes one argument for the generated runner script.
##
## Without this, a value containing $VAR, $(...), a backtick or a quote is
## expanded or executed by sh, and %VAR% is expanded by cmd — so ordinary
## caller-supplied arguments could be corrupted or run as shell syntax.
func _quote_arg(arg: String, is_windows: bool) -> String:
	if is_windows:
		# Batch neutralises % only by doubling it. A literal " cannot be
		# represented at all, which is why callers are rejected earlier.
		var escaped := arg.replace("%", "%%")
		# A run of backslashes immediately before the closing quote is read as
		# escapes by the callee's argv parser, so `C:\dir\` would swallow the
		# quote and merge with the next argument. Doubling them fixes it.
		var trailing := 0
		while trailing < escaped.length() and escaped[escaped.length() - 1 - trailing] == "\\":
			trailing += 1
		if trailing > 0:
			escaped += "\\".repeat(trailing)
		return '"%s"' % escaped
	# POSIX single quotes suppress every expansion; a literal ' is closed,
	# escaped and reopened.
	return "'%s'" % arg.replace("'", "'\\''")


## Waits for `pid` to disappear. Returns false if it is still running after
## `limit_sec`, so the caller can report an unconfirmed kill instead of
## asserting one that may not have happened.
func _await_process_exit(pid: int, limit_sec: float) -> bool:
	var waited := 0.0
	while OS.is_process_running(pid) and waited < limit_sec:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return not OS.is_process_running(pid)


## `pid` is the shell wrapper, not Godot itself. Killing only the shell orphans
## the Godot process, which then runs forever holding the log file open — so the
## whole tree has to go.
func _kill_process_tree(pid: int) -> void:
	var out: Array = []
	if OS.get_name() == "Windows":
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid)], out, true)
		return

	# pkill -P would only reach the shell's direct child. A test runner that
	# spawns its own helpers (a server, workers) would leave those running
	# after Godot exits, so walk the whole descendant tree depth-first.
	#
	# The script has to go through a FILE. Passing it inline to OS.execute does
	# not work: measured on Linux, every `$1`, `$c` and `$#` inside a `sh -c`
	# string arrives empty, so `pgrep -P ""` errors out and nothing is killed —
	# while the call still reports success. The pid is passed as an argv
	# element, which survives intact.
	var script_path := "user://mcp_kill_tree.sh"
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		push_error("[MCP] Could not write the kill helper; falling back to killing only the runner.")
		OS.kill(pid)
		return
	file.store_string(
		"#!/bin/sh\n"
		+ "kill_tree() {\n"
		+ "  for c in $(pgrep -P \"$1\" 2>/dev/null); do kill_tree \"$c\"; done\n"
		+ "  kill -9 \"$1\" 2>/dev/null\n"
		+ "}\n"
		+ "kill_tree \"$1\"\n"
	)
	file.close()

	OS.execute("sh", [ProjectSettings.globalize_path(script_path), str(pid)], out, true)
	OS.kill(pid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(script_path))


## Godot reports forward-slash paths everywhere; cmd.exe redirects want backslashes.
func _to_native(path: String, is_windows: bool) -> String:
	return path.replace("/", "\\") if is_windows else path


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
