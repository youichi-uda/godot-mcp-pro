@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"list_export_presets": _list_export_presets,
		"export_project": _export_project,
		"get_export_info": _get_export_info,
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
