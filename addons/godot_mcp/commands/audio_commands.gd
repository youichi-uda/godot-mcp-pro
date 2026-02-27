@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"get_audio_bus_layout": _get_audio_bus_layout,
		"add_audio_bus": _add_audio_bus,
		"set_audio_bus": _set_audio_bus,
		"add_audio_bus_effect": _add_audio_bus_effect,
		"add_audio_player": _add_audio_player,
		"get_audio_info": _get_audio_info,
	}


func _get_audio_bus_layout(_params: Dictionary) -> Dictionary:
	var buses: Array[Dictionary] = []
	for i in range(AudioServer.bus_count):
		var bus_data := {
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"solo": AudioServer.is_bus_solo(i),
			"mute": AudioServer.is_bus_mute(i),
			"bypass_effects": AudioServer.is_bus_bypassing_effects(i),
			"send": AudioServer.get_bus_send(i),
			"effects": [],
		}
		var effects: Array[Dictionary] = []
		for j in range(AudioServer.get_bus_effect_count(i)):
			var effect := AudioServer.get_bus_effect(i, j)
			var effect_data := {
				"index": j,
				"type": effect.get_class(),
				"enabled": AudioServer.is_bus_effect_enabled(i, j),
			}
			# Include effect-specific parameters
			effect_data["params"] = _get_effect_params(effect)
			effects.append(effect_data)
		bus_data["effects"] = effects
		buses.append(bus_data)
	return success({"bus_count": AudioServer.bus_count, "buses": buses})


func _get_effect_params(effect: AudioEffect) -> Dictionary:
	var params := {}
	if effect is AudioEffectReverb:
		var rev := effect as AudioEffectReverb
		params = {"room_size": rev.room_size, "damping": rev.damping, "wet": rev.wet, "dry": rev.dry, "spread": rev.spread}
	elif effect is AudioEffectDelay:
		var d := effect as AudioEffectDelay
		params = {"tap1_active": d.tap1_active, "tap1_delay_ms": d.tap1_delay_ms, "tap1_level_db": d.tap1_level_db, "tap2_active": d.tap2_active, "tap2_delay_ms": d.tap2_delay_ms, "tap2_level_db": d.tap2_level_db}
	elif effect is AudioEffectCompressor:
		var c := effect as AudioEffectCompressor
		params = {"threshold": c.threshold, "ratio": c.ratio, "attack_us": c.attack_us, "release_ms": c.release_ms, "gain": c.gain, "mix": c.mix, "sidechain": c.sidechain}
	elif effect is AudioEffectLimiter:
		var l := effect as AudioEffectLimiter
		params = {"ceiling_db": l.ceiling_db, "threshold_db": l.threshold_db, "soft_clip_db": l.soft_clip_db, "soft_clip_ratio": l.soft_clip_ratio}
	elif effect is AudioEffectDistortion:
		var dist := effect as AudioEffectDistortion
		params = {"mode": dist.mode, "pre_gain": dist.pre_gain, "post_gain": dist.post_gain, "keep_hf_hz": dist.keep_hf_hz, "drive": dist.drive}
	elif effect is AudioEffectChorus:
		var ch := effect as AudioEffectChorus
		params = {"voice_count": ch.voice_count, "dry": ch.dry, "wet": ch.wet}
	elif effect is AudioEffectPhaser:
		var ph := effect as AudioEffectPhaser
		params = {"range_min_hz": ph.range_min_hz, "range_max_hz": ph.range_max_hz, "rate_hz": ph.rate_hz, "feedback": ph.feedback, "depth": ph.depth}
	elif effect is AudioEffectFilter:
		# Covers LowPassFilter, HighPassFilter, BandPassFilter, etc.
		var f := effect as AudioEffectFilter
		params = {"cutoff_hz": f.cutoff_hz, "resonance": f.resonance, "gain": f.gain, "db": f.db}
	elif effect is AudioEffectAmplify:
		var a := effect as AudioEffectAmplify
		params = {"volume_db": a.volume_db}
	return params


