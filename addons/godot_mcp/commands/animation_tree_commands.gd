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
		"setup_ik_modifier": _setup_ik_modifier,
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

	add_child_with_undo(parent, tree, root, "MCP: Create AnimationTree")

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
	elif node is AnimationNodeBlendSpace1D or node is AnimationNodeBlendSpace2D:
		return _read_blend_space_structure(node)
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
		elif child is AnimationNodeBlendSpace1D or child is AnimationNodeBlendSpace2D:
			node_info.merge(_read_blend_space_structure(child))
		elif child is AnimationNodeOneShot and _has_property(child, "abort_on_reset"):
			node_info["abort_on_reset"] = child.get("abort_on_reset")
		nodes_info.append(node_info)

	# Read connections
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
	var position_x: float = optional_float(params, "position_x", 0.0)
	var position_y: float = optional_float(params, "position_y", 0.0)
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
		"blend_space_1d", "blend_space_2d":
			var bs_result := _build_blend_space(state_type == "blend_space_2d", params)
			if bs_result[1] != null:
				return bs_result[1]
			node = bs_result[0]
		_:
			return error_invalid_params("Unknown state_type: '%s'. Use 'animation', 'blend_tree', 'state_machine', 'blend_space_1d', or 'blend_space_2d'" % state_type)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add state machine state")
	undo_redo.add_do_method(sm, "add_node", StringName(state_name), node, position)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(sm, "remove_node", StringName(state_name))
	undo_redo.commit_action()

	var state_out := {
		"state_name": state_name,
		"state_type": state_type,
		"position": {"x": position_x, "y": position_y},
		"added": true,
	}
	if node is AnimationNodeBlendSpace1D or node is AnimationNodeBlendSpace2D:
		state_out["blend_space"] = _read_blend_space_structure(node)
	return success(state_out)


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

	var old_node := sm.get_node(StringName(state_name))
	var old_position := sm.get_node_position(StringName(state_name))
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Remove state machine state")
	undo_redo.add_do_method(sm, "remove_node", StringName(state_name))
	undo_redo.add_undo_method(sm, "add_node", StringName(state_name), old_node, old_position)
	undo_redo.add_undo_reference(old_node)
	undo_redo.commit_action()

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
		transition.xfade_time = optional_float(params, "xfade_time")

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add state machine transition")
	undo_redo.add_do_method(sm, "add_transition", StringName(from_state), StringName(to_state), transition)
	undo_redo.add_do_reference(transition)
	undo_redo.add_undo_method(sm, "remove_transition", StringName(from_state), StringName(to_state))
	undo_redo.commit_action()

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

	var transition: AnimationNodeStateMachineTransition = null
	for i in sm.get_transition_count():
		if str(sm.get_transition_from(i)) == from_state and str(sm.get_transition_to(i)) == to_state:
			transition = sm.get_transition(i)
			break

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Remove state machine transition")
	undo_redo.add_do_method(sm, "remove_transition", StringName(from_state), StringName(to_state))
	undo_redo.add_undo_method(sm, "add_transition", StringName(from_state), StringName(to_state), transition)
	undo_redo.add_undo_reference(transition)
	undo_redo.commit_action()

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

	var position_x: float = optional_float(params, "position_x", 0.0)
	var position_y: float = optional_float(params, "position_y", 0.0)
	var position := Vector2(position_x, position_y)

	var had_old_node := bt.has_node(StringName(bt_node_name))
	var old_node: AnimationNode = bt.get_node(StringName(bt_node_name)) if had_old_node else null
	var old_position := bt.get_node_position(StringName(bt_node_name)) if had_old_node else Vector2.ZERO

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
			var one_shot := AnimationNodeOneShot.new()
			if params.has("abort_on_reset"):
				# AnimationNodeOneShot.abort_on_reset is Godot 4.6+.
				if not _has_property(one_shot, "abort_on_reset"):
					return _error_requires_version("OneShot 'abort_on_reset'", "4.6")
				one_shot.set("abort_on_reset", optional_bool(params, "abort_on_reset", false))
			node = one_shot
		"Sub2":
			node = AnimationNodeSub2.new()
		"BlendSpace1D", "BlendSpace2D":
			var bs_result := _build_blend_space(bt_node_type == "BlendSpace2D", params)
			if bs_result[1] != null:
				return bs_result[1]
			node = bs_result[0]
		_:
			return error_invalid_params("Unknown bt_node_type: '%s'. Use: Animation, Add2, Blend2, Add3, Blend3, TimeScale, TimeSeek, Transition, OneShot, Sub2, BlendSpace1D, BlendSpace2D" % bt_node_type)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set blend tree node")
	if had_old_node:
		undo_redo.add_do_method(bt, "remove_node", StringName(bt_node_name))
		undo_redo.add_undo_method(bt, "add_node", StringName(bt_node_name), old_node, old_position)
		undo_redo.add_undo_reference(old_node)
	undo_redo.add_do_method(bt, "add_node", StringName(bt_node_name), node, position)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(bt, "remove_node", StringName(bt_node_name))

	# Connect to another node if specified
	var connect_to: String = optional_string(params, "connect_to", "")
	var connect_port: int = optional_int(params, "connect_port", 0)
	if not connect_to.is_empty():
		undo_redo.add_do_method(bt, "connect_node", StringName(connect_to), connect_port, StringName(bt_node_name))
	undo_redo.commit_action()

	var connected_to_value: Variant = null
	if not connect_to.is_empty():
		connected_to_value = connect_to
	var bt_out := {
		"blend_tree_state": bt_state,
		"bt_node_name": bt_node_name,
		"bt_node_type": bt_node_type,
		"position": {"x": position_x, "y": position_y},
		"connected_to": connected_to_value,
		"added": true,
	}
	if node is AnimationNodeBlendSpace1D or node is AnimationNodeBlendSpace2D:
		bt_out["blend_space"] = _read_blend_space_structure(node)
	elif node is AnimationNodeOneShot and params.has("abort_on_reset"):
		bt_out["abort_on_reset"] = node.get("abort_on_reset")
	return success(bt_out)


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

	set_property_with_undo(tree, parameter, value, "MCP: Set AnimationTree parameter")

	# Read back to confirm
	var actual = tree.get(parameter)

	return success({
		"parameter": parameter,
		"value": str(actual),
		"set": true,
	})


