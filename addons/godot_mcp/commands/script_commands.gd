@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"list_scripts": _list_scripts,
		"read_script": _read_script,
		"create_script": _create_script,
		"edit_script": _edit_script,
		"attach_script": _attach_script,
		"get_open_scripts": _get_open_scripts,
		"validate_script": _validate_script,
		"close_script": _close_script,
		"reload_open_scripts": _reload_open_scripts,
	}


func _guard_script_file_path(path: String, operation: String) -> Dictionary:
	var ext := path.get_extension().to_lower()
	if ext in ["gd", "cs"]:
		return {}
	return error(
		-32602,
		"%s only supports script files (.gd, .cs): %s" % [operation, normalize_project_path(path)],
		{
			"path": normalize_project_path(path),
			"extension": ext,
			"suggestion": "Use scene commands for .tscn/.scn files and shader commands for shader resources.",
		}
	)


func _list_scripts(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var recursive: bool = optional_bool(params, "recursive", true)

	var scripts: Array = []
	_find_scripts(path, recursive, scripts)

	return success({"scripts": scripts, "count": scripts.size()})


func _find_scripts(path: String, recursive: bool, scripts: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			if recursive:
				_find_scripts(full_path, recursive, scripts)
		elif file_name.get_extension() in ["gd", "cs", "gdshader"]:
			var info := {"path": full_path, "type": file_name.get_extension()}
			# Get basic file info
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				info["size"] = file.get_length()
				# Read first line for class/extends info
				var first_line := file.get_line().strip_edges()
				if first_line.begins_with("class_name "):
					info["class_name"] = first_line.substr(11).strip_edges()
				elif first_line.begins_with("extends "):
					info["extends"] = first_line.substr(8).strip_edges()
				file.close()
			scripts.append(info)

		file_name = dir.get_next()

	dir.list_dir_end()


func _read_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Script '%s'" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read script: %s" % error_string(FileAccess.get_open_error()))

	var content := file.get_as_text()
	var line_count := content.count("\n") + 1
	file.close()

	return success({
		"path": path,
		"content": content,
		"line_count": line_count,
		"size": content.length(),
	})


func _create_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]
	var path_guard := _guard_script_file_path(path, "create_script")
	if not path_guard.is_empty():
		return path_guard

	var content: String = optional_string(params, "content", "")
	var base_class: String = optional_string(params, "extends", "Node")
	var class_name_str: String = optional_string(params, "class_name", "")
	var force: bool = optional_bool(params, "force", false)

	var guard := guard_text_resource_write(path, force)
	if not guard.is_empty():
		return guard
	# Only reachable while the file is open when force=true bypassed the guard.
	var open_in_editor := is_text_resource_open_in_script_editor(path)

	# Generate template if no content provided
	if content.is_empty():
		var lines: PackedStringArray = []
		if not class_name_str.is_empty():
			lines.append("class_name %s" % class_name_str)
		lines.append("extends %s" % base_class)
		lines.append("")
		lines.append("")
		lines.append("func _ready() -> void:")
		lines.append("\tpass")
		lines.append("")
		content = "\n".join(lines)

	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_internal("Cannot create script: %s" % error_string(FileAccess.get_open_error()))

	file.store_string(content)
	file.close()

	# Prove the write instead of assuming it; see base_command.gd.
	var verify := verify_text_write(path, content, "create_script")
	if not verify.is_empty():
		return verify
	watch_text_persistence(path, content.md5_text(), "create_script")

	var payload := {"path": path, "created": true}
	if open_in_editor:
		await _sync_open_editor_buffer(path, payload)

	EditorInterface.get_resource_filesystem().scan()

	# Pre-load so the script is available immediately
	if ResourceLoader.exists(path):
		var script = load(path)
		if script is Script:
			script.reload(true)

	return success(payload)


