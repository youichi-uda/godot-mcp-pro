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
		"add_virtual_joystick": _add_virtual_joystick,
	}


const _ANCHOR_PRESETS := {
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

	var ext_guard := guard_expected_extension(path, ["tres", "res", "theme"], "a theme resource")
	if not ext_guard.is_empty():
		return ext_guard

	var scene_guard := guard_offline_scene_save(path)
	if not scene_guard.is_empty():
		return scene_guard

	var dir_guard := ensure_parent_dir(path)
	if not dir_guard.is_empty():
		return dir_guard

	var err := ResourceSaver.save(theme, path)
	if err != OK:
		return error_internal("Failed to save theme: %s" % error_string(err))

	EditorInterface.get_resource_filesystem().scan()
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

	var had_old := control.has_theme_color_override(color_name)
	var old_value: Variant = control.get("theme_override_colors/" + color_name) if had_old else null
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set theme color override")
	undo_redo.add_do_method(control, "add_theme_color_override", color_name, color)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "color", color_name, had_old, old_value)
	undo_redo.commit_action()

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
	var value: int = optional_int(params, "value", 0)

	var had_old := control.has_theme_constant_override(const_name)
	var old_value: Variant = control.get("theme_override_constants/" + const_name) if had_old else null
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set theme constant override")
	undo_redo.add_do_method(control, "add_theme_constant_override", const_name, value)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "constant", const_name, had_old, old_value)
	undo_redo.commit_action()

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
	var size: int = optional_int(params, "size", 16)

	var had_old := control.has_theme_font_size_override(font_name)
	var old_value: Variant = control.get("theme_override_font_sizes/" + font_name) if had_old else null
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set theme font size override")
	undo_redo.add_do_method(control, "add_theme_font_size_override", font_name, size)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "font_size", font_name, had_old, old_value)
	undo_redo.commit_action()

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

	var had_old := control.has_theme_stylebox_override(style_name)
	var old_value: Variant = control.get("theme_override_styles/" + style_name) if had_old else null
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set theme stylebox override")
	undo_redo.add_do_method(control, "add_theme_stylebox_override", style_name, stylebox)
	undo_redo.add_do_reference(stylebox)
	undo_redo.add_undo_method(self, "_restore_theme_override", control, "stylebox", style_name, had_old, old_value)
	if old_value is Resource:
		undo_redo.add_undo_reference(old_value)
	undo_redo.commit_action()

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

	# Version-gated transform/size properties are validated up front, before
	# the scratch duplicate exists, so an error cannot leak it.
	var extra := _parse_control_extras(params, control)
	if extra.has("error"):
		return extra

	var old_state := _capture_control_setup_state(control)
	var target: Control = control.duplicate() as Control

	# Anchor preset
	var anchor_preset: String = optional_string(params, "anchor_preset", "")
	if not anchor_preset.is_empty():
		if _ANCHOR_PRESETS.has(anchor_preset):
			target.set_anchors_and_offsets_preset(_ANCHOR_PRESETS[anchor_preset])
			applied.append("anchor_preset=%s" % anchor_preset)

	# Min size
	var min_size_str: String = optional_string(params, "min_size", "")
	if not min_size_str.is_empty():
		var expr := Expression.new()
		if expr.parse(min_size_str) == OK:
			var val = expr.execute()
			if val is Vector2:
				target.custom_minimum_size = val
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
			target.size_flags_horizontal = flags_map[sf_h]
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
			target.size_flags_vertical = flags_map[sf_v]
			applied.append("size_flags_v=%s" % sf_v)

	# Margins (for MarginContainer)
	if params.has("margins") and params["margins"] is Dictionary:
		var margins: Dictionary = params["margins"]
		if target is MarginContainer:
			if margins.has("left"):
				target.add_theme_constant_override("margin_left", int(margins["left"]))
			if margins.has("top"):
				target.add_theme_constant_override("margin_top", int(margins["top"]))
			if margins.has("right"):
				target.add_theme_constant_override("margin_right", int(margins["right"]))
			if margins.has("bottom"):
				target.add_theme_constant_override("margin_bottom", int(margins["bottom"]))
			applied.append("margins=%s" % str(margins))

	# Separation (for VBox/HBoxContainer)
	if params.has("separation"):
		var sep: int = optional_int(params, "separation")
		if target is BoxContainer:
			target.add_theme_constant_override("separation", sep)
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
			target.grow_horizontal = grow_map[grow_h]
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
			target.grow_vertical = grow_map[grow_v]
			applied.append("grow_v=%s" % grow_v)

	var extra_props: Dictionary = extra["properties"]
	for property: String in extra_props:
		target.set(property, extra_props[property])
		applied.append("%s=%s" % [property, str(extra_props[property])])

	if not applied.is_empty():
		var new_state := _capture_control_setup_state(target)
		_register_control_setup_undo(control, old_state, new_state)
	target.free()
	return success({"node_path": node_path, "applied": applied, "count": applied.size()})


