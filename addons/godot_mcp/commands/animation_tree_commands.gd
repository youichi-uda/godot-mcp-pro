@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_animation_tree": _create_animation_tree,
		"get_animation_tree_structure": _get_animation_tree_structure,
		"add_state_machine_state": _add_state_machine_state,
		"remove_state_machine_state": _remove_state_machine_state,
		"add_state_machine_transition": _add_state_machine_transition,
		"remove_state_machine_transition": _remove_state_machine_transition,
		"set_blend_tree_node": _set_blend_tree_node,
		"set_tree_parameter": _set_tree_parameter,
	}


## Find AnimationTree on a node or return null
func _find_animation_tree(node_path: String) -> AnimationTree:
	var node := find_node_by_path(node_path)
	if node is AnimationTree:
		return node as AnimationTree
	return null


## Navigate to a nested state machine by slash-separated path (e.g. "Run/SubState")
## Returns [state_machine, error_or_null]
func _resolve_state_machine(tree: AnimationTree, sm_path: String) -> Array:
	var root := tree.tree_root
	if not root is AnimationNodeStateMachine:
		return [null, error_invalid_params("AnimationTree root is not an AnimationNodeStateMachine")]

	if sm_path.is_empty() or sm_path == ".":
		return [root as AnimationNodeStateMachine, null]

	var current: AnimationNodeStateMachine = root as AnimationNodeStateMachine
	var parts := sm_path.split("/")
	for part in parts:
		if not current.has_node(StringName(part)):
			return [null, error_not_found("State machine node '%s' in path '%s'" % [part, sm_path])]
		var child := current.get_node(StringName(part))
		if not child is AnimationNodeStateMachine:
			return [null, error_invalid_params("Node '%s' is not a StateMachine" % part)]
		current = child as AnimationNodeStateMachine
	return [current, null]


## Resolve a BlendTree inside the tree. bt_path can be a state name inside a state machine,
## or a slash-separated path. The last segment is the BlendTree node name.
## Returns [blend_tree, error_or_null]
func _resolve_blend_tree(tree: AnimationTree, sm_path: String, bt_name: String) -> Array:
	var result := _resolve_state_machine(tree, sm_path)
	if result[1] != null:
		return result

	var sm: AnimationNodeStateMachine = result[0]
	if not sm.has_node(StringName(bt_name)):
		return [null, error_not_found("BlendTree node '%s'" % bt_name)]

	var node := sm.get_node(StringName(bt_name))
	if not node is AnimationNodeBlendTree:
		return [null, error_invalid_params("Node '%s' is not an AnimationNodeBlendTree" % bt_name)]

	return [node as AnimationNodeBlendTree, null]