## ─── Version-aware helpers ─────────────────────────────────────────────────

## Error for a feature the running Godot does not have (-32601, the same code
## base_command uses for version-gated tools). Names both the
## required and the running version so an older editor is not mistaken for a
## typo in the request.
func _error_requires_version(feature: String, required: String) -> Dictionary:
	var running: String = Engine.get_version_info().get("string", "unknown")
	return error(-32601, "%s requires Godot %s+ (running %s)" % [feature, required, running], {
		"required_version": required,
		"running_version": running,
	})


## True when `obj` really exposes `prop` (checked on its property list, so no
## version number is assumed).
func _has_property(obj: Object, prop: String) -> bool:
	for p: Dictionary in obj.get_property_list():
		if p["name"] == prop:
			return true
	return false


## ─── Blend spaces ──────────────────────────────────────────────────────────

## AnimationNodeBlendSpace1D/2D.SyncMode (Godot 4.7+), in enum order.
const _BLEND_SPACE_SYNC_MODES := ["none", "independent", "cyclic_mutable", "cyclic_constant"]


## Returns [position, error_or_null]: a float for 1D, a Vector2 for 2D.
func _parse_blend_position(value: Variant, is_2d: bool) -> Array:
	if is_2d:
		if value is Dictionary:
			return [Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0))), null]
		if value is Array and value.size() >= 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int):
			return [Vector2(float(value[0]), float(value[1])), null]
		return [null, "2D blend positions must be {x, y} or [x, y]"]
	if value is float or value is int:
		return [float(value), null]
	return [null, "1D blend positions must be a number"]


## Builds an AnimationNodeBlendSpace1D/2D from params:
##   min_space / max_space, sync (bool, all versions), sync_mode (4.7+),
##   cyclic_length (4.7+), blend_points [{animation, position, name (4.7+)}].
## Returns [blend_space, error_or_null]. Nothing 4.7-only is referenced
## statically, so the file still parses on 4.5.
const _MAX_BLEND_POINTS := 64


