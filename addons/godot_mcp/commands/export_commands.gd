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
## One patch export at a time per editor: Godot 4.4's packer writes through
## a fixed temporary file name in the editor's temp directory, so two
## concurrent exports could interleave into a corrupt pack.
static var _patch_export_busy := false


## Called when the plugin starts: a handler freed mid-export (plugin disabled
## or editor restarting) never cleared the static flag, which would block
## every later export for the rest of the editor session.
static func reset_export_session_state() -> void:
	_patch_export_busy = false


## Runner process of the running (or abandoned) patch export. Kept across
## plugin lifetimes: disabling the plugin frees the handler but not the OS
## process, and a second export must not overlap it (Godot 4.4's packer uses
## a fixed temp file name).
static var _patch_export_pid := 0


static func _patch_export_running() -> bool:
	if _patch_export_busy:
		return true
	return _patch_export_pid > 0 and OS.is_process_running(_patch_export_pid)


static func _set_patch_export_pid(pid: int) -> void:
	_patch_export_pid = pid


## Temp output of the running export, removed by abort_active_export().
static var _patch_export_temp_abs := ""


## Called when the plugin exits. The handler awaiting the export is freed
## with the plugin, taking its timeout and cleanup with it, so end the child
## process tree here and remove what it would have left behind.
static func abort_active_export() -> void:
	if _patch_export_pid > 0 and OS.is_process_running(_patch_export_pid):
		var killer: Node = _HEADLESS_COMMANDS.new()
		killer.call("_kill_process_tree", _patch_export_pid)
		killer.free()
	_patch_export_pid = 0
	_patch_export_busy = false
	if not _patch_export_temp_abs.is_empty():
		DirAccess.remove_absolute(_patch_export_temp_abs)
		_patch_export_temp_abs = ""
	# Runner files of patch exports use run counters from 900000 up.
	var dir := DirAccess.open("user://")
	if dir != null:
		var prefix := "mcp_headless_%d_9" % OS.get_process_id()
		for f in dir.get_files():
			if f.begins_with(prefix):
				dir.remove(f)


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

	# Godot opens the destination for writing before it knows whether there
	# is anything to export, so a failed or no-change export used to replace
	# an existing, valid patch with a stub. Export to a temp file next to it
	# and move it into place only on success.
	var temp_abs := output_abs.get_base_dir().path_join(".%s.mcp-%d-%d.tmp.pck" % [output_abs.get_file().get_basename(), OS.get_process_id(), Time.get_ticks_usec()])
	# Path comparison cannot see through junctions, symlinks or other aliases,
	# so also refuse when the file at output_path IS one of the base packs by
	# content: overwriting it would replace the baseline with its own delta.
	var base_list: Array = patches.duplicate()
	if using_preset_patches:
		for entry: Variant in preset["patches"]:
			var base_abs2 := _to_absolute_path(str(entry))
			base_list.append(base_abs2 if not base_abs2.is_empty() else ProjectSettings.globalize_path("res://").path_join(str(entry)))
	var alias_of := _find_same_content(output_abs, base_list)
	if not alias_of.is_empty():
		return error_invalid_params(
			"output_path '%s' holds the same bytes as base pack '%s' (the same file through a link, or a copy of it); the patch must go to a different file" % [output_path, alias_of]
		)
	var args: Array = ["--export-patch", preset["name"], temp_abs]
	# Always pass the validated list explicitly, even when it came from the
	# preset: without --patches Godot re-reads the preset when the child
	# starts, and an edit to its Patches list while this call waited would
	# export against (and possibly overwrite) a pack nobody checked.
	for bp in base_list:
		if str(bp).contains(",") or _has_cli_unsafe_chars(str(bp)):
			return error_invalid_params("Base pack path '%s' contains a comma, quote or line break, which cannot be passed to Godot's --patches" % bp)
	args.append("--patches")
	args.append(",".join(PackedStringArray(base_list)))

	var timeout_sec: float = clampf(optional_float(params, "timeout_sec", _PATCH_DEFAULT_TIMEOUT_SEC), 10.0, _PATCH_MAX_TIMEOUT_SEC)
	var started_unix := Time.get_unix_time_from_system()

	# Measured on the monotonic clock: a stalled editor (a long
	# execute_editor_script, a modal dialog) delays timers, and counting timer
	# ticks would then leave the export almost its whole budget after the
	# caller had already timed out.
	var deadline_ms := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while _patch_export_running() and Time.get_ticks_msec() < deadline_ms:
		await get_tree().create_timer(0.1).timeout
	if _patch_export_running():
		return error(-32000, "Another export_patch_pck is still running in this editor", {"suggestion": "Retry once it finishes; patch exports are serialised."})
	_patch_export_busy = true
	var runner: Node = _HEADLESS_COMMANDS.new()
	runner.editor_plugin = editor_plugin
	_patch_run_seq += 1
	runner.set("_run_counter", 900000 + _patch_run_seq)
	add_child(runner)
	# One deadline covers queueing and the export itself; the MCP server's
	# own timeout is derived from timeout_sec, so the child must not get a
	# fresh full budget after waiting in the queue.
	var remaining_sec := (deadline_ms - Time.get_ticks_msec()) / 1000.0
	if remaining_sec < 5.0:
		_patch_export_busy = false
		runner.queue_free()
		return error(-32000, "Timed out waiting for another export_patch_pck to finish", {"suggestion": "Retry once it finishes, or pass a larger timeout_sec."})
	_patch_export_temp_abs = temp_abs
	var run: Dictionary = await runner._run_headless({"timeout_sec": remaining_sec}, args, "export_patch_pck", _PATCH_MAX_TIMEOUT_SEC, _set_patch_export_pid)
	runner.queue_free()
	_patch_export_busy = false
	_patch_export_pid = 0
	_patch_export_temp_abs = ""
	if run.has("error"):
		return run
	var outcome: Dictionary = run.get("result", {})

	var ansi := RegEx.create_from_string(String.chr(27) + "[[][0-9;]*m")
	var log_text: String = ansi.sub(str(outcome.get("output", "")), "", true)
	if log_text.length() > _PATCH_MAX_OUTPUT_CHARS:
		log_text = log_text.substr(log_text.length() - _PATCH_MAX_OUTPUT_CHARS)

	var produced := FileAccess.file_exists(temp_abs)
	var data := {
		"preset": preset["name"],
		"platform": preset["platform"],
		"output_path": output_abs,
		"patches": base_list,
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
	var unverified_pack := false
	var failed := log_text.contains("No files or changes to export") or int(outcome.get("exit_code", -1)) != 0 or bool(outcome.get("timed_out", false)) or not produced
	if failed:
		DirAccess.remove_absolute(temp_abs)
	else:
		# Replace the destination only now, and never lose it: move the old
		# pack aside, move the new one in, and roll back if that fails (on
		# Windows another process holding the temp file blocks the rename).
		# Godot 4.4's packer ignores failed payload writes (e.g. a full disk)
		# and still exits 0, so check the pack is structurally complete
		# before it may replace anything.
		var pck_problem := pck_structure_problem(temp_abs)
		if pck_problem == "UNVERIFIABLE":
			# Encrypted directory: its integrity cannot be checked here. Never
			# let an unverifiable pack replace an existing one; a new file is
			# fine (nothing is lost) but is reported as unverified.
			if FileAccess.file_exists(output_abs):
				DirAccess.remove_absolute(temp_abs)
				return error(-32000, "The patch has an encrypted file directory, so its integrity cannot be verified; the existing file at output_path was left untouched", {
					"suggestion": "Export to a new output_path (an unverified pack never replaces an existing one), then check it and replace the old one yourself.",
				})
			unverified_pack = true
			pck_problem = ""
		if not pck_problem.is_empty():
			DirAccess.remove_absolute(temp_abs)
			return error(-32000, "The exported patch %s; the existing file at output_path was left untouched" % pck_problem, {
				"suggestion": "Check free disk space where output_path lives, then export again.",
			})
		var late_alias := _find_same_content(output_abs, base_list)
		if not late_alias.is_empty():
			DirAccess.remove_absolute(temp_abs)
			return error_invalid_params("output_path now holds the same bytes as base pack '%s'; refusing to replace it" % late_alias)
		var backup_abs := ""
		if FileAccess.file_exists(output_abs):
			backup_abs = temp_abs.get_basename() + ".previous.pck"
			var bk_err := DirAccess.rename_absolute(output_abs, backup_abs)
			if bk_err != OK:
				DirAccess.remove_absolute(temp_abs)
				return error_internal("Patch exported, but the existing '%s' could not be moved aside to replace it (left untouched): %s" % [output_abs, error_string(bk_err)])
		var mv_err := DirAccess.rename_absolute(temp_abs, output_abs)
		if mv_err != OK:
			var restored := backup_abs.is_empty() or DirAccess.rename_absolute(backup_abs, output_abs) == OK
			return error_internal("Patch exported to '%s' but could not be moved to '%s': %s. %s" % [
				temp_abs, output_abs, error_string(mv_err),
				"The previous pack was restored." if restored else "The previous pack is at '%s'." % backup_abs,
			])
		if not backup_abs.is_empty():
			DirAccess.remove_absolute(backup_abs)
	if log_text.contains("No files or changes to export"):
		# Godot treats "nothing differs from the base packs" as a failed export.
		# Say so plainly instead of reporting an opaque exit code.
		data["no_changes"] = true
		data["suggestion"] = "Nothing in the project differs from the base packs, so there is no patch to ship. Change or add files, then export again. Any existing file at output_path was left untouched."
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
	if unverified_pack:
		data["integrity_verified"] = false
		data["warning"] = "The pack's file directory is encrypted, so its completeness could not be checked. Verify it (e.g. load it in a test build) before shipping."
	return success(data)


## Returns the first path in `bases` whose file has exactly the same size and
## MD5 as `path`, or "" when none does (or `path` does not exist). Used to
## catch a destination that is a base pack under another name.
func _find_same_content(path: String, bases: Array) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var size := _file_size(path)
	var md5 := ""
	for b: Variant in bases:
		var bp := str(b)
		if not FileAccess.file_exists(bp) or _file_size(bp) != size:
			continue
		if md5.is_empty():
			md5 = FileAccess.get_md5(path)
		if FileAccess.get_md5(bp) == md5:
			return bp
	return ""


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n


## "" when the file at `path` is a structurally complete Godot pack, else a
## short reason. Reads the header and the file directory (format 2 as
## written by Godot 4.0-4.4, 3+ with a directory offset as written by 4.5+)
## and checks every stored file lies within the pack's data. Offsets are
## relative to the header's file base, as the packers write them.
static func pck_structure_problem(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "cannot be opened"
	var length := f.get_length()
	if length < 104:
		return "is too short to be a pack"
	if f.get_32() != 0x43504447:
		return "has no pack header"
	var version := f.get_32()
	f.get_32()
	f.get_32()
	f.get_32()
	var flags := f.get_32()
	var file_base := f.get_64()
	var payload_end := length
	if version >= 3:
		var dir_offset := f.get_64()
		if dir_offset <= 0 or dir_offset >= length:
			return "is truncated: its file directory lies outside the file"
		payload_end = dir_offset
		f.seek(dir_offset)
	else:
		f.seek(24 + 8 + 64)
	if flags & 1:
		return "UNVERIFIABLE"  # encrypted directory: contents cannot be checked without the key
	if f.get_position() + 4 > length:
		return "is truncated: its file directory is incomplete"
	var count := f.get_32()
	if count > 1000000:
		return "has an implausible file count"
	for _i in count:
		if f.get_position() + 4 > length:
			return "is truncated: its file directory is incomplete"
		var path_len := f.get_32()
		if path_len > 65536 or f.get_position() + path_len + 36 > length:
			return "is truncated: its file directory is incomplete"
		f.seek(f.get_position() + path_len)
		var ofs := f.get_64()
		var size := f.get_64()
		f.seek(f.get_position() + 16)  # md5
		var file_flags := f.get_32()
		# An encrypted file (PACK_FILE_ENCRYPTED) is stored as a 40-byte header
		# (md5, length, iv) followed by its data padded to 16-byte AES blocks,
		# so it occupies more than its plain size.
		var stored := size
		if file_flags & 1:
			stored = 40 + ((size + 15) / 16) * 16
		if file_base + ofs + stored > payload_end:
			return "is truncated: a stored file extends past the end of its data"
	return ""


## True when a path cannot be carried on the headless runner's command line.
func _has_cli_unsafe_chars(path: String) -> bool:
	return path.contains('"') or path.contains("\n") or path.contains("\r")


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
