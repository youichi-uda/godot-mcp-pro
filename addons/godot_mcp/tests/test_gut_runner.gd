extends SceneTree

## Logic tests for the run_gut_tests command (issue #44).
##
## Requires a scratch project that has BOTH the addon and GUT installed, plus
## the two sample scripts below under res://tests/unit:
##
##   test_sample_pass.gd: test_addition, test_string        (both pass)
##   test_sample_fail.gd: test_subtraction (fails), test_pending (pending)
##
## Run:
##   godot --headless --path <scratch-with-gut> \
##         --script res://addons/godot_mcp/tests/test_gut_runner.gd
##
## The suite SKIPS (exit 0) when GUT is not installed, so it can live in any
## project that has the addon. Exits 1 when a check fails.

var _failures: int = 0
var _checks: int = 0
var _cmd: Node


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	if not FileAccess.file_exists("res://addons/gut/gut_cmdln.gd"):
		print("SKIP: GUT is not installed in this project (res://addons/gut/gut_cmdln.gd missing).")
		print("RESULT: skipped")
		quit(0)
		return
	if not FileAccess.file_exists("res://tests/unit/test_sample_pass.gd") \
			or not FileAccess.file_exists("res://tests/unit/test_sample_fail.gd"):
		print("SKIP: sample test scripts (res://tests/unit/test_sample_{pass,fail}.gd) not present.")
		print("RESULT: skipped")
		quit(0)
		return

	_cmd = load("res://addons/godot_mcp/commands/headless_commands.gd").new()
	root.add_child(_cmd)
	await process_frame

	# T1: full run over the sample suite. One failing test and one pending
	# test are expected, so the run completes and reports passed=false with
	# exact totals, per-script suites and a failure detail carrying the line.
	var r1: Dictionary = await _cmd._run_gut_tests({"dirs": ["res://tests/unit"]})
	var t1 := _result_of(r1)
	_check("T1 completed with results", t1.has("totals"))
	if t1.has("totals"):
		var totals: Dictionary = t1["totals"]
		_check("T1 passed=false (one failing test)", t1.get("passed", true) == false)
		_check("T1 totals 4 tests / 1 failure / 1 skipped / 2 passing",
			int(totals.get("tests", -1)) == 4 and int(totals.get("failures", -1)) == 1
			and int(totals.get("skipped", -1)) == 1 and int(totals.get("passing", -1)) == 2)
		_check("T1 two suites (one per script)", (t1.get("suites", []) as Array).size() == 2)
		var failing: Dictionary = {}
		for s: Dictionary in t1.get("suites", []):
			for c: Dictionary in s.get("cases", []):
				if str(c.get("status", "")) == "fail":
					failing = c
		_check("T1 failing case found with detail and source line",
			not failing.is_empty() and str(failing.get("detail", "")).contains("at line"))
	_check("T1 junit temp file cleaned up", not FileAccess.file_exists(_first_stale_junit()))

	# T2: exact script selection — only the passing script runs.
	var r2: Dictionary = await _cmd._run_gut_tests({"scripts": ["res://tests/unit/test_sample_pass.gd"]})
	var t2 := _result_of(r2)
	_check("T2 selected script run passed", t2.get("passed", false) == true)
	_check("T2 selected script totals 2 tests / 0 failures",
		int(t2.get("totals", {}).get("tests", -1)) == 2 and int(t2.get("totals", {}).get("failures", -1)) == 0)

	# T3: down to a single pending test by name — pending does not fail a run.
	var r3: Dictionary = await _cmd._run_gut_tests({
		"select": "test_sample_fail",
		"unit_test_name": "test_pending",
	})
	var t3 := _result_of(r3)
	_check("T3 single pending test passed (pending does not fail)", t3.get("passed", false) == true)
	if t3.has("suites"):
		var cases: Array = (t3["suites"] as Array)[0].get("cases", [])
		_check("T3 exactly one case, status pending", cases.size() == 1 and str(cases[0].get("status", "")) == "pending")

	# T4: junit=false skips the XML entirely but still reports pass/fail.
	var r4: Dictionary = await _cmd._run_gut_tests({"dirs": ["res://tests/unit"], "junit": false})
	var t4 := _result_of(r4)
	_check("T4 junit=false reports pass/fail from the exit code", t4.get("passed", true) == false)
	_check("T4 junit=false has no suites", not t4.has("suites"))
	_check("T4 junit=false still has raw_output", str(t4.get("raw_output", "")).length() > 0)

	# T5: no dirs resolvable (no param, config ignored, res://tests hidden)
	# must be a clear parameter error, not a mystery GUT failure.
	DirAccess.rename_absolute("res://tests", "res://tests_hidden")
	var r5: Dictionary = await _cmd._run_gut_tests({"ignore_config": true})
	DirAccess.rename_absolute("res://tests_hidden", "res://tests")
	_check("T5 no directories configured is a parameter error",
		r5.has("error") and int(r5["error"].get("code", 0)) == -32602)

	# T6: a zero-test selection (nothing matches) completes with 0 tests
	# instead of hanging or erroring.
	var r6: Dictionary = await _cmd._run_gut_tests({"dirs": ["res://tests/unit"], "unit_test_name": "no_such_test_anywhere"})
	var t6 := _result_of(r6)
	_check("T6 zero-match selection completes with 0 tests",
		t6.has("totals") and int(t6["totals"].get("tests", -1)) == 0)

	print("")
	print("RESULT: %d/%d checks passed" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


func _result_of(response: Dictionary) -> Dictionary:
	if response.has("error"):
		_check("unexpected error: " + str(response["error"].get("message", "")), false)
		return {}
	return response.get("result", {})


func _first_stale_junit() -> String:
	var dir := DirAccess.open("user://")
	for f: String in dir.get_files():
		if f.begins_with("mcp_gut_junit_"):
			return ProjectSettings.globalize_path("user://" + f)
	return "user://mcp_gut_junit_none"


func _check(name: String, passed: bool) -> void:
	_checks += 1
	if passed:
		print("PASS %s" % name)
	else:
		_failures += 1
		print("FAIL %s" % name)