func _edit_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]
	var path_guard := _guard_script_file_path(path, "edit_script")
	if not path_guard.is_empty():
		return path_guard

	if not FileAccess.file_exists(path):
		return error_not_found("Script '%s'" % path)

	var force: bool = optional_bool(params, "force", false)
	var guard := guard_text_resource_write(path, force)
	if not guard.is_empty():
		return guard
	# Only reachable while the file is open when force=true bypassed the guard.
	var open_in_editor := is_text_resource_open_in_script_editor(path)

	# The read-modify-write section runs exclusively per file path: several
	# MCP sessions can ride the same editor at once (each through its own
	# server port), and two overlapping edits on one file interleave into a
	# silently lost update.
	var written: Dictionary = await run_path_serialized(path, _edit_script_write.bind(path, params))
	if written.has("error"):
		return written
	var write_result: Dictionary = written.get("result", {})

	var changes_made: int = write_result.get("changes_made", 0)
	if changes_made == 0:
		return success({"path": path, "changes_made": 0, "message": "No changes applied"})

	# The write was verified against disk before this response was built;
	# without that check a success answer only meant store_string() was
	# called, not that the file kept the content.
	var payload := {"path": path, "changes_made": changes_made, "disk_verified": true}
	var indent_warning: String = write_result.get("indent_warning", "")
	if not indent_warning.is_empty():
		payload["indentation_warning"] = indent_warning

	if open_in_editor:
		await _sync_open_editor_buffer(path, payload)

	# Reload the script resource so the editor picks up changes immediately
	_reload_script(path)

	# Report immediately if the edit left the file unparseable. Writing blindly
	# is how a bad edit stays invisible until something else fails much later.
	var check := await _validate_script({"path": path})
	var check_result: Dictionary = check.get("result", {})
	if check_result.get("valid") == false:
		payload["valid_after_edit"] = false
		payload["message"] = "The edit was written, but the file no longer parses. Review it or edit again."
		if check_result.has("parse_errors"):
			payload["parse_errors"] = check_result["parse_errors"]
	elif check_result.get("valid") == true:
		payload["valid_after_edit"] = true

	return success(payload)


## Read-modify-write part of edit_script, executed via run_path_serialized so
## concurrent edits to the same file are ordered. Returns
## success({"changes_made": int, "indent_warning": String}) or an error
## dictionary, following the same shape as every other handler.
func _edit_script_write(path: String, params: Dictionary) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read script: %s" % error_string(FileAccess.get_open_error()))

	var content := file.get_as_text()
	file.close()
	var original_for_diff := content

	var changes_made := 0

	# Support search-and-replace
	if params.has("replacements") and params["replacements"] is Array:
		var replacements: Array = params["replacements"]
		for replacement in replacements:
			if replacement is Dictionary:
				var search: String = replacement.get("search", "")
				var replace: String = replacement.get("replace", "")
				if not search.is_empty():
					var use_regex: bool = replacement.get("regex", false)
					if use_regex:
						var regex := RegEx.new()
						var err := regex.compile(search)
						if err == OK:
							var new_content := regex.sub(content, replace, true)
							if new_content != content:
								content = new_content
								changes_made += 1
					else:
						if content.contains(search):
							content = content.replace(search, replace)
							changes_made += 1

	# Support 1-based inclusive line range replacement
	elif params.has("content") and (params.has("start_line") or params.has("end_line")):
		if not params.has("start_line"):
			return error_invalid_params("start_line is required when end_line is provided")
		var start_line: int = optional_int(params, "start_line")
		var end_line: int = optional_int(params, "end_line", start_line)
		var lines := content.split("\n")
		if start_line < 1:
			return error_invalid_params("start_line must be >= 1")
		if end_line < start_line:
			return error_invalid_params("end_line must be >= start_line")
		if start_line > lines.size():
			return error_invalid_params("start_line is beyond the end of the file")
		if end_line > lines.size():
			return error_invalid_params("end_line is beyond the end of the file")

		var replacement_lines := str(params["content"]).split("\n")
		var start_index := start_line - 1
		var remove_count := end_line - start_line + 1
		for _i in range(remove_count):
			lines.remove_at(start_index)
		for i in range(replacement_lines.size()):
			lines.insert(start_index + i, replacement_lines[i])
		content = "\n".join(lines)
		changes_made = 1

	# Support full content replacement
	elif params.has("content"):
		content = str(params["content"])
		changes_made = 1

	# Support insert at line
	elif params.has("insert_at_line") and params.has("text"):
		var line_num: int = optional_int(params, "insert_at_line")
		var text: String = str(params["text"])
		var lines := content.split("\n")
		line_num = clampi(line_num, 0, lines.size())
		lines.insert(line_num, text)
		content = "\n".join(lines)
		changes_made = 1

	if changes_made == 0:
		return success({"changes_made": 0, "indent_warning": ""})

	var original_content := original_for_diff
	var indent_warning := _indentation_mismatch_warning(original_content, content)

	# Write back
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_internal("Cannot write script: %s" % error_string(FileAccess.get_open_error()))

	file.store_string(content)
	file.close()

	# Prove the write instead of assuming it: report an error, with md5
	# evidence, when the file on disk does not hold what was just written.
	var verify := verify_text_write(path, content, "edit_script")
	if not verify.is_empty():
		return verify
	watch_text_persistence(path, content.md5_text(), "edit_script")

	return success({"changes_made": changes_made, "indent_warning": indent_warning})