func _build_blend_space(is_2d: bool, params: Dictionary) -> Array:
	var bs: AnimationRootNode
	if is_2d:
		bs = AnimationNodeBlendSpace2D.new()
	else:
		bs = AnimationNodeBlendSpace1D.new()

	# Godot clamps each bound against the other one's CURRENT value (default
	# -1..1), so setting min_space=2 before max_space=4 silently produced
	# 0..4. Validate the pair, apply both twice (the second pass lands every
	# value once the first has widened the range), then verify.
	var bounds := {}
	for key: String in ["min_space", "max_space"]:
		if params.has(key):
			var parsed := _parse_blend_position(params[key], is_2d)
			if parsed[1] != null:
				return [null, error_invalid_params("'%s': %s" % [key, parsed[1]])]
			bounds[key] = parsed[0]
	if not bounds.is_empty():
		var want_min: Variant = bounds.get("min_space", bs.get("min_space"))
		var want_max: Variant = bounds.get("max_space", bs.get("max_space"))
		var ordered: bool = (want_min.x < want_max.x and want_min.y < want_max.y) if is_2d else (float(want_min) < float(want_max))
		if not ordered:
			return [null, error_invalid_params("min_space must be below max_space on every axis (got %s and %s)" % [str(want_min), str(want_max)])]
		for _pass in 2:
			bs.set("min_space", want_min)
			bs.set("max_space", want_max)
		# Godot stores the bounds as 32-bit floats, so compare approximately.
		var got_min: Variant = bs.get("min_space")
		var got_max: Variant = bs.get("max_space")
		var same: bool = (got_min.is_equal_approx(want_min) and got_max.is_equal_approx(want_max)) if is_2d else (is_equal_approx(float(got_min), float(want_min)) and is_equal_approx(float(got_max), float(want_max)))
		if not same:
			return [null, error_internal("Godot kept the blend space range at %s..%s instead of %s..%s" % [str(bs.get("min_space")), str(bs.get("max_space")), str(want_min), str(want_max)])]

	if params.has("sync"):
		bs.set("sync", optional_bool(params, "sync", false))

	if params.has("sync_mode"):
		var mode_str := optional_string(params, "sync_mode", "").to_lower()
		var mode_idx := _BLEND_SPACE_SYNC_MODES.find(mode_str)
		if mode_idx == -1:
			return [null, error_invalid_params("Unknown sync_mode '%s'. Use: %s" % [mode_str, ", ".join(_BLEND_SPACE_SYNC_MODES)])]
		if _has_property(bs, "sync_mode"):
			bs.set("sync_mode", mode_idx)
		elif mode_idx <= 1:
			# Before 4.7 there is only the boolean: none = false, independent = true.
			bs.set("sync", mode_idx == 1)
		else:
			return [null, _error_requires_version("Blend space sync_mode '%s'" % mode_str, "4.7")]

	if params.has("cyclic_length"):
		if not _has_property(bs, "cyclic_length"):
			return [null, _error_requires_version("Blend space 'cyclic_length'", "4.7")]
		bs.set("cyclic_length", optional_float(params, "cyclic_length", 0.0))

	if params.has("blend_points"):
		var arr_err := require_dictionary_array(params, "blend_points")
		if not arr_err.is_empty():
			return [null, arr_err]
		var supports_names := bs.has_method("find_blend_point_by_name")
		var used_names := {}
		var points: Array = params["blend_points"]
		# Godot refuses points beyond MAX_BLEND_POINTS (64, 1D and 2D) with
		# only an engine error, so the state would be created short.
		if points.size() > _MAX_BLEND_POINTS:
			return [null, error_invalid_params("A blend space holds at most %d points; got %d" % [_MAX_BLEND_POINTS, points.size()])]
		for i in points.size():
			var pt: Dictionary = points[i]
			if not pt.has("position"):
				return [null, error_invalid_params("blend_points[%d] is missing 'position'" % i)]
			var pos := _parse_blend_position(pt["position"], is_2d)
			if pos[1] != null:
				return [null, error_invalid_params("blend_points[%d]: %s" % [i, pos[1]])]
			var anim_node := AnimationNodeAnimation.new()
			var anim_name := str(pt.get("animation", ""))
			if not anim_name.is_empty():
				anim_node.animation = StringName(anim_name)
			var point_name := str(pt.get("name", ""))
			if not point_name.is_empty() and not supports_names:
				return [null, _error_requires_version("Named blend points (blend_points[%d].name)" % i, "4.7")]
			if supports_names:
				# 4.7 warns about unnamed points; default to the animation name
				# (or point_<i>) so every point stays addressable by name.
				# Godot rejects '/', '.', ':' and similar when it reloads the
				# scene (a different setter than add_blend_point), so a name
				# like "locomotion/walk" silently became "0" after reload.
				if not point_name.is_empty() and point_name.validate_node_name() != point_name:
					return [null, error_invalid_params("blend_points[%d].name '%s' contains characters Godot cannot store in a blend point name (e.g. / . :)" % [i, point_name])]
				if point_name.is_empty():
					var base_name := anim_name.validate_node_name().replace("@", "_")
					if base_name.is_empty():
						base_name = "point_%d" % i
					point_name = base_name
					var suffix := 2
					while used_names.has(point_name):
						point_name = "%s_%d" % [base_name, suffix]
						suffix += 1
				if used_names.has(point_name):
					return [null, error_invalid_params("Duplicate blend point name '%s'" % point_name)]
				used_names[point_name] = true
				bs.call("add_blend_point", anim_node, pos[0], -1, StringName(point_name))
			else:
				bs.call("add_blend_point", anim_node, pos[0])
	if params.has("blend_points"):
		var expected := (params["blend_points"] as Array).size()
		var got: int = bs.call("get_blend_point_count")
		if got != expected:
			return [null, error_internal("Godot accepted %d of %d blend points" % [got, expected])]
	return [bs, null]


