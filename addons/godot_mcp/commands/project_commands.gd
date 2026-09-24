@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_project_info": _get_project_info,
		"get_filesystem_tree": _get_filesystem_tree,
		"search_files": _search_files,
		"search_in_files": _search_in_files,
		"get_project_settings": _get_project_settings,
		"set_project_setting": _set_project_setting,
		"uid_to_project_path": _uid_to_project_path,
		"project_path_to_uid": _project_path_to_uid,
		"add_autoload": _add_autoload,
		"remove_autoload": _remove_autoload,
	}


func _get_project_info(params: Dictionary) -> Dictionary:
	var info := {}
	info["project_name"] = ProjectSettings.get_setting("application/config/name", "")
	info["godot_version"] = Engine.get_version_info()
	info["project_path"] = ProjectSettings.globalize_path("res://")
	info["main_scene"] = ProjectSettings.get_setting("application/run/main_scene", "")

	# Viewport settings
	info["viewport_width"] = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	info["viewport_height"] = ProjectSettings.get_setting("display/window/size/viewport_height", 0)
	info["window_width"] = ProjectSettings.get_setting("display/window/size/window_width_override", 0)
	info["window_height"] = ProjectSettings.get_setting("display/window/size/window_height_override", 0)

	# Rendering
	info["renderer"] = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")

	# Autoloads
	var autoloads := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("autoload/"):
			autoloads[name.substr(9)] = ProjectSettings.get_setting(name)
	info["autoloads"] = autoloads

	return success(info)


func _get_filesystem_tree(params: Dictionary) -> Dictionary:
	var path: String = optional_string(params, "path", "res://")
	var filter: String = optional_string(params, "filter", "")  # e.g. "*.gd", "*.tscn"
	var max_depth: int = optional_int(params, "max_depth", 10)

	var tree := _scan_directory(path, filter, max_depth, 0)
	return success({"tree": tree})


func _scan_directory(path: String, filter: String, max_depth: int, depth: int) -> Dictionary:
	var result := {"name": path.get_file(), "path": path, "type": "directory"}

	if depth >= max_depth:
		return result

	var dir := DirAccess.open(path)
	if dir == null:
		return result

	var children: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			children.append(_scan_directory(full_path, filter, max_depth, depth + 1))
		else:
			if filter.is_empty() or file_name.match(filter):
				children.append({
					"name": file_name,
					"path": full_path,
					"type": "file",
				})

		file_name = dir.get_next()

	dir.list_dir_end()

	if not children.is_empty():
		result["children"] = children

	return result


func _search_files(params: Dictionary) -> Dictionary:
	var result := require_string(params, "query")
	if result[1] != null:
		return result[1]
	var query: String = result[0]

	var path: String = optional_string(params, "path", "res://")
	var file_type: String = optional_string(params, "file_type", "")  # e.g. "gd", "tscn"
	var max_results: int = optional_int(params, "max_results", 50)

	var matches: Array = []
	_search_recursive(path, query, file_type, matches, max_results)

	return success({"matches": matches, "count": matches.size()})


func _search_recursive(path: String, query: String, file_type: String, matches: Array, max_results: int) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty() and matches.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			_search_recursive(full_path, query, file_type, matches, max_results)
		else:
			# Check file type filter
			if not file_type.is_empty() and file_name.get_extension() != file_type:
				file_name = dir.get_next()
				continue

			# Fuzzy match: check if query is contained in filename (case insensitive)
			if file_name.to_lower().contains(query.to_lower()):
				matches.append(full_path)
			# Also check glob pattern
			elif file_name.match(query):
				matches.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


func _get_project_settings(params: Dictionary) -> Dictionary:
	var section: String = optional_string(params, "section", "")
	var key: String = optional_string(params, "key", "")

	# If specific key requested
	if not key.is_empty():
		if ProjectSettings.has_setting(key):
			var value = ProjectSettings.get_setting(key)
			return success({"key": key, "value": str(value), "type": typeof(value)})
		else:
			return error_not_found("Setting '%s'" % key)

	var non_default_only: bool = optional_bool(params, "non_default_only", false)

	# If section requested, return all settings in that section
	var settings := {}
	var defaults := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop["name"]
		if section.is_empty() or name.begins_with(section):
			if non_default_only:
				if not ProjectSettings.has_setting(name):
					continue  # "ProjectSettings" category entry, "script", ...
				var state := _setting_default_state(name)
				if not state["differs"]:
					continue
				defaults[name] = state["default"]
			settings[name] = str(ProjectSettings.get_setting(name))

	var payload := {"settings": settings, "count": settings.size()}
	if non_default_only:
		payload["defaults"] = defaults
		payload["note"] = "Settings whose value differs from the engine default (property_get_revert), including custom keys that have no default (default null). Reflects the editor's in-memory state, which may include changes not yet saved to project.godot."
	return success(payload)


