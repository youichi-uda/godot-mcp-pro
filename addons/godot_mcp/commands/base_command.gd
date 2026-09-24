@tool
extends Node

var editor_plugin: EditorPlugin


## Override in subclasses: return {"method_name": Callable}
func get_commands() -> Dictionary:
	return {}


## Helper: return a success result
func success(data: Dictionary = {}) -> Dictionary:
	return {"result": data}


## Helper: return an error
func error(code: int, message: String, data: Dictionary = {}) -> Dictionary:
	var err := {"code": code, "message": message}
	if not data.is_empty():
		err["data"] = data
	return {"error": err}


## Error codes
func error_not_found(what: String, suggestion: String = "") -> Dictionary:
	var data := {}
	if suggestion:
		data["suggestion"] = suggestion
	return error(-32001, "%s not found" % what, data)


func error_invalid_params(message: String) -> Dictionary:
	return error(-32602, message)


func error_no_scene() -> Dictionary:
	return error(-32000, "No scene is currently open", {"suggestion": "Use open_scene to open a scene first"})


func error_internal(message: String) -> Dictionary:
	return error(-32603, "Internal error: %s" % message)


func error_conflict(message: String, data: Dictionary = {}) -> Dictionary:
	return error(-32009, message, data)


## Get required string param
func require_string(params: Dictionary, key: String) -> Array:
	if not params.has(key) or not params[key] is String or (params[key] as String).is_empty():
		return [null, error_invalid_params("Missing required parameter: %s" % key)]
	return [params[key] as String, null]


## Get optional string param with default
func optional_string(params: Dictionary, key: String, default: String = "") -> String:
	if params.has(key) and params[key] is String:
		return params[key] as String
	return default


## Get optional bool param with default
func optional_bool(params: Dictionary, key: String, default: bool = false) -> bool:
	if params.has(key) and params[key] is bool:
		return params[key] as bool
	return default


## Get optional int param with default.
##
## Only converts from types that have a meaningful integer value. int() raises
## on null, arrays and dictionaries — and a raise inside a command handler
## aborts the coroutine, so the caller gets no response at all and waits out
## its full timeout for what is really one bad parameter.
func optional_int(params: Dictionary, key: String, default: int = 0) -> int:
	if not params.has(key):
		return default
	var value: Variant = params[key]
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is bool:
		return 1 if value else 0
	if value is String and (value as String).is_valid_int():
		return (value as String).to_int()
	return default


## Get optional float param with default. Same reasoning as optional_int:
## float() raises on null, arrays and dictionaries, and a raise inside a
## handler means the caller never gets a response.
func optional_float(params: Dictionary, key: String, default: float = 0.0) -> float:
	if not params.has(key):
		return default
	var value: Variant = params[key]
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	if value is String and (value as String).is_valid_float():
		return (value as String).to_float()
	return default


## Validates that every entry of `params[key]` is a Dictionary.
##
## `for entry: Dictionary in some_array` raises on the first non-Dictionary
## element, which aborts the handler before it can answer. Returns {} when the
## array is usable, or an error dictionary naming the offending index.
func require_dictionary_array(params: Dictionary, key: String) -> Dictionary:
	if not params.has(key) or not params[key] is Array:
		return error_invalid_params("'%s' array is required" % key)
	var items: Array = params[key]
	for i in items.size():
		if not items[i] is Dictionary:
			return error_invalid_params(
				"'%s'[%d] must be an object, got %s" % [key, i, type_string(typeof(items[i]))]
			)
	return {}


## Get the game process's user data directory.
## OS.get_user_data_dir() is cached at editor startup and won't reflect
## project name changes made to project.godot while the editor is running.
## The game process reads the name from disk, so we must do the same.
func get_game_user_dir() -> String:
	var cached_dir := OS.get_user_data_dir()
	var cfg := ConfigFile.new()
	var err := cfg.load(ProjectSettings.globalize_path("res://project.godot"))
	if err != OK:
		return cached_dir
	# When use_custom_user_dir=true, editor and game share the same dir
	# (OS.get_user_data_dir() already resolves to the custom path).
	if cfg.get_value("application", "config/use_custom_user_dir", false):
		return cached_dir
	var disk_name = cfg.get_value("application", "config/name", "")
	if typeof(disk_name) != TYPE_STRING or (disk_name as String).is_empty():
		return cached_dir
	# Sanitize exactly like Godot does when computing the default user dir
	# (OS::get_user_data_dir -> OS::get_safe_dir_name). Periods are kept:
	# "MyGame_V0.04" really lives under app_userdata/MyGame_V0.04 (issue #39).
	var sanitized := get_safe_dir_name(disk_name as String)
	if sanitized.is_empty():
		return cached_dir
	var base_dir := cached_dir.get_base_dir()
	var game_dir := base_dir.path_join(sanitized)
	# Ensure the directory exists (game may not have created it yet)
	if not DirAccess.dir_exists_absolute(game_dir):
		DirAccess.make_dir_recursive_absolute(game_dir)
	return game_dir


## Port of OS::get_safe_dir_name(name, allow_paths=false) from core/os/os.cpp.
## Godot replaces each of  : * ? " < > | / \  with "-" and trims whitespace;
## nothing else is altered. String.validate_filename() is NOT equivalent: it
## substitutes "_" instead of "-" and also strips "%", so a project name such
## as "Game 100%" would resolve to a directory the running game never uses.
static func get_safe_dir_name(dir_name: String) -> String:
	var safe := dir_name.strip_edges()
	# "." and ".." are not usable directory names; Godot maps them to words
	# (so a project named ".." does not resolve to the parent directory).
	if safe == ".":
		safe = "dot"
	elif safe == "..":
		safe = "twodots"
	for invalid in [":", "*", "?", "\"", "<", ">", "|", "/", "\\"]:
		safe = safe.replace(invalid, "-")
	# Trailing periods are invalid in Windows folder names; Godot strips them
	# on every platform so the result is the same everywhere.
	return safe.rstrip(".")


