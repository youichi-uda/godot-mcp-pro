@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")


func get_commands() -> Dictionary:
	return {
		"setup_collision": _setup_collision,
		"set_physics_layers": _set_physics_layers,
		"get_physics_layers": _get_physics_layers,
		"add_raycast": _add_raycast,
		"setup_physics_body": _setup_physics_body,
		"get_collision_info": _get_collision_info,
	}


## Determine if a node (or its ancestors) lives in a 2D or 3D context.
## Returns "2d", "3d", or "" if undetermined.
func _detect_dimension(node: Node) -> String:
	if node is Node2D or node is Control:
		return "2d"
	if node is Node3D:
		return "3d"
	# Walk up the tree
	var parent := node.get_parent()
	while parent != null:
		if parent is Node2D or parent is Control:
			return "2d"
		if parent is Node3D:
			return "3d"
		parent = parent.get_parent()
	return ""


func _setup_collision(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "shape")
	if result2[1] != null:
		return result2[1]
	var shape_name: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var dim := _detect_dimension(node)
	if dim.is_empty():
		# Allow explicit override
		dim = optional_string(params, "dimension", "2d")

	# Validate parent can have collision children
	var valid_parents_2d := ["PhysicsBody2D", "Area2D", "StaticBody2D", "CharacterBody2D", "RigidBody2D", "AnimatableBody2D"]
	var valid_parents_3d := ["PhysicsBody3D", "Area3D", "StaticBody3D", "CharacterBody3D", "RigidBody3D", "AnimatableBody3D"]

	var is_valid_parent := false
	if dim == "2d":
		for vp: String in valid_parents_2d:
			if node.is_class(vp):
				is_valid_parent = true
				break
	else:
		for vp: String in valid_parents_3d:
			if node.is_class(vp):
				is_valid_parent = true
				break

	if not is_valid_parent:
		return error_invalid_params("Node '%s' (%s) is not a physics body or area. CollisionShape should be added to a PhysicsBody or Area node." % [node_path, node.get_class()])

	# Create shape resource
	var shape: Resource = null
	var child_name := "CollisionShape"

	if dim == "2d":
		match shape_name:
			"rectangle", "rect":
				shape = RectangleShape2D.new()
				var w: float = float(params.get("width", 32.0))
				var h: float = float(params.get("height", 32.0))
				shape.size = Vector2(w, h)
			"circle":
				shape = CircleShape2D.new()
				shape.radius = float(params.get("radius", 16.0))
			"capsule":
				shape = CapsuleShape2D.new()
				shape.radius = float(params.get("radius", 16.0))
				shape.height = float(params.get("height", 40.0))
			"segment":
				shape = SegmentShape2D.new()
				shape.a = Vector2(float(params.get("ax", 0.0)), float(params.get("ay", 0.0)))
				shape.b = Vector2(float(params.get("bx", 32.0)), float(params.get("by", 0.0)))
			"custom":
				# ConvexPolygonShape2D — expects "points" as array of [x,y] pairs
				shape = ConvexPolygonShape2D.new()
				var points_data: Array = params.get("points", [])
				var pool: PackedVector2Array = PackedVector2Array()
				for p: Variant in points_data:
					if p is Array and p.size() >= 2:
						pool.append(Vector2(float(p[0]), float(p[1])))
				if pool.size() >= 3:
					shape.points = pool
			_:
				return error_invalid_params("Unknown 2D shape: '%s'. Available: rectangle, circle, capsule, segment, custom" % shape_name)

		var collision_node := CollisionShape2D.new()
		collision_node.shape = shape
		collision_node.name = child_name

		var disabled: bool = optional_bool(params, "disabled", false)
		collision_node.disabled = disabled
		var one_way: bool = optional_bool(params, "one_way_collision", false)
		collision_node.one_way_collision = one_way

		var undo_redo := get_undo_redo()
		undo_redo.create_action("MCP: Add CollisionShape2D to %s" % node.name)
		undo_redo.add_do_method(node, "add_child", collision_node)
		undo_redo.add_do_method(collision_node, "set_owner", root)
		undo_redo.add_do_reference(collision_node)
		undo_redo.add_undo_method(node, "remove_child", collision_node)
		undo_redo.commit_action()

		return success({
			"node_path": str(root.get_path_to(collision_node)),
			"shape_type": shape.get_class(),
			"dimension": "2D",
		})

	else:
		# 3D shapes
		match shape_name:
			"box", "rectangle", "rect":
				shape = BoxShape3D.new()
				var sx: float = float(params.get("width", 1.0))
				var sy: float = float(params.get("height", 1.0))
				var sz: float = float(params.get("depth", 1.0))
				shape.size = Vector3(sx, sy, sz)
			"sphere", "circle":
				shape = SphereShape3D.new()
				shape.radius = float(params.get("radius", 0.5))
			"capsule":
				shape = CapsuleShape3D.new()
				shape.radius = float(params.get("radius", 0.5))
				shape.height = float(params.get("height", 2.0))
			"cylinder":
				shape = CylinderShape3D.new()
				shape.radius = float(params.get("radius", 0.5))
				shape.height = float(params.get("height", 2.0))
			"convex", "custom":
				shape = ConvexPolygonShape3D.new()
				var points_data: Array = params.get("points", [])
				var pool: PackedVector3Array = PackedVector3Array()
				for p: Variant in points_data:
					if p is Array and p.size() >= 3:
						pool.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
				if pool.size() >= 4:
					shape.points = pool
			_:
				return error_invalid_params("Unknown 3D shape: '%s'. Available: box, sphere, capsule, cylinder, convex" % shape_name)

		var collision_node := CollisionShape3D.new()
		collision_node.shape = shape
		collision_node.name = child_name

		var disabled: bool = optional_bool(params, "disabled", false)
		collision_node.disabled = disabled

		var undo_redo := get_undo_redo()
		undo_redo.create_action("MCP: Add CollisionShape3D to %s" % node.name)
		undo_redo.add_do_method(node, "add_child", collision_node)
		undo_redo.add_do_method(collision_node, "set_owner", root)
		undo_redo.add_do_reference(collision_node)
		undo_redo.add_undo_method(node, "remove_child", collision_node)
		undo_redo.commit_action()

		return success({
			"node_path": str(root.get_path_to(collision_node)),
			"shape_type": shape.get_class(),
			"dimension": "3D",
		})


