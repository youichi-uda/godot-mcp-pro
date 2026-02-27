@tool
extends RefCounted

## Parse a string value into the appropriate Godot type
static func parse_value(value: Variant, target_type: int = TYPE_NIL) -> Variant:
	if value == null:
		return null

	# If already the correct type, return as-is
	if target_type == TYPE_NIL:
		return _auto_parse(value)

	match target_type:
		TYPE_BOOL:
			if value is bool: return value
			if value is String: return value.to_lower() in ["true", "1", "yes"]
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return str(value)
		TYPE_VECTOR2:
			return _parse_vector2(value)
		TYPE_VECTOR2I:
			return _parse_vector2i(value)
		TYPE_VECTOR3:
			return _parse_vector3(value)
		TYPE_VECTOR3I:
			return _parse_vector3i(value)
		TYPE_RECT2:
			return _parse_rect2(value)
		TYPE_COLOR:
			return _parse_color(value)
		TYPE_NODE_PATH:
			return NodePath(str(value))
		TYPE_ARRAY:
			if value is Array: return value
			return [value]
		TYPE_DICTIONARY:
			if value is Dictionary: return value
			return {}
		_:
			return value


static func _auto_parse(value: Variant) -> Variant:
	if not value is String:
		return value

	var s: String = value

	# Boolean
	if s == "true": return true
	if s == "false": return false

	# Integer
	if s.is_valid_int(): return s.to_int()

	# Float
	if s.is_valid_float(): return s.to_float()

	# Vector2: "Vector2(x, y)" or "(x, y)" or "x, y"
	if s.begins_with("Vector2(") or s.begins_with("Vector2i("):
		return _parse_vector2(s)

	# Vector3
	if s.begins_with("Vector3(") or s.begins_with("Vector3i("):
		return _parse_vector3(s)

	# Color
	if s.begins_with("Color(") or s.begins_with("#"):
		return _parse_color(s)

	# Rect2
	if s.begins_with("Rect2("):
		return _parse_rect2(s)

	return s


static func _extract_numbers(s: String) -> PackedFloat64Array:
	# Remove type prefix and parentheses
	var cleaned := s
	for prefix in ["Vector3i(", "Vector3(", "Vector2i(", "Vector2(", "Rect2(", "Color(", "("]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length())
			break
	cleaned = cleaned.trim_suffix(")")
	cleaned = cleaned.strip_edges()

	var parts := cleaned.split(",")
	var numbers: PackedFloat64Array = []
	for part in parts:
		numbers.append(part.strip_edges().to_float())
	return numbers


static func _parse_vector2(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Dictionary:
		return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
	var nums := _extract_numbers(str(value))
	if nums.size() >= 2:
		return Vector2(nums[0], nums[1])
	return Vector2.ZERO


static func _parse_vector2i(value: Variant) -> Vector2i:
	var v := _parse_vector2(value)
	return Vector2i(int(v.x), int(v.y))


static func _parse_vector3(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0)))
	var nums := _extract_numbers(str(value))
	if nums.size() >= 3:
		return Vector3(nums[0], nums[1], nums[2])
	return Vector3.ZERO


static func _parse_vector3i(value: Variant) -> Vector3i:
	var v := _parse_vector3(value)
	return Vector3i(int(v.x), int(v.y), int(v.z))


static func _parse_rect2(value: Variant) -> Rect2:
	if value is Rect2: return value
	if value is Dictionary:
		return Rect2(
			float(value.get("x", 0)), float(value.get("y", 0)),
			float(value.get("w", value.get("width", 0))),
			float(value.get("h", value.get("height", 0)))
		)
	var nums := _extract_numbers(str(value))
	if nums.size() >= 4:
		return Rect2(nums[0], nums[1], nums[2], nums[3])
	return Rect2()


static func _parse_color(value: Variant) -> Color:
	if value is Color: return value
	var s := str(value)
	if s.begins_with("#"):
		return Color.html(s)
	if s.begins_with("Color("):
		var nums := _extract_numbers(s)
		match nums.size():
			3: return Color(nums[0], nums[1], nums[2])
			4: return Color(nums[0], nums[1], nums[2], nums[3])
	# Try named color
	if Color.html_is_valid(s):
		return Color.html(s)
	return Color.WHITE


## Serialize a Variant to JSON-safe representation
static func serialize_value(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_VECTOR2:
			var v: Vector2 = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR2I:
			var v: Vector2i = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR3:
			var v: Vector3 = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_VECTOR3I:
			var v: Vector3i = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_RECT2:
			var r: Rect2 = value
			return {"x": r.position.x, "y": r.position.y, "width": r.size.x, "height": r.size.y}
		TYPE_COLOR:
			var c: Color = value
			return {"r": c.r, "g": c.g, "b": c.b, "a": c.a, "html": "#" + c.to_html()}
		TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			if value is Resource:
				var res: Resource = value
				return {"type": res.get_class(), "path": res.resource_path}
			return str(value)
		TYPE_ARRAY:
			var arr: Array = value
			var result: Array = []
			for item in arr:
				result.append(serialize_value(item))
			return result
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var result: Dictionary = {}
			for key in dict:
				result[str(key)] = serialize_value(dict[key])
			return result
		_:
			return value