## Get EditorInterface
func get_editor() -> EditorInterface:
	return editor_plugin.get_editor_interface()


## Get the edited scene root
func get_edited_root() -> Node:
	return EditorInterface.get_edited_scene_root()


## Get UndoRedo
func get_undo_redo() -> EditorUndoRedoManager:
	return editor_plugin.get_undo_redo()


func normalize_project_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		return path.simplify_path()
	return ProjectSettings.localize_path(path).simplify_path()


## Compares two project paths for the purpose of a protective guard.
##
## Windows and macOS have case-insensitive filesystems, so "res://Player.gd"
## and "res://player.gd" are the same file while comparing unequal. An exact
## match would let a differently-cased alias slip past the open-resource
## guards and overwrite the file the user has open. These guards are meant to
## refuse when in doubt, so the comparison is case-insensitive: at worst a
## write is refused that would have been safe, which the caller can override.
func paths_match(a: String, b: String) -> bool:
	return a.nocasecmp_to(b) == 0


## Refuses a write whose path does not carry one of the expected extensions.
##
## Without this, create_shader / create_theme / create_resource and friends
## will happily ResourceSaver.save over whatever the path points at — a
## mistyped destination silently destroys a script or an image, with no undo.
## `what` names the tool's own file kind for the message.
func guard_expected_extension(path: String, allowed: Array, what: String) -> Dictionary:
	var ext := path.get_extension().to_lower()
	if ext in allowed:
		return {}
	var pretty: Array = []
	for e: String in allowed:
		pretty.append("." + e)
	return error_invalid_params(
		"'%s' does not look like %s (expected %s). Refusing to write, since this would overwrite whatever is at that path." % [
			path, what, ", ".join(pretty)
		]
	)