## Flags an edit whose indentation style differs from the file's own.
##
## edit_script writes content verbatim — it never reindents — so when a caller
## supplies a snippet indented differently from the surrounding file, the file
## silently ends up mixed or wrongly nested. Reported as a warning rather than
## a refusal, since a deliberate reindent is legitimate.
func _indentation_mismatch_warning(before: String, after: String) -> String:
	var before_style := _detect_indent_style(before)
	var after_style := _detect_indent_style(after)
	if before_style.is_empty() or after_style.is_empty() or before_style == after_style:
		return ""
	return "This file was indented with %s but the new content uses %s. edit_script writes content verbatim and never reindents, so mixed indentation here is what the caller supplied." % [
		before_style, after_style
	]


## Returns "tabs", "N spaces", or "" when there is nothing to go on.
func _detect_indent_style(text: String) -> String:
	var tab_lines := 0
	var smallest_space_indent := 0
	var space_lines := 0
	for line in text.split("\n"):
		if line.is_empty() or line.strip_edges().is_empty():
			continue
		if line.begins_with("\t"):
			tab_lines += 1
			continue
		var spaces := 0
		while spaces < line.length() and line[spaces] == " ":
			spaces += 1
		if spaces > 0:
			space_lines += 1
			if smallest_space_indent == 0 or spaces < smallest_space_indent:
				smallest_space_indent = spaces
	if tab_lines == 0 and space_lines == 0:
		return ""
	if tab_lines >= space_lines:
		return "tabs"
	return "%d spaces" % smallest_space_indent


## After a verified force-write to a script that is open in the script editor,
## brings the editor buffer back in line with disk (ScriptEditor
## .reload_open_files, Godot 4.7+) so the stale buffer does not linger and
## trigger a "files changed on disk" prompt. Adds editor_buffer_reloaded to
## `payload`, based on comparing the buffer text with the file, not on having
## asked for a reload. On older versions the payload is left untouched,
## exactly as before this existed.
##
## Two cases measured on 4.7.2 need care:
## - A buffer with unsaved edits is never reloaded. Saving it later would
##   overwrite what was just written, so that is reported, not hidden.
## - Godot notices a changed file by its modification time, which has
##   one-second resolution. A second write within the same second as the
##   previous one (edit_script twice in a row) is not picked up. In that case
##   wait for the clock to pass the file's timestamp, rewrite the identical
##   bytes so the timestamp moves, and reload again.
func _sync_open_editor_buffer(path: String, payload: Dictionary) -> void:
	# reload_open_files() reloads EVERY open script, and a buffer holding edits
	# from a failed save is reported clean by Godot, so any such buffer (this
	# file's or another's) would be reloaded over. Skip the reload entirely.
	var protected := get_protected_unsaved_buffers()
	if not protected.is_empty():
		payload["editor_buffer_reloaded"] = false
		if protected.has(normalize_project_path(path)):
			payload["editor_buffer_unsaved"] = true
		payload["editor_buffer_warning"] = "Script editor buffers were not reloaded because these still hold edits from a failed save, and a reload would discard them: %s. Save them (save_all) or discard them (close_script with discard_unsaved=true), then call reload_open_scripts." % ", ".join(PackedStringArray(protected))
		return
	if not reload_script_editor_buffers():
		return
	var still_unsaved: Variant = is_script_unsaved_in_editor(path)
	if still_unsaved is bool and still_unsaved:
		payload["editor_buffer_reloaded"] = false
		payload["editor_buffer_unsaved"] = true
		payload["editor_buffer_warning"] = "The script editor holds unsaved edits for this file, so Godot kept that buffer instead of reloading it. Saving it in the editor (or save_all) will overwrite what was just written to disk. Use close_script with discard_unsaved=true to drop the buffer, then reopen the file."
		return
	if _editor_buffer_matches_disk(path):
		payload["editor_buffer_reloaded"] = true
		return

	# Same-second rewrite: let the timestamp advance, then touch the file.
	var waited := 0.0
	while int(Time.get_unix_time_from_system()) <= FileAccess.get_modified_time(path) and waited < 1.5:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var touched: Dictionary = await run_path_serialized(path, _rewrite_same_content.bind(path))
	# Re-check after the awaits above: another session may have hit a failed
	# save meanwhile, and this reload is global.
	var protected_now := get_protected_unsaved_buffers()
	if not protected_now.is_empty():
		payload["editor_buffer_reloaded"] = false
		payload["editor_buffer_warning"] = "Script editor buffers were not reloaded because these still hold edits from a failed save, and a reload would discard them: %s." % ", ".join(PackedStringArray(protected_now))
		return
	if not touched.has("error"):
		reload_script_editor_buffers()
	var synced := _editor_buffer_matches_disk(path)
	payload["editor_buffer_reloaded"] = synced
	if not synced:
		payload["editor_buffer_warning"] = "The file on disk is correct, but the script editor still shows older text for it. Call reload_open_scripts, or close_script and reopen the file, before editing it in the editor."