func _create_animation_tree(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent := find_node_by_path(node_path)
	if parent == null:
		return error_not_found("Node at '%s'" % node_path)

	var anim_player_path: String = optional_string(params, "anim_player", "")
	var tree_name: String = optional_string(params, "name", "AnimationTree")

	# Create the AnimationTree
	var tree := AnimationTree.new()
	tree.name = tree_name

	# Set root to AnimationNodeStateMachine
	var state_machine := AnimationNodeStateMachine.new()
	tree.tree_root = state_machine

	# Link to AnimationPlayer if provided
	if not anim_player_path.is_empty():
		tree.anim_player = NodePath(anim_player_path)

	parent.add_child(tree, true)
	tree.owner = root

	return success({
		"name": tree.name,
		"node_path": str(root.get_path_to(tree)),
		"root_type": "AnimationNodeStateMachine",
		"anim_player": anim_player_path,
		"created": true,
	})


func _get_animation_tree_structure(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tree := _find_animation_tree(node_path)
	if tree == null:
		return error_not_found("AnimationTree at '%s'" % node_path)

	var root := tree.tree_root
	if root == null:
		return success({"node_path": node_path, "root": null})

	var structure := _read_node_structure(root)
	structure["active"] = tree.active
	structure["anim_player"] = str(tree.anim_player)
	structure["node_path"] = node_path

	return success(structure)


func _read_node_structure(node: AnimationNode) -> Dictionary:
	if node is AnimationNodeStateMachine:
		return _read_state_machine_structure(node as AnimationNodeStateMachine)
	elif node is AnimationNodeBlendTree:
		return _read_blend_tree_structure(node as AnimationNodeBlendTree)
	elif node is AnimationNodeAnimation:
		var anim_node := node as AnimationNodeAnimation
		return {"type": "AnimationNodeAnimation", "animation": str(anim_node.animation)}
	else:
		return {"type": node.get_class()}


func _read_state_machine_structure(sm: AnimationNodeStateMachine) -> Dictionary:
	var states: Array = []
	# Iterate through graph nodes via get_node_name
	# AnimationNodeStateMachine doesn't have get_node_list in 4.x, iterate using _get_child_nodes
	var node_list := _get_sm_node_names(sm)
	for state_name in node_list:
		var child := sm.get_node(StringName(state_name))
		var state_info := {
			"name": state_name,
			"position": {"x": sm.get_node_position(StringName(state_name)).x, "y": sm.get_node_position(StringName(state_name)).y},
		}
		state_info.merge(_read_node_structure(child))
		states.append(state_info)

	var transitions: Array = []
	for i in sm.get_transition_count():
		var from_node := sm.get_transition_from(i)
		var to_node := sm.get_transition_to(i)
		var trans := sm.get_transition(i)
		var trans_info := {
			"from": str(from_node),
			"to": str(to_node),
			"switch_mode": trans.switch_mode,
			"advance_mode": trans.advance_mode,
		}
		if not trans.advance_expression.is_empty():
			trans_info["advance_expression"] = trans.advance_expression
		if trans.advance_mode == AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO:
			trans_info["auto"] = true
		transitions.append(trans_info)

	return {
		"type": "AnimationNodeStateMachine",
		"states": states,
		"transitions": transitions,
	}


func _get_sm_node_names(sm: AnimationNodeStateMachine) -> Array:
	# Use the internal _get_child_nodes or iterate known patterns
	# AnimationNodeStateMachine doesn't expose a simple list method,
	# but we can use get_graph_offset and iterate via has_node with common checks.
	# Actually in Godot 4.x we can get the node list by checking property list
	# or using the script resource approach. The most reliable is iterating through
	# the resource properties.
	var names: Array = []
	var prop_list := sm.get_property_list()
	for prop in prop_list:
		var pname: String = prop["name"]
		# State machine stores nodes as "states/<name>/node"
		if pname.begins_with("states/") and pname.ends_with("/node"):
			var state_name := pname.get_slice("/", 1)
			if state_name != "Start" and state_name != "End":
				names.append(state_name)
	return names


func _read_blend_tree_structure(bt: AnimationNodeBlendTree) -> Dictionary:
	var nodes_info: Array = []
	var prop_list := bt.get_property_list()
	var node_names: Array = []
	for prop in prop_list:
		var pname: String = prop["name"]
		if pname.begins_with("nodes/") and pname.ends_with("/node"):
			var n := pname.get_slice("/", 1)
			if n != "output":
				node_names.append(n)

	for n_name in node_names:
		var child: AnimationNode = bt.get_node(StringName(n_name))
		var node_info := {
			"name": n_name,
			"type": child.get_class(),
			"position": {"x": bt.get_node_position(StringName(n_name)).x, "y": bt.get_node_position(StringName(n_name)).y},
		}
		if child is AnimationNodeAnimation:
			node_info["animation"] = str((child as AnimationNodeAnimation).animation)
		nodes_info.append(node_info)

	# Read connections
	var connections: Array = []
	# BlendTree connections are stored as "node_connections" in properties
	# We can read them from the resource property list
	for prop in prop_list:
		var pname: String = prop["name"]
		if pname.begins_with("nodes/") and pname.ends_with("/node"):
			continue
		if pname.begins_with("nodes/") and pname.ends_with("/position"):
			continue
		# Connection format: "node_connection/<idx>/<input_node>/<input_port>"
		# Actually connections are stored differently - let's skip for now

	return {
		"type": "AnimationNodeBlendTree",
		"nodes": nodes_info,
	}


func _add_state_machine_state(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "state_name")
	if result2[1] != null:
		return result2[1]
	var state_name: String = result2[0]

	var tree := _find_animation_tree(node_path)
	if tree == null:
		return error_not_found("AnimationTree at '%s'" % node_path)

	var sm_path: String = optional_string(params, "state_machine_path", "")
	var sm_result := _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]

	if sm.has_node(StringName(state_name)):
		return error_invalid_params("State '%s' already exists" % state_name)

	var state_type: String = optional_string(params, "state_type", "animation")
	var position_x: float = float(params.get("position_x", 0.0))
	var position_y: float = float(params.get("position_y", 0.0))
	var position := Vector2(position_x, position_y)

	var node: AnimationNode
	match state_type:
		"animation":
			var anim_node := AnimationNodeAnimation.new()
			var anim_name: String = optional_string(params, "animation", "")
			if not anim_name.is_empty():
				anim_node.animation = StringName(anim_name)
			node = anim_node
		"blend_tree":
			node = AnimationNodeBlendTree.new()
		"state_machine":
			node = AnimationNodeStateMachine.new()
		_:
			return error_invalid_params("Unknown state_type: '%s'. Use 'animation', 'blend_tree', or 'state_machine'" % state_type)

	sm.add_node(StringName(state_name), node, position)

	return success({
		"state_name": state_name,
		"state_type": state_type,
		"position": {"x": position_x, "y": position_y},
		"added": true,
	})


func _remove_state_machine_state(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "state_name")
	if result2[1] != null:
		return result2[1]
	var state_name: String = result2[0]

	var tree := _find_animation_tree(node_path)
	if tree == null:
		return error_not_found("AnimationTree at '%s'" % node_path)

	var sm_path: String = optional_string(params, "state_machine_path", "")
	var sm_result := _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]

	if not sm.has_node(StringName(state_name)):
		return error_not_found("State '%s'" % state_name)

	sm.remove_node(StringName(state_name))

	return success({"state_name": state_name, "removed": true})