func is_scene_resource_path(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext == "tscn" or ext == "scn"


func get_open_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	var open_scenes: PackedStringArray = EditorInterface.get_open_scenes()
	for scene_path: String in open_scenes:
		var normalized := normalize_project_path(scene_path)
		if not normalized.is_empty() and normalized not in paths:
			paths.append(normalized)

	var root := get_edited_root()
	if root != null and not root.scene_file_path.is_empty():
		var active_path := normalize_project_path(root.scene_file_path)
		if active_path not in paths:
			paths.append(active_path)
	return paths


func is_scene_path_open(path: String) -> bool:
	var normalized := normalize_project_path(path)
	if normalized.is_empty():
		return false
	for open_path: String in get_open_scene_paths():
		if paths_match(open_path, normalized):
			return true
	return false


func is_active_scene_path(path: String) -> bool:
	var root := get_edited_root()
	if root == null:
		return false
	return paths_match(normalize_project_path(root.scene_file_path), normalize_project_path(path))


func guard_offline_scene_save(path: String) -> Dictionary:
	if is_scene_resource_path(path) and is_scene_path_open(path):
		return error_conflict(
			"Refusing to save open scene '%s' outside the Godot editor state" % normalize_project_path(path),
			{
				"path": normalize_project_path(path),
				"open_scenes": get_open_scene_paths(),
				"suggestion": "Use live editor changes plus save_scene, or close the scene before offline edits.",
			}
		)
	return {}


## Helper: create the parent directory of a res:// path if missing.
## Returns {} on success, an error dictionary on failure.
func ensure_parent_dir(path: String) -> Dictionary:
	var dir := path.get_base_dir()
	if dir.is_empty() or DirAccess.dir_exists_absolute(dir):
		return {}
	var derr := DirAccess.make_dir_recursive_absolute(dir)
	if derr != OK:
		return error_internal("Cannot create directory '%s': %s" % [dir, error_string(derr)])
	return {}


## Helper: unwrap the (possibly multi-)wrapped {"result": ...} envelope returned
## by the game IPC channel. The game writes its own {"result": ...} envelope and
## the transport wraps it again, so consumers must unwrap defensively.
func unwrap_game_result(result: Dictionary) -> Dictionary:
	var payload: Variant = result
	while payload is Dictionary and payload.has("result") and payload["result"] is Dictionary:
		payload = payload["result"]
	return payload if payload is Dictionary else {}


## Shared IPC helper: send a command to the running game and await its response.
## Only one game command may be in flight: the request and response files are
## shared, so two at once would overwrite each other's request and consume each
## other's reply. Static, because each command file has its own instance.
static var _game_command_busy := false
static var _game_command_seq := 0


## Called when the plugin starts. Static state outlives a plugin disable or
## reload; a lock held by a handler that was freed mid-await would otherwise
## block game commands and text writes for the rest of the editor session.
## The failed-save registry is kept: those buffers are still open and still
## hold edits that are not on disk.
static func reset_session_state() -> void:
	_game_command_busy = false
	_text_write_gates.clear()


func send_game_command(command: String, params: Dictionary = {}, timeout_sec: float = 5.0) -> Dictionary:
	var ei := get_editor()
	if not ei.is_playing_scene():
		return error(-32000, "No scene is currently playing", {"suggestion": "Use play_scene first"})

	# Wait for any in-flight game command rather than trampling it. One
	# monotonic deadline covers the wait and the command itself: the MCP
	# server's timeout is sized from timeout_sec, so a queued command must not
	# start a fresh full run the caller has already given up on.
	var deadline_ms := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	var session := _play_session_gen
	while _game_command_busy and Time.get_ticks_msec() < deadline_ms:
		await get_tree().create_timer(0.05).timeout
	var remaining_sec := (deadline_ms - Time.get_ticks_msec()) / 1000.0
	if session != _play_session_gen or not ei.is_playing_scene():
		return error(-32000, "The game stopped while this command was waiting", {"suggestion": "Nothing was sent. Start the game again and retry."})
	if _game_command_busy or remaining_sec < 0.5:
		return error(-32000, "Timed out waiting for another game command to finish", {
			"suggestion": "Retry once it finishes; game commands are serialised because they share one request channel.",
		})

	# Tell the game how long this editor will wait for it. Long-running game
	# operations that inject input (move_to) must finish inside it, or they
	# keep keys held after the caller has already received a timeout.
	var sent_params := params.duplicate()
	# Absolute expiry on the wall clock shared by editor and game: a relative
	# budget would restart whenever the game finally reads the request (a
	# stalled game can pick it up long after it was written).
	sent_params["_mcp_expires_unix"] = Time.get_unix_time_from_system() + remaining_sec
	_game_command_busy = true
	var result := await _send_game_command_locked(command, sent_params, remaining_sec, session)
	_game_command_busy = false
	return result


func _send_game_command_locked(command: String, params: Dictionary, timeout_sec: float, session: int = -1) -> Dictionary:
	if session < 0:
		session = _play_session_gen
	var ei := get_editor()
	var user_dir := get_game_user_dir()
	var request_path := user_dir + "/mcp_game_request"
	var response_path := user_dir + "/mcp_game_response"

	# Clean our own stale response (another editor's may be pending there).
	remove_ipc_file_if_owned(response_path)

	# Write request, tagged so a late reply from a command that already timed
	# out is recognised and discarded instead of being read as this one's.
	_game_command_seq += 1
	var request_id := "%d-%d" % [Time.get_ticks_msec(), _game_command_seq]
	var request_data := JSON.stringify({"command": command, "params": params, "request_id": request_id, "editor_pid": OS.get_process_id()})
	var pub_err := await publish_ipc_exclusive(request_path, request_data, Time.get_ticks_msec() + 2000, true, session)
	if pub_err == ERR_UNAVAILABLE:
		return error(-32000, "The game stopped or restarted before this command could be sent", {"suggestion": "Nothing was sent. Retry against the running game."})
	if pub_err == ERR_BUSY:
		return error(-32000, "Another editor's game request is still pending in this user:// directory", {"suggestion": "Retry shortly."})
	if pub_err != OK:
		return error_internal("Could not create game request file: %s" % error_string(pub_err))

	# Poll for response against the monotonic clock: counting timer ticks
	# stretched the wait far past timeout_sec whenever the editor itself was
	# slow (low frame rate, a long script), keeping the command lock held.
	var deadline_ms := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	# A restart keeps is_playing_scene() true, but the game this request went
	# to is gone and will never answer; stop waiting (and release the lock)
	# as soon as the play session changes.
	while Time.get_ticks_msec() < deadline_ms:
		await get_tree().create_timer(0.1).timeout
		if _own_response_ready(response_path):
			break
		if session != _play_session_gen:
			return error(-32000, "The game was restarted before it answered this command")
		if not ei.is_playing_scene():
			if FileAccess.file_exists(request_path):
				DirAccess.remove_absolute(request_path)
			return error(-32000, "Game stopped during command execution")

	if not _own_response_ready(response_path):
		# Try to auto-resume the debugger (runtime error may have paused the
		# game), with a fixed 2 s of wall-clock grace.
		if ei.is_playing_scene():
			try_debugger_continue()
			var retry_deadline_ms := Time.get_ticks_msec() + 2000
			while Time.get_ticks_msec() < retry_deadline_ms:
				await get_tree().create_timer(0.1).timeout
				if _own_response_ready(response_path):
					break
				if session != _play_session_gen:
					return error(-32000, "The game was restarted before it answered this command")

	if not _own_response_ready(response_path):
		if FileAccess.file_exists(request_path):
			DirAccess.remove_absolute(request_path)
		return build_timeout_error(timeout_sec)

	# Read response
	var file := FileAccess.open(response_path, FileAccess.READ)
	if file == null:
		return error_internal("Could not read game response file")
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(response_path)

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return error_internal("Invalid response JSON from game")

	var reply_id := str(parsed.get("request_id", ""))
	if not reply_id.is_empty() and reply_id != request_id:
		return error_internal(
			"Discarded a stale game response belonging to an earlier command. Retry this one."
		)

	# Transport bookkeeping, not part of the result.
	parsed.erase("editor_pid")
	parsed.erase("request_id")

	if parsed.has("error"):
		return error(-32000, str(parsed["error"]))

	return success(parsed)


func is_shader_resource_path(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext == "gdshader" or ext == "gdshaderinc" or ext == "shader"


func is_text_resource_open_in_script_editor(path: String) -> bool:
	var target := normalize_project_path(path)
	if target.is_empty():
		return false
	if is_shader_resource_path(target) and ResourceLoader.has_cached(target):
		return true
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return false
	for open_resource in script_editor.get_open_scripts():
		if open_resource is Resource:
			var resource_path := normalize_project_path((open_resource as Resource).resource_path)
			if paths_match(resource_path, target):
				return true
	return false


func guard_text_resource_write(path: String, force: bool) -> Dictionary:
	if not force and is_text_resource_open_in_script_editor(path):
		return error_conflict(
			"Refusing to write open text resource '%s' outside the script editor state" % normalize_project_path(path),
			{
				"path": normalize_project_path(path),
				"suggestion": "Close the file in Godot's script editor or pass force=true to overwrite it deliberately.",
			}
		)
	return {}


## Marks the edited scene dirty after a change that bypassed undo/redo.
##
## Godot 4.6 added EditorInterface.set_object_edited()/is_object_edited(), but
## they only toggle a per-object "edited" flag: measured on 4.7.2, calling
## set_object_edited(scene_root, true) leaves get_unsaved_scenes() empty,
## while mark_scene_as_unsaved() adds the scene to it. The flag therefore does
## not make the scene savable-dirty, so this helper keeps using
## mark_scene_as_unsaved() on every version.
func mark_current_scene_unsaved() -> void:
	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()


## ── Version-gated editor APIs ─────────────────────────────────────────────
## Several editor queries only exist on newer Godot versions. The addon must
## still parse on 4.5, so these are always reached through has_method()/call()
## rather than referenced statically: a static call to a method the running
## engine lacks is a parse error that takes down the whole command file.

func get_godot_version_string() -> String:
	return str(Engine.get_version_info().get("string", "unknown"))


## Error for a tool whose editor API is newer than the running Godot.
## -32601 matches the router's "method not found": the capability does not
## exist here, which is different from a bad parameter or a failed call.
func error_requires_godot(tool_name: String, min_version: String) -> Dictionary:
	var running := get_godot_version_string()
	return error(-32601, "%s requires Godot %s+ (running %s)" % [tool_name, min_version, running], {
		"required_version": min_version,
		"running_version": running,
	})


## Paths of open scenes with unsaved changes (EditorInterface.get_unsaved_scenes,
## Godot 4.7+). Returns null when this Godot cannot tell; null means unknown,
## never "nothing is unsaved".
func get_unsaved_scene_paths() -> Variant:
	if not EditorInterface.has_method("get_unsaved_scenes"):
		return null
	var paths: Array = []
	for scene_path: String in EditorInterface.call("get_unsaved_scenes"):
		paths.append(normalize_project_path(scene_path) if not scene_path.is_empty() else scene_path)
	return paths


## Paths of scripts whose script-editor buffer holds unsaved edits
## (ScriptEditor.get_unsaved_files, Godot 4.7+). Returns null when this Godot
## cannot tell. Older versions have no reliable way to ask: the only signal
## is the "(*)" decoration in the script list UI, which is not an API.
func get_unsaved_script_paths() -> Variant:
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null or not script_editor.has_method("get_unsaved_files"):
		return null
	var paths: Array = []
	for file_path: String in script_editor.call("get_unsaved_files"):
		paths.append(normalize_project_path(file_path) if not file_path.is_empty() else file_path)
	return paths


## true / false when the script editor can say whether `path` has unsaved
## buffer edits (Godot 4.7+), null when it cannot.
func is_script_unsaved_in_editor(path: String) -> Variant:
	var unsaved: Variant = get_unsaved_script_paths()
	if unsaved == null:
		return null
	var target := normalize_project_path(path)
	for unsaved_path: String in unsaved:
		if paths_match(unsaved_path, target):
			return true
	return false


## Reloads the script editor's open buffers from disk
## (ScriptEditor.reload_open_files, Godot 4.7+). Returns false when the API
## is missing. Measured on 4.7.2: only buffers WITHOUT unsaved edits are
## refreshed; a modified buffer keeps its content.
## Pairs each open script tab's editor with its Script, as
## [{"editor": ScriptEditorBase, "script": Script, "path": String}].
##
## get_open_script_editors() also returns TextEditor tabs (JSON, .txt, .cfg…)
## while get_open_scripts() lists Scripts only, so pairing the two arrays by
## index shifted every script after a text tab onto the wrong editor. Only
## ScriptTextEditor tabs edit Scripts, in the same order as
## get_open_scripts(). If the counts still disagree, nothing is paired rather
## than risking a wrong attribution.
func get_open_script_editor_pairs() -> Array:
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return []
	var editors: Array = []
	for e in script_editor.get_open_script_editors():
		if e != null and e.get_class() == "ScriptTextEditor":
			editors.append(e)
	var scripts: Array = script_editor.get_open_scripts()
	if editors.size() != scripts.size():
		return []
	var pairs: Array = []
	for i in scripts.size():
		var script: Variant = scripts[i]
		var path := ""
		if script is Resource:
			path = (script as Resource).resource_path
		pairs.append({"editor": editors[i], "script": script, "path": path})
	return pairs


## Buffers whose save was verified to have FAILED, as {path: md5 of the
## buffer text at that time}. Godot clears the modified flag anyway, so from
## then on nothing in the engine protects those edits: a reload (auto reload
## on external change, reload_open_files) would replace them with the older
## disk contents. Static so every command file sees the same registry.
static var _failed_save_buffers := {}


## Remembers that saving these scripts failed while their buffers held the
## current text (see _failed_save_buffers).
func record_failed_script_saves(paths: Array) -> void:
	for p in paths:
		var path := normalize_project_path(str(p))
		var buffer: Variant = get_script_buffer_text(path)
		if buffer is String:
			_failed_save_buffers[path] = (buffer as String).md5_text()


## Call right before any save that may also write script buffers (including
## starting a game, which saves first when "save before running" is on)
## (Godot's
## scene save runs the script editor's save): registers every buffer whose
## edits are not on disk as protected, because a failed write clears
## Godot's modified flag and a later reload would then replace the edits.
## Buffers that do get written drop out of the registry on their own.
func protect_script_buffers_before_save() -> void:
	var to_protect: Array = get_buffers_differing_from_disk()
	var unsaved: Variant = get_unsaved_script_paths()
	if unsaved is Array:
		for s in unsaved:
			if not str(s).contains("::") and not to_protect.has(s):
				to_protect.append(s)
	record_failed_script_saves(to_protect)


## Scripts whose buffers still hold edits from a failed save. Protection
## lasts until the buffer matches disk (the edits were saved) or the script
## is closed. Further edits do not end it: undo can return the buffer to the
## text Godot wrongly marked as saved, and edits on top are just as unsaved.
func get_protected_unsaved_buffers() -> Array:
	var out: Array = []
	var differing := get_buffers_differing_from_disk()
	for path: String in _failed_save_buffers.keys():
		var buffer: Variant = get_script_buffer_text(path)
		if buffer is String and differing.has(path):
			out.append(path)
		else:
			_failed_save_buffers.erase(path)
	return out


## File-backed scripts open in the script editor whose buffer text differs
## from the file on disk (line endings ignored). Godot's own modified flag is
## not enough: it is cleared even when a save fails (read-only file, verified
## on 4.7.2), leaving edits that exist only in the buffer. Built-in scripts
## ("scene.tscn::GDScript_x") are skipped; they live inside their scene.
func get_buffers_differing_from_disk() -> Array:
	var out: Array = []
	for pair: Dictionary in get_open_script_editor_pairs():
		var path: String = pair["path"]
		if path.is_empty() or path.contains("::"):
			continue
		var base_editor: Control = (pair["editor"] as ScriptEditorBase).get_base_editor()
		if not base_editor is TextEdit:
			continue
		var buffer := (base_editor as TextEdit).text.replace("\r\n", "\n")
		var disk := FileAccess.get_file_as_string(path).replace("\r\n", "\n") if FileAccess.file_exists(path) else ""
		if buffer != disk:
			out.append(normalize_project_path(path))
	return out


## The script editor's buffer text for `path`, or null when the script is not
## open (or its tab cannot be identified).
func get_script_buffer_text(path: String) -> Variant:
	var target := normalize_project_path(path)
	for pair: Dictionary in get_open_script_editor_pairs():
		if (pair["path"] as String).is_empty() or not paths_match(normalize_project_path(pair["path"]), target):
			continue
		var base_editor: Control = (pair["editor"] as ScriptEditorBase).get_base_editor()
		if base_editor is TextEdit:
			return (base_editor as TextEdit).text
		return null
	return null


func reload_script_editor_buffers() -> bool:
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null or not script_editor.has_method("reload_open_files"):
		return false
	script_editor.call("reload_open_files")
	return true


func add_child_with_undo(parent: Node, child: Node, root: Node, action_name: String) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", child)
	undo_redo.add_do_method(child, "set_owner", root)
	undo_redo.add_do_reference(child)
	undo_redo.add_undo_method(parent, "remove_child", child)
	undo_redo.commit_action()


func set_property_with_undo(target: Object, property: String, new_value: Variant, action_name: String) -> void:
	var old_value: Variant = target.get(property)
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_property(target, property, new_value)
	if new_value is Resource:
		undo_redo.add_do_reference(new_value)
	undo_redo.add_undo_property(target, property, old_value)
	if old_value is Resource:
		undo_redo.add_undo_reference(old_value)
	undo_redo.commit_action()


## ── Game-command timeout diagnostics ──────────────────────────────────────────
## Shared by the file-IPC `_send_game_command` helpers (runtime/test commands).
## The goal is to never tell the agent "the game isn't running / autoload missing"
## when the game IS running and merely paused by a runtime error.

## Locate the editor's ScriptEditorDebugger node (BFS from base control).
func _find_script_editor_debugger() -> Node:
	var base := EditorInterface.get_base_control()
	if base == null:
		return null
	var queue: Array[Node] = [base]
	while not queue.is_empty():
		var node := queue.pop_front()
		if node.get_class() == "ScriptEditorDebugger":
			return node
		for child in node.get_children():
			queue.append(child)
	return null


## Look up an editor theme icon by name (locale-independent), or null.
func _get_editor_icon(icon_name: String) -> Texture2D:
	var base := EditorInterface.get_base_control()
	if base != null and base.has_theme_icon(icon_name, "EditorIcons"):
		return base.get_theme_icon(icon_name, "EditorIcons")
	return null


## Find the debugger "Continue" button without relying on UI text.
## The editor is translated, so matching tooltip/label text breaks for
## non-English editors (issue #34: Italian → "Continua"). Match by the editor
## theme icon "DebugContinue" first, falling back to the English text only if
## the icon can't be resolved.
func _find_debugger_continue_button() -> Button:
	var dbg := _find_script_editor_debugger()
	if dbg == null:
		return null
	var continue_icon := _get_editor_icon("DebugContinue")
	var fallback: Button = null
	var inner: Array[Node] = [dbg]
	while not inner.is_empty():
		var n := inner.pop_front()
		if n is Button:
			var b := n as Button
			if continue_icon != null and b.icon == continue_icon:
				return b
			if b.tooltip_text == "Continue":
				fallback = b
		for c in n.get_children():
			inner.append(c)
	return fallback


## True when the running game is halted at a breakpoint or runtime error
## (the debugger's "Continue" button is present and enabled).
func is_debugger_paused() -> bool:
	var btn := _find_debugger_continue_button()
	return btn != null and not btn.disabled


## Read recent runtime errors from the debugger's "Errors" tab tree, so a
## timeout caused by a script error can report the actual cause inline.
func collect_debugger_errors(max_errors: int = 10) -> Array:
	var out: Array = []
	var dbg := _find_script_editor_debugger()
	if dbg == null:
		return out
	for child in dbg.get_children():
		if child is TabContainer:
			var tab_container := child as TabContainer
			for tab_idx in range(tab_container.get_tab_count()):
				var tab_control: Control = tab_container.get_tab_control(tab_idx)
				if tab_control is VBoxContainer and tab_control.name.begins_with("Errors"):
					for vchild in tab_control.get_children():
						if vchild is Tree:
							var tree := vchild as Tree
							var root_item: TreeItem = tree.get_root()
							if root_item:
								var item: TreeItem = root_item.get_first_child()
								while item and out.size() < max_errors:
									var col0: String = item.get_text(0).strip_edges()
									var col1: String = item.get_text(1).strip_edges()
									var msg: String = col0
									if not col1.is_empty():
										msg = (msg + " " + col1) if not msg.is_empty() else col1
									if not msg.is_empty():
										out.append(msg)
									item = item.get_next()
					break
			break
	return out


## Press the debugger "Continue" button to resume a paused game process.
func try_debugger_continue() -> void:
	var btn := _find_debugger_continue_button()
	if btn != null and not btn.disabled:
		btn.emit_signal("pressed")
		push_warning("[MCP] Auto-resumed debugger after runtime error")


## Build an accurate error for a file-IPC game-command timeout.
## Distinguishes "game not running" from "game running but unresponsive
## (likely paused by a runtime error / breakpoint)" so callers aren't misled
## into thinking the MCP connection is dead or the autoload is missing.
func build_timeout_error(timeout_sec: float) -> Dictionary:
	# Re-check play state at the moment we give up.
	if not get_editor().is_playing_scene():
		return error(
			-32000,
			"Game command timed out after %.1fs and the game process is no longer running." % timeout_sec,
			{
				"game_running": false,
				"suggestion": "The scene stopped. Call play_scene to start it again before sending runtime commands.",
			}
		)

	# The game IS running. Figure out *why* it didn't answer.
	var paused := is_debugger_paused()
	var runtime_errors := collect_debugger_errors(10)
	var data := {
		"game_running": true,
		"debugger_paused": paused,
	}
	if not runtime_errors.is_empty():
		data["runtime_errors"] = runtime_errors

	var msg: String
	if paused or not runtime_errors.is_empty():
		msg = ("Game command timed out after %.1fs, but the game IS running. " % timeout_sec) \
			+ "A runtime/script error paused the scene, so it could not respond to the command."
		data["suggestion"] = "This is NOT a connection or autoload problem. Fix the error in 'runtime_errors' " \
			+ "(or call get_editor_errors for the full list), then retry. The debugger was auto-resumed; " \
			+ "if errors persist, call stop_scene then play_scene to restart cleanly."
	else:
		msg = ("Game command timed out after %.1fs. The game is running but did not respond in time." % timeout_sec)
		data["suggestion"] = "The MCP server connection is fine and the game is running. The command may be slow " \
			+ "or the game may be busy/blocked. Retry with a longer timeout, and call get_editor_errors to check " \
			+ "for runtime errors. In rare cases (custom projects) verify the MCPGameInspector autoload is active."
	return error(-32000, msg, data)


## ── Verified text-file writes ──────────────────────────────────────────────
## edit_script / create_script / edit_shader / create_shader used to report
## success from having *called* store_string() without ever looking at the
## file again. When something else overwrote the file right after the write
## (a second MCP session talking to the same editor through another server
## port, a stale duplicate tool call, an editor-side buffer save), the edit
## silently vanished even though the caller had been told it landed. These
## helpers turn that silent loss into a loud error or a logged diagnosis.

## One gate per normalized path: while a gate exists and is not done, other
## writers wait. Static so the script and shader command instances share it.
static var _text_write_gates: Dictionary = {}
## Last md5 this addon wrote per normalized path, so a delayed persistence
## check knows whether a newer MCP write has already replaced its content.
static var _last_text_write_md5: Dictionary = {}


## Runs `op` (a Callable returning a result Dictionary) exclusively per file
## path. Several MCP sessions can be attached to one editor at once — each
## through its own server port — and their commands run as overlapping
## coroutines, so two read-modify-write cycles on the same file can
## interleave into a lost update. Awaiting this lets one caller's
## read-to-write section finish before the next one starts.
func run_path_serialized(path: String, op: Callable) -> Dictionary:
	var key := normalize_project_path(path).to_lower()
	var lock_waited := 0.0
	while _text_write_gates.has(key) and not _text_write_gates[key]["done"]:
		# A handler that dies mid-run would leave its gate closed forever;
		# time out and proceed loudly rather than queueing every future
		# write of this file behind a dead gate.
		if lock_waited >= 10.0:
			push_warning("[MCP] Waited %.0fs for the previous write to '%s' to finish; proceeding anyway." % [lock_waited, key])
			break
		await get_tree().create_timer(0.05).timeout
		lock_waited += 0.05
	var gate := {"done": false}
	_text_write_gates[key] = gate
	var result: Dictionary = await op.call()
	gate["done"] = true
	if _text_write_gates.get(key) == gate:
		_text_write_gates.erase(key)
	return result


## Reads the file back and compares it against the content that was just
## written. Returns {} when the bytes on disk match, or an error dictionary
## carrying the md5 evidence when they do not.
func verify_text_write(path: String, expected: String, what: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal(
			"%s: the file cannot be read back after writing it: %s" % [what, error_string(FileAccess.get_open_error())]
		)
	var on_disk := file.get_as_text()
	file.close()
	if on_disk == expected:
		return {}
	return error(
		-32003,
		"%s: what is on disk does not match what was just written — the edit did not persist." % what,
		{
			"path": normalize_project_path(path),
			"md5_expected": expected.md5_text(),
			"md5_on_disk": on_disk.md5_text(),
			"suggestion": "Another writer overwrote the file immediately (a parallel MCP session on a second server port, a stale duplicate tool call, or an editor buffer save). Re-read the file, reapply the edit once, and check again.",
		}
	)


## Fire-and-forget delayed re-check: reads the file again ~5s after the edit
## was reported and, when it no longer matches, logs the md5 evidence to the
## editor Output so a late overwrite still leaves a trace. Call it without
## await; the tool response must not wait on it.
func watch_text_persistence(path: String, expected_md5: String, what: String) -> void:
	var key := normalize_project_path(path).to_lower()
	_last_text_write_md5[key] = expected_md5
	await get_tree().create_timer(5.0).timeout
	# A later MCP write to the same file supersedes this check; the normal
	# create_script -> edit_script sequence must not be reported as a lost edit.
	if _last_text_write_md5.get(key, "") != expected_md5:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[MCP] %s: '%s' can no longer be read ~5s after writing it." % [what, normalize_project_path(path)])
		return
	var disk_md5 := file.get_as_text().md5_text()
	file.close()
	if disk_md5 != expected_md5:
		# A warning, not an error: the file legitimately changes whenever the
		# user or a later tool call edits it within these 5s. The md5 pair is
		# what makes a genuinely lost edit diagnosable after the fact.
		push_warning(
			"[MCP] %s: '%s' changed within ~5s of the edit being reported as written (md5 %s -> %s). If nothing else was supposed to touch it, look for a second writer: a parallel MCP session on another server port, a stale duplicate tool call, or an editor buffer save." % [what, normalize_project_path(path), expected_md5, disk_md5]
		)


## Writes `text` to an IPC file so the reader can never see it half-written:
## the content goes to a uniquely named temp file first and is then renamed
## onto `path`. A reader polling `path` (the game, or the editor for
## responses) otherwise could open it between open() and store_string()
## and consume empty or partial JSON.
static func write_file_atomic(path: String, text: String, clobber: bool = true) -> Error:
	var tmp := "%s.tmp_%d_%d" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		if not clobber:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
			return ERR_ALREADY_EXISTS
		# rename onto an existing file fails on Windows
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return err


## Cross-process lock for one IPC channel, shared by every editor using this
## user:// directory. Directory creation is the only atomic "create if
## absent" Godot offers (make_dir fails with ERR_ALREADY_EXISTS), so the lock
## is a directory holding an owner file. A lock whose owner file is older
## than 5 s is left over from a crashed writer and is broken.
static func _try_acquire_ipc_lock(lock_path: String) -> bool:
	var g := ProjectSettings.globalize_path(lock_path)
	var owner := lock_path + "/owner"
	if DirAccess.make_dir_absolute(g) == OK:
		var f := FileAccess.open(owner, FileAccess.WRITE)
		if f == null:
			# Cannot mark ownership: give the lock back rather than holding
			# one another writer could not tell from an abandoned one.
			DirAccess.remove_absolute(g)
			return false
		f.store_string(_ipc_lock_token())
		f.close()
		return true
	# Held by someone. Break it only when clearly abandoned: an owner file,
	# or (while a writer is still creating it) the directory itself, not
	# touched for more than 5 s.
	var stamp_path := owner if FileAccess.file_exists(owner) else lock_path
	var modified := FileAccess.get_modified_time(stamp_path)
	if modified <= 0 or int(Time.get_unix_time_from_system()) - modified <= 5:
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(owner))
	DirAccess.remove_absolute(g)
	return false


## Identifies this process as a lock owner.
static func _ipc_lock_token() -> String:
	return str(OS.get_process_id())


static func _release_ipc_lock(lock_path: String) -> void:
	# Only release a lock this process owns; a broken-and-retaken lock
	# belongs to someone else now.
	var owner := lock_path + "/owner"
	if FileAccess.file_exists(owner) and FileAccess.get_file_as_string(owner) != _ipc_lock_token():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(owner))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lock_path))