## Rewrites a file with exactly the bytes it already holds, only to move its
## modification time forward. Runs under run_path_serialized; skips (and
## reports an error) if the file cannot be read or written.
func _rewrite_same_content(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read '%s'" % path)
	var content := file.get_as_text()
	file.close()
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_internal("Cannot write '%s'" % path)
	file.store_string(content)
	file.close()
	var verify := verify_text_write(path, content, "editor buffer sync")
	if not verify.is_empty():
		return verify
	return success({})


## True when the script editor's buffer for `path` holds the same text as the
## file on disk (line endings ignored). False when it differs or the script
## is not open.
func _editor_buffer_matches_disk(path: String) -> bool:
	var buffer: Variant = get_script_buffer_text(path)
	if buffer == null:
		return false
	var disk_text := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	return (buffer as String).replace("\r\n", "\n") == disk_text


## Closes a script tab in the script editor (ScriptEditor.close_file, Godot
## 4.7+). close_file discards unsaved buffer edits without asking (measured on
## 4.7.2), so a modified buffer is refused unless discard_unsaved=true.
func _close_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path := normalize_project_path(result[0])
	var path_guard := _guard_script_file_path(path, "close_script")
	if not path_guard.is_empty():
		return path_guard
	var discard_unsaved: bool = optional_bool(params, "discard_unsaved", false)

	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null or not script_editor.has_method("close_file"):
		return error_requires_godot("close_script", "4.7")

	# Resolve the path the editor itself uses, so a differently-cased alias
	# on a case-insensitive filesystem still names the open tab.
	var editor_path := ""
	var open_paths: Array = []
	for open_resource in script_editor.get_open_scripts():
		if open_resource is Resource:
			var open_path := normalize_project_path((open_resource as Resource).resource_path)
			open_paths.append(open_path)
			if editor_path.is_empty() and paths_match(open_path, path):
				editor_path = (open_resource as Resource).resource_path
	if editor_path.is_empty():
		return error_not_found(
			"Script '%s' in the script editor" % path,
			"It is not open. Use get_open_scripts to list open scripts. Open: %s" % [", ".join(open_paths)]
		)

	var unsaved_state: Variant = is_script_unsaved_in_editor(editor_path)
	# Also compare the buffer with disk: after a failed save Godot reports
	# the script clean while its edits exist only in this buffer.
	var was_unsaved: bool = (unsaved_state is bool and unsaved_state) or get_buffers_differing_from_disk().has(normalize_project_path(editor_path))
	if was_unsaved and not discard_unsaved:
		return error_conflict(
			"Refusing to close '%s': its script editor buffer has unsaved changes" % path,
			{
				"path": path,
				"unsaved_scripts": get_unsaved_script_paths(),
				"suggestion": "Call save_all (scripts=true) to keep the changes first, or pass discard_unsaved=true to close and lose them.",
			}
		)

	var err: int = script_editor.call("close_file", editor_path)
	if err != OK:
		return error_internal("close_file('%s') failed: %s" % [editor_path, error_string(err)])
	return success({"path": path, "closed": true, "discarded_unsaved": was_unsaved})


## Reloads the script editor's open buffers from disk (ScriptEditor
## .reload_open_files, Godot 4.7+). Buffers with unsaved edits are kept as
## they are, which the response lists so nothing is silently assumed synced.
func _reload_open_scripts(params: Dictionary) -> Dictionary:
	var unsaved_before: Variant = get_unsaved_script_paths()
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null or not script_editor.has_method("reload_open_files"):
		return error_requires_godot("reload_open_scripts", "4.7")
	# Edits left behind by a failed save are no longer flagged as modified,
	# so Godot would reload over them. Refuse unless the caller opts in.
	var protected := get_protected_unsaved_buffers()
	if not protected.is_empty() and not optional_bool(params, "discard_unsaved", false):
		return error_conflict(
			"Refusing to reload: these buffers hold edits whose save failed, and reloading would replace them with the older disk contents",
			{
				"unsaved_after_failed_save": protected,
				"suggestion": "Fix the save problem (e.g. a read-only file) and call save_all, or pass discard_unsaved=true to reload anyway and lose those edits.",
			}
		)
	if not reload_script_editor_buffers():
		return error_requires_godot("reload_open_scripts", "4.7")
	var open_scripts: Array = []
	for open_resource in EditorInterface.get_script_editor().get_open_scripts():
		if open_resource is Resource and not (open_resource as Resource).resource_path.is_empty():
			open_scripts.append(normalize_project_path((open_resource as Resource).resource_path))
	# reload_open_files() only starts Godot's own disk check: with
	# "auto reload scripts on external change" off it opens a confirmation
	# dialog and keeps the old buffer. Measure the result instead of assuming.
	await get_tree().process_frame
	var kept_unsaved: Array = unsaved_before if unsaved_before is Array else []
	var not_reloaded: Array = []
	for pair: Dictionary in get_open_script_editor_pairs():
		var p: String = pair["path"]
		if p.is_empty() or p.contains("::") or kept_unsaved.has(normalize_project_path(p)) or kept_unsaved.has(p):
			continue
		if not _editor_buffer_matches_disk(p):
			not_reloaded.append(normalize_project_path(p))
	var payload := {"reloaded": not_reloaded.is_empty(), "open_scripts": open_scripts}
	if not kept_unsaved.is_empty():
		payload["kept_unsaved"] = kept_unsaved
		payload["note"] = "Buffers listed in kept_unsaved have unsaved edits, so Godot did not reload them from disk."
	if not not_reloaded.is_empty():
		payload["not_reloaded"] = not_reloaded
		payload["suggestion"] = "These buffers still differ from disk. Godot may be showing a reload confirmation dialog (Editor Settings > Text Editor > Behavior > Files > Auto Reload Scripts on External Change is off); answer it or enable that setting."
	return success(payload)


## Force-reload a script so the editor reflects disk changes immediately.
func _reload_script(path: String) -> void:
	# First, trigger a filesystem scan so Godot knows the file changed
	EditorInterface.get_resource_filesystem().scan()

	# If the script is already loaded in memory, reload it
	if ResourceLoader.exists(path):
		var script = load(path)
		if script is Script:
			script.reload(true)

	# If the script is open in the script editor, the reload above updates it.
	# But we also need to notify the editor to refresh its error indicators.
	EditorInterface.get_script_editor().notification(Control.NOTIFICATION_VISIBILITY_CHANGED)


func _attach_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "script_path")
	if result2[1] != null:
		return result2[1]
	var script_path: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not FileAccess.file_exists(script_path):
		return error_not_found("Script '%s'" % script_path)

	var script: Script = load(script_path)
	if script == null:
		return error_internal("Failed to load script: %s" % script_path)

	var old_script: Variant = node.get_script()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Attach script to %s" % node.name)
	undo_redo.add_do_method(node, "set_script", script)
	undo_redo.add_undo_method(node, "set_script", old_script)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"script_path": script_path,
		"attached": true,
	})