func _restore_theme_override(control: Control, kind: String, override_name: String, had_old: bool, old_value: Variant) -> void:
	match kind:
		"color":
			if had_old:
				control.add_theme_color_override(override_name, old_value)
			else:
				control.remove_theme_color_override(override_name)
		"constant":
			if had_old:
				control.add_theme_constant_override(override_name, old_value)
			else:
				control.remove_theme_constant_override(override_name)
		"font_size":
			if had_old:
				control.add_theme_font_size_override(override_name, old_value)
			else:
				control.remove_theme_font_size_override(override_name)
		"stylebox":
			if had_old:
				control.add_theme_stylebox_override(override_name, old_value)
			else:
				control.remove_theme_stylebox_override(override_name)


## Control properties that only exist on newer Godot versions, with the version
## that added them (verified by diffing Control's property list on 4.5.1, 4.6.2
## and 4.7.2). Always accessed by name through get()/set().
const _VERSIONED_CONTROL_PROPERTIES := {
	"pivot_offset_ratio": "4.6",
	"custom_maximum_size": "4.7",
	"offset_transform_enabled": "4.7",
	"offset_transform_position": "4.7",
	"offset_transform_position_ratio": "4.7",
	"offset_transform_scale": "4.7",
	"offset_transform_rotation": "4.7",
	"offset_transform_pivot": "4.7",
	"offset_transform_pivot_ratio": "4.7",
	"offset_transform_visual_only": "4.7",
}

## offset_transform sub-keys that take a Vector2 -> the Control property.
const _OFFSET_TRANSFORM_VECTOR_KEYS := {
	"position": "offset_transform_position",
	"position_ratio": "offset_transform_position_ratio",
	"scale": "offset_transform_scale",
	"pivot": "offset_transform_pivot",
	"pivot_ratio": "offset_transform_pivot_ratio",
}


func _control_has_property(control: Control, property: String) -> bool:
	for prop in control.get_property_list():
		if prop["name"] == property:
			return true
	return false