func _read_blend_space_structure(bs: AnimationRootNode) -> Dictionary:
	var is_2d := bs is AnimationNodeBlendSpace2D
	var info := {"type": bs.get_class()}
	var min_space: Variant = bs.get("min_space")
	var max_space: Variant = bs.get("max_space")
	if is_2d:
		info["min_space"] = {"x": (min_space as Vector2).x, "y": (min_space as Vector2).y}
		info["max_space"] = {"x": (max_space as Vector2).x, "y": (max_space as Vector2).y}
	else:
		info["min_space"] = min_space
		info["max_space"] = max_space
	info["sync"] = bs.get("sync")
	if _has_property(bs, "sync_mode"):
		var mode: int = bs.get("sync_mode")
		info["sync_mode"] = _BLEND_SPACE_SYNC_MODES[mode] if mode >= 0 and mode < _BLEND_SPACE_SYNC_MODES.size() else mode
	if _has_property(bs, "cyclic_length"):
		info["cyclic_length"] = bs.get("cyclic_length")
	var has_names := bs.has_method("get_blend_point_name")
	var points: Array = []
	var count: int = bs.call("get_blend_point_count")
	for i in count:
		var pos: Variant = bs.call("get_blend_point_position", i)
		var point := {"index": i}
		if is_2d:
			point["position"] = {"x": (pos as Vector2).x, "y": (pos as Vector2).y}
		else:
			point["position"] = pos
		if has_names:
			point["name"] = str(bs.call("get_blend_point_name", i))
		var pnode: Variant = bs.call("get_blend_point_node", i)
		if pnode is AnimationNode:
			point["node_type"] = (pnode as AnimationNode).get_class()
			if pnode is AnimationNodeAnimation:
				point["animation"] = str((pnode as AnimationNodeAnimation).animation)
		points.append(point)
	info["points"] = points
	return info


## ─── setup_ik_modifier (Godot 4.6+) ─────────────────────────────────────────

const _IK_TYPES := ["TwoBoneIK3D", "CCDIK3D", "FABRIK3D", "JacobianIK3D", "SplineIK3D"]
const _ITERATE_IK_TYPES := ["CCDIK3D", "FABRIK3D", "JacobianIK3D"]
## SkeletonModifier3D.SecondaryDirection (pole direction), in enum order.
const _POLE_DIRECTIONS := ["none", "+x", "-x", "+y", "-y", "+z", "-z", "custom"]
## SkeletonModifier3D.BoneDirection (end bone direction), in enum order.
const _BONE_DIRECTIONS := ["+x", "-x", "+y", "-y", "+z", "-z", "from_parent"]


func _normalize_axis_name(value: String) -> String:
	return value.strip_edges().to_lower().replace("plus_", "+").replace("minus_", "-").replace(" ", "_")


func _is_bone_descendant(skel: Skeleton3D, bone: int, ancestor: int) -> bool:
	var cur := skel.get_bone_parent(bone)
	while cur != -1:
		if cur == ancestor:
			return true
		cur = skel.get_bone_parent(cur)
	return false


