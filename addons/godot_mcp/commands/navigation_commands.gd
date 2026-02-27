@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"setup_navigation_region": _setup_navigation_region,
		"bake_navigation_mesh": _bake_navigation_mesh,
		"setup_navigation_agent": _setup_navigation_agent,
		"set_navigation_layers": _set_navigation_layers,
		"get_navigation_info": _get_navigation_info,
	}


func _is_3d_context(node: Node) -> bool:
	if node is Node3D:
		return true
	if node is Node2D:
		return false
	# Walk up to detect context
	var parent := node.get_parent()
	while parent != null:
		if parent is Node3D:
			return true
		if parent is Node2D:
			return false
		parent = parent.get_parent()
	return false


func _setup_navigation_region(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	var force_mode: String = optional_string(params, "mode", "auto")
	var is_3d: bool
	match force_mode:
		"2d": is_3d = false
		"3d": is_3d = true
		_: is_3d = _is_3d_context(node)

	if is_3d:
		var region := NavigationRegion3D.new()
		region.name = optional_string(params, "name", "NavigationRegion3D")

		var nav_mesh := NavigationMesh.new()
		nav_mesh.agent_radius = float(params.get("agent_radius", 0.5))
		nav_mesh.agent_height = float(params.get("agent_height", 1.5))
		nav_mesh.agent_max_climb = float(params.get("agent_max_climb", 0.25))
		nav_mesh.agent_max_slope = float(params.get("agent_max_slope", 45.0))
		nav_mesh.cell_size = float(params.get("cell_size", 0.25))
		nav_mesh.cell_height = float(params.get("cell_height", 0.25))
		region.navigation_mesh = nav_mesh

		if params.has("navigation_layers"):
			region.navigation_layers = int(params["navigation_layers"])

		node.add_child(region, true)
		region.owner = get_edited_root()

		return success({
			"node_path": str(region.get_path()),
			"type": "NavigationRegion3D",
			"agent_radius": nav_mesh.agent_radius,
			"agent_height": nav_mesh.agent_height,
			"cell_size": nav_mesh.cell_size,
			"created": true,
		})
	else:
		var region := NavigationRegion2D.new()
		region.name = optional_string(params, "name", "NavigationRegion2D")

		var nav_poly := NavigationPolygon.new()

		# Set parsed geometry source if available
		if params.has("source_geometry_mode"):
			var mode_str: String = str(params["source_geometry_mode"])
			match mode_str:
				"root_node": nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
				"groups_with_children": nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
				"groups_explicit": nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT

		if params.has("cell_size"):
			nav_poly.cell_size = float(params["cell_size"])

		if params.has("agent_radius"):
			nav_poly.agent_radius = float(params["agent_radius"])

		region.navigation_polygon = nav_poly

		if params.has("navigation_layers"):
			region.navigation_layers = int(params["navigation_layers"])

		node.add_child(region, true)
		region.owner = get_edited_root()

		return success({
			"node_path": str(region.get_path()),
			"type": "NavigationRegion2D",
			"cell_size": nav_poly.cell_size,
			"created": true,
		})


func _bake_navigation_mesh(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	if node is NavigationRegion3D:
		var region: NavigationRegion3D = node as NavigationRegion3D
		if region.navigation_mesh == null:
			return error_invalid_params("NavigationRegion3D has no NavigationMesh resource")
		region.bake_navigation_mesh()
		return success({
			"node_path": node_path,
			"type": "NavigationRegion3D",
			"baked": true,
		})

	elif node is NavigationRegion2D:
		var region: NavigationRegion2D = node as NavigationRegion2D
		if region.navigation_polygon == null:
			var nav_poly := NavigationPolygon.new()
			region.navigation_polygon = nav_poly

		# Set outline vertices from params
		if params.has("outline"):
			var outline_data: Array = params["outline"]
			var outline := PackedVector2Array()
			for point in outline_data:
				if point is Array and point.size() >= 2:
					outline.append(Vector2(float(point[0]), float(point[1])))
				elif point is Dictionary:
					outline.append(Vector2(float(point.get("x", 0)), float(point.get("y", 0))))

			if outline.size() >= 3:
				# Clear existing outlines
				while region.navigation_polygon.get_outline_count() > 0:
					region.navigation_polygon.remove_outline(0)
				region.navigation_polygon.add_outline(outline)
				region.navigation_polygon.make_polygons_from_outlines()
				return success({
					"node_path": node_path,
					"type": "NavigationRegion2D",
					"outline_vertices": outline.size(),
					"baked": true,
				})
			else:
				return error_invalid_params("Outline must have at least 3 vertices")
		else:
			# Try baking from source geometry
			region.bake_navigation_polygon()
			return success({
				"node_path": node_path,
				"type": "NavigationRegion2D",
				"baked": true,
			})

	return error_invalid_params("Node '%s' is not a NavigationRegion2D or NavigationRegion3D" % node_path)


func _setup_navigation_agent(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	var force_mode: String = optional_string(params, "mode", "auto")
	var is_3d: bool
	match force_mode:
		"2d": is_3d = false
		"3d": is_3d = true
		_: is_3d = _is_3d_context(node)

	var agent_name: String = optional_string(params, "name", "NavigationAgent3D" if is_3d else "NavigationAgent2D")

	if is_3d:
		var agent := NavigationAgent3D.new()
		agent.name = agent_name

		if params.has("path_desired_distance"):
			agent.path_desired_distance = float(params["path_desired_distance"])
		if params.has("target_desired_distance"):
			agent.target_desired_distance = float(params["target_desired_distance"])
		if params.has("radius"):
			agent.radius = float(params["radius"])
		if params.has("neighbor_distance"):
			agent.neighbor_distance = float(params["neighbor_distance"])
		if params.has("max_neighbors"):
			agent.max_neighbors = int(params["max_neighbors"])
		if params.has("max_speed"):
			agent.max_speed = float(params["max_speed"])
		if params.has("avoidance_enabled"):
			agent.avoidance_enabled = bool(params["avoidance_enabled"])
		if params.has("navigation_layers"):
			agent.navigation_layers = int(params["navigation_layers"])

		node.add_child(agent, true)
		agent.owner = get_edited_root()

		return success({
			"node_path": str(agent.get_path()),
			"type": "NavigationAgent3D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers,
			"created": true,
		})
	else:
		var agent := NavigationAgent2D.new()
		agent.name = agent_name

		if params.has("path_desired_distance"):
			agent.path_desired_distance = float(params["path_desired_distance"])
		if params.has("target_desired_distance"):
			agent.target_desired_distance = float(params["target_desired_distance"])
		if params.has("radius"):
			agent.radius = float(params["radius"])
		if params.has("neighbor_distance"):
			agent.neighbor_distance = float(params["neighbor_distance"])
		if params.has("max_neighbors"):
			agent.max_neighbors = int(params["max_neighbors"])
		if params.has("max_speed"):
			agent.max_speed = float(params["max_speed"])
		if params.has("avoidance_enabled"):
			agent.avoidance_enabled = bool(params["avoidance_enabled"])
		if params.has("navigation_layers"):
			agent.navigation_layers = int(params["navigation_layers"])

		node.add_child(agent, true)
		agent.owner = get_edited_root()

		return success({
			"node_path": str(agent.get_path()),
			"type": "NavigationAgent2D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers,
			"created": true,
		})


func _set_navigation_layers(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	# Support setting by bitmask value
	if params.has("layers"):
		var layers_val: int = int(params["layers"])
		if node is NavigationRegion2D:
			(node as NavigationRegion2D).navigation_layers = layers_val
		elif node is NavigationRegion3D:
			(node as NavigationRegion3D).navigation_layers = layers_val
		elif node is NavigationAgent2D:
			(node as NavigationAgent2D).navigation_layers = layers_val
		elif node is NavigationAgent3D:
			(node as NavigationAgent3D).navigation_layers = layers_val
		else:
			return error_invalid_params("Node '%s' is not a navigation region or agent" % node_path)

		return success({
			"node_path": node_path,
			"navigation_layers": layers_val,
			"updated": true,
		})

	# Support setting individual layer bits by number
	if params.has("layer_bits"):
		var bits: Array = params["layer_bits"]
		var current_layers: int = 0

		# Calculate bitmask from layer numbers (1-based)
		for bit in bits:
			var layer_num: int = int(bit)
			if layer_num >= 1 and layer_num <= 32:
				current_layers |= (1 << (layer_num - 1))

		if node is NavigationRegion2D:
			(node as NavigationRegion2D).navigation_layers = current_layers
		elif node is NavigationRegion3D:
			(node as NavigationRegion3D).navigation_layers = current_layers
		elif node is NavigationAgent2D:
			(node as NavigationAgent2D).navigation_layers = current_layers
		elif node is NavigationAgent3D:
			(node as NavigationAgent3D).navigation_layers = current_layers
		else:
			return error_invalid_params("Node '%s' is not a navigation region or agent" % node_path)

		return success({
			"node_path": node_path,
			"navigation_layers": current_layers,
			"layer_bits": bits,
			"updated": true,
		})

	# Support named layers from ProjectSettings
	if params.has("layer_names"):
		var names: Array = params["layer_names"]
		var current_layers: int = 0
		var is_2d: bool = node is NavigationRegion2D or node is NavigationAgent2D
		var prefix: String = "layer_names/2d_navigation/layer_" if is_2d else "layer_names/3d_navigation/layer_"

		for i in range(1, 33):
			var setting_key: String = prefix + str(i)
			if ProjectSettings.has_setting(setting_key):
				var layer_name: String = str(ProjectSettings.get_setting(setting_key))
				if layer_name in names:
					current_layers |= (1 << (i - 1))

		if node is NavigationRegion2D:
			(node as NavigationRegion2D).navigation_layers = current_layers
		elif node is NavigationRegion3D:
			(node as NavigationRegion3D).navigation_layers = current_layers
		elif node is NavigationAgent2D:
			(node as NavigationAgent2D).navigation_layers = current_layers
		elif node is NavigationAgent3D:
			(node as NavigationAgent3D).navigation_layers = current_layers
		else:
			return error_invalid_params("Node '%s' is not a navigation region or agent" % node_path)

		return success({
			"node_path": node_path,
			"navigation_layers": current_layers,
			"layer_names": names,
			"updated": true,
		})

	return error_invalid_params("Must provide 'layers' (bitmask), 'layer_bits' (array of layer numbers), or 'layer_names' (array of named layers)")


func _get_navigation_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	var regions: Array = []
	var agents: Array = []

	_collect_navigation_nodes(node, regions, agents)

	# Collect named layers from ProjectSettings
	var layer_names_2d: Dictionary = {}
	var layer_names_3d: Dictionary = {}
	for i in range(1, 33):
		var key_2d: String = "layer_names/2d_navigation/layer_" + str(i)
		var key_3d: String = "layer_names/3d_navigation/layer_" + str(i)
		if ProjectSettings.has_setting(key_2d):
			var name_2d: String = str(ProjectSettings.get_setting(key_2d))
			if not name_2d.is_empty():
				layer_names_2d[i] = name_2d
		if ProjectSettings.has_setting(key_3d):
			var name_3d: String = str(ProjectSettings.get_setting(key_3d))
			if not name_3d.is_empty():
				layer_names_3d[i] = name_3d

	return success({
		"node_path": node_path,
		"regions": regions,
		"agents": agents,
		"region_count": regions.size(),
		"agent_count": agents.size(),
		"layer_names_2d": layer_names_2d,
		"layer_names_3d": layer_names_3d,
	})


func _collect_navigation_nodes(node: Node, regions: Array, agents: Array) -> void:
	if node is NavigationRegion2D:
		var region: NavigationRegion2D = node as NavigationRegion2D
		var region_info := {
			"path": str(region.get_path()),
			"type": "NavigationRegion2D",
			"enabled": region.enabled,
			"navigation_layers": region.navigation_layers,
			"has_polygon": region.navigation_polygon != null,
		}
		if region.navigation_polygon != null:
			var nav_poly: NavigationPolygon = region.navigation_polygon
			region_info["outline_count"] = nav_poly.get_outline_count()
			region_info["polygon_count"] = nav_poly.get_polygon_count()
			region_info["cell_size"] = nav_poly.cell_size
			region_info["agent_radius"] = nav_poly.agent_radius
		regions.append(region_info)

	elif node is NavigationRegion3D:
		var region: NavigationRegion3D = node as NavigationRegion3D
		var region_info := {
			"path": str(region.get_path()),
			"type": "NavigationRegion3D",
			"enabled": region.enabled,
			"navigation_layers": region.navigation_layers,
			"has_mesh": region.navigation_mesh != null,
		}
		if region.navigation_mesh != null:
			var nav_mesh: NavigationMesh = region.navigation_mesh
			region_info["agent_radius"] = nav_mesh.agent_radius
			region_info["agent_height"] = nav_mesh.agent_height
			region_info["agent_max_climb"] = nav_mesh.agent_max_climb
			region_info["agent_max_slope"] = nav_mesh.agent_max_slope
			region_info["cell_size"] = nav_mesh.cell_size
			region_info["cell_height"] = nav_mesh.cell_height
		regions.append(region_info)

	if node is NavigationAgent2D:
		var agent: NavigationAgent2D = node as NavigationAgent2D
		agents.append({
			"path": str(agent.get_path()),
			"type": "NavigationAgent2D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"path_desired_distance": agent.path_desired_distance,
			"target_desired_distance": agent.target_desired_distance,
			"neighbor_distance": agent.neighbor_distance,
			"max_neighbors": agent.max_neighbors,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers,
		})

	elif node is NavigationAgent3D:
		var agent: NavigationAgent3D = node as NavigationAgent3D
		agents.append({
			"path": str(agent.get_path()),
			"type": "NavigationAgent3D",
			"radius": agent.radius,
			"max_speed": agent.max_speed,
			"path_desired_distance": agent.path_desired_distance,
			"target_desired_distance": agent.target_desired_distance,
			"neighbor_distance": agent.neighbor_distance,
			"max_neighbors": agent.max_neighbors,
			"avoidance_enabled": agent.avoidance_enabled,
			"navigation_layers": agent.navigation_layers,
		})

	for child in node.get_children():
		_collect_navigation_nodes(child, regions, agents)