## Parses pivot_offset_ratio (4.6+), max_size (custom_maximum_size, 4.7+) and
## offset_transform (4.7+). Returns {"properties": {name: value}} or an error
## dictionary. Nothing is touched when a parameter is absent.
func _parse_control_extras(params: Dictionary, control: Control) -> Dictionary:
	var props := {}

	if params.has("pivot_offset_ratio"):
		var v: Variant = _parse_vector2_param(params["pivot_offset_ratio"])
		if v == null:
			return error_invalid_params("pivot_offset_ratio must be a Vector2, e.g. 'Vector2(0.5, 0.5)' or {\"x\": 0.5, \"y\": 0.5}")
		props["pivot_offset_ratio"] = v

	if params.has("max_size"):
		var v: Variant = _parse_vector2_param(params["max_size"])
		if v == null:
			return error_invalid_params("max_size must be a Vector2, e.g. 'Vector2(400, 300)'")
		props["custom_maximum_size"] = v

	if params.has("offset_transform"):
		if not params["offset_transform"] is Dictionary:
			return error_invalid_params("offset_transform must be an object")
		var ot: Dictionary = params["offset_transform"]
		for key: Variant in ot:
			var k := str(key)
			if _OFFSET_TRANSFORM_VECTOR_KEYS.has(k):
				var v: Variant = _parse_vector2_param(ot[key])
				if v == null:
					return error_invalid_params("offset_transform.%s must be a Vector2" % k)
				props[_OFFSET_TRANSFORM_VECTOR_KEYS[k]] = v
			elif k == "rotation_degrees":
				if not (ot[key] is int or ot[key] is float):
					return error_invalid_params("offset_transform.rotation_degrees must be a number")
				props["offset_transform_rotation"] = deg_to_rad(float(ot[key]))
			elif k == "enabled" or k == "visual_only":
				if not ot[key] is bool:
					return error_invalid_params("offset_transform.%s must be a boolean" % k)
				props["offset_transform_" + k] = ot[key]
			else:
				return error_invalid_params(
					"Unknown offset_transform key '%s'. Valid: position, position_ratio, scale, rotation_degrees, pivot, pivot_ratio, visual_only, enabled" % k
				)
		# The transform only applies while enabled; setting its values without
		# enabling it would look like a silent no-op. enabled=false still wins.
		if not ot.is_empty() and not ot.has("enabled"):
			props["offset_transform_enabled"] = true

	for property: String in props:
		if not _control_has_property(control, property):
			return error_requires_godot("setup_control '%s'" % property, _VERSIONED_CONTROL_PROPERTIES.get(property, "?"))
	return {"properties": props}


## Accepts 'Vector2(x, y)' / '(x, y)' / 'x, y' strings, {"x", "y"} objects and
## [x, y] arrays. Returns null (instead of a silent Vector2.ZERO) when the
## value is not exactly two numbers.
func _parse_vector2_param(value: Variant) -> Variant:
	if value is Vector2:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		if d.has("x") and d.has("y") and (d["x"] is int or d["x"] is float) and (d["y"] is int or d["y"] is float):
			return Vector2(float(d["x"]), float(d["y"]))
		return null
	if value is Array:
		var a: Array = value
		if a.size() == 2 and (a[0] is int or a[0] is float) and (a[1] is int or a[1] is float):
			return Vector2(float(a[0]), float(a[1]))
		return null
	if value is String:
		var text := (value as String).strip_edges()
		# The "2" in the constructor name would otherwise count as a number.
		for prefix: String in ["Vector2i", "Vector2"]:
			if text.begins_with(prefix):
				text = text.substr(prefix.length())
				break
		var re := RegEx.create_from_string("[-+]?(?:[0-9]+[.]?[0-9]*|[.][0-9]+)(?:[eE][-+]?[0-9]+)?")
		var nums: Array = []
		for m: RegExMatch in re.search_all(text):
			nums.append(m.get_string().to_float())
		if nums.size() == 2:
			return Vector2(nums[0], nums[1])
	return null


func _capture_control_setup_state(control: Control) -> Dictionary:
	var state := {"properties": {}, "theme_constants": {}}
	var properties: Array = [
		"anchor_left", "anchor_top", "anchor_right", "anchor_bottom",
		"offset_left", "offset_top", "offset_right", "offset_bottom",
		"custom_minimum_size", "size_flags_horizontal", "size_flags_vertical",
		"grow_horizontal", "grow_vertical",
	]
	# Newer-version properties join the undo snapshot only where they exist.
	for property: String in _VERSIONED_CONTROL_PROPERTIES:
		if _control_has_property(control, property):
			properties.append(property)
	for property: String in properties:
		state["properties"][property] = control.get(property)
	for constant_name: String in ["margin_left", "margin_top", "margin_right", "margin_bottom", "separation"]:
		var had_override := control.has_theme_constant_override(constant_name)
		state["theme_constants"][constant_name] = {
			"had": had_override,
			"value": control.get("theme_override_constants/" + constant_name) if had_override else null,
		}
	return state