func _add_audio_bus(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var bus_name: String = result[0]

	# Check if bus name already exists
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return error_invalid_params("Audio bus '%s' already exists at index %d" % [bus_name, i])

	var at_position: int = optional_int(params, "at_position", -1)
	AudioServer.add_bus(at_position)

	var idx: int = AudioServer.bus_count - 1 if at_position < 0 else at_position
	AudioServer.set_bus_name(idx, bus_name)

	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(idx, float(params["volume_db"]))

	var send: String = optional_string(params, "send", "")
	if not send.is_empty():
		AudioServer.set_bus_send(idx, send)

	if params.has("solo"):
		AudioServer.set_bus_solo(idx, bool(params["solo"]))

	if params.has("mute"):
		AudioServer.set_bus_mute(idx, bool(params["mute"]))

	return success({"name": bus_name, "index": idx, "bus_count": AudioServer.bus_count})


func _set_audio_bus(params: Dictionary) -> Dictionary:
	var result := require_string(params, "name")
	if result[1] != null:
		return result[1]
	var bus_name: String = result[0]

	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return error_not_found("Audio bus '%s'" % bus_name)

	var changes := 0

	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(idx, float(params["volume_db"]))
		changes += 1

	if params.has("solo"):
		AudioServer.set_bus_solo(idx, bool(params["solo"]))
		changes += 1

	if params.has("mute"):
		AudioServer.set_bus_mute(idx, bool(params["mute"]))
		changes += 1

	if params.has("bypass_effects"):
		AudioServer.set_bus_bypass_effects(idx, bool(params["bypass_effects"]))
		changes += 1

	var send: String = optional_string(params, "send", "")
	if not send.is_empty():
		AudioServer.set_bus_send(idx, send)
		changes += 1

	if params.has("rename"):
		var new_name: String = str(params["rename"])
		AudioServer.set_bus_name(idx, new_name)
		bus_name = new_name
		changes += 1

	return success({"name": bus_name, "index": idx, "changes": changes})


func _add_audio_bus_effect(params: Dictionary) -> Dictionary:
	var result := require_string(params, "bus")
	if result[1] != null:
		return result[1]
	var bus_name: String = result[0]

	var result2 := require_string(params, "effect_type")
	if result2[1] != null:
		return result2[1]
	var effect_type: String = result2[0]

	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return error_not_found("Audio bus '%s'" % bus_name)

	var effect: AudioEffect = null
	var effect_params: Dictionary = params.get("params", {}) if params.has("params") else {}

	match effect_type.to_lower():
		"reverb":
			var e := AudioEffectReverb.new()
			if effect_params.has("room_size"):
				e.room_size = float(effect_params["room_size"])
			if effect_params.has("damping"):
				e.damping = float(effect_params["damping"])
			if effect_params.has("wet"):
				e.wet = float(effect_params["wet"])
			if effect_params.has("dry"):
				e.dry = float(effect_params["dry"])
			if effect_params.has("spread"):
				e.spread = float(effect_params["spread"])
			effect = e
		"chorus":
			var e := AudioEffectChorus.new()
			if effect_params.has("voice_count"):
				e.voice_count = int(effect_params["voice_count"])
			if effect_params.has("dry"):
				e.dry = float(effect_params["dry"])
			if effect_params.has("wet"):
				e.wet = float(effect_params["wet"])
			effect = e
		"delay":
			var e := AudioEffectDelay.new()
			if effect_params.has("tap1_active"):
				e.tap1_active = bool(effect_params["tap1_active"])
			if effect_params.has("tap1_delay_ms"):
				e.tap1_delay_ms = float(effect_params["tap1_delay_ms"])
			if effect_params.has("tap1_level_db"):
				e.tap1_level_db = float(effect_params["tap1_level_db"])
			if effect_params.has("tap2_active"):
				e.tap2_active = bool(effect_params["tap2_active"])
			if effect_params.has("tap2_delay_ms"):
				e.tap2_delay_ms = float(effect_params["tap2_delay_ms"])
			if effect_params.has("tap2_level_db"):
				e.tap2_level_db = float(effect_params["tap2_level_db"])
			effect = e
		"compressor":
			var e := AudioEffectCompressor.new()
			if effect_params.has("threshold"):
				e.threshold = float(effect_params["threshold"])
			if effect_params.has("ratio"):
				e.ratio = float(effect_params["ratio"])
			if effect_params.has("attack_us"):
				e.attack_us = float(effect_params["attack_us"])
			if effect_params.has("release_ms"):
				e.release_ms = float(effect_params["release_ms"])
			if effect_params.has("gain"):
				e.gain = float(effect_params["gain"])
			if effect_params.has("mix"):
				e.mix = float(effect_params["mix"])
			effect = e
		"limiter":
			var e := AudioEffectLimiter.new()
			if effect_params.has("ceiling_db"):
				e.ceiling_db = float(effect_params["ceiling_db"])
			if effect_params.has("threshold_db"):
				e.threshold_db = float(effect_params["threshold_db"])
			if effect_params.has("soft_clip_db"):
				e.soft_clip_db = float(effect_params["soft_clip_db"])
			if effect_params.has("soft_clip_ratio"):
				e.soft_clip_ratio = float(effect_params["soft_clip_ratio"])
			effect = e
		"phaser":
			var e := AudioEffectPhaser.new()
			if effect_params.has("range_min_hz"):
				e.range_min_hz = float(effect_params["range_min_hz"])
			if effect_params.has("range_max_hz"):
				e.range_max_hz = float(effect_params["range_max_hz"])
			if effect_params.has("rate_hz"):
				e.rate_hz = float(effect_params["rate_hz"])
			if effect_params.has("feedback"):
				e.feedback = float(effect_params["feedback"])
			if effect_params.has("depth"):
				e.depth = float(effect_params["depth"])
			effect = e
		"distortion":
			var e := AudioEffectDistortion.new()
			if effect_params.has("mode"):
				e.mode = int(effect_params["mode"])
			if effect_params.has("pre_gain"):
				e.pre_gain = float(effect_params["pre_gain"])
			if effect_params.has("post_gain"):
				e.post_gain = float(effect_params["post_gain"])
			if effect_params.has("keep_hf_hz"):
				e.keep_hf_hz = float(effect_params["keep_hf_hz"])
			if effect_params.has("drive"):
				e.drive = float(effect_params["drive"])
			effect = e
		"lowpassfilter", "lowpass":
			var e := AudioEffectLowPassFilter.new()
			if effect_params.has("cutoff_hz"):
				e.cutoff_hz = float(effect_params["cutoff_hz"])
			if effect_params.has("resonance"):
				e.resonance = float(effect_params["resonance"])
			effect = e
		"highpassfilter", "highpass":
			var e := AudioEffectHighPassFilter.new()
			if effect_params.has("cutoff_hz"):
				e.cutoff_hz = float(effect_params["cutoff_hz"])
			if effect_params.has("resonance"):
				e.resonance = float(effect_params["resonance"])
			effect = e
		"bandpassfilter", "bandpass":
			var e := AudioEffectBandPassFilter.new()
			if effect_params.has("cutoff_hz"):
				e.cutoff_hz = float(effect_params["cutoff_hz"])
			if effect_params.has("resonance"):
				e.resonance = float(effect_params["resonance"])
			effect = e
		"amplify":
			var e := AudioEffectAmplify.new()
			if effect_params.has("volume_db"):
				e.volume_db = float(effect_params["volume_db"])
			effect = e
		"eq":
			var e := AudioEffectEQ.new()
			effect = e
		_:
			return error_invalid_params("Unknown effect type: '%s'. Valid types: reverb, chorus, delay, compressor, limiter, phaser, distortion, lowpassfilter, highpassfilter, bandpassfilter, amplify, eq" % effect_type)

	var at_position: int = optional_int(params, "at_position", -1)
	AudioServer.add_bus_effect(bus_idx, effect, at_position)

	var effect_idx: int = AudioServer.get_bus_effect_count(bus_idx) - 1 if at_position < 0 else at_position
	return success({"bus": bus_name, "bus_index": bus_idx, "effect_type": effect.get_class(), "effect_index": effect_idx})


func _add_audio_player(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "name")
	if result2[1] != null:
		return result2[1]
	var player_name: String = result2[0]

	var player_type: String = optional_string(params, "type", "AudioStreamPlayer")
	var valid_types := ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]
	if player_type not in valid_types:
		return error_invalid_params("Invalid player type '%s'. Valid: %s" % [player_type, ", ".join(valid_types)])

	var parent := find_node_by_path(node_path)
	if parent == null:
		return error_not_found("Node at '%s'" % node_path)

	var player: Node = null
	match player_type:
		"AudioStreamPlayer":
			player = AudioStreamPlayer.new()
		"AudioStreamPlayer2D":
			player = AudioStreamPlayer2D.new()
		"AudioStreamPlayer3D":
			player = AudioStreamPlayer3D.new()

	player.name = player_name

	# Set stream if provided
	var stream_path: String = optional_string(params, "stream", "")
	if not stream_path.is_empty():
		if ResourceLoader.exists(stream_path):
			var stream = ResourceLoader.load(stream_path)
			if stream is AudioStream:
				player.set("stream", stream)
			else:
				player.queue_free()
				return error_invalid_params("Resource at '%s' is not an AudioStream" % stream_path)
		else:
			player.queue_free()
			return error_not_found("Audio stream at '%s'" % stream_path)

	# Common properties
	if params.has("volume_db"):
		player.set("volume_db", float(params["volume_db"]))

	var bus: String = optional_string(params, "bus", "")
	if not bus.is_empty():
		player.set("bus", bus)

	if params.has("autoplay"):
		player.set("autoplay", bool(params["autoplay"]))

	# 2D-specific properties
	if player is AudioStreamPlayer2D:
		if params.has("max_distance"):
			(player as AudioStreamPlayer2D).max_distance = float(params["max_distance"])
		if params.has("attenuation"):
			(player as AudioStreamPlayer2D).attenuation = float(params["attenuation"])

	# 3D-specific properties
	if player is AudioStreamPlayer3D:
		if params.has("max_distance"):
			(player as AudioStreamPlayer3D).max_distance = float(params["max_distance"])
		if params.has("attenuation_model"):
			(player as AudioStreamPlayer3D).attenuation_model = int(params["attenuation_model"])
		if params.has("unit_size"):
			(player as AudioStreamPlayer3D).unit_size = float(params["unit_size"])

	parent.add_child(player)
	player.owner = get_edited_root()

	return success({
		"name": player_name,
		"type": player_type,
		"parent": node_path,
		"stream": stream_path,
		"bus": player.get("bus"),
		"volume_db": player.get("volume_db"),
		"autoplay": player.get("autoplay"),
	})


func _get_audio_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	var players: Array[Dictionary] = []
	_collect_audio_players(node, players)

	return success({"node_path": node_path, "audio_player_count": players.size(), "players": players})


func _collect_audio_players(node: Node, result: Array[Dictionary]) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		var info := {
			"name": node.name,
			"path": str(get_edited_root().get_path_to(node)),
			"type": node.get_class(),
			"volume_db": node.get("volume_db"),
			"bus": node.get("bus"),
			"autoplay": node.get("autoplay"),
			"playing": node.get("playing"),
			"stream": "",
		}
		var stream = node.get("stream")
		if stream != null and stream is AudioStream:
			info["stream"] = stream.resource_path

		if node is AudioStreamPlayer2D:
			info["max_distance"] = (node as AudioStreamPlayer2D).max_distance
			info["attenuation"] = (node as AudioStreamPlayer2D).attenuation
		elif node is AudioStreamPlayer3D:
			info["max_distance"] = (node as AudioStreamPlayer3D).max_distance
			info["attenuation_model"] = (node as AudioStreamPlayer3D).attenuation_model
			info["unit_size"] = (node as AudioStreamPlayer3D).unit_size

		result.append(info)

	for child in node.get_children():
		_collect_audio_players(child, result)