## Whether a project setting differs from its engine default.
##
## ProjectSettings.get_changed_settings() (Godot 4.6+) is NOT this: measured on
## 4.6.2 and 4.7.2 it holds the keys touched since the last deferred
## settings_changed emission, which is cleared about once a frame — at startup
## it lists every registered setting, afterwards it is almost always empty. The
## default comes from property_get_revert(), which ProjectSettings implements
## on every supported version (4.5+). Custom keys have no default and revert to
## null, so they always count as differing.
func _setting_default_state(name: String) -> Dictionary:
	var current: Variant = ProjectSettings.get_setting(name)
	if not ProjectSettings.property_can_revert(name):
		return {"differs": true, "default": null}
	var default_value: Variant = ProjectSettings.property_get_revert(name)
	var differs: bool
	if (current is int or current is float) and (default_value is int or default_value is float):
		# project.godot may store 1 for a float setting whose default is 1.0.
		differs = not is_equal_approx(float(current), float(default_value))
	elif typeof(current) != typeof(default_value):
		# == between unrelated Variant types raises; different types differ.
		differs = true
	elif current is Array or current is Dictionary:
		# Input actions hold InputEvent objects, which == compares by identity:
		# compare the serialized form instead.
		differs = var_to_str(current) != var_to_str(default_value)
	else:
		differs = current != default_value
	return {"differs": differs, "default": str(default_value) if default_value != null else null}


func _set_project_setting(params: Dictionary) -> Dictionary:
	var result := require_string(params, "key")
	if result[1] != null:
		return result[1]
	var key: String = result[0]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")

	var value = params["value"]
	var type_hint: String = optional_string(params, "type", "")

	# editor_plugins/enabled must stay a PackedStringArray whose entries Godot
	# also mirrors elsewhere; writing it directly can disable every plugin in
	# the project (including this one) on the next editor start.
	if key == "editor_plugins/enabled":
		return error_invalid_params(
			"Refusing to write 'editor_plugins/enabled' directly — a malformed value disables every plugin in the project. Use EditorInterface.set_plugin_enabled(name, enabled) via execute_editor_script instead."
		)

	var target_type := TYPE_NIL
	if not type_hint.is_empty():
		if not _SETTING_TYPE_NAMES.has(type_hint):
			return error_invalid_params(
				"Unknown type '%s'. Supported: %s" % [type_hint, ", ".join(_SETTING_TYPE_NAMES.keys())]
			)
		target_type = _SETTING_TYPE_NAMES[type_hint]
	elif ProjectSettings.has_setting(key):
		# Preserve the declared type of an existing setting rather than guessing
		# from the incoming string's shape.
		target_type = typeof(ProjectSettings.get_setting(key))

	var converted := _coerce_setting_value(value, target_type)
	if converted[1] != "":
		return error_invalid_params(converted[1])
	value = converted[0]

	ProjectSettings.set_setting(key, value)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	var stored = ProjectSettings.get_setting(key)
	return success({
		"key": key,
		"value": str(stored),
		"type": typeof(stored),
		"type_name": type_string(typeof(stored)),
		"saved": true,
	})