## Resolves a scene node path and returns it as a NodePath relative to a
## modifier that will be a direct child of `skel`. Returns [NodePath, error].
func _ik_node_path(skel: Skeleton3D, scene_path: String, what: String, required_class: String) -> Array:
	var target := find_node_by_path(scene_path)
	if target == null:
		return [null, error_not_found("%s node '%s'" % [what, scene_path])]
	if not target.is_class(required_class):
		return [null, error_invalid_params("%s node '%s' must be a %s (is %s)" % [what, scene_path, required_class, target.get_class()])]
	if target == skel:
		return [NodePath(".."), null]
	return [NodePath("../" + str(skel.get_path_to(target))), null]


## Returns [bone_index, bone_name, error_or_null].
func _require_bone(skel: Skeleton3D, setting: Dictionary, key: String, index: int) -> Array:
	var bone_name := str(setting.get(key, ""))
	if bone_name.is_empty():
		return [-1, "", error_invalid_params("settings[%d].%s is required" % [index, key])]
	var idx := skel.find_bone(bone_name)
	if idx == -1:
		var names: Array = []
		for b in mini(skel.get_bone_count(), 40):
			names.append(skel.get_bone_name(b))
		return [-1, bone_name, error_not_found(
			"Bone '%s' (settings[%d].%s) on skeleton '%s'" % [bone_name, index, key, skel.name],
			"Available bones%s: %s" % [" (first 40)" if skel.get_bone_count() > 40 else "", ", ".join(names)]
		)]
	return [idx, bone_name, null]


## Validates and applies one IK setting through the indexed setters. Returns
## {} or an error dictionary.
func _apply_ik_setting(modifier: Node, ik_type: String, skel: Skeleton3D, i: int, s: Dictionary) -> Dictionary:
	var is_two_bone := ik_type == "TwoBoneIK3D"
	var is_spline := ik_type == "SplineIK3D"

	var root_r := _require_bone(skel, s, "root_bone", i)
	if root_r[2] != null:
		return root_r[2]
	var root_idx: int = root_r[0]

	var use_virtual_end := optional_bool(s, "use_virtual_end", false)
	var end_idx := -1
	var end_name := ""
	if not (is_two_bone and use_virtual_end and not s.has("end_bone")):
		var end_r := _require_bone(skel, s, "end_bone", i)
		if end_r[2] != null:
			return end_r[2]
		end_idx = end_r[0]
		end_name = end_r[1]

	if is_two_bone:
		var mid_r := _require_bone(skel, s, "middle_bone", i)
		if mid_r[2] != null:
			return mid_r[2]
		var mid_idx: int = mid_r[0]
		if not _is_bone_descendant(skel, mid_idx, root_idx):
			return error_invalid_params("settings[%d]: middle_bone '%s' is not a descendant of root_bone '%s'" % [i, mid_r[1], root_r[1]])
		if end_idx != -1 and not _is_bone_descendant(skel, end_idx, mid_idx):
			return error_invalid_params("settings[%d]: end_bone '%s' is not a descendant of middle_bone '%s'" % [i, end_name, mid_r[1]])
		modifier.call("set_root_bone_name", i, root_r[1])
		modifier.call("set_middle_bone_name", i, mid_r[1])
		if end_idx != -1:
			modifier.call("set_end_bone_name", i, end_name)
		if s.has("use_virtual_end"):
			modifier.call("set_use_virtual_end", i, use_virtual_end)
	else:
		if not _is_bone_descendant(skel, end_idx, root_idx):
			return error_invalid_params("settings[%d]: end_bone '%s' is not a descendant of root_bone '%s'" % [i, end_name, root_r[1]])
		modifier.call("set_root_bone_name", i, root_r[1])
		modifier.call("set_end_bone_name", i, end_name)

	# Optional end-bone extension (all IK types).
	if s.has("extend_end_bone") or s.has("end_bone_length") or s.has("end_bone_direction"):
		modifier.call("set_extend_end_bone", i, optional_bool(s, "extend_end_bone", true))
	if s.has("end_bone_length"):
		modifier.call("set_end_bone_length", i, maxf(optional_float(s, "end_bone_length", 0.0), 0.0))
	if s.has("end_bone_direction"):
		var dir_name := _normalize_axis_name(str(s["end_bone_direction"]))
		var dir_idx := _BONE_DIRECTIONS.find(dir_name)
		if dir_idx == -1:
			return error_invalid_params("settings[%d].end_bone_direction '%s' unknown. Use: %s" % [i, dir_name, ", ".join(_BONE_DIRECTIONS)])
		modifier.call("set_end_bone_direction", i, dir_idx)

	if is_spline:
		var path_str := str(s.get("path_3d", ""))
		if path_str.is_empty():
			return error_invalid_params("settings[%d].path_3d (a Path3D node) is required for SplineIK3D" % i)
		var p := _ik_node_path(skel, path_str, "path_3d", "Path3D")
		if p[1] != null:
			return p[1]
		modifier.call("set_path_3d", i, p[0])
		if s.has("tilt_enabled"):
			modifier.call("set_tilt_enabled", i, optional_bool(s, "tilt_enabled", false))
	else:
		var target_str := str(s.get("target_path", ""))
		if not target_str.is_empty():
			var t := _ik_node_path(skel, target_str, "target_path", "Node3D")
			if t[1] != null:
				return t[1]
			modifier.call("set_target_node", i, t[0])

	if is_two_bone:
		var pole_str := str(s.get("pole_path", ""))
		if not pole_str.is_empty():
			var pp := _ik_node_path(skel, pole_str, "pole_path", "Node3D")
			if pp[1] != null:
				return pp[1]
			modifier.call("set_pole_node", i, pp[0])
		if s.has("pole_direction"):
			var pole_dir := _normalize_axis_name(str(s["pole_direction"]))
			var pole_idx := _POLE_DIRECTIONS.find(pole_dir)
			if pole_idx == -1:
				return error_invalid_params("settings[%d].pole_direction '%s' unknown. Use: %s" % [i, pole_dir, ", ".join(_POLE_DIRECTIONS)])
			modifier.call("set_pole_direction", i, pole_idx)
		if s.has("pole_direction_vector"):
			var v: Variant = s["pole_direction_vector"]
			if not v is Dictionary:
				return error_invalid_params("settings[%d].pole_direction_vector must be {x, y, z}" % i)
			modifier.call("set_pole_direction", i, _POLE_DIRECTIONS.find("custom"))
			modifier.call("set_pole_direction_vector", i, Vector3(float(v.get("x", 0.0)), float(v.get("y", 0.0)), float(v.get("z", 0.0))))
	elif s.has("pole_path") or s.has("pole_direction") or s.has("pole_direction_vector"):
		return error_invalid_params("settings[%d]: pole_path/pole_direction only apply to TwoBoneIK3D" % i)
	return {}


