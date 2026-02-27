@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const NodeUtils := preload("res://addons/godot_mcp/utils/node_utils.gd")
const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")


func get_commands() -> Dictionary:
	return {
		"add_node": _add_node,
		"delete_node": _delete_node,
		"duplicate_node": _duplicate_node,
		"move_node": _move_node,
		"update_property": _update_property,
		"get_node_properties": _get_node_properties,
		"add_resource": _add_resource,
		"set_anchor_preset": _set_anchor_preset,
		"rename_node": _rename_node,
		"connect_signal": _connect_signal,
		"disconnect_signal": _disconnect_signal,
	}


func _add_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "type")
	if result[1] != null:
		return result[1]
	var type: String = result[0]

	var parent_path: String = optional_string(params, "parent_path", ".")
	var node_name: String = optional_string(params, "name", "")
	var properties: Dictionary = params.get("properties", {})

	if not ClassDB.class_exists(type):
		return error_invalid_params("Unknown node type: %s" % type)

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path, "Use get_scene_tree to see available nodes")

	var node: Node = ClassDB.instantiate(type)
	if not node_name.is_empty():
		node.name = node_name

	# Apply properties
	for prop_name: String in properties:
		var prop_exists := false
		for prop in node.get_property_list():
			if prop["name"] == prop_name:
				prop_exists = true
				break
		if prop_exists:
			var current: Variant = node.get(prop_name)
			var target_type := typeof(current)
			node.set(prop_name, PropertyParser.parse_value(properties[prop_name], target_type))

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add %s" % type)
	undo_redo.add_do_method(parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": type,
		"name": str(node.name),
	})


func _delete_node(params: Dictionary) -> Dictionary:
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

	if node == root:
		return error_invalid_params("Cannot delete the root node")

	var parent := node.get_parent()
	var node_name := str(node.name)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Delete %s" % node_name)
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(node, "set_owner", root)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()

	return success({"deleted": node_name})


func _duplicate_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var new_name: String = optional_string(params, "name", "")

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if new_name.is_empty():
		new_name = str(node.name) + "_copy"

	var dup := node.duplicate()
	dup.name = new_name
	var parent := node.get_parent()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Duplicate %s" % node.name)
	undo_redo.add_do_method(parent, "add_child", dup)
	undo_redo.add_do_method(dup, "set_owner", root)
	undo_redo.add_do_reference(dup)
	undo_redo.add_undo_method(parent, "remove_child", dup)
	undo_redo.commit_action()

	NodeUtils.set_owner_recursive(dup, root)

	return success({
		"original": str(root.get_path_to(node)),
		"duplicate": str(root.get_path_to(dup)),
		"name": str(dup.name),
	})


func _move_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "new_parent_path")
	if result2[1] != null:
		return result2[1]
	var new_parent_path: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if node == root:
		return error_invalid_params("Cannot move the root node")

	var new_parent := find_node_by_path(new_parent_path)
	if new_parent == null:
		return error_not_found("Target parent '%s'" % new_parent_path, "Use get_scene_tree to see available nodes")

	# Check we're not moving a node into its own subtree
	if new_parent == node or node.is_ancestor_of(new_parent):
		return error_invalid_params("Cannot move a node into its own subtree")

	var old_parent := node.get_parent()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Move %s" % node.name)
	undo_redo.add_do_method(old_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(old_parent, "add_child", node)
	undo_redo.add_undo_method(node, "set_owner", root)
	undo_redo.commit_action()

	NodeUtils.set_owner_recursive(node, root)

	return success({
		"node": str(node.name),
		"old_parent": str(root.get_path_to(old_parent)),
		"new_parent": str(root.get_path_to(new_parent)),
		"new_path": str(root.get_path_to(node)),
	})


func _update_property(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var property: String = result2[0]

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")
	var value: Variant = params["value"]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	# Check property exists
	if not property in node:
		var available: Array = []
		for prop in node.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_EDITOR:
				available.append(prop["name"])
		return error_not_found("Property '%s' on %s" % [property, node.get_class()],
			"Available: %s" % str(available.slice(0, 20)))

	var old_value: Variant = node.get(property)
	var target_type := typeof(old_value)
	var parsed_value: Variant = PropertyParser.parse_value(value, target_type)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set %s.%s" % [node.name, property])
	undo_redo.add_do_property(node, property, parsed_value)
	undo_redo.add_undo_property(node, property, old_value)
	undo_redo.commit_action()

	return success({
		"node": str(root.get_path_to(node)),
		"property": property,
		"old_value": PropertyParser.serialize_value(old_value),
		"new_value": PropertyParser.serialize_value(node.get(property)),
	})


func _get_node_properties(params: Dictionary) -> Dictionary:
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

	var category: String = optional_string(params, "category", "")
	var props := NodeUtils.get_node_properties_dict(node)

	# Filter by category if specified
	if not category.is_empty():
		var filtered: Dictionary = {}
		for key: String in props:
			if key.begins_with(category):
				filtered[key] = props[key]
		props = filtered

	return success({
		"node_path": str(root.get_path_to(node)),
		"type": node.get_class(),
		"properties": props,
	})


func _add_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "property")
	if result2[1] != null:
		return result2[1]
	var property: String = result2[0]

	var result3 := require_string(params, "resource_type")
	if result3[1] != null:
		return result3[1]
	var resource_type: String = result3[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not ClassDB.class_exists(resource_type):
		return error_invalid_params("Unknown resource type: %s" % resource_type)

	if not ClassDB.is_parent_class(resource_type, "Resource"):
		return error_invalid_params("'%s' is not a Resource type" % resource_type)

	var resource: Resource = ClassDB.instantiate(resource_type)
	if resource == null:
		return error_internal("Failed to create resource: %s" % resource_type)

	# Apply resource properties if provided
	var resource_props: Dictionary = params.get("resource_properties", {})
	for prop_name: String in resource_props:
		if prop_name in resource:
			var current := resource.get(prop_name)
			resource.set(prop_name, PropertyParser.parse_value(resource_props[prop_name], typeof(current)))

	var old_value: Variant = node.get(property) if property in node else null

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add %s to %s" % [resource_type, node.name])
	undo_redo.add_do_property(node, property, resource)
	undo_redo.add_undo_property(node, property, old_value)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(node)),
		"property": property,
		"resource_type": resource_type,
	})