func _add_state_machine_transition(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "from_state")
	if result2[1] != null:
		return result2[1]
	var from_state: String = result2[0]

	var result3 := require_string(params, "to_state")
	if result3[1] != null:
		return result3[1]
	var to_state: String = result3[0]

	var tree := _find_animation_tree(node_path)
	if tree == null:
		return error_not_found("AnimationTree at '%s'" % node_path)

	var sm_path: String = optional_string(params, "state_machine_path", "")
	var sm_result := _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]

	# Validate states exist (Start and End are special built-in nodes)
	if from_state != "Start" and from_state != "End" and not sm.has_node(StringName(from_state)):
		return error_not_found("State '%s'" % from_state)
	if to_state != "Start" and to_state != "End" and not sm.has_node(StringName(to_state)):
		return error_not_found("State '%s'" % to_state)

	var transition := AnimationNodeStateMachineTransition.new()

	# switch_mode: AT_END=0, IMMEDIATE=1, SYNC=2
	var switch_mode_str: String = optional_string(params, "switch_mode", "immediate")
	match switch_mode_str:
		"at_end": transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		"immediate": transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		"sync": transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END  # SYNC maps similarly
		_: transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE

	# advance_mode: DISABLED=0, ENABLED=1, AUTO=2
	var advance_mode_str: String = optional_string(params, "advance_mode", "enabled")
	match advance_mode_str:
		"disabled": transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED
		"enabled": transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
		"auto": transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		_: transition.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED

	# advance_expression
	var expression: String = optional_string(params, "advance_expression", "")
	if not expression.is_empty():
		transition.advance_expression = expression

	# xfade_time
	if params.has("xfade_time"):
		transition.xfade_time = float(params["xfade_time"])

	sm.add_transition(StringName(from_state), StringName(to_state), transition)

	return success({
		"from": from_state,
		"to": to_state,
		"switch_mode": switch_mode_str,
		"advance_mode": advance_mode_str,
		"advance_expression": expression,
		"added": true,
	})


func _remove_state_machine_transition(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "from_state")
	if result2[1] != null:
		return result2[1]
	var from_state: String = result2[0]

	var result3 := require_string(params, "to_state")
	if result3[1] != null:
		return result3[1]
	var to_state: String = result3[0]

	var tree := _find_animation_tree(node_path)
	if tree == null:
		return error_not_found("AnimationTree at '%s'" % node_path)

	var sm_path: String = optional_string(params, "state_machine_path", "")
	var sm_result := _resolve_state_machine(tree, sm_path)
	if sm_result[1] != null:
		return sm_result[1]
	var sm: AnimationNodeStateMachine = sm_result[0]

	# Check if transition exists
	var found := false
	for i in sm.get_transition_count():
		if str(sm.get_transition_from(i)) == from_state and str(sm.get_transition_to(i)) == to_state:
			found = true
			break

	if not found:
		return error_not_found("Transition from '%s' to '%s'" % [from_state, to_state])

	sm.remove_transition(StringName(from_state), StringName(to_state))

	return success({"from": from_state, "to": to_state, "removed": true})