const _SETTING_TYPE_NAMES: Dictionary = {
	"string": TYPE_STRING,
	"string_name": TYPE_STRING_NAME,
	"int": TYPE_INT,
	"float": TYPE_FLOAT,
	"bool": TYPE_BOOL,
	"vector2": TYPE_VECTOR2,
	"vector2i": TYPE_VECTOR2I,
	"vector3": TYPE_VECTOR3,
	"vector3i": TYPE_VECTOR3I,
	"rect2": TYPE_RECT2,
	"rect2i": TYPE_RECT2I,
	"color": TYPE_COLOR,
	"array": TYPE_ARRAY,
	"dictionary": TYPE_DICTIONARY,
	"packed_string_array": TYPE_PACKED_STRING_ARRAY,
	"packed_int32_array": TYPE_PACKED_INT32_ARRAY,
	"packed_int64_array": TYPE_PACKED_INT64_ARRAY,
	"packed_float32_array": TYPE_PACKED_FLOAT32_ARRAY,
	"packed_float64_array": TYPE_PACKED_FLOAT64_ARRAY,
	"packed_vector2_array": TYPE_PACKED_VECTOR2_ARRAY,
	"packed_color_array": TYPE_PACKED_COLOR_ARRAY,
}


## Converts `value` to `target_type`.
## Returns [converted_value, error_message]; error_message is "" on success.
## TYPE_NIL as target means "store as-is" (new key, no hint given).
func _coerce_setting_value(value: Variant, target_type: int) -> Array:
	if target_type == TYPE_NIL:
		return [value, ""]

	if typeof(value) == target_type:
		return [value, ""]

	# type_convert("false", TYPE_BOOL) yields true — every non-empty string is
	# truthy — so booleans are parsed explicitly rather than cast.
	if target_type == TYPE_BOOL and value is String:
		match (value as String).to_lower():
			"true":
				return [true, ""]
			"false":
				return [false, ""]
			_:
				return [null, "Cannot represent '%s' as bool. Use true or false." % value]

	# Constructor-style strings ("Vector2(1, 2)", "Color(1,0,0,1)") stay
	# supported, but only in that literal shape. Expression.execute() will
	# happily evaluate anything, including calls, which would both run code
	# from a setting value and slip past the range checks below.
	if value is String and _is_constructor_literal(value, target_type):
		# Route the components through the array path rather than trusting the
		# constructor: it would happily narrow Vector2i(1.5, 0) to (1, 0) and
		# widen Vector2(1e39, 0) to infinity, which the array path rejects.
		var components := _constructor_components(value, target_type)
		return _build_packed_array(components, target_type)

	# Arrays coming over JSON must be rebuilt into the packed/typed target.
	if value is Array:
		var packed_result := _build_packed_array(value, target_type)
		if packed_result[1] != "":
			return [null, packed_result[1]]
		return [packed_result[0], ""]

	if not _is_safe_conversion(value, target_type):
		return [null, "Cannot represent value %s (%s) as %s. Pass a value of the correct shape, or an explicit 'type' parameter." % [
			str(value), type_string(typeof(value)), type_string(target_type)
		]]

	return [type_convert(value, target_type), ""]


## type_convert() never fails — it returns a zero/empty value for nonsense input.
## This rejects the conversions that would silently lose the caller's data.
func _is_safe_conversion(value: Variant, target_type: int) -> bool:
	match target_type:
		TYPE_INT:
			if value is String:
				return _string_is_exact_int(value)
			if value is float:
				# JSON has no integer type, so 1080.0 must be accepted — but
				# 1.5 would be silently truncated to 1, which is data loss.
				# Exact comparison: is_equal_approx() scales its tolerance with
				# magnitude, so it would call 100000.5 integral.
				return value == floorf(value) and _fits_int64(value)
			return value is bool
		TYPE_FLOAT:
			if value is String:
				# is_valid_float() only checks syntax; "1e999" parses to
				# infinity, which is not the number the caller wrote.
				return (value as String).is_valid_float() and is_finite((value as String).to_float())
			if value is int:
				# Beyond 2^53 a float cannot hold every integer, so the stored
				# value would differ from the one asked for.
				return int(float(value)) == value
			return value is bool
		TYPE_BOOL:
			# Strings are handled before this point, in _coerce_setting_value.
			# Only 0 and 1 map to a bool without discarding information — 2 and
			# 0.5 would both silently become true.
			return (value is int or value is float) and (value == 0 or value == 1)
		TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY, TYPE_DICTIONARY:
			return false
		_:
			# Vector/Rect/Color and packed arrays cannot be built from a scalar.
			return false


