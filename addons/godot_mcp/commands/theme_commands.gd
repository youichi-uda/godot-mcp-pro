@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_theme": _create_theme,
		"set_theme_color": _set_theme_color,
		"set_theme_constant": _set_theme_constant,
		"set_theme_font_size": _set_theme_font_size,
		"set_theme_stylebox": _set_theme_stylebox,
		"get_theme_info": _get_theme_info,
	}


func _create_theme(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	var theme := Theme.new()

	# Optionally set default font size
	var font_size: int = optional_int(params, "default_font_size", 0)
	if font_size > 0:
		theme.default_font_size = font_size

	var err := ResourceSaver.save(theme, path)
	if err != OK:
		return error_internal("Failed to save theme: %s" % error_string(err))

	get_editor().get_resource_filesystem().scan()
	return success({"path": path, "created": true})


func _set_theme_color(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var color_name: String = result2[0]

	var result3 := require_string(params, "color")
	if result3[1] != null:
		return result3[1]
	var color_str: String = result3[0]

	var node := find_node_by_path(node_path)
	if node == null or not (node is Control):
		return error_not_found("Control node at '%s'" % node_path)

	var control: Control = node
	var color := Color(color_str)

	var theme_type: String = optional_string(params, "theme_type", "")
	if theme_type.is_empty():
		theme_type = control.get_class()

	control.add_theme_color_override(color_name, color)

	return success({"node_path": node_path, "name": color_name, "color": color_str})


func _set_theme_constant(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var const_name: String = result2[0]

	var node := find_node_by_path(node_path)
	if node == null or not (node is Control):
		return error_not_found("Control node at '%s'" % node_path)

	var control: Control = node
	var value: int = int(params.get("value", 0))

	control.add_theme_constant_override(const_name, value)

	return success({"node_path": node_path, "name": const_name, "value": value})


func _set_theme_font_size(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var font_name: String = result2[0]

	var node := find_node_by_path(node_path)
	if node == null or not (node is Control):
		return error_not_found("Control node at '%s'" % node_path)

	var control: Control = node
	var size: int = int(params.get("size", 16))

	control.add_theme_font_size_override(font_name, size)

	return success({"node_path": node_path, "name": font_name, "size": size})


func _set_theme_stylebox(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var style_name: String = result2[0]

	var node := find_node_by_path(node_path)
	if node == null or not (node is Control):
		return error_not_found("Control node at '%s'" % node_path)

	var control: Control = node

	var stylebox := StyleBoxFlat.new()

	var bg_color: String = optional_string(params, "bg_color", "")
	if not bg_color.is_empty():
		stylebox.bg_color = Color(bg_color)

	var border_color: String = optional_string(params, "border_color", "")
	if not border_color.is_empty():
		stylebox.border_color = Color(border_color)

	var border_width: int = optional_int(params, "border_width", 0)
	if border_width > 0:
		stylebox.border_width_left = border_width
		stylebox.border_width_top = border_width
		stylebox.border_width_right = border_width
		stylebox.border_width_bottom = border_width

	var corner_radius: int = optional_int(params, "corner_radius", 0)
	if corner_radius > 0:
		stylebox.corner_radius_top_left = corner_radius
		stylebox.corner_radius_top_right = corner_radius
		stylebox.corner_radius_bottom_left = corner_radius
		stylebox.corner_radius_bottom_right = corner_radius

	var padding: int = optional_int(params, "padding", 0)
	if padding > 0:
		stylebox.content_margin_left = padding
		stylebox.content_margin_top = padding
		stylebox.content_margin_right = padding
		stylebox.content_margin_bottom = padding

	control.add_theme_stylebox_override(style_name, stylebox)

	return success({"node_path": node_path, "name": style_name, "type": "StyleBoxFlat"})


func _get_theme_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null or not (node is Control):
		return error_not_found("Control node at '%s'" % node_path)

	var control: Control = node
	var info := {"node_path": node_path, "class": control.get_class()}

	# Check if node has a theme
	var theme := control.theme
	if theme:
		info["theme_path"] = theme.resource_path
		info["type_list"] = Array(theme.get_type_list())

	# List overrides
	var overrides := {"colors": {}, "constants": {}, "font_sizes": {}, "styleboxes": {}}
	for prop in control.get_property_list():
		var pname: String = prop["name"]
		if pname.begins_with("theme_override_colors/"):
			var key := pname.substr(22)
			overrides["colors"][key] = "#" + (control.get(pname) as Color).to_html()
		elif pname.begins_with("theme_override_constants/"):
			var key := pname.substr(25)
			overrides["constants"][key] = control.get(pname)
		elif pname.begins_with("theme_override_font_sizes/"):
			var key := pname.substr(26)
			overrides["font_sizes"][key] = control.get(pname)
		elif pname.begins_with("theme_override_styles/"):
			var key := pname.substr(22)
			var style = control.get(pname)
			overrides["styleboxes"][key] = style.get_class() if style else null

	info["overrides"] = overrides
	return success(info)