func _set_blend_tree_node(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "blend_tree_state")
	if result2[1] != null:
		return result2[1]
	var bt_state: String = result2[0]

	var result3 := require_string(params, "bt_node_name")
	if result3[1] != null:
		return result3[1]
	var bt_node_name: String = result3[0]

	var result4 := require_string(params, "bt_node_type")
	if result4[1] != null:
		return result4[1]
	var bt_node_type: String = result4[0]

	var tree := _find_animation_tree(node_path)
	if tree == null:
		return error_not_found("AnimationTree at '%s'" % node_path)

	var sm_path: String = optional_string(params, "state_machine_path", "")
	var bt_result := _resolve_blend_tree(tree, sm_path, bt_state)
	if bt_result[1] != null:
		return bt_result[1]
	var bt: AnimationNodeBlendTree = bt_result[0]

	var position_x: float = float(params.get("position_x", 0.0))
	var position_y: float = float(params.get("position_y", 0.0))
	var position := Vector2(position_x, position_y)

	# Remove existing node if replacing
	if bt.has_node(StringName(bt_node_name)):
		bt.remove_node(StringName(bt_node_name))

	var node: AnimationNode
	match bt_node_type:
		"Animation":
			var anim_node := AnimationNodeAnimation.new()
			var anim_name: String = optional_string(params, "animation", "")
			if not anim_name.is_empty():
				anim_node.animation = StringName(anim_name)
			node = anim_node
		"Add2":
			node = AnimationNodeAdd2.new()
		"Blend2":
			node = AnimationNodeBlend2.new()
		"Add3":
			node = AnimationNodeAdd3.new()
		"Blend3":
			node = AnimationNodeBlend3.new()
		"TimeScale":
			node = AnimationNodeTimeScale.new()
		"TimeSeek":
			node = AnimationNodeTimeSeek.new()
		"Transition":
			node = AnimationNodeTransition.new()
		"OneShot":
			node = AnimationNodeOneShot.new()
		"Sub2":
			node = AnimationNodeSub2.new()
		_:
			return error_invalid_params("Unknown bt_node_type: '%s'. Use: Animation, Add2, Blend2, Add3, Blend3, TimeScale, TimeSeek, Transition, OneShot, Sub2" % bt_node_type)

	bt.add_node(StringName(bt_node_name), node, position)

	# Connect to another node if specified
	var connect_to: String = optional_string(params, "connect_to", "")
	var connect_port: int = optional_int(params, "connect_port", 0)
	if not connect_to.is_empty():
		bt.connect_node(StringName(connect_to), connect_port, StringName(bt_node_name))

	return success({
		"blend_tree_state": bt_state,
		"bt_node_name": bt_node_name,
		"bt_node_type": bt_node_type,
		"position": {"x": position_x, "y": position_y},
		"connected_to": connect_to if not connect_to.is_empty() else null,
		"added": true,
	})


func _set_tree_parameter(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "parameter")
	if result2[1] != null:
		return result2[1]
	var parameter: String = result2[0]

	var tree := _find_animation_tree(node_path)
	if tree == null:
		return error_not_found("AnimationTree at '%s'" % node_path)

	if not params.has("value"):
		return error_invalid_params("Missing required parameter: value")

	var value = params["value"]

	# Prefix with "parameters/" if not already
	if not parameter.begins_with("parameters/"):
		parameter = "parameters/" + parameter

	# Parse string values for common types
	if value is String:
		var s: String = value
		var expr := Expression.new()
		if expr.parse(s) == OK:
			var parsed = expr.execute()
			if parsed != null:
				value = parsed

	tree.set(parameter, value)

	# Read back to confirm
	var actual = tree.get(parameter)

	return success({
		"parameter": parameter,
		"value": str(actual),
		"set": true,
	})