func _read_ik_settings(modifier: Node, ik_type: String) -> Array:
	var out: Array = []
	var count: int = modifier.get("setting_count")
	for i in count:
		var s := {
			"root_bone": str(modifier.call("get_root_bone_name", i)),
			"end_bone": str(modifier.call("get_end_bone_name", i)),
		}
		if ik_type == "TwoBoneIK3D":
			s["middle_bone"] = str(modifier.call("get_middle_bone_name", i))
			s["target_node"] = str(modifier.call("get_target_node", i))
			s["pole_node"] = str(modifier.call("get_pole_node", i))
			var pd: int = modifier.call("get_pole_direction", i)
			s["pole_direction"] = _POLE_DIRECTIONS[pd] if pd >= 0 and pd < _POLE_DIRECTIONS.size() else pd
			s["use_virtual_end"] = modifier.call("is_using_virtual_end", i)
		elif ik_type == "SplineIK3D":
			s["path_3d"] = str(modifier.call("get_path_3d", i))
		else:
			s["target_node"] = str(modifier.call("get_target_node", i))
		if modifier.has_method("get_joint_count"):
			s["joint_count"] = modifier.call("get_joint_count", i)
		out.append(s)
	return out


func _setup_ik_modifier(params: Dictionary) -> Dictionary:
	var result := require_string(params, "skeleton_path")
	if result[1] != null:
		return result[1]
	var skeleton_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var ik_type := optional_string(params, "ik_type", "TwoBoneIK3D")
	if not ik_type in _IK_TYPES:
		return error_invalid_params("Unknown ik_type '%s'. Use: %s" % [ik_type, ", ".join(_IK_TYPES)])
	# IK modifiers are Godot 4.6+, so they are never referenced statically.
	if not ClassDB.class_exists(ik_type) or not ClassDB.can_instantiate(ik_type):
		return _error_requires_version(ik_type, "4.6")

	var skel_node := find_node_by_path(skeleton_path)
	if skel_node == null:
		return error_not_found("Skeleton3D '%s'" % skeleton_path, "Use find_nodes_by_type with type 'Skeleton3D'")
	if not skel_node is Skeleton3D:
		return error_invalid_params("Node '%s' is not a Skeleton3D (is %s)" % [skeleton_path, skel_node.get_class()])
	var skel := skel_node as Skeleton3D
	if skel.get_bone_count() == 0:
		return error_invalid_params("Skeleton3D '%s' has no bones" % skeleton_path)

	var iterate_keys := ["max_iterations", "min_distance", "angular_delta_limit", "deterministic"]
	for key: String in iterate_keys:
		if params.has(key) and not ik_type in _ITERATE_IK_TYPES:
			return error_invalid_params("'%s' only applies to %s" % [key, ", ".join(_ITERATE_IK_TYPES)])

	# Either an explicit settings array, or a single setting given top-level.
	var settings: Array = []
	if params.has("settings"):
		var arr_err := require_dictionary_array(params, "settings")
		if not arr_err.is_empty():
			return arr_err
		settings = params["settings"]
		if settings.is_empty():
			return error_invalid_params("'settings' must contain at least one entry")
	else:
		var single := {}
		for key: String in ["root_bone", "middle_bone", "end_bone", "target_path", "pole_path", "pole_direction",
				"pole_direction_vector", "path_3d", "use_virtual_end", "extend_end_bone", "end_bone_length",
				"end_bone_direction", "tilt_enabled"]:
			if params.has(key):
				single[key] = params[key]
		settings = [single]

	var modifier: Node = ClassDB.instantiate(ik_type)
	modifier.name = optional_string(params, "name", ik_type)
	modifier.set("setting_count", settings.size())

	for i in settings.size():
		var err := _apply_ik_setting(modifier, ik_type, skel, i, settings[i])
		if not err.is_empty():
			modifier.free()
			return err

	if params.has("influence"):
		modifier.set("influence", clampf(optional_float(params, "influence", 1.0), 0.0, 1.0))
	if params.has("active"):
		modifier.set("active", optional_bool(params, "active", true))
	if params.has("mutable_bone_axes"):
		modifier.set("mutable_bone_axes", optional_bool(params, "mutable_bone_axes", true))
	if params.has("max_iterations"):
		modifier.set("max_iterations", maxi(optional_int(params, "max_iterations", 4), 0))
	if params.has("min_distance"):
		modifier.set("min_distance", maxf(optional_float(params, "min_distance", 0.001), 0.0))
	if params.has("angular_delta_limit"):
		# Taken in degrees like the inspector shows it; stored in radians.
		modifier.set("angular_delta_limit", deg_to_rad(optional_float(params, "angular_delta_limit", 2.0)))
	if params.has("deterministic"):
		modifier.set("deterministic", optional_bool(params, "deterministic", false))

	add_child_with_undo(skel, modifier, root, "MCP: Add %s" % ik_type)

	# A chain without its driver node is accepted (it can be wired up later)
	# but does nothing until then. TwoBoneIK3D in particular leaves the pose
	# untouched without a pole node (observed on 4.6.2 and 4.7.2).
	var warnings: Array = []
	for i in settings.size():
		var s: Dictionary = settings[i]
		if ik_type == "TwoBoneIK3D" and str(s.get("pole_path", "")).is_empty():
			warnings.append("settings[%d]: no pole_path; TwoBoneIK3D does not bend the chain until a pole node is set" % i)
		if ik_type != "SplineIK3D" and str(s.get("target_path", "")).is_empty():
			warnings.append("settings[%d]: no target_path; the chain is not driven until a target node is set" % i)

	var out := {
		"node_path": str(root.get_path_to(modifier)),
		"name": str(modifier.name),
		"ik_type": ik_type,
		"skeleton": str(root.get_path_to(skel)),
		"setting_count": modifier.get("setting_count"),
		"settings": _read_ik_settings(modifier, ik_type),
		"influence": modifier.get("influence"),
		"active": modifier.get("active"),
	}
	if not warnings.is_empty():
		out["warnings"] = warnings
	return success(out)
