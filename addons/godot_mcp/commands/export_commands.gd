@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"list_export_presets": _list_export_presets,
		"export_project": _export_project,
		"get_export_info": _get_export_info,
		"export_patch_pck": _export_patch_pck,
	}


func _list_export_presets(params: Dictionary) -> Dictionary:
	# Read export_presets.cfg
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		return success({"presets": [], "count": 0, "message": "No export_presets.cfg found"})

	var cfg := ConfigFile.new()
	var err := cfg.load(presets_path)
	if err != OK:
		return error_internal("Failed to read export_presets.cfg: %s" % error_string(err))

	var presets: Array = []
	var idx := 0
	while cfg.has_section("preset.%d" % idx):
		var section := "preset.%d" % idx
		presets.append({
			"index": idx,
			"name": cfg.get_value(section, "name", ""),
			"platform": cfg.get_value(section, "platform", ""),
			"runnable": cfg.get_value(section, "runnable", false),
			"export_path": cfg.get_value(section, "export_path", ""),
		})
		idx += 1

	return success({"presets": presets, "count": presets.size()})


func _export_project(params: Dictionary) -> Dictionary:
	var preset_index: int = optional_int(params, "preset_index", -1)
	var preset_name: String = optional_string(params, "preset_name", "")
	var debug: bool = optional_bool(params, "debug", true)

	# Find preset
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		return error(-32000, "No export_presets.cfg found. Configure exports in Project > Export first.")

	var cfg := ConfigFile.new()
	var err := cfg.load(presets_path)
	if err != OK:
		return error_internal("Failed to read export_presets.cfg")

	# Find by name or index
	var target_section := ""
	var target_name := ""
	var target_path := ""

	if not preset_name.is_empty():
		var idx := 0
		while cfg.has_section("preset.%d" % idx):
			var section := "preset.%d" % idx
			if cfg.get_value(section, "name", "") == preset_name:
				target_section = section
				target_name = preset_name
				target_path = cfg.get_value(section, "export_path", "")
				break
			idx += 1
	elif preset_index >= 0:
		var section := "preset.%d" % preset_index
		if cfg.has_section(section):
			target_section = section
			target_name = cfg.get_value(section, "name", "")
			target_path = cfg.get_value(section, "export_path", "")

	if target_section.is_empty():
		return error_not_found("Export preset")

	if target_path.is_empty():
		return error(-32000, "Export path not configured for preset '%s'" % target_name)

	# Use EditorExportPlatform via command line
	# We can't directly call export from the plugin, so we return the command to run
	var godot_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var export_path := ProjectSettings.globalize_path(target_path) if target_path.begins_with("res://") else target_path

	var flag := "--export-debug" if debug else "--export-release"
	var command := '"%s" --headless --path "%s" %s "%s"' % [godot_path, project_path, flag, target_name]

	return success({
		"preset": target_name,
		"export_path": export_path,
		"debug": debug,
		"command": command,
		"message": "Run the command above to export. Direct export from editor plugin is not supported in Godot 4.",
	})


## ── export_patch_pck ──────────────────────────────────────────────────────
## EditorExportPlatform.export_pack_patch() exists on 4.5.1, 4.6.2 and 4.7.2
## (preset, debug, path, patches = [], flags = 0), but a plugin cannot reach
## it: no script API returns the project's configured EditorExportPreset or an
## EditorExportPlatform instance (none are instantiable, and
## EditorExportPlugin.get_export_preset() only works during an export). So the
## patch is exported by a headless child running Godot's own
## `--export-patch <preset> <path> --patches <a,b>` CLI, which ends in the same
## export_pack_patch() call with the real preset. That CLI always exports in
## release mode (it never sets the debug flag).

const _HEADLESS_COMMANDS := preload("res://addons/godot_mcp/commands/headless_commands.gd")
const _PATCH_DEFAULT_TIMEOUT_SEC := 300.0
## Upper bound for timeout_sec; passed to the headless runner so its own
## 900s default cap does not silently cut a large export short.
const _PATCH_MAX_TIMEOUT_SEC := 1800.0
const _PATCH_MAX_OUTPUT_CHARS := 6000
## Keeps the runner's user:// temp files apart from run_headless_* runs.
static var _patch_run_seq := 0