## Publishes `text` at `path` without ever replacing an unread file another
## writer (another editor sharing user://) published in the meantime: the
## absence check and the rename happen under the channel's cross-process
## lock. `own_is_stale`: an existing file written by THIS editor is left over
## (true for game requests, which this editor serialises) rather than
## pending (false for input, where our own unread payload must survive).
## Returns OK, ERR_BUSY (a foreign/pending file is still unread at the
## deadline) or another error.
func publish_ipc_exclusive(path: String, text: String, deadline_ms: int, own_is_stale: bool, session: int = -1) -> Error:
	var lock_path := path + ".lock"
	while Time.get_ticks_msec() < deadline_ms:
		# The game this was meant for may be gone (stopped or restarted
		# while we waited): never publish into a different session.
		if session >= 0 and (session != _play_session_gen or not get_editor().is_playing_scene()):
			return ERR_UNAVAILABLE
		if FileAccess.file_exists(path):
			if own_is_stale and _ipc_file_owner_pid(path) == OS.get_process_id():
				if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
					return ERR_FILE_CANT_WRITE
				continue
		elif _try_acquire_ipc_lock(lock_path):
			var err := OK
			# Re-check everything under the lock: time may have passed.
			if Time.get_ticks_msec() >= deadline_ms:
				err = ERR_BUSY
			elif session >= 0 and (session != _play_session_gen or not get_editor().is_playing_scene()):
				err = ERR_UNAVAILABLE
			elif FileAccess.file_exists(path):
				err = ERR_ALREADY_EXISTS
			else:
				err = write_file_atomic(path, text, false)
			_release_ipc_lock(lock_path)
			if err == OK or err == ERR_UNAVAILABLE or (err != ERR_BUSY and err != ERR_ALREADY_EXISTS):
				return err
		await get_tree().create_timer(0.02).timeout
	return ERR_BUSY