func _validate_script(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]
	var path_guard := _guard_script_file_path(path, "validate_script")
	if not path_guard.is_empty():
		return path_guard

	if not FileAccess.file_exists(path):
		return error_not_found("Script '%s'" % path)

	# Load the real path with the cache bypassed. Compiling an anonymous
	# GDScript.new() copy instead would give it no resource_path, so any
	# class_name it declares collides with the already-registered global class
	# and every class_name script reports a bogus "Parse error".
	# CACHE_MODE_IGNORE keeps the live cached script untouched.
	# Note where the Output panel ends before anything in this validation runs,
	# so stale failures of the same file are not re-reported as current. The
	# load below already emits the parser message, so the mark has to precede
	# it, not just the reload.
	var log_mark := _output_line_count()

	var script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if script == null:
		return success({
			"path": path,
			"valid": false,
			"message": "Could not load script as GDScript",
		})

	# load() alone is not a validity check — it returns a non-null GDScript even
	# for a file that does not compile. reload() is what actually parses.
	#
	# keep_state=true matters: without it, reload() returns ERR_ALREADY_IN_USE
	# *before compiling* for any script that has live instances in the editor —
	# @tool scripts, autoloads, plugin code — and a perfectly valid script would
	# be reported invalid. It still returns a parse error for broken source.
	var err := script.reload(true)

	if err == OK:
		return success({"path": path, "valid": true, "message": "Script compiles successfully"})

	if err == ERR_ALREADY_IN_USE:
		# Godot skipped the reload, so nothing was compiled. That is not
		# evidence of a parse error — but it is not evidence of validity
		# either, so claim neither.
		return success({
			"path": path,
			"valid": null,
			"indeterminate": true,
			"error_code": err,
			"error_string": error_string(err),
			"message": "Godot skipped the reload because the script is in use by live instances, so no compilation verdict was produced. Nothing here says the script is broken, and nothing says it is valid. Re-check after closing scenes that instance it, or inspect get_editor_errors.",
		})

	# The Output panel is appended to on a deferred call, so the parser message
	# is not there yet on the frame the reload failed.
	await get_tree().process_frame

	var parse_errors := _collect_parse_errors(path, log_mark)
	var result_payload := {
		"path": path,
		"valid": false,
		"error_code": err,
		"error_string": error_string(err),
		"message": "Compilation failed. Use get_output_log or get_editor_errors for details.",
	}
	if not parse_errors.is_empty():
		result_payload["parse_errors"] = parse_errors
	return success(result_payload)