func _get_layer_name(dim: String, layer_index: int) -> String:
	var setting_key := "layer_names/%s_physics/layer_%d" % [dim, layer_index]
	if ProjectSettings.has_setting(setting_key):
		var name_val: Variant = ProjectSettings.get_setting(setting_key)
		if name_val is String and not (name_val as String).is_empty():
			return name_val as String
	return ""


func _layer_bitmask_to_info(bitmask: int, dim: String) -> Array:
	var layers: Array = []
	for i in range(1, 33):
		if bitmask & (1 << (i - 1)):
			var layer_name := _get_layer_name(dim, i)
			var entry: Dictionary = {"layer": i}
			if not layer_name.is_empty():
				entry["name"] = layer_name
			layers.append(entry)
	return layers


func _set_physics_layers(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	# Check node has collision_layer/collision_mask properties
	if not "collision_layer" in node:
		return error_invalid_params("Node '%s' (%s) does not have collision_layer property" % [node_path, node.get_class()])

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set physics layers on %s" % node.name)

	var changes: Dictionary = {}

	if params.has("collision_layer"):
		var old_layer: int = node.get("collision_layer")
		var new_layer: int = _parse_layer_value(params["collision_layer"])
		undo_redo.add_do_property(node, "collision_layer", new_layer)
		undo_redo.add_undo_property(node, "collision_layer", old_layer)
		changes["collision_layer"] = new_layer

	if params.has("collision_mask"):
		var old_mask: int = node.get("collision_mask")
		var new_mask: int = _parse_layer_value(params["collision_mask"])
		undo_redo.add_do_property(node, "collision_mask", new_mask)
		undo_redo.add_undo_property(node, "collision_mask", old_mask)
		changes["collision_mask"] = new_mask

	if changes.is_empty():
		return error_invalid_params("Must provide collision_layer and/or collision_mask")

	undo_redo.commit_action()

	var dim := _detect_dimension(node)
	if dim.is_empty():
		dim = "2d"

	var result_data: Dictionary = {
		"node_path": str(root.get_path_to(node)),
	}
	if changes.has("collision_layer"):
		result_data["collision_layer"] = changes["collision_layer"]
		result_data["collision_layer_info"] = _layer_bitmask_to_info(changes["collision_layer"], dim)
	if changes.has("collision_mask"):
		result_data["collision_mask"] = changes["collision_mask"]
		result_data["collision_mask_info"] = _layer_bitmask_to_info(changes["collision_mask"], dim)

	return success(result_data)


## Parse layer value: can be an int bitmask, or an array of layer numbers [1, 3, 5]
func _parse_layer_value(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	if value is Array:
		var bitmask: int = 0
		for layer_num: Variant in value:
			var n: int = int(layer_num)
			if n >= 1 and n <= 32:
				bitmask |= (1 << (n - 1))
		return bitmask
	# Try parsing as int
	return int(value)


func _get_physics_layers(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not "collision_layer" in node:
		return error_invalid_params("Node '%s' (%s) does not have collision_layer property" % [node_path, node.get_class()])

	var layer: int = node.get("collision_layer")
	var mask: int = node.get("collision_mask")

	var dim := _detect_dimension(node)
	if dim.is_empty():
		dim = "2d"

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"collision_layer": layer,
		"collision_layer_info": _layer_bitmask_to_info(layer, dim),
		"collision_mask": mask,
		"collision_mask_info": _layer_bitmask_to_info(mask, dim),
	})


func _add_raycast(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var dim := _detect_dimension(node)
	if dim.is_empty():
		dim = optional_string(params, "dimension", "2d")

	var ray_name: String = optional_string(params, "name", "RayCast")
	var enabled: bool = optional_bool(params, "enabled", true)
	var collision_mask: int = optional_int(params, "collision_mask", 1)
	var collide_with_areas: bool = optional_bool(params, "collide_with_areas", false)
	var collide_with_bodies: bool = optional_bool(params, "collide_with_bodies", true)
	var hit_from_inside: bool = optional_bool(params, "hit_from_inside", false)

	var undo_redo := get_undo_redo()

	if dim == "2d":
		var ray := RayCast2D.new()
		ray.name = ray_name
		ray.enabled = enabled
		ray.collision_mask = collision_mask
		ray.collide_with_areas = collide_with_areas
		ray.collide_with_bodies = collide_with_bodies
		ray.hit_from_inside = hit_from_inside

		var tx: float = float(params.get("target_x", 0.0))
		var ty: float = float(params.get("target_y", 50.0))
		ray.target_position = Vector2(tx, ty)

		undo_redo.create_action("MCP: Add RayCast2D to %s" % node.name)
		undo_redo.add_do_method(node, "add_child", ray)
		undo_redo.add_do_method(ray, "set_owner", root)
		undo_redo.add_do_reference(ray)
		undo_redo.add_undo_method(node, "remove_child", ray)
		undo_redo.commit_action()

		return success({
			"node_path": str(root.get_path_to(ray)),
			"type": "RayCast2D",
			"target_position": "Vector2(%s, %s)" % [tx, ty],
			"collision_mask": collision_mask,
		})

	else:
		var ray := RayCast3D.new()
		ray.name = ray_name
		ray.enabled = enabled
		ray.collision_mask = collision_mask
		ray.collide_with_areas = collide_with_areas
		ray.collide_with_bodies = collide_with_bodies
		ray.hit_from_inside = hit_from_inside

		var tx: float = float(params.get("target_x", 0.0))
		var ty: float = float(params.get("target_y", -1.0))
		var tz: float = float(params.get("target_z", 0.0))
		ray.target_position = Vector3(tx, ty, tz)

		undo_redo.create_action("MCP: Add RayCast3D to %s" % node.name)
		undo_redo.add_do_method(node, "add_child", ray)
		undo_redo.add_do_method(ray, "set_owner", root)
		undo_redo.add_do_reference(ray)
		undo_redo.add_undo_method(node, "remove_child", ray)
		undo_redo.commit_action()

		return success({
			"node_path": str(root.get_path_to(ray)),
			"type": "RayCast3D",
			"target_position": "Vector3(%s, %s, %s)" % [tx, ty, tz],
			"collision_mask": collision_mask,
		})


func _setup_physics_body(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Setup physics body %s" % node.name)

	var applied: Dictionary = {}

	if node is CharacterBody2D or node is CharacterBody3D:
		# CharacterBody properties
		if params.has("floor_stop_on_slope"):
			var old_val: bool = node.floor_stop_on_slope
			var new_val: bool = bool(params["floor_stop_on_slope"])
			undo_redo.add_do_property(node, "floor_stop_on_slope", new_val)
			undo_redo.add_undo_property(node, "floor_stop_on_slope", old_val)
			applied["floor_stop_on_slope"] = new_val

		if params.has("floor_max_angle"):
			var old_val: float = node.floor_max_angle
			var new_val: float = float(params["floor_max_angle"])
			undo_redo.add_do_property(node, "floor_max_angle", new_val)
			undo_redo.add_undo_property(node, "floor_max_angle", old_val)
			applied["floor_max_angle"] = new_val

		if params.has("floor_snap_length"):
			var old_val: float = node.floor_snap_length
			var new_val: float = float(params["floor_snap_length"])
			undo_redo.add_do_property(node, "floor_snap_length", new_val)
			undo_redo.add_undo_property(node, "floor_snap_length", old_val)
			applied["floor_snap_length"] = new_val

		if params.has("wall_min_slide_angle"):
			var old_val: float = node.wall_min_slide_angle
			var new_val: float = float(params["wall_min_slide_angle"])
			undo_redo.add_do_property(node, "wall_min_slide_angle", new_val)
			undo_redo.add_undo_property(node, "wall_min_slide_angle", old_val)
			applied["wall_min_slide_angle"] = new_val

		if params.has("motion_mode"):
			var mode_str: String = str(params["motion_mode"])
			var mode_val: int = 0
			if node is CharacterBody2D:
				match mode_str.to_lower():
					"grounded":
						mode_val = CharacterBody2D.MOTION_MODE_GROUNDED
					"floating":
						mode_val = CharacterBody2D.MOTION_MODE_FLOATING
					_:
						mode_val = int(params["motion_mode"])
			else:
				match mode_str.to_lower():
					"grounded":
						mode_val = CharacterBody3D.MOTION_MODE_GROUNDED
					"floating":
						mode_val = CharacterBody3D.MOTION_MODE_FLOATING
					_:
						mode_val = int(params["motion_mode"])
			var old_val: int = node.motion_mode
			undo_redo.add_do_property(node, "motion_mode", mode_val)
			undo_redo.add_undo_property(node, "motion_mode", old_val)
			applied["motion_mode"] = mode_str

		if params.has("max_slides"):
			var old_val: int = node.max_slides
			var new_val: int = int(params["max_slides"])
			undo_redo.add_do_property(node, "max_slides", new_val)
			undo_redo.add_undo_property(node, "max_slides", old_val)
			applied["max_slides"] = new_val

		if params.has("slide_on_ceiling"):
			var old_val: bool = node.slide_on_ceiling
			var new_val: bool = bool(params["slide_on_ceiling"])
			undo_redo.add_do_property(node, "slide_on_ceiling", new_val)
			undo_redo.add_undo_property(node, "slide_on_ceiling", old_val)
			applied["slide_on_ceiling"] = new_val

	elif node is RigidBody2D or node is RigidBody3D:
		# RigidBody properties
		if params.has("mass"):
			var old_val: float = node.mass
			var new_val: float = float(params["mass"])
			undo_redo.add_do_property(node, "mass", new_val)
			undo_redo.add_undo_property(node, "mass", old_val)
			applied["mass"] = new_val

		if params.has("gravity_scale"):
			var old_val: float = node.gravity_scale
			var new_val: float = float(params["gravity_scale"])
			undo_redo.add_do_property(node, "gravity_scale", new_val)
			undo_redo.add_undo_property(node, "gravity_scale", old_val)
			applied["gravity_scale"] = new_val

		if params.has("linear_damp"):
			var old_val: float = node.linear_damp
			var new_val: float = float(params["linear_damp"])
			undo_redo.add_do_property(node, "linear_damp", new_val)
			undo_redo.add_undo_property(node, "linear_damp", old_val)
			applied["linear_damp"] = new_val

		if params.has("angular_damp"):
			var old_val: float = node.angular_damp
			var new_val: float = float(params["angular_damp"])
			undo_redo.add_do_property(node, "angular_damp", new_val)
			undo_redo.add_undo_property(node, "angular_damp", old_val)
			applied["angular_damp"] = new_val

		if params.has("freeze"):
			var old_val: bool = node.freeze
			var new_val: bool = bool(params["freeze"])
			undo_redo.add_do_property(node, "freeze", new_val)
			undo_redo.add_undo_property(node, "freeze", old_val)
			applied["freeze"] = new_val

		if params.has("freeze_mode"):
			var mode_str: String = str(params["freeze_mode"])
			var mode_val: int = 0
			if node is RigidBody2D:
				match mode_str.to_lower():
					"static":
						mode_val = RigidBody2D.FREEZE_MODE_STATIC
					"kinematic":
						mode_val = RigidBody2D.FREEZE_MODE_KINEMATIC
					_:
						mode_val = int(params["freeze_mode"])
			else:
				match mode_str.to_lower():
					"static":
						mode_val = RigidBody3D.FREEZE_MODE_STATIC
					"kinematic":
						mode_val = RigidBody3D.FREEZE_MODE_KINEMATIC
					_:
						mode_val = int(params["freeze_mode"])
			var old_val: int = node.freeze_mode
			undo_redo.add_do_property(node, "freeze_mode", mode_val)
			undo_redo.add_undo_property(node, "freeze_mode", old_val)
			applied["freeze_mode"] = mode_str

		if params.has("continuous_cd"):
			if node is RigidBody2D:
				var ccd_str: String = str(params["continuous_cd"])
				var ccd_val: int = 0
				match ccd_str.to_lower():
					"disabled":
						ccd_val = RigidBody2D.CCD_MODE_DISABLED
					"cast_ray":
						ccd_val = RigidBody2D.CCD_MODE_CAST_RAY
					"cast_shape":
						ccd_val = RigidBody2D.CCD_MODE_CAST_SHAPE
					_:
						ccd_val = int(params["continuous_cd"])
				var old_val: int = node.continuous_cd
				undo_redo.add_do_property(node, "continuous_cd", ccd_val)
				undo_redo.add_undo_property(node, "continuous_cd", old_val)
				applied["continuous_cd"] = ccd_str
			else:
				var old_val: bool = node.continuous_cd
				var new_val: bool = bool(params["continuous_cd"])
				undo_redo.add_do_property(node, "continuous_cd", new_val)
				undo_redo.add_undo_property(node, "continuous_cd", old_val)
				applied["continuous_cd"] = new_val

		if params.has("contact_monitor"):
			var old_val: bool = node.contact_monitor
			var new_val: bool = bool(params["contact_monitor"])
			undo_redo.add_do_property(node, "contact_monitor", new_val)
			undo_redo.add_undo_property(node, "contact_monitor", old_val)
			applied["contact_monitor"] = new_val

		if params.has("max_contacts_reported"):
			var old_val: int = node.max_contacts_reported
			var new_val: int = int(params["max_contacts_reported"])
			undo_redo.add_do_property(node, "max_contacts_reported", new_val)
			undo_redo.add_undo_property(node, "max_contacts_reported", old_val)
			applied["max_contacts_reported"] = new_val

	elif node is StaticBody2D or node is StaticBody3D or node is AnimatableBody2D or node is AnimatableBody3D:
		# StaticBody / AnimatableBody shared properties
		if params.has("physics_material_override"):
			# We just note it — use add_resource for complex resource assignment
			return error_invalid_params("Use add_resource to set physics_material_override")
	else:
		return error_invalid_params("Node '%s' (%s) is not a recognized physics body type. Supported: CharacterBody2D/3D, RigidBody2D/3D, StaticBody2D/3D, AnimatableBody2D/3D" % [node_path, node.get_class()])

	if applied.is_empty():
		undo_redo.commit_action()
		return error_invalid_params("No valid properties provided for %s" % node.get_class())

	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"applied": applied,
	})


func _get_collision_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var include_children: bool = optional_bool(params, "include_children", true)

	var info: Dictionary = {
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
	}

	# Collect physics body properties
	if "collision_layer" in node:
		var dim := _detect_dimension(node)
		if dim.is_empty():
			dim = "2d"
		info["collision_layer"] = node.get("collision_layer")
		info["collision_layer_info"] = _layer_bitmask_to_info(int(node.get("collision_layer")), dim)
		info["collision_mask"] = node.get("collision_mask")
		info["collision_mask_info"] = _layer_bitmask_to_info(int(node.get("collision_mask")), dim)

	# Collect body-specific properties
	if node is CharacterBody2D or node is CharacterBody3D:
		info["body_settings"] = {
			"motion_mode": node.motion_mode,
			"floor_stop_on_slope": node.floor_stop_on_slope,
			"floor_max_angle": node.floor_max_angle,
			"floor_snap_length": node.floor_snap_length,
			"wall_min_slide_angle": node.wall_min_slide_angle,
			"max_slides": node.max_slides,
			"slide_on_ceiling": node.slide_on_ceiling,
		}
	elif node is RigidBody2D or node is RigidBody3D:
		info["body_settings"] = {
			"mass": node.mass,
			"gravity_scale": node.gravity_scale,
			"linear_damp": node.linear_damp,
			"angular_damp": node.angular_damp,
			"freeze": node.freeze,
			"freeze_mode": node.freeze_mode,
			"contact_monitor": node.contact_monitor,
			"max_contacts_reported": node.max_contacts_reported,
		}

	# Collect collision shapes
	var shapes: Array = []
	var raycasts: Array = []
	var nodes_to_check: Array = [node]

	if include_children:
		var queue: Array = [node]
		while queue.size() > 0:
			var current: Node = queue.pop_front()
			for child_idx in current.get_child_count():
				var child := current.get_child(child_idx)
				nodes_to_check.append(child)
				queue.append(child)

	for check_node: Node in nodes_to_check:
		if check_node is CollisionShape2D:
			var shape_info: Dictionary = {
				"node_path": str(root.get_path_to(check_node)),
				"disabled": check_node.disabled,
				"one_way_collision": check_node.one_way_collision,
			}
			if check_node.shape != null:
				shape_info["shape_type"] = check_node.shape.get_class()
				if check_node.shape is RectangleShape2D:
					shape_info["size"] = "Vector2(%s, %s)" % [check_node.shape.size.x, check_node.shape.size.y]
				elif check_node.shape is CircleShape2D:
					shape_info["radius"] = check_node.shape.radius
				elif check_node.shape is CapsuleShape2D:
					shape_info["radius"] = check_node.shape.radius
					shape_info["height"] = check_node.shape.height
			shapes.append(shape_info)

		elif check_node is CollisionShape3D:
			var shape_info: Dictionary = {
				"node_path": str(root.get_path_to(check_node)),
				"disabled": check_node.disabled,
			}
			if check_node.shape != null:
				shape_info["shape_type"] = check_node.shape.get_class()
				if check_node.shape is BoxShape3D:
					shape_info["size"] = "Vector3(%s, %s, %s)" % [check_node.shape.size.x, check_node.shape.size.y, check_node.shape.size.z]
				elif check_node.shape is SphereShape3D:
					shape_info["radius"] = check_node.shape.radius
				elif check_node.shape is CapsuleShape3D:
					shape_info["radius"] = check_node.shape.radius
					shape_info["height"] = check_node.shape.height
				elif check_node.shape is CylinderShape3D:
					shape_info["radius"] = check_node.shape.radius
					shape_info["height"] = check_node.shape.height
			shapes.append(shape_info)

		elif check_node is CollisionPolygon2D:
			shapes.append({
				"node_path": str(root.get_path_to(check_node)),
				"shape_type": "CollisionPolygon2D",
				"disabled": check_node.disabled,
				"one_way_collision": check_node.one_way_collision,
				"polygon_points": check_node.polygon.size(),
			})

		elif check_node is CollisionPolygon3D:
			shapes.append({
				"node_path": str(root.get_path_to(check_node)),
				"shape_type": "CollisionPolygon3D",
				"disabled": check_node.disabled,
				"polygon_points": check_node.polygon.size(),
			})

		elif check_node is RayCast2D:
			raycasts.append({
				"node_path": str(root.get_path_to(check_node)),
				"type": "RayCast2D",
				"enabled": check_node.enabled,
				"target_position": "Vector2(%s, %s)" % [check_node.target_position.x, check_node.target_position.y],
				"collision_mask": check_node.collision_mask,
				"collide_with_areas": check_node.collide_with_areas,
				"collide_with_bodies": check_node.collide_with_bodies,
			})

		elif check_node is RayCast3D:
			raycasts.append({
				"node_path": str(root.get_path_to(check_node)),
				"type": "RayCast3D",
				"enabled": check_node.enabled,
				"target_position": "Vector3(%s, %s, %s)" % [check_node.target_position.x, check_node.target_position.y, check_node.target_position.z],
				"collision_mask": check_node.collision_mask,
				"collide_with_areas": check_node.collide_with_areas,
				"collide_with_bodies": check_node.collide_with_bodies,
			})

	info["collision_shapes"] = shapes
	info["raycasts"] = raycasts

	return success(info)
