@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"list_android_devices": _list_android_devices,
		"get_android_preset_info": _get_android_preset_info,
		"deploy_to_android": _deploy_to_android,
	}


## Resolve adb path from editor settings or PATH fallback.
func _resolve_adb_path() -> String:
	var editor_settings := get_editor().get_editor_settings()
	# Godot exposes this under export/android/adb (may be stored as an absolute path).
	var configured: String = ""
	if editor_settings.has_setting("export/android/adb"):
		configured = str(editor_settings.get_setting("export/android/adb"))
	if not configured.is_empty() and FileAccess.file_exists(configured):
		return configured
	# Fallback: assume adb is on PATH. OS.execute will resolve it at call time.
	return "adb"


func _run(cmd: String, args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(cmd, args, output, true)
	var stdout := ""
	if not output.is_empty():
		stdout = str(output[0])
	return {"exit_code": exit_code, "stdout": stdout}


## List devices visible to adb.
func _list_android_devices(_params: Dictionary) -> Dictionary:
	var adb := _resolve_adb_path()
	var result := _run(adb, PackedStringArray(["devices", "-l"]))
	if result["exit_code"] != 0:
		return error(-32000, "adb failed (exit %d). Install Android platform-tools or set Editor Settings > Export > Android > Adb." % result["exit_code"], {"adb_path": adb, "output": result["stdout"]})

	# Parse `adb devices -l` output:
	#   List of devices attached
	#   R58M12345  device usb:3-1 product:foo model:Pixel_5 device:redfin
	var devices: Array = []
	var lines: PackedStringArray = str(result["stdout"]).split("\n")
	for raw_line in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("List of devices") or line.begins_with("* daemon"):
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() < 2:
			continue
		var dev: Dictionary = {"serial": parts[0], "state": parts[1]}
		for i in range(2, parts.size()):
			var kv: String = parts[i]
			var eq: int = kv.find(":")
			if eq > 0:
				dev[kv.substr(0, eq)] = kv.substr(eq + 1)
		devices.append(dev)

	return success({"devices": devices, "count": devices.size(), "adb_path": adb})


## Find an Android preset in export_presets.cfg. Returns the preset dict or null.
func _find_android_preset(preset_name: String, preset_index: int) -> Dictionary:
	var presets_path := "res://export_presets.cfg"
	if not FileAccess.file_exists(presets_path):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(presets_path) != OK:
		return {}

	var idx := 0
	while cfg.has_section("preset.%d" % idx):
		var section := "preset.%d" % idx
		var platform := str(cfg.get_value(section, "platform", ""))
		var name := str(cfg.get_value(section, "name", ""))
		var matches := false
		if not preset_name.is_empty():
			matches = (name == preset_name)
		elif preset_index >= 0:
			matches = (idx == preset_index)
		else:
			# No filter: pick the first Android preset.
			matches = (platform == "Android")
		if matches:
			var options_section := "preset.%d.options" % idx
			var package_name := ""
			if cfg.has_section(options_section):
				package_name = str(cfg.get_value(options_section, "package/unique_name", ""))
			return {
				"index": idx,
				"name": name,
				"platform": platform,
				"runnable": bool(cfg.get_value(section, "runnable", false)),
				"export_path": str(cfg.get_value(section, "export_path", "")),
				"package_name": package_name,
			}
		idx += 1
	return {}


## Read Android preset metadata (package name, export path, etc.)
func _get_android_preset_info(params: Dictionary) -> Dictionary:
	var preset_name: String = optional_string(params, "preset_name", "")
	var preset_index: int = optional_int(params, "preset_index", -1)
	var preset := _find_android_preset(preset_name, preset_index)
	if preset.is_empty():
		return error_not_found("Android export preset", "Configure an Android preset in Project > Export first.")
	if preset["platform"] != "Android":
		return error(-32000, "Preset '%s' is not an Android preset (platform=%s)" % [preset["name"], preset["platform"]])
	return success(preset)


## Export APK, install it on a device, then optionally launch the main activity.
func _deploy_to_android(params: Dictionary) -> Dictionary:
	var preset_name: String = optional_string(params, "preset_name", "")
	var preset_index: int = optional_int(params, "preset_index", -1)
	var device_serial: String = optional_string(params, "device_serial", "")
	var debug: bool = optional_bool(params, "debug", true)
	var launch: bool = optional_bool(params, "launch", true)
	var skip_export: bool = optional_bool(params, "skip_export", false)

	var preset := _find_android_preset(preset_name, preset_index)
	if preset.is_empty():
		return error_not_found("Android export preset", "Configure an Android preset in Project > Export first.")
	if preset["platform"] != "Android":
		return error(-32000, "Preset '%s' is not an Android preset" % preset["name"])

	var export_path_res: String = preset["export_path"]
	if export_path_res.is_empty():
		return error(-32000, "Export path not configured for preset '%s'" % preset["name"])
	var export_path_abs: String = ProjectSettings.globalize_path(export_path_res) if export_path_res.begins_with("res://") else export_path_res

	var steps: Array = []

	# Step 1: Export APK via Godot CLI (unless caller already has an APK).
	if not skip_export:
		var godot_bin := OS.get_executable_path()
		var project_dir := ProjectSettings.globalize_path("res://")
		var export_flag := "--export-debug" if debug else "--export-release"
		var export_args := PackedStringArray(["--headless", "--path", project_dir, export_flag, preset["name"], export_path_abs])
		var export_result := _run(godot_bin, export_args)
		steps.append({"step": "export", "command": godot_bin, "args": export_args, "exit_code": export_result["exit_code"]})
		if export_result["exit_code"] != 0:
			return error(-32000, "Godot export failed (exit %d). See stdout." % export_result["exit_code"], {"steps": steps, "stdout": export_result["stdout"]})

	if not FileAccess.file_exists(export_path_abs):
		return error(-32000, "APK not found at %s after export" % export_path_abs, {"steps": steps})

	# Step 2: adb install -r
	var adb := _resolve_adb_path()
	var install_args := PackedStringArray()
	if not device_serial.is_empty():
		install_args.append("-s")
		install_args.append(device_serial)
	install_args.append("install")
	install_args.append("-r")
	install_args.append(export_path_abs)
	var install_result := _run(adb, install_args)
	steps.append({"step": "install", "command": adb, "args": install_args, "exit_code": install_result["exit_code"], "stdout": install_result["stdout"]})
	if install_result["exit_code"] != 0:
		return error(-32000, "adb install failed (exit %d)" % install_result["exit_code"], {"steps": steps})

	# Step 3: adb shell am start (optional)
	if launch:
		var package_name: String = preset["package_name"]
		if package_name.is_empty():
			steps.append({"step": "launch", "skipped": true, "reason": "package_name not found in preset"})
		else:
			var launch_args := PackedStringArray()
			if not device_serial.is_empty():
				launch_args.append("-s")
				launch_args.append(device_serial)
			launch_args.append("shell")
			launch_args.append("monkey")
			launch_args.append("-p")
			launch_args.append(package_name)
			launch_args.append("-c")
			launch_args.append("android.intent.category.LAUNCHER")
			launch_args.append("1")
			var launch_result := _run(adb, launch_args)
			steps.append({"step": "launch", "command": adb, "args": launch_args, "exit_code": launch_result["exit_code"], "stdout": launch_result["stdout"]})

	return success({
		"preset": preset["name"],
		"apk_path": export_path_abs,
		"device": device_serial if not device_serial.is_empty() else "(default)",
		"package_name": preset["package_name"],
		"steps": steps,
	})