func _register_control_setup_undo(control: Control, old_state: Dictionary, new_state: Dictionary) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Setup Control")
	for property: String in new_state["properties"]:
		undo_redo.add_do_property(control, property, new_state["properties"][property])
		undo_redo.add_undo_property(control, property, old_state["properties"][property])
	for constant_name: String in new_state["theme_constants"]:
		var new_constant: Dictionary = new_state["theme_constants"][constant_name]
		var old_constant: Dictionary = old_state["theme_constants"][constant_name]
		undo_redo.add_do_method(self, "_restore_theme_override", control, "constant", constant_name, new_constant["had"], new_constant["value"])
		undo_redo.add_undo_method(self, "_restore_theme_override", control, "constant", constant_name, old_constant["had"], old_constant["value"])
	undo_redo.commit_action()


## VirtualJoystick (Godot 4.7+) enum values, looked up by name at runtime: the
## class does not exist on 4.5/4.6, so naming it statically would be a parse
## error there. Verified on 4.7.2: JOYSTICK_FIXED=0, JOYSTICK_DYNAMIC=1,
## JOYSTICK_FOLLOWING=2, VISIBILITY_ALWAYS=0, VISIBILITY_WHEN_TOUCHED=1.
const _JOYSTICK_MODES := {
	"fixed": "JOYSTICK_FIXED",
	"dynamic": "JOYSTICK_DYNAMIC",
	"following": "JOYSTICK_FOLLOWING",
}
const _JOYSTICK_VISIBILITY := {
	"always": "VISIBILITY_ALWAYS",
	"when_touched": "VISIBILITY_WHEN_TOUCHED",
}