func _build_packed_array(items: Array, target_type: int) -> Array:
	match target_type:
		TYPE_ARRAY:
			return [items, ""]
		TYPE_PACKED_STRING_ARRAY:
			var out := PackedStringArray()
			for item: Variant in items:
				out.append(str(item))
			return [out, ""]
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			# Collect into an untyped Array: the packed constructors accept an
			# Array but refuse a differently-sized packed array
			# ("Cannot convert argument 1 from PackedInt64Array to Array").
			var ints: Array = []
			for item: Variant in items:
				if not (item is int or item is float):
					return [null, "Packed int array requires numeric entries, got %s" % type_string(typeof(item))]
				if not _is_integral(item):
					return [null, "Packed int array cannot hold the fractional value %s without losing data" % str(item)]
				# 1e30 is "integral" but has no int64 representation, and int()
				# on it is undefined rather than an error.
				if item is float and not _fits_int64(item):
					return [null, "%s is outside the range an integer array can hold" % str(item)]
				var as_int := int(item)
				if target_type == TYPE_PACKED_INT32_ARRAY and (as_int < -2147483648 or as_int > 2147483647):
					return [null, "%s exceeds the range of a 32-bit int; use packed_int64_array" % str(item)]
				ints.append(as_int)
			if target_type == TYPE_PACKED_INT32_ARRAY:
				return [PackedInt32Array(ints), ""]
			return [PackedInt64Array(ints), ""]
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var floats: Array = []
			for item: Variant in items:
				if not (item is int or item is float):
					return [null, "Packed float array requires numeric entries, got %s" % type_string(typeof(item))]
				# Rounding to fewer significant digits is inherent to float32,
				# but overflowing to infinity discards the value entirely.
				if target_type == TYPE_PACKED_FLOAT32_ARRAY and is_finite(float(item)) and absf(float(item)) > 3.4028235e38:
					return [null, "%s is outside float32 range and would be stored as infinity" % str(item)]
				floats.append(float(item))
			if target_type == TYPE_PACKED_FLOAT32_ARRAY:
				return [PackedFloat32Array(floats), ""]
			return [PackedFloat64Array(floats), ""]
		TYPE_VECTOR2, TYPE_VECTOR2I:
			if items.size() != 2:
				return [null, "%s requires exactly 2 numbers, got %d" % [type_string(target_type), items.size()]]
			if not _all_numeric(items):
				return [null, "%s requires numeric entries" % type_string(target_type)]
			if target_type == TYPE_VECTOR2I:
				var guard := _guard_int32_components(items, "Vector2i")
				if guard != "":
					return [null, guard]
			if target_type == TYPE_VECTOR2I:
				return [Vector2i(int(items[0]), int(items[1])), ""]
			var v2_guard := _guard_float32_components(items, "Vector2")
			if v2_guard != "":
				return [null, v2_guard]
			return [Vector2(float(items[0]), float(items[1])), ""]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			if items.size() != 3:
				return [null, "%s requires exactly 3 numbers, got %d" % [type_string(target_type), items.size()]]
			if not _all_numeric(items):
				return [null, "%s requires numeric entries" % type_string(target_type)]
			if target_type == TYPE_VECTOR3I:
				var guard := _guard_int32_components(items, "Vector3i")
				if guard != "":
					return [null, guard]
			if target_type == TYPE_VECTOR3I:
				return [Vector3i(int(items[0]), int(items[1]), int(items[2])), ""]
			var v3_guard := _guard_float32_components(items, "Vector3")
			if v3_guard != "":
				return [null, v3_guard]
			return [Vector3(float(items[0]), float(items[1]), float(items[2])), ""]
		TYPE_COLOR:
			if items.size() < 3 or items.size() > 4:
				return [null, "Color requires 3 or 4 numbers, got %d" % items.size()]
			if not _all_numeric(items):
				return [null, "Color requires numeric entries"]
			var color_guard := _guard_float32_components(items, "Color")
			if color_guard != "":
				return [null, color_guard]
			var a := 1.0
			if items.size() == 4:
				a = float(items[3])
			return [Color(float(items[0]), float(items[1]), float(items[2]), a), ""]
		TYPE_RECT2, TYPE_RECT2I:
			if items.size() != 4:
				return [null, "%s requires exactly 4 numbers, got %d" % [type_string(target_type), items.size()]]
			if not _all_numeric(items):
				return [null, "%s requires numeric entries" % type_string(target_type)]
			if target_type == TYPE_RECT2I:
				var guard := _guard_int32_components(items, "Rect2i")
				if guard != "":
					return [null, guard]
			if target_type == TYPE_RECT2I:
				return [Rect2i(int(items[0]), int(items[1]), int(items[2]), int(items[3])), ""]
			var r2_guard := _guard_float32_components(items, "Rect2")
			if r2_guard != "":
				return [null, r2_guard]
			return [Rect2(float(items[0]), float(items[1]), float(items[2]), float(items[3])), ""]
		TYPE_PACKED_VECTOR2_ARRAY:
			var vectors := PackedVector2Array()
			for item: Variant in items:
				if not (item is Array) or (item as Array).size() != 2 or not _all_numeric(item):
					return [null, "PackedVector2Array requires entries shaped [x, y], e.g. [[0, 0], [1, 2]]"]
				var pv_guard := _guard_float32_components(item, "PackedVector2Array")
				if pv_guard != "":
					return [null, pv_guard]
				vectors.append(Vector2(float(item[0]), float(item[1])))
			return [vectors, ""]
		TYPE_PACKED_COLOR_ARRAY:
			var colors := PackedColorArray()
			for item: Variant in items:
				if not (item is Array) or not _all_numeric(item):
					return [null, "PackedColorArray requires entries shaped [r, g, b] or [r, g, b, a]"]
				var entry: Array = item
				if entry.size() < 3 or entry.size() > 4:
					return [null, "PackedColorArray entries need 3 or 4 numbers, got %d" % entry.size()]
				var entry_guard := _guard_float32_components(entry, "PackedColorArray")
				if entry_guard != "":
					return [null, entry_guard]
				var alpha := 1.0
				if entry.size() == 4:
					alpha = float(entry[3])
				colors.append(Color(float(entry[0]), float(entry[1]), float(entry[2]), alpha))
			return [colors, ""]
		_:
			return [null, "Cannot build %s from an array" % type_string(target_type)]


