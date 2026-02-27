@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_performance_monitors": _get_performance_monitors,
		"get_editor_performance": _get_editor_performance,
	}


func _get_performance_monitors(params: Dictionary) -> Dictionary:
	# Return all available performance monitors
	var monitors := {}
	monitors["fps"] = Performance.get_monitor(Performance.TIME_FPS)
	monitors["frame_time_msec"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	monitors["physics_frame_time_msec"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	monitors["navigation_process_msec"] = Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0

	monitors["memory_static"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	monitors["memory_static_max"] = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)

	monitors["object_count"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	monitors["object_resource_count"] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	monitors["object_node_count"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	monitors["object_orphan_node_count"] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	monitors["render_total_objects_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	monitors["render_total_primitives_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	monitors["render_total_draw_calls_in_frame"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	monitors["render_video_mem_used"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)

	monitors["physics_2d_active_objects"] = Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	monitors["physics_2d_collision_pairs"] = Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
	monitors["physics_2d_island_count"] = Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)

	monitors["physics_3d_active_objects"] = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	monitors["physics_3d_collision_pairs"] = Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
	monitors["physics_3d_island_count"] = Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)

	monitors["navigation_active_maps"] = Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS)
	monitors["navigation_region_count"] = Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT)
	monitors["navigation_agent_count"] = Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT)

	# Filter by category if requested
	var category: String = optional_string(params, "category", "")
	if not category.is_empty():
		var filtered := {}
		for key: String in monitors:
			if key.begins_with(category):
				filtered[key] = monitors[key]
		return success({"monitors": filtered, "category": category})

	return success({"monitors": monitors})


func _get_editor_performance(params: Dictionary) -> Dictionary:
	# Quick summary for common use
	var summary := {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time_msec": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memory_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0),
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
	}
	return success(summary)