## Scrapes the editor Output panel for parser messages naming this script, so a
## failed validation says *what* is wrong instead of only "Parse error".
## `since_line` is where the Output panel ended before the reload, so stale
## failures of the same file are not re-reported as if they were current.
func _collect_parse_errors(path: String, since_line: int) -> Array:
	var found: Array = []
	var rtl := _output_label()
	if rtl == null:
		return found

	var lines: PackedStringArray = rtl.get_parsed_text().split("\n")
	# The panel can be cleared between the mark and now, which would leave the
	# mark past the end; fall back to scanning the tail in that case.
	var start: int = since_line if since_line <= lines.size() else maxi(0, lines.size() - 40)
	for i in range(start, lines.size()):
		var line: String = lines[i].strip_edges()
		if line.is_empty():
			continue
		# Match the full res:// path, not the basename — a project can hold
		# several player.gd. CACHE_MODE_IGNORE preserves resource_path, so
		# genuine messages for this script always carry it in full.
		if line.contains(path) and not found.has(line):
			found.append(line)
	return found


func _output_label() -> RichTextLabel:
	var base: Control = get_editor().get_base_control()
	if base == null:
		return null
	var editor_log: Node = base.find_child("Output", true, false)
	if editor_log == null:
		return null
	return _find_rtl_node(editor_log)


## Index where the next appended line will land. Output entries end with a
## newline, so split() leaves a trailing empty element — counting elements
## would point one past the new line and skip it.
func _output_line_count() -> int:
	var rtl := _output_label()
	if rtl == null:
		return 0
	var text := rtl.get_parsed_text()
	var count := text.split("\n").size()
	if text.ends_with("\n"):
		count -= 1
	return maxi(0, count)


func _find_rtl_node(node: Node) -> RichTextLabel:
	if node is RichTextLabel:
		return node
	for child in node.get_children():
		var found := _find_rtl_node(child)
		if found:
			return found
	return null


func _get_open_scripts(_params: Dictionary) -> Dictionary:
	var script_editor := EditorInterface.get_script_editor()
	var open_scripts: Array = []

	for script_base in script_editor.get_open_scripts():
		var info := {
			"path": script_base.resource_path,
			"type": script_base.get_class(),
		}
		open_scripts.append(info)

	return success({"scripts": open_scripts, "count": open_scripts.size()})
