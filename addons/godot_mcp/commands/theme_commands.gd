@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_theme": _create_theme,
		"set_theme_color": _set_theme_color,
		"set_theme_constant": _set_theme_constant,
		"set_theme_font_size": _set_theme_font_size,
		"set_theme_stylebox": _set_theme_stylebox,
		"setup_control": _setup_control,
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


func _setup_control(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null or not (node is Control):
		return error_not_found("Control node at '%s'" % node_path)

	var control: Control = node
	var applied: Array = []

	# Anchor preset
	var anchor_preset: String = optional_string(params, "anchor_preset", "")
	if not anchor_preset.is_empty():
		var preset_map := {
			"top_left": Control.PRESET_TOP_LEFT,
			"top_right": Control.PRESET_TOP_RIGHT,
			"bottom_left": Control.PRESET_BOTTOM_LEFT,
			"bottom_right": Control.PRESET_BOTTOM_RIGHT,
			"center_left": Control.PRESET_CENTER_LEFT,
			"center_top": Control.PRESET_CENTER_TOP,
			"center_right": Control.PRESET_CENTER_RIGHT,
			"center_bottom": Control.PRESET_CENTER_BOTTOM,
			"center": Control.PRESET_CENTER,
			"left_wide": Control.PRESET_LEFT_WIDE,
			"top_wide": Control.PRESET_TOP_WIDE,
			"right_wide": Control.PRESET_RIGHT_WIDE,
			"bottom_wide": Control.PRESET_BOTTOM_WIDE,
			"vcenter_wide": Control.PRESET_VCENTER_WIDE,
			"hcenter_wide": Control.PRESET_HCENTER_WIDE,
			"full_rect": Control.PRESET_FULL_RECT,
		}
		if preset_map.has(anchor_preset):
			control.set_anchors_and_offsets_preset(preset_map[anchor_preset])
			applied.append("anchor_preset=%s" % anchor_preset)

	# Min size
	var min_size_str: String = optional_string(params, "min_size", "")
	if not min_size_str.is_empty():
		var expr := Expression.new()
		if expr.parse(min_size_str) == OK:
			var val = expr.execute()
			if val is Vector2:
				control.custom_minimum_size = val
				applied.append("min_size=%s" % min_size_str)

	# Size flags horizontal
	var sf_h: String = optional_string(params, "size_flags_h", "")
	if not sf_h.is_empty():
		var flags_map := {
			"fill": Control.SIZE_FILL,
			"expand": Control.SIZE_EXPAND,
			"fill_expand": Control.SIZE_EXPAND_FILL,
			"shrink_center": Control.SIZE_SHRINK_CENTER,
			"shrink_end": Control.SIZE_SHRINK_END,
		}
		if flags_map.has(sf_h):
			control.size_flags_horizontal = flags_map[sf_h]
			applied.append("size_flags_h=%s" % sf_h)

	# Size flags vertical
	var sf_v: String = optional_string(params, "size_flags_v", "")
	if not sf_v.is_empty():
		var flags_map := {
			"fill": Control.SIZE_FILL,
			"expand": Control.SIZE_EXPAND,
			"fill_expand": Control.SIZE_EXPAND_FILL,
			"shrink_center": Control.SIZE_SHRINK_CENTER,
			"shrink_end": Control.SIZE_SHRINK_END,
		}
		if flags_map.has(sf_v):
			control.size_flags_vertical = flags_map[sf_v]
			applied.append("size_flags_v=%s" % sf_v)

	# Margins (for MarginContainer)
	if params.has("margins") and params["margins"] is Dictionary:
		var margins: Dictionary = params["margins"]
		if control is MarginContainer:
			if margins.has("left"):
				control.add_theme_constant_override("margin_left", int(margins["left"]))
			if margins.has("top"):
				control.add_theme_constant_override("margin_top", int(margins["top"]))
			if margins.has("right"):
				control.add_theme_constant_override("margin_right", int(margins["right"]))
			if margins.has("bottom"):
				control.add_theme_constant_override("margin_bottom", int(margins["bottom"]))
			applied.append("margins=%s" % str(margins))

	# Separation (for VBox/HBoxContainer)
	if params.has("separation"):
		var sep: int = int(params["separation"])
		if control is BoxContainer:
			control.add_theme_constant_override("separation", sep)
			applied.append("separation=%d" % sep)

	# Grow direction horizontal
	var grow_h: String = optional_string(params, "grow_h", "")
	if not grow_h.is_empty():
		var grow_map := {
			"begin": Control.GROW_DIRECTION_BEGIN,
			"end": Control.GROW_DIRECTION_END,
			"both": Control.GROW_DIRECTION_BOTH,
		}
		if grow_map.has(grow_h):
			control.grow_horizontal = grow_map[grow_h]
			applied.append("grow_h=%s" % grow_h)

	# Grow direction vertical
	var grow_v: String = optional_string(params, "grow_v", "")
	if not grow_v.is_empty():
		var grow_map := {
			"begin": Control.GROW_DIRECTION_BEGIN,
			"end": Control.GROW_DIRECTION_END,
			"both": Control.GROW_DIRECTION_BOTH,
		}
		if grow_map.has(grow_v):
			control.grow_vertical = grow_map[grow_v]
			applied.append("grow_v=%s" % grow_v)

	return success({"node_path": node_path, "applied": applied, "count": applied.size()})


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
