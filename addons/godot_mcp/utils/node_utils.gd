@tool
extends RefCounted

## Recursively set owner for all children (needed when adding nodes via code)
static func set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		set_owner_recursive(child, owner)


## Get a simplified tree structure from a node
static func get_node_tree(node: Node, max_depth: int = -1, current_depth: int = 0) -> Dictionary:
	var result := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	# Add script info
	var script: Script = node.get_script()
	if script:
		result["script"] = script.resource_path

	# Add children
	if max_depth == -1 or current_depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			children.append(get_node_tree(child, max_depth, current_depth + 1))
		if not children.is_empty():
			result["children"] = children

	return result


## Get all properties of a node as a serializable dictionary
static func get_node_properties_dict(node: Node) -> Dictionary:
	var PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")
	var result: Dictionary = {}
	var property_list := node.get_property_list()

	for prop_info in property_list:
		var prop_name: String = prop_info["name"]
		var usage: int = prop_info["usage"]

		# Only include user-facing properties (PROPERTY_USAGE_EDITOR)
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue

		# Skip internal/meta properties
		if prop_name.begins_with("_") or prop_name in ["script"]:
			continue

		var value: Variant = node.get(prop_name)
		result[prop_name] = PropertyParser.serialize_value(value)

	return result


## Duplicate a node and all its children, properly setting owners
static func duplicate_node_in_scene(node: Node, new_name: String, root: Node) -> Node:
	var dup := node.duplicate()
	dup.name = new_name
	node.get_parent().add_child(dup)
	dup.owner = root
	set_owner_recursive(dup, root)
	return dup


## Find node by class type in subtree
static func find_nodes_by_type(root: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if root.get_class() == type_name or root.is_class(type_name):
		result.append(root)
	for child in root.get_children():
		result.append_array(find_nodes_by_type(child, type_name))
	return result