## Whole-number check for values headed into an integer type. Exact, because
## is_equal_approx() scales its tolerance with magnitude.
func _is_integral(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return value == floorf(value)
	return false


## Matches only "TypeName(number, number, ...)" for the type being written.
## Anything else — a call, an operator, a property lookup — is refused rather
## than handed to Expression, which evaluates whatever it is given.
func _is_constructor_literal(text: String, target_type: int) -> bool:
	var expected := type_string(target_type)
	var trimmed := text.strip_edges()
	if not trimmed.begins_with(expected + "(") or not trimmed.ends_with(")"):
		return false
	var inner := trimmed.substr(expected.length() + 1, trimmed.length() - expected.length() - 2)
	if inner.strip_edges().is_empty():
		return false
	for part: String in inner.split(","):
		var token := part.strip_edges()
		if token.is_empty() or not (token.is_valid_float() or token.is_valid_int()):
			return false
		# Judge an oversized exponent from the text: to_float() logs an engine
		# warning on its way to returning infinity, and a rejected input should
		# not leave anything in the user's Output panel. Doubles top out at
		# ~1e308.
		if not _exponent_is_representable(token):
			return false
	return true


## True unless the literal carries an exponent a double cannot represent.
## Checked as text so to_float() is never handed something it will warn about.
func _exponent_is_representable(token: String) -> bool:
	var lowered := token.to_lower()
	var e_index := lowered.find("e")
	if e_index == -1:
		return true
	var exponent := lowered.substr(e_index + 1).lstrip("+")
	var negative := exponent.begins_with("-")
	var digits := exponent.lstrip("-").lstrip("0")
	if digits.is_empty():
		return true
	if digits.length() > 3:
		return false
	# Godot's parser warns on an out-of-range exponent in either direction, so
	# both are bounded. Doubles run out at roughly 1e308 / 1e-324.
	return digits.to_int() <= (324 if negative else 308)


## Splits "Vector2(3, 4)" into [3.0, 4.0]. Only called after
## _is_constructor_literal has confirmed every component is a plain number.
func _constructor_components(text: String, target_type: int) -> Array:
	var expected := type_string(target_type)
	var trimmed := text.strip_edges()
	var inner := trimmed.substr(expected.length() + 1, trimmed.length() - expected.length() - 2)
	var out: Array = []
	for part: String in inner.split(","):
		var token := part.strip_edges()
		# Keep integer literals as ints. Routing them through to_float() would
		# lose precision past 2^53 before the int guards ever see them.
		if token.is_valid_int() and _string_is_exact_int(token):
			out.append(token.to_int())
		else:
			out.append(token.to_float())
	return out


## Godot stores Color components and, on a standard build, Vector/Rect
## components as 32-bit floats. A finite value beyond that range becomes
## infinity, which is not precision loss but total loss.
const _FLOAT32_MAX := 3.4028235e38

func _guard_float32_components(items: Array, type_name: String) -> String:
	for item: Variant in items:
		var as_float := float(item)
		if not is_finite(as_float):
			return "%s cannot hold %s" % [type_name, str(item)]
		if absf(as_float) > _FLOAT32_MAX:
			return "%s components are 32-bit floats; %s would be stored as infinity" % [type_name, str(item)]
	return ""


## is_valid_int() accepts a digit string of any length, and to_int() then
## saturates at int64's limits — so "99999999999999999999" would be stored as
## 9223372036854775807 while the tool reported success. Round-tripping the
## parsed value catches exactly that.
func _string_is_exact_int(text: String) -> bool:
	if not text.is_valid_int():
		return false
	var normalized := text.strip_edges().lstrip("+")
	# Reject on digit count before parsing: to_int() pushes a Godot error for
	# an oversized literal, which would show up in the user's Output panel for
	# what is really just a rejected input. int64 max has 19 digits.
	var negative := normalized.begins_with("-")
	var magnitude := normalized.lstrip("-").lstrip("0")
	if magnitude.length() > 19:
		return false
	# 19 digits can still exceed int64; compare against the limit as text
	# before parsing, since to_int() logs an engine error on overflow.
	if magnitude.length() == 19:
		var limit := "9223372036854775808" if negative else "9223372036854775807"
		if magnitude > limit:
			return false
	var parsed := normalized.to_int()
	if str(parsed) == normalized:
		return true
	# Accept insignificant leading zeros ("007"), but nothing that changes value.
	var sign_prefix := ""
	var digits := normalized
	if digits.begins_with("-"):
		sign_prefix = "-"
		digits = digits.substr(1)
	digits = digits.lstrip("0")
	if digits.is_empty():
		digits = "0"
	return str(parsed) == sign_prefix + digits or (parsed == 0 and digits == "0")


## True when a float has an exact int64 counterpart. NaN and infinities are
## "integral" by a floorf() test but have no integer representation at all.
func _fits_int64(value: float) -> bool:
	if not is_finite(value):
		return false
	# 9223372036854775807.0 rounds up to 2^63, which int64 cannot hold, so the
	# upper bound has to be exclusive against 2^63 itself.
	return value >= -9223372036854775808.0 and value < 9223372036854775808.0


## Vector2i/Vector3i/Rect2i store 32-bit components, so an in-range-looking
## integer can be narrowed silently by the constructor. Returns "" when the
## items are safe, or the reason they are not.
func _guard_int32_components(items: Array, type_name: String) -> String:
	for item: Variant in items:
		if not _is_integral(item):
			return "%s cannot hold the fractional value %s without losing data" % [type_name, str(item)]
		if item is float and not _fits_int64(item):
			return "%s cannot hold %s" % [type_name, str(item)]
		var as_int := int(item)
		if as_int < -2147483648 or as_int > 2147483647:
			return "%s components are 32-bit; %s would be narrowed" % [type_name, str(item)]
	return ""


func _all_integral(items: Array) -> bool:
	for item: Variant in items:
		if not _is_integral(item):
			return false
	return true


func _all_numeric(items: Array) -> bool:
	for item: Variant in items:
		if not (item is int or item is float):
			return false
	return true


func _uid_to_project_path(params: Dictionary) -> Dictionary:
	var result := require_string(params, "uid")
	if result[1] != null:
		return result[1]
	var uid_str: String = result[0]

	# Use ResourceUID to convert
	var uid := ResourceUID.text_to_id(uid_str)
	if uid == ResourceUID.INVALID_ID:
		return error_invalid_params("Invalid UID format: %s" % uid_str)

	if not ResourceUID.has_id(uid):
		return error_not_found("UID '%s'" % uid_str)

	var path := ResourceUID.get_id_path(uid)
	return success({"uid": uid_str, "path": path})


func _project_path_to_uid(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not ResourceLoader.exists(path):
		return error_not_found("Resource at '%s'" % path)

	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return error(-32001, "No UID assigned to '%s'" % path)

	var uid_str := ResourceUID.id_to_text(uid)
	return success({"path": path, "uid": uid_str})


const _TEXT_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres", "cfg", "godot", "gdshader", "md", "txt", "json"]

func _search_in_files(params: Dictionary) -> Dictionary:
	var result := require_string(params, "query")
	if result[1] != null:
		return result[1]
	var query: String = result[0]

	var path: String = optional_string(params, "path", "res://")
	var max_results: int = optional_int(params, "max_results", 50)
	var use_regex: bool = optional_bool(params, "regex", false)
	var file_type: String = optional_string(params, "file_type", "")
	var include_addons: bool = optional_bool(params, "include_addons", false)

	var regex: RegEx = null
	if use_regex:
		regex = RegEx.new()
		var err := regex.compile(query)
		if err != OK:
			return error_invalid_params("Invalid regex pattern: %s" % error_string(err))

	var matches: Array = []
	_search_in_files_recursive(path, query, regex, file_type, matches, max_results, include_addons)

	return success({
		"matches": matches,
		"count": matches.size(),
		"query": query,
		"include_addons": include_addons,
	})


func _search_in_files_recursive(path: String, query: String, regex: RegEx, file_type: String, matches: Array, max_results: int, include_addons: bool) -> void:
	if matches.size() >= max_results:
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty() and matches.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			# .godot is engine cache and never worth searching; addons is skipped
			# by default but reachable via include_addons (or an explicit path).
			var skip_dir := file_name == ".godot" or (file_name == "addons" and not include_addons)
			if not skip_dir:
				_search_in_files_recursive(full_path, query, regex, file_type, matches, max_results, include_addons)
		else:
			var ext := file_name.get_extension()
			# Filter by file type if specified, otherwise use text extensions
			if not file_type.is_empty():
				if ext != file_type:
					file_name = dir.get_next()
					continue
			elif ext not in _TEXT_EXTENSIONS:
				file_name = dir.get_next()
				continue

			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content := file.get_as_text()
				file.close()
				var lines := content.split("\n")
				for i in range(lines.size()):
					if matches.size() >= max_results:
						break
					var line: String = lines[i]
					var matched := false
					if regex != null:
						matched = regex.search(line) != null
					else:
						matched = line.contains(query)
					if matched:
						matches.append({
							"file": full_path,
							"line": i + 1,
							"text": line.strip_edges(),
						})

		file_name = dir.get_next()

	dir.list_dir_end()


func _add_autoload(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var autoload_name: String = result[0]

	var result2 := require_string(params, "path")
	if result2[1] != null:
		return result2[1]
	var autoload_path: String = result2[0]

	if not FileAccess.file_exists(autoload_path):
		return error_not_found("File '%s'" % autoload_path)

	# Check if already exists
	var setting_key := "autoload/" + autoload_name
	if ProjectSettings.has_setting(setting_key):
		return error(-32000, "Autoload '%s' already exists" % autoload_name, {
			"current_value": str(ProjectSettings.get_setting(setting_key)),
			"suggestion": "Use remove_autoload first to replace it",
		})

	# Autoload format: "*res://path.gd" (the * prefix means it's a singleton)
	ProjectSettings.set_setting(setting_key, "*" + autoload_path)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"name": autoload_name,
		"path": autoload_path,
		"added": true,
	})


func _remove_autoload(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var autoload_name: String = result[0]

	var setting_key := "autoload/" + autoload_name
	if not ProjectSettings.has_setting(setting_key):
		return error_not_found("Autoload '%s'" % autoload_name)

	var old_value: String = str(ProjectSettings.get_setting(setting_key))
	ProjectSettings.clear(setting_key)
	var err := ProjectSettings.save()
	if err != OK:
		return error_internal("Failed to save project settings: %s" % error_string(err))

	return success({
		"name": autoload_name,
		"old_path": old_value,
		"removed": true,
	})