func _export_patch_pck(params: Dictionary) -> Dictionary:
	var out_result := require_string(params, "output_path")
	if out_result[1] != null:
		return out_result[1]
	var output_path: String = out_result[0]

	if output_path.get_extension().to_lower() != "pck":
		return error_invalid_params("output_path must end in .pck, got '%s'" % output_path)
	var output_abs := _to_absolute_path(output_path)
	if output_abs.is_empty():
		return error_invalid_params("output_path must be a res://, user:// or absolute path, got '%s'" % output_path)
	var output_dir := output_abs.get_base_dir()
	if not DirAccess.dir_exists_absolute(output_dir):
		return error_not_found("Output directory '%s'" % output_dir, "Create it first; export_patch_pck does not create directories.")
	if output_abs.contains(","):
		return error_invalid_params("output_path must not contain a comma")
	if _has_cli_unsafe_chars(output_abs):
		return error_invalid_params("output_path must not contain a double quote or line break (it is passed on a batch command line)")

	# Preset, resolved exactly like export_project.
	var preset := _find_export_preset(optional_string(params, "preset_name", ""), optional_int(params, "preset_index", -1))
	if preset.has("error"):
		return preset

	# Base packs. Godot's --patches list is comma-separated, so a comma inside
	# a path cannot be passed through.
	var patches: Array = []
	var raw_patches: Variant = params.get("patches", [])
	if raw_patches != null and not raw_patches is Array:
		return error_invalid_params("patches must be an array of .pck paths")
	for entry: Variant in (raw_patches if raw_patches is Array else []):
		if not entry is String or (entry as String).is_empty():
			return error_invalid_params("Each patches entry must be a non-empty path string")
		var abs_path := _to_absolute_path(entry as String)
		if abs_path.is_empty():
			return error_invalid_params("Patch path must be a res://, user:// or absolute path, got '%s'" % entry)
		if not FileAccess.file_exists(abs_path):
			return error_not_found("Base pack '%s'" % entry)
		if abs_path.contains(","):
			return error_invalid_params("Patch path '%s' contains a comma, which Godot's --patches list cannot carry" % entry)
		if _has_cli_unsafe_chars(abs_path):
			return error_invalid_params("Patch path '%s' contains a double quote or line break" % entry)
		if paths_match(abs_path.simplify_path(), output_abs.simplify_path()):
			return error_invalid_params("output_path is also listed in patches; the patch must go to a different file than its base packs")
		patches.append(abs_path)
	var using_preset_patches := patches.is_empty()
	if using_preset_patches and (preset["patches"] as Array).is_empty():
		return error_invalid_params(
			"No base packs: pass 'patches' (the .pck files the game already ships), or configure the preset's Patches list in Project > Export."
		)
	if using_preset_patches:
		# The preset's own base packs must be protected too: exporting onto one
		# of them would replace the baseline with its own delta and break every
		# later patch. Preset entries may be res://, absolute, or relative to
		# the project directory.
		for entry: Variant in preset["patches"]:
			var base_abs := _to_absolute_path(str(entry))
			if base_abs.is_empty():
				base_abs = ProjectSettings.globalize_path("res://").path_join(str(entry))
			if paths_match(base_abs.simplify_path(), output_abs.simplify_path()):
				return error_invalid_params(
					"output_path '%s' is one of the preset's base packs; the patch must go to a different file" % output_path
				)
			if not FileAccess.file_exists(base_abs):
				return error_not_found(
					"Base pack '%s' from the preset's Patches list" % str(entry),
					"Export the base pack first, fix the preset's Patches list, or pass 'patches' explicitly."
				)

	var warnings: Array = []
	var unsaved: Variant = get_unsaved_scene_paths()
	if unsaved is Array and not (unsaved as Array).is_empty():
		warnings.append("Unsaved scenes are exported as last saved on disk: %s. Call save_scene first to include the edits." % ", ".join(PackedStringArray(unsaved)))

	var args: Array = ["--export-patch", preset["name"], output_abs]
	if not using_preset_patches:
		args.append("--patches")
		args.append(",".join(PackedStringArray(patches)))

	var timeout_sec: float = clampf(optional_float(params, "timeout_sec", _PATCH_DEFAULT_TIMEOUT_SEC), 10.0, _PATCH_MAX_TIMEOUT_SEC)
	var started_unix := Time.get_unix_time_from_system()

	var runner: Node = _HEADLESS_COMMANDS.new()
	runner.editor_plugin = editor_plugin
	_patch_run_seq += 1
	runner.set("_run_counter", 900000 + _patch_run_seq)
	add_child(runner)
	var run: Dictionary = await runner._run_headless({"timeout_sec": timeout_sec}, args, "export_patch_pck", _PATCH_MAX_TIMEOUT_SEC)
	runner.queue_free()
	if run.has("error"):
		return run
	var outcome: Dictionary = run.get("result", {})

	var ansi := RegEx.create_from_string(String.chr(27) + "[[][0-9;]*m")
	var log_text: String = ansi.sub(str(outcome.get("output", "")), "", true)
	if log_text.length() > _PATCH_MAX_OUTPUT_CHARS:
		log_text = log_text.substr(log_text.length() - _PATCH_MAX_OUTPUT_CHARS)

	var produced := FileAccess.file_exists(output_abs) and FileAccess.get_modified_time(output_abs) >= int(started_unix) - 1
	var data := {
		"preset": preset["name"],
		"platform": preset["platform"],
		"output_path": output_abs,
		"patches": patches if not using_preset_patches else preset["patches"],
		"patches_source": "preset" if using_preset_patches else "params",
		"debug": false,
		"exit_code": outcome.get("exit_code", -1),
		"timed_out": outcome.get("timed_out", false),
		"duration_sec": outcome.get("duration_sec", 0.0),
		"command": outcome.get("command", ""),
		"output_tail": log_text,
	}
	if not warnings.is_empty():
		data["warnings"] = warnings
	if log_text.contains("No files or changes to export"):
		# Godot treats "nothing differs from the base packs" as a failed export.
		# Say so plainly instead of reporting an opaque exit code.
		data["no_changes"] = true
		data["suggestion"] = "Nothing in the project differs from the base packs, so there is no patch to ship. Change or add files, then export again."
		return error(-32000, "No patch written: nothing changed since the base packs", data)
	if int(outcome.get("exit_code", -1)) != 0 or bool(outcome.get("timed_out", false)) or not produced:
		data["suggestion"] = "Check output_tail. Common causes: a wrong preset name, base packs from another project, or an export already running."
		return error(-32000, "Patch export failed (exit code %s%s)" % [
			str(outcome.get("exit_code", -1)),
			", timed out" if outcome.get("timed_out", false) else ("" if produced else ", no output file written"),
		], data)

	var f := FileAccess.open(output_abs, FileAccess.READ)
	data["output_size_bytes"] = f.get_length() if f != null else -1
	if f != null:
		f.close()
	# On success the log is just the list of stored files; keep only its end.
	if log_text.length() > 1500:
		data["output_tail"] = log_text.substr(log_text.length() - 1500)
	data["note"] = "Exported in release mode: Godot's --export-patch CLI has no debug variant."
	return success(data)