func _set_anchor_preset(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "preset")
	if result2[1] != null:
		return result2[1]
	var preset_name: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	if not node is Control:
		return error_invalid_params("Node '%s' is not a Control (is %s)" % [node_path, node.get_class()])

	var control: Control = node
	var presets := {
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

	if not presets.has(preset_name):
		return error_invalid_params("Unknown preset: '%s'. Available: %s" % [preset_name, presets.keys()])

	var keep_offsets: bool = optional_bool(params, "keep_offsets", false)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set anchor preset on %s" % node.name)

	# Store old values
	var old_anchors := [control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom]
	var old_offsets := [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom]

	control.set_anchors_and_offsets_preset(presets[preset_name],
		Control.PRESET_MODE_KEEP_SIZE if keep_offsets else Control.PRESET_MODE_MINSIZE)

	undo_redo.add_do_property(control, "anchor_left", control.anchor_left)
	undo_redo.add_do_property(control, "anchor_top", control.anchor_top)
	undo_redo.add_do_property(control, "anchor_right", control.anchor_right)
	undo_redo.add_do_property(control, "anchor_bottom", control.anchor_bottom)
	undo_redo.add_do_property(control, "offset_left", control.offset_left)
	undo_redo.add_do_property(control, "offset_top", control.offset_top)
	undo_redo.add_do_property(control, "offset_right", control.offset_right)
	undo_redo.add_do_property(control, "offset_bottom", control.offset_bottom)

	undo_redo.add_undo_property(control, "anchor_left", old_anchors[0])
	undo_redo.add_undo_property(control, "anchor_top", old_anchors[1])
	undo_redo.add_undo_property(control, "anchor_right", old_anchors[2])
	undo_redo.add_undo_property(control, "anchor_bottom", old_anchors[3])
	undo_redo.add_undo_property(control, "offset_left", old_offsets[0])
	undo_redo.add_undo_property(control, "offset_top", old_offsets[1])
	undo_redo.add_undo_property(control, "offset_right", old_offsets[2])
	undo_redo.add_undo_property(control, "offset_bottom", old_offsets[3])

	undo_redo.commit_action()

	return success({"node_path": str(root.get_path_to(control)), "preset": preset_name})


func _rename_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "new_name")
	if result2[1] != null:
		return result2[1]
	var new_name: String = result2[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use get_scene_tree to see available nodes")

	var old_name: String = node.name
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Rename %s to %s" % [old_name, new_name])
	undo_redo.add_do_property(node, "name", new_name)
	undo_redo.add_undo_property(node, "name", old_name)
	undo_redo.commit_action()

	return success({"old_name": old_name, "new_name": str(node.name), "node_path": str(root.get_path_to(node))})


func _connect_signal(params: Dictionary) -> Dictionary:
	var result := require_string(params, "source_path")
	if result[1] != null:
		return result[1]
	var source_path: String = result[0]

	var result2 := require_string(params, "signal_name")
	if result2[1] != null:
		return result2[1]
	var signal_name: String = result2[0]

	var result3 := require_string(params, "target_path")
	if result3[1] != null:
		return result3[1]
	var target_path: String = result3[0]

	var result4 := require_string(params, "method_name")
	if result4[1] != null:
		return result4[1]
	var method_name: String = result4[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var source := find_node_by_path(source_path)
	if source == null:
		return error_not_found("Source node '%s'" % source_path)

	var target := find_node_by_path(target_path)
	if target == null:
		return error_not_found("Target node '%s'" % target_path)

	if not source.has_signal(signal_name):
		return error_invalid_params("Signal '%s' not found on %s" % [signal_name, source.get_class()])

	if source.is_connected(signal_name, Callable(target, method_name)):
		return success({"already_connected": true, "signal": signal_name})

	source.connect(signal_name, Callable(target, method_name))

	return success({
		"source": str(root.get_path_to(source)),
		"signal": signal_name,
		"target": str(root.get_path_to(target)),
		"method": method_name,
		"connected": true,
	})


func _disconnect_signal(params: Dictionary) -> Dictionary:
	var result := require_string(params, "source_path")
	if result[1] != null:
		return result[1]
	var source_path: String = result[0]

	var result2 := require_string(params, "signal_name")
	if result2[1] != null:
		return result2[1]
	var signal_name: String = result2[0]

	var result3 := require_string(params, "target_path")
	if result3[1] != null:
		return result3[1]
	var target_path: String = result3[0]

	var result4 := require_string(params, "method_name")
	if result4[1] != null:
		return result4[1]
	var method_name: String = result4[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var source := find_node_by_path(source_path)
	if source == null:
		return error_not_found("Source node '%s'" % source_path)

	var target := find_node_by_path(target_path)
	if target == null:
		return error_not_found("Target node '%s'" % target_path)

	if not source.is_connected(signal_name, Callable(target, method_name)):
		return success({"was_connected": false})

	source.disconnect(signal_name, Callable(target, method_name))

	return success({
		"source": str(root.get_path_to(source)),
		"signal": signal_name,
		"target": str(root.get_path_to(target)),
		"method": method_name,
		"disconnected": true,
	})
