@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"list_animations": _list_animations,
		"create_animation": _create_animation,
		"add_animation_track": _add_animation_track,
		"set_animation_keyframe": _set_animation_keyframe,
		"get_animation_info": _get_animation_info,
		"remove_animation": _remove_animation,
	}


func _find_animation_player(node_path: String) -> AnimationPlayer:
	var node := find_node_by_path(node_path)
	if node is AnimationPlayer:
		return node as AnimationPlayer
	return null


func _list_animations(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var animations: Array = []
	for anim_name in player.get_animation_list():
		var anim := player.get_animation(anim_name)
		animations.append({
			"name": anim_name,
			"length": anim.length,
			"loop_mode": anim.loop_mode,
			"track_count": anim.get_track_count(),
		})

	return success({"node_path": node_path, "animations": animations, "count": animations.size()})


func _create_animation(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var length: float = float(params.get("length", 1.0))
	var loop_mode: int = int(params.get("loop_mode", 0))  # 0=none, 1=linear, 2=pingpong

	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = loop_mode as Animation.LoopMode

	var lib := player.get_animation_library("")
	var created_library := false
	if lib == null:
		lib = AnimationLibrary.new()
		created_library = true

	if lib.has_animation(anim_name):
		return error_invalid_params("Animation '%s' already exists" % anim_name)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Create animation %s" % anim_name)
	if created_library:
		undo_redo.add_do_method(player, "add_animation_library", "", lib)
		undo_redo.add_do_reference(lib)
		undo_redo.add_undo_method(player, "remove_animation_library", "")
	undo_redo.add_do_method(lib, "add_animation", anim_name, anim)
	undo_redo.add_do_reference(anim)
	undo_redo.add_undo_method(lib, "remove_animation", anim_name)
	undo_redo.commit_action()

	return success({"name": anim_name, "length": length, "created": true})


func _add_animation_track(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "animation")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var result3 := require_string(params, "track_path")
	if result3[1] != null:
		return result3[1]
	var track_path: String = result3[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var anim := player.get_animation(anim_name)
	if anim == null:
		return error_not_found("Animation '%s'" % anim_name)

	var track_type_str: String = optional_string(params, "track_type", "value")
	var track_type: int
	match track_type_str:
		"value": track_type = Animation.TYPE_VALUE
		"position_2d": track_type = Animation.TYPE_POSITION_3D  # Godot uses 3D type for 2D too
		"rotation_2d": track_type = Animation.TYPE_ROTATION_3D
		"scale_2d": track_type = Animation.TYPE_SCALE_3D
		"method": track_type = Animation.TYPE_METHOD
		"bezier": track_type = Animation.TYPE_BEZIER
		"blend_shape": track_type = Animation.TYPE_BLEND_SHAPE
		_: track_type = Animation.TYPE_VALUE

	var track_idx := anim.get_track_count()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Add animation track")
	undo_redo.add_do_method(anim, "add_track", track_type, track_idx)
	undo_redo.add_do_method(anim, "track_set_path", track_idx, NodePath(track_path))

	var update_mode_str: String = optional_string(params, "update_mode", "")
	if not update_mode_str.is_empty() and track_type == Animation.TYPE_VALUE:
		match update_mode_str:
			"continuous": undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_CONTINUOUS)
			"discrete": undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_DISCRETE)
			"capture": undo_redo.add_do_method(anim, "value_track_set_update_mode", track_idx, Animation.UPDATE_CAPTURE)
	undo_redo.add_undo_method(anim, "remove_track", track_idx)
	undo_redo.commit_action()

	return success({"track_index": track_idx, "track_path": track_path, "track_type": track_type_str})


func _set_animation_keyframe(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "animation")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var anim := player.get_animation(anim_name)
	if anim == null:
		return error_not_found("Animation '%s'" % anim_name)

	var track_index: int = int(params.get("track_index", 0))
	if track_index < 0 or track_index >= anim.get_track_count():
		return error_invalid_params("Invalid track_index: %d" % track_index)

	var time: float = float(params.get("time", 0.0))
	var value = params.get("value")

	# Parse value string for common types
	if value is String:
		var s: String = value
		var expr := Expression.new()
		if expr.parse(s) == OK:
			var parsed = expr.execute()
			if parsed != null:
				value = parsed

	var easing: float = float(params.get("easing", 1.0))
	var old_key_idx := _find_animation_key_at_time(anim, track_index, time)
	var had_old_key := old_key_idx >= 0
	var old_value: Variant = anim.track_get_key_value(track_index, old_key_idx) if had_old_key else null
	var old_easing: float = anim.track_get_key_transition(track_index, old_key_idx) if had_old_key else 1.0

	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set animation keyframe")
	undo_redo.add_do_method(self, "_upsert_animation_key", anim, track_index, time, value, easing)
	undo_redo.add_undo_method(self, "_restore_animation_key", anim, track_index, time, had_old_key, old_value, old_easing)
	undo_redo.commit_action()

	var key_idx := _find_animation_key_at_time(anim, track_index, time)

	return success({"track_index": track_index, "time": time, "key_index": key_idx, "easing": anim.track_get_key_transition(track_index, key_idx)})


func _get_animation_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "animation")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var anim := player.get_animation(anim_name)
	if anim == null:
		return error_not_found("Animation '%s'" % anim_name)

	var tracks: Array = []
	for i in anim.get_track_count():
		var track_info := {
			"index": i,
			"path": str(anim.track_get_path(i)),
			"type": anim.track_get_type(i),
			"key_count": anim.track_get_key_count(i),
		}
		var keys: Array = []
		for k in anim.track_get_key_count(i):
			keys.append({
				"time": anim.track_get_key_time(i, k),
				"value": str(anim.track_get_key_value(i, k)),
				"easing": anim.track_get_key_transition(i, k),
			})
		track_info["keys"] = keys
		tracks.append(track_info)

	return success({
		"name": anim_name,
		"length": anim.length,
		"loop_mode": anim.loop_mode,
		"step": anim.step,
		"tracks": tracks,
	})