## True when a path cannot be carried on the headless runner's command line.
func _has_cli_unsafe_chars(path: String) -> bool:
	return path.contains('"') or path.contains("
") or path.contains("")


## res:// and user:// are globalized; an absolute OS path passes through.
## Relative paths return "" because the child process would resolve them
## against the project directory, not the caller's working directory.
func _to_absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return ""


## Looks a preset up in export_presets.cfg by name, or by index when no name is
## given. Returns {name, platform, patches} or an error dictionary.
func _find_export_preset(preset_name: String, preset_index: int) -> Dictionary:
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		return error(-32000, "No export_presets.cfg found. Configure exports in Project > Export first.")
	var cfg := ConfigFile.new()
	var err := cfg.load(presets_path)
	if err != OK:
		return error_internal("Failed to read export_presets.cfg: %s" % error_string(err))

	var section := ""
	if not preset_name.is_empty():
		var idx := 0
		while cfg.has_section("preset.%d" % idx):
			if cfg.get_value("preset.%d" % idx, "name", "") == preset_name:
				section = "preset.%d" % idx
				break
			idx += 1
	elif preset_index >= 0 and cfg.has_section("preset.%d" % preset_index):
		section = "preset.%d" % preset_index
	if section.is_empty():
		return error_not_found("Export preset", "Use list_export_presets to see the configured presets")

	var found_name := str(cfg.get_value(section, "name", ""))
	if found_name.contains('"') or found_name.contains("\n") or found_name.contains("\r"):
		# The headless runner is a batch file on Windows, which can carry neither.
		return error_invalid_params("Export preset name '%s' contains a quote or line break and cannot be passed to the Godot CLI" % found_name)
	var preset_patches: Array = []
	var raw: Variant = cfg.get_value(section, "patches", PackedStringArray())
	if raw is PackedStringArray or raw is Array:
		for p: Variant in raw:
			preset_patches.append(str(p))
	return {"name": found_name, "platform": str(cfg.get_value(section, "platform", "")), "patches": preset_patches}


func _get_export_info(params: Dictionary) -> Dictionary:
	# General export-related project info
	var info := {}

	# Check if export_presets.cfg exists
	info["has_export_presets"] = FileAccess.file_exists("res://export_presets.cfg")

	# Get Godot executable path (useful for command-line exports)
	info["godot_executable"] = OS.get_executable_path()
	info["project_path"] = ProjectSettings.globalize_path("res://")

	# Check for common export templates
	var templates_path := OS.get_data_dir().path_join("export_templates")
	info["templates_dir"] = templates_path
	info["templates_installed"] = DirAccess.dir_exists_absolute(templates_path)

	return success(info)