func _add_virtual_joystick(params: Dictionary) -> Dictionary:
	if not ClassDB.class_exists("VirtualJoystick"):
		return error_requires_godot("add_virtual_joystick", "4.7")

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path, "Use get_scene_tree to see available nodes")

	var node_name: String = optional_string(params, "name", "VirtualJoystick")
	if node_name.is_empty() or node_name.validate_node_name() != node_name:
		return error_invalid_params("Invalid node name '%s'" % node_name)

	# Enums
	var mode_name: String = optional_string(params, "mode", "fixed")
	if not _JOYSTICK_MODES.has(mode_name):
		return error_invalid_params("Invalid mode '%s'. Valid: %s" % [mode_name, ", ".join(_JOYSTICK_MODES.keys())])
	var visibility_name: String = optional_string(params, "visibility", "always")
	if not _JOYSTICK_VISIBILITY.has(visibility_name):
		return error_invalid_params("Invalid visibility '%s'. Valid: %s" % [visibility_name, ", ".join(_JOYSTICK_VISIBILITY.keys())])

	# Numbers, range-checked against the inspector hints measured on 4.7.2.
	var numbers := {}
	for spec: Array in [
		["joystick_size", 10.0, 500.0],
		["tip_size", 5.0, 250.0],
		["deadzone_ratio", 0.0, 1.0],
		["clampzone_ratio", 0.0, 2.0],
	]:
		var key: String = spec[0]
		if not params.has(key):
			continue
		var raw: Variant = params[key]
		if not (raw is int or raw is float) or is_nan(float(raw)) or float(raw) < spec[1] or float(raw) > spec[2]:
			return error_invalid_params("%s must be a number between %s and %s" % [key, str(spec[1]), str(spec[2])])
		numbers[key] = float(raw)

	var vectors := {}
	for key: String in ["initial_offset_ratio", "size", "position"]:
		if params.has(key):
			var v: Variant = _parse_vector2_param(params[key])
			if v == null:
				return error_invalid_params("%s must be a Vector2, e.g. 'Vector2(300, 300)' or {\"x\": 300, \"y\": 300}" % key)
			vectors[key] = v
	if vectors.has("size") and (vectors["size"].x <= 0.0 or vectors["size"].y <= 0.0):
		return error_invalid_params("size must be positive: the Control's rect is the joystick's touch area")

	var anchor_preset: String = optional_string(params, "anchor_preset", "")
	if not anchor_preset.is_empty() and not _ANCHOR_PRESETS.has(anchor_preset):
		return error_invalid_params("Invalid anchor_preset '%s'. Valid: %s" % [anchor_preset, ", ".join(_ANCHOR_PRESETS.keys())])
	if not anchor_preset.is_empty() and vectors.has("position"):
		return error_invalid_params("Pass either anchor_preset or position, not both")
	var margin: int = optional_int(params, "margin", 0)

	# Actions default to the built-in ui_* ones, like the node itself. A missing
	# action is a warning rather than an error: the caller may add it with
	# set_input_action next.
	var warnings: Array = []
	var actions := {}
	for dir: String in ["left", "right", "up", "down"]:
		var key := "action_" + dir
		var action: String = optional_string(params, key, "ui_" + dir)
		if action.is_empty():
			return error_invalid_params("%s must not be empty" % key)
		if not ProjectSettings.has_setting("input/" + action):
			warnings.append("Input action '%s' (%s) is not defined in the project's Input Map; that direction does nothing (and the running game logs 'InputMap action doesn't exist' errors) until it is added with set_input_action." % [action, key])
		actions[key] = action

	var joystick: Control = ClassDB.instantiate("VirtualJoystick")
	if joystick == null:
		return error_internal("Could not instantiate VirtualJoystick")
	joystick.name = node_name
	for key: String in actions:
		joystick.set(key, StringName(actions[key]))
	joystick.set("joystick_mode", ClassDB.class_get_integer_constant("VirtualJoystick", _JOYSTICK_MODES[mode_name]))
	joystick.set("visibility_mode", ClassDB.class_get_integer_constant("VirtualJoystick", _JOYSTICK_VISIBILITY[visibility_name]))
	for key: String in numbers:
		joystick.set(key, numbers[key])
	if vectors.has("initial_offset_ratio"):
		joystick.set("initial_offset_ratio", vectors["initial_offset_ratio"])

	# A new VirtualJoystick is 0x0, and its rect is where touches register (the
	# stick is drawn at size * initial_offset_ratio), so give it a usable
	# default: a square 2.5x the stick's diameter.
	var stick_size: float = joystick.get("joystick_size")
	joystick.size = vectors.get("size", Vector2(stick_size, stick_size) * 2.5)
	if not anchor_preset.is_empty():
		joystick.set_anchors_and_offsets_preset(_ANCHOR_PRESETS[anchor_preset], Control.PRESET_MODE_KEEP_SIZE, margin)
	elif vectors.has("position"):
		joystick.position = vectors["position"]

	if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)):
		warnings.append("VirtualJoystick only reacts to touch input. To try it with a mouse (desktop, simulate_mouse_click), enable input_devices/pointing/emulate_touch_from_mouse.")

	add_child_with_undo(parent, joystick, root, "MCP: Add VirtualJoystick")

	var info := {
		"node_path": str(root.get_path_to(joystick)),
		"type": "VirtualJoystick",
		"name": str(joystick.name),
		"mode": mode_name,
		"visibility": visibility_name,
		"actions": actions,
		"joystick_size": joystick.get("joystick_size"),
		"tip_size": joystick.get("tip_size"),
		"deadzone_ratio": joystick.get("deadzone_ratio"),
		"clampzone_ratio": joystick.get("clampzone_ratio"),
		"size": {"x": joystick.size.x, "y": joystick.size.y},
	}
	if anchor_preset.is_empty():
		info["position"] = {"x": joystick.position.x, "y": joystick.position.y}
	else:
		# Position is relative to the anchors, which the parent resolves at
		# layout time, so report what is actually stored.
		info["anchor_preset"] = anchor_preset
		info["offsets"] = {
			"left": joystick.offset_left, "top": joystick.offset_top,
			"right": joystick.offset_right, "bottom": joystick.offset_bottom,
		}
	if not warnings.is_empty():
		info["warnings"] = warnings
	return success(info)


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