func _remove_animation(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var anim_name: String = result2[0]

	var player := _find_animation_player(node_path)
	if player == null:
		return error_not_found("AnimationPlayer at '%s'" % node_path)

	var lib := player.get_animation_library("")
	if lib == null or not lib.has_animation(anim_name):
		return error_not_found("Animation '%s'" % anim_name)

	var anim := lib.get_animation(anim_name)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Remove animation %s" % anim_name)
	undo_redo.add_do_method(lib, "remove_animation", anim_name)
	undo_redo.add_undo_method(lib, "add_animation", anim_name, anim)
	undo_redo.add_undo_reference(anim)
	undo_redo.commit_action()
	return success({"name": anim_name, "removed": true})


func _find_animation_key_at_time(anim: Animation, track_index: int, time: float) -> int:
	for key_index: int in anim.track_get_key_count(track_index):
		if is_equal_approx(anim.track_get_key_time(track_index, key_index), time):
			return key_index
	return -1


func _upsert_animation_key(anim: Animation, track_index: int, time: float, value: Variant, easing: float) -> void:
	var key_idx := _find_animation_key_at_time(anim, track_index, time)
	if key_idx < 0:
		key_idx = anim.track_insert_key(track_index, time, value)
	else:
		anim.track_set_key_value(track_index, key_idx, value)
	if easing != 1.0:
		anim.track_set_key_transition(track_index, key_idx, easing)


func _restore_animation_key(anim: Animation, track_index: int, time: float, had_old_key: bool, old_value: Variant, old_easing: float) -> void:
	var key_idx := _find_animation_key_at_time(anim, track_index, time)
	if had_old_key:
		if key_idx < 0:
			key_idx = anim.track_insert_key(track_index, time, old_value)
		else:
			anim.track_set_key_value(track_index, key_idx, old_value)
		anim.track_set_key_transition(track_index, key_idx, old_easing)
	elif key_idx >= 0:
		anim.track_remove_key(track_index, key_idx)