## True when a game response exists and is addressed to this editor (or to
## no one in particular). Another editor sharing user:// may be waiting for
## the reply sitting there; reading it would discard their result.
static func _own_response_ready(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var owner := _ipc_file_owner_pid(path)
	return owner == 0 or owner == OS.get_process_id()


## editor_pid recorded in an IPC file, or 0 when it has none.
static func _ipc_file_owner_pid(path: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed.get("editor_pid") is int or parsed.get("editor_pid") is float):
		return int(parsed["editor_pid"])
	return 0


const INPUT_COMMANDS_PATH := "user://mcp_input_commands"


## Removes an IPC file this editor wrote (or one that names no writer).
## Another editor sharing the user:// directory may have a pending payload
## there; its file is left alone.
static func remove_ipc_file_if_owned(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	# Inspect and delete under the channel's lock: otherwise the game could
	# consume our file and another editor publish a new one between the
	# ownership check and the deletion, and we would delete theirs. Publishers
	# hold the lock only for a write+rename, so a short wait suffices.
	var lock_path := path + ".lock"
	var locked := false
	for _i in 40:
		if _try_acquire_ipc_lock(lock_path):
			locked = true
			break
		OS.delay_msec(5)
	if not locked:
		return  # busy: leave it; an unread file of ours is dropped next time
	if FileAccess.file_exists(path):
		var owner := _ipc_file_owner_pid(path)
		if owner == 0 or owner == OS.get_process_id():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path)
	_release_ipc_lock(lock_path)


## Some editor operations stop a running game on their own (saving all
## scenes does). Call with the playing state from before the operation: if
## the game is gone now, end its session exactly like stop_scene does, so
## writers waiting to publish into it give up and its unread input and
## requests cannot reach the next game.
func handle_implicit_stop(was_playing: bool) -> void:
	if not was_playing or get_editor().is_playing_scene():
		return
	bump_play_session()
	var dirs: Array = [OS.get_user_data_dir()]
	var game_dir := get_game_user_dir()
	if not dirs.has(game_dir):
		dirs.append(game_dir)
	for d: String in dirs:
		remove_ipc_file_if_owned(d.path_join("mcp_input_commands"))
		remove_ipc_file_if_owned(d.path_join("mcp_game_request"))

## Incremented by the plugin each time a game stops. A writer that waited
## across a stop must not publish into the next session: the stop cleanup
## has already run, so nothing would remove what it writes.
static var _play_session_gen := 0


static func bump_play_session() -> void:
	_play_session_gen += 1


## The one way to hand input to the running game (simulate_*, test
## scenarios, stress tests). Refuses rather than overwriting input the game
## has not read yet, stamps the payload with its write time (the game drops
## payloads older than its own start, i.e. left over from an earlier play
## session), and publishes it atomically.
func write_input_payload(payload: Variant) -> Dictionary:
	# Input is only ever written while a game runs; the plugin clears what a
	# stopped game left unread (see plugin.gd), so nothing stale can reach
	# the next play session.
	if not get_editor().is_playing_scene():
		return error(-32000, "No scene is currently playing", {"suggestion": "Use play_scene first"})
	var session := _play_session_gen
	var doc: Dictionary = (payload as Dictionary).duplicate() if payload is Dictionary else {"events": payload}
	doc["written_unix"] = Time.get_unix_time_from_system()
	# Lets cleanup tell this editor's pending input from another editor's
	# when several share one user:// directory.
	doc["editor_pid"] = OS.get_process_id()
	# Wait (1 s) for the channel to be free, then publish without ever
	# replacing unread input, ours or another editor's.
	var err := await publish_ipc_exclusive(INPUT_COMMANDS_PATH, JSON.stringify(doc), Time.get_ticks_msec() + 1000, false, session)
	if err == ERR_UNAVAILABLE:
		return error(-32000, "The game stopped before this input could be sent", {"suggestion": "Nothing was sent. Start the game again and retry."})
	if err == ERR_BUSY:
		return error(-32000, "The game has not read the previous input yet", {
			"suggestion": "The game may be paused, stalled or not running. Retry once it is responsive; the earlier input is still pending and will be delivered first.",
		})
	if err != OK:
		return error_internal("Failed to write input commands: %s" % error_string(err))
	return {}


## Waits (up to timeout_sec) until the running game's MCPInputService has
## consumed the previous input payload at `path`. The game reads and deletes
## that single file once per frame, so writing a new payload before it has
## been read silently replaced — and dropped — the previous input. Returns
## false on timeout; callers then overwrite as before so a stale file left by
## a stopped or paused game cannot block input forever.
func await_input_payload_consumed(path: String, timeout_sec: float = 1.0) -> bool:
	# Monotonic deadline: in a slow editor, counting timer ticks turned the
	# 1 s wait into close to a minute, so input could be published long
	# after its caller had timed out.
	var deadline_ms := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while FileAccess.file_exists(path):
		if Time.get_ticks_msec() >= deadline_ms:
			return false
		await get_tree().create_timer(0.02).timeout
	# The file may have gone while this editor was blocked past the deadline;
	# the caller has given up by then, so do not report success.
	return Time.get_ticks_msec() < deadline_ms


## Find node by path in edited scene
func find_node_by_path(node_path: String) -> Node:
	var root := get_edited_root()
	if root == null:
		return null
	if node_path == "." or node_path == root.name:
		return root
	# Try relative from root
	if root.has_node(node_path):
		return root.get_node(node_path)
	# Try with root name prefix stripped
	if node_path.begins_with(root.name + "/"):
		var rel := node_path.substr(root.name.length() + 1)
		if root.has_node(rel):
			return root.get_node(rel)
	return null
