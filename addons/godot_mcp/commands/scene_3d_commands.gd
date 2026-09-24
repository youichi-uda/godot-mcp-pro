@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")
const NodeUtils := preload("res://addons/godot_mcp/utils/node_utils.gd")


func get_commands() -> Dictionary:
	return {
		"add_mesh_instance": _add_mesh_instance,
		"setup_lighting": _setup_lighting,
		"set_material_3d": _set_material_3d,
		"setup_environment": _setup_environment,
		"setup_camera_3d": _setup_camera_3d,
		"add_gridmap": _add_gridmap,
		"get_gridmap_info": _get_gridmap_info,
	}


## ─── Helpers ───────────────────────────────────────────────────────────────

## Kept as a thin alias so existing call sites are unchanged; the shared
## helper is the one that does not raise on null, arrays or dictionaries.
func _optional_float(params: Dictionary, key: String, default: float) -> float:
	return optional_float(params, key, default)


func _parse_color_param(params: Dictionary, key: String, default: Color) -> Color:
	if not params.has(key):
		return default
	var val: Variant = params[key]
	if val is String:
		return PropertyParser.parse_value(val, TYPE_COLOR)
	if val is Dictionary:
		return Color(
			float(val.get("r", default.r)),
			float(val.get("g", default.g)),
			float(val.get("b", default.b)),
			float(val.get("a", default.a))
		)
	return default


func _parse_vector3_param(params: Dictionary, key: String, default: Vector3) -> Vector3:
	if not params.has(key):
		return default
	var val: Variant = params[key]
	if val is String:
		return PropertyParser.parse_value(val, TYPE_VECTOR3)
	if val is Dictionary:
		return Vector3(
			float(val.get("x", default.x)),
			float(val.get("y", default.y)),
			float(val.get("z", default.z))
		)
	if val is Array and val.size() >= 3:
		return Vector3(float(val[0]), float(val[1]), float(val[2]))
	return default


func _add_child_with_undo(node: Node, parent: Node, root: Node, action_name: String) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action()


## ─── 1. add_mesh_instance ──────────────────────────────────────────────────

func _add_mesh_instance(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var node_name: String = optional_string(params, "name", "MeshInstance3D")
	var mesh_type: String = optional_string(params, "mesh_type", "")
	var mesh_file: String = optional_string(params, "mesh_file", "")

	if mesh_type.is_empty() and mesh_file.is_empty():
		return error_invalid_params("Either 'mesh_type' or 'mesh_file' is required")

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name

	if not mesh_file.is_empty():
		# Load .glb / .gltf / .obj
		if not ResourceLoader.exists(mesh_file):
			mesh_instance.queue_free()
			return error_not_found("Mesh file '%s'" % mesh_file, "Provide a valid res:// path to .glb, .gltf, or .obj")
		var loaded: Resource = load(mesh_file)
		if loaded is Mesh:
			mesh_instance.mesh = loaded as Mesh
		elif loaded is PackedScene:
			# For .glb/.gltf we instantiate and steal the first MeshInstance3D's mesh
			var scene_instance: Node = (loaded as PackedScene).instantiate()
			var found_mesh: Mesh = null
			var search_nodes: Array[Node] = [scene_instance]
			while not search_nodes.is_empty():
				var n: Node = search_nodes.pop_front()
				if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
					found_mesh = (n as MeshInstance3D).mesh
					break
				for child in n.get_children():
					search_nodes.append(child)
			scene_instance.queue_free()
			if found_mesh == null:
				mesh_instance.queue_free()
				return error_invalid_params("No mesh found in '%s'" % mesh_file)
			mesh_instance.mesh = found_mesh
		else:
			mesh_instance.queue_free()
			return error_invalid_params("'%s' is not a Mesh or PackedScene" % mesh_file)
	else:
		# Primitive mesh
		var mesh_classes := {
			"BoxMesh": BoxMesh,
			"SphereMesh": SphereMesh,
			"CylinderMesh": CylinderMesh,
			"CapsuleMesh": CapsuleMesh,
			"PlaneMesh": PlaneMesh,
			"PrismMesh": PrismMesh,
			"TorusMesh": TorusMesh,
			"QuadMesh": QuadMesh,
		}
		if not mesh_classes.has(mesh_type):
			mesh_instance.queue_free()
			return error_invalid_params("Unknown mesh_type '%s'. Available: %s" % [mesh_type, mesh_classes.keys()])
		var mesh_res: Mesh = mesh_classes[mesh_type].new()
		# Apply mesh properties if provided
		var mesh_properties: Dictionary = params.get("mesh_properties", {})
		for prop_name: String in mesh_properties:
			if prop_name in mesh_res:
				var current: Variant = mesh_res.get(prop_name)
				mesh_res.set(prop_name, PropertyParser.parse_value(mesh_properties[prop_name], typeof(current)))
		mesh_instance.mesh = mesh_res

	# Transform
	var position := _parse_vector3_param(params, "position", Vector3.ZERO)
	var rotation_deg := _parse_vector3_param(params, "rotation", Vector3.ZERO)
	var scale_vec := _parse_vector3_param(params, "scale", Vector3.ONE)

	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_deg
	mesh_instance.scale = scale_vec

	_add_child_with_undo(mesh_instance, parent, root, "MCP: Add MeshInstance3D")

	return success({
		"node_path": str(root.get_path_to(mesh_instance)),
		"name": str(mesh_instance.name),
		"mesh_type": mesh_type if mesh_file.is_empty() else mesh_file,
	})


## ─── 2. setup_lighting ────────────────────────────────────────────────────

func _setup_lighting(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var light_type: String = optional_string(params, "light_type", "")
	var preset: String = optional_string(params, "preset", "")
	var node_name: String = optional_string(params, "name", "")

	# Preset configurations
	if not preset.is_empty():
		match preset:
			"sun":
				light_type = "DirectionalLight3D"
				if node_name.is_empty():
					node_name = "SunLight"
			"indoor":
				light_type = "OmniLight3D"
				if node_name.is_empty():
					node_name = "IndoorLight"
			"dramatic":
				light_type = "SpotLight3D"
				if node_name.is_empty():
					node_name = "DramaticLight"
			_:
				return error_invalid_params("Unknown preset '%s'. Available: sun, indoor, dramatic" % preset)

	if light_type.is_empty():
		return error_invalid_params("Either 'light_type' or 'preset' is required")

	var light: Light3D
	match light_type:
		"DirectionalLight3D":
			light = DirectionalLight3D.new()
		"OmniLight3D":
			light = OmniLight3D.new()
		"SpotLight3D":
			light = SpotLight3D.new()
		"AreaLight3D":
			# Godot 4.7+. Never referenced statically so this file still parses on 4.5/4.6.
			if not ClassDB.class_exists("AreaLight3D"):
				return _error_requires_version("light_type 'AreaLight3D'", "4.7")
			light = ClassDB.instantiate("AreaLight3D") as Light3D
		_:
			return error_invalid_params("Unknown light_type '%s'. Available: DirectionalLight3D, OmniLight3D, SpotLight3D, AreaLight3D (Godot 4.7+)" % light_type)

	if node_name.is_empty():
		node_name = light_type
	light.name = node_name

	# Common properties
	light.light_color = _parse_color_param(params, "color", Color.WHITE)
	light.light_energy = _optional_float(params, "energy", 1.0)
	light.shadow_enabled = optional_bool(params, "shadows", false)

	# Type-specific properties
	if light is OmniLight3D:
		var omni: OmniLight3D = light as OmniLight3D
		omni.omni_range = _optional_float(params, "range", 5.0)
		omni.omni_attenuation = _optional_float(params, "attenuation", 1.0)
	elif light is SpotLight3D:
		var spot: SpotLight3D = light as SpotLight3D
		spot.spot_range = _optional_float(params, "range", 5.0)
		spot.spot_attenuation = _optional_float(params, "attenuation", 1.0)
		spot.spot_angle = _optional_float(params, "spot_angle", 45.0)
		spot.spot_angle_attenuation = _optional_float(params, "spot_angle_attenuation", 1.0)
	elif light.get_class() == "AreaLight3D":
		var area_err := _apply_area_light_params(light, params)
		if not area_err.is_empty():
			light.free()
			return area_err

	# Apply preset defaults after type creation
	if not preset.is_empty():
		match preset:
			"sun":
				light.light_energy = _optional_float(params, "energy", 1.0)
				light.shadow_enabled = optional_bool(params, "shadows", true)
				light.rotation_degrees = _parse_vector3_param(params, "rotation", Vector3(-45, -30, 0))
			"indoor":
				light.light_energy = _optional_float(params, "energy", 0.8)
				light.light_color = _parse_color_param(params, "color", Color(1.0, 0.95, 0.85))
				if light is OmniLight3D:
					(light as OmniLight3D).omni_range = _optional_float(params, "range", 8.0)
			"dramatic":
				light.light_energy = _optional_float(params, "energy", 2.0)
				light.shadow_enabled = optional_bool(params, "shadows", true)
				if light is SpotLight3D:
					(light as SpotLight3D).spot_angle = _optional_float(params, "spot_angle", 25.0)
					(light as SpotLight3D).spot_range = _optional_float(params, "range", 10.0)

	# Position / rotation
	light.position = _parse_vector3_param(params, "position", Vector3.ZERO)
	if params.has("rotation"):
		light.rotation_degrees = _parse_vector3_param(params, "rotation", light.rotation_degrees)

	_add_child_with_undo(light, parent, root, "MCP: Add %s" % light_type)

	var out := {
		"node_path": str(root.get_path_to(light)),
		"name": str(light.name),
		"light_type": light_type,
		"preset": preset,
	}
	if light_type == "AreaLight3D":
		var area_size: Vector2 = light.get("area_size")
		out["area_size"] = {"x": area_size.x, "y": area_size.y}
		out["area_range"] = light.get("area_range")
		out["area_attenuation"] = light.get("area_attenuation")
		out["area_normalize_energy"] = light.get("area_normalize_energy")
		var area_tex: Variant = light.get("area_texture")
		out["area_texture"] = (area_tex as Resource).resource_path if area_tex is Resource else ""
	return success(out)


## Error for a feature that the running Godot does not have (-32601, the same
## code base_command uses for version-gated tools). Names both the
## required and the running version so the caller can tell the difference
## between a typo and an older editor.
func _error_requires_version(feature: String, required: String) -> Dictionary:
	var running: String = Engine.get_version_info().get("string", "unknown")
	return error(-32601, "%s requires Godot %s+ (running %s)" % [feature, required, running], {
		"required_version": required,
		"running_version": running,
	})


## AreaLight3D (4.7+) properties: area_size, area_range, area_attenuation,
## area_normalize_energy, area_texture. `range`/`attenuation` are accepted as
## aliases for area_range/area_attenuation so the generic params keep working.
## Everything goes through set() so nothing here is resolved at parse time.
func _apply_area_light_params(light: Light3D, params: Dictionary) -> Dictionary:
	if params.has("area_size"):
		var v: Variant = params["area_size"]
		var size := Vector2.ZERO
		if v is Dictionary:
			size = Vector2(float(v.get("x", 1.0)), float(v.get("y", 1.0)))
		elif v is Array and v.size() >= 2:
			size = Vector2(float(v[0]), float(v[1]))
		elif v is String:
			var parsed: Variant = PropertyParser.parse_value(v, TYPE_VECTOR2)
			if parsed is Vector2:
				size = parsed
		else:
			return error_invalid_params("'area_size' must be {x, y}, [x, y] or 'Vector2(x, y)'")
		if size.x <= 0.0 or size.y <= 0.0:
			return error_invalid_params("'area_size' components must be > 0")
		light.set("area_size", size)
	if params.has("area_range") or params.has("range"):
		light.set("area_range", _optional_float(params, "area_range", _optional_float(params, "range", 5.0)))
	if params.has("area_attenuation") or params.has("attenuation"):
		light.set("area_attenuation", _optional_float(params, "area_attenuation", _optional_float(params, "attenuation", 1.0)))
	if params.has("area_normalize_energy"):
		light.set("area_normalize_energy", optional_bool(params, "area_normalize_energy", true))
	var tex_path := optional_string(params, "area_texture", "")
	if not tex_path.is_empty():
		if not ResourceLoader.exists(tex_path):
			return error_not_found("Texture '%s'" % tex_path)
		var tex: Resource = load(tex_path)
		if not tex is Texture2D:
			return error_invalid_params("'%s' is not a Texture2D" % tex_path)
		light.set("area_texture", tex)
	return {}


## ─── 3. set_material_3d ───────────────────────────────────────────────────

func _set_material_3d(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path)

	if not node is MeshInstance3D:
		return error_invalid_params("Node '%s' is not a MeshInstance3D (is %s)" % [node_path, node.get_class()])

	var mesh_inst: MeshInstance3D = node as MeshInstance3D
	var surface_index: int = optional_int(params, "surface_index", 0)

	var mat := StandardMaterial3D.new()

	# Albedo
	mat.albedo_color = _parse_color_param(params, "albedo_color", Color.WHITE)
	if params.has("albedo_texture"):
		var tex_path: String = params["albedo_texture"]
		if ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path) as Texture2D

	# PBR
	mat.metallic = _optional_float(params, "metallic", 0.0)
	mat.roughness = _optional_float(params, "roughness", 1.0)
	if params.has("metallic_texture"):
		var tex_path: String = params["metallic_texture"]
		if ResourceLoader.exists(tex_path):
			mat.metallic_texture = load(tex_path) as Texture2D
	if params.has("roughness_texture"):
		var tex_path: String = params["roughness_texture"]
		if ResourceLoader.exists(tex_path):
			mat.roughness_texture = load(tex_path) as Texture2D
	if params.has("normal_texture"):
		mat.normal_enabled = true
		var tex_path: String = params["normal_texture"]
		if ResourceLoader.exists(tex_path):
			mat.normal_texture = load(tex_path) as Texture2D

	# Emission
	if params.has("emission") or params.has("emission_color"):
		mat.emission_enabled = true
		mat.emission = _parse_color_param(params, "emission", _parse_color_param(params, "emission_color", Color.BLACK))
		mat.emission_energy_multiplier = _optional_float(params, "emission_energy", 1.0)
	if params.has("emission_texture"):
		mat.emission_enabled = true
		var tex_path: String = params["emission_texture"]
		if ResourceLoader.exists(tex_path):
			mat.emission_texture = load(tex_path) as Texture2D

	# Transparency
	if params.has("transparency"):
		var transparency_val: String = str(params["transparency"])
		match transparency_val.to_upper():
			"DISABLED", "0":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			"ALPHA", "1":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"ALPHA_SCISSOR", "2":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			"ALPHA_HASH", "3":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			"ALPHA_DEPTH_PRE_PASS", "4":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS

	# Cull mode
	if params.has("cull_mode"):
		var cull_val: String = str(params["cull_mode"])
		match cull_val.to_upper():
			"BACK", "0":
				mat.cull_mode = BaseMaterial3D.CULL_BACK
			"FRONT", "1":
				mat.cull_mode = BaseMaterial3D.CULL_FRONT
			"DISABLED", "2":
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Apply
	var old_mat: Material = mesh_inst.get_surface_override_material(surface_index)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("MCP: Set material on %s" % mesh_inst.name)
	undo_redo.add_do_method(mesh_inst, "set_surface_override_material", surface_index, mat)
	undo_redo.add_undo_method(mesh_inst, "set_surface_override_material", surface_index, old_mat)
	undo_redo.commit_action()

	return success({
		"node_path": str(root.get_path_to(mesh_inst)),
		"surface_index": surface_index,
		"albedo_color": str(mat.albedo_color),
		"metallic": mat.metallic,
		"roughness": mat.roughness,
	})


## ─── 4. setup_environment ─────────────────────────────────────────────────

func _setup_environment(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var node_name: String = optional_string(params, "name", "WorldEnvironment")

	# Check if a WorldEnvironment already exists at the target
	var node_path: String = optional_string(params, "node_path", "")
	var world_env: WorldEnvironment = null
	var is_existing := false

	if not node_path.is_empty():
		var existing := find_node_by_path(node_path)
		if existing != null and existing is WorldEnvironment:
			world_env = existing as WorldEnvironment
			is_existing = true

	if world_env == null:
		world_env = WorldEnvironment.new()
		world_env.name = node_name

	var env: Environment = world_env.environment
	if env == null:
		env = Environment.new()

	# Background / Sky
	var bg_mode: String = optional_string(params, "background_mode", "sky")
	match bg_mode.to_lower():
		"sky":
			env.background_mode = Environment.BG_SKY
		"color":
			env.background_mode = Environment.BG_COLOR
			env.background_color = _parse_color_param(params, "background_color", Color(0.3, 0.3, 0.3))
		"canvas":
			env.background_mode = Environment.BG_CANVAS
		"clear_color":
			env.background_mode = Environment.BG_CLEAR_COLOR

	# Procedural sky
	if params.has("sky") and params["sky"] is Dictionary:
		var sky_params: Dictionary = params["sky"]
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = _parse_color_param(sky_params, "sky_top_color", Color(0.385, 0.454, 0.55))
		sky_mat.sky_horizon_color = _parse_color_param(sky_params, "sky_horizon_color", Color(0.646, 0.654, 0.67))
		sky_mat.ground_bottom_color = _parse_color_param(sky_params, "ground_bottom_color", Color(0.2, 0.169, 0.133))
		sky_mat.ground_horizon_color = _parse_color_param(sky_params, "ground_horizon_color", Color(0.646, 0.654, 0.67))
		sky_mat.sun_angle_max = _optional_float(sky_params, "sun_angle_max", 30.0) if sky_params.has("sun_angle_max") else 30.0
		sky_mat.sky_curve = _optional_float(sky_params, "sky_curve", 0.15) if sky_params.has("sky_curve") else 0.15

		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY

	# Ambient light
	if params.has("ambient_light_color"):
		env.ambient_light_color = _parse_color_param(params, "ambient_light_color", Color.WHITE)
	env.ambient_light_energy = _optional_float(params, "ambient_light_energy", 1.0) if params.has("ambient_light_energy") else env.ambient_light_energy
	if params.has("ambient_light_source"):
		var src: String = str(params["ambient_light_source"])
		match src.to_upper():
			"BACKGROUND", "0":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
			"DISABLED", "1":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
			"COLOR", "2":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			"SKY", "3":
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	# Tonemap
	if params.has("tonemap_mode"):
		var tm: String = str(params["tonemap_mode"])
		match tm.to_upper():
			"LINEAR", "0":
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			"REINHARDT", "1":
				env.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
			"FILMIC", "2":
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			"ACES", "3":
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
			"AGX", "4":
				env.tonemap_mode = 4  # Environment.TONE_MAPPER_AGX (Godot 4.4+)
	if params.has("tonemap_exposure"):
		env.tonemap_exposure = _optional_float(params, "tonemap_exposure", 1.0)
	if params.has("tonemap_white"):
		env.tonemap_white = _optional_float(params, "tonemap_white", 1.0)

	# Fog
	if params.has("fog_enabled"):
		env.fog_enabled = optional_bool(params, "fog_enabled", false)
	if env.fog_enabled or params.has("fog_light_color"):
		env.fog_light_color = _parse_color_param(params, "fog_light_color", Color(0.518, 0.553, 0.608))
		env.fog_density = _optional_float(params, "fog_density", 0.01) if params.has("fog_density") else env.fog_density
		env.fog_light_energy = _optional_float(params, "fog_light_energy", 1.0) if params.has("fog_light_energy") else env.fog_light_energy

	# Glow
	if params.has("glow_enabled"):
		env.glow_enabled = optional_bool(params, "glow_enabled", false)
	if env.glow_enabled:
		env.glow_intensity = _optional_float(params, "glow_intensity", 0.8) if params.has("glow_intensity") else env.glow_intensity
		env.glow_strength = _optional_float(params, "glow_strength", 1.0) if params.has("glow_strength") else env.glow_strength
		env.glow_bloom = _optional_float(params, "glow_bloom", 0.0) if params.has("glow_bloom") else env.glow_bloom

	# SSAO
	if params.has("ssao_enabled"):
		env.ssao_enabled = optional_bool(params, "ssao_enabled", false)
	if env.ssao_enabled:
		env.ssao_radius = _optional_float(params, "ssao_radius", 1.0) if params.has("ssao_radius") else env.ssao_radius
		env.ssao_intensity = _optional_float(params, "ssao_intensity", 2.0) if params.has("ssao_intensity") else env.ssao_intensity

	# SSR
	if params.has("ssr_enabled"):
		env.ssr_enabled = optional_bool(params, "ssr_enabled", false)
	if env.ssr_enabled:
		env.ssr_max_steps = optional_int(params, "ssr_max_steps", 64) if params.has("ssr_max_steps") else env.ssr_max_steps
		env.ssr_fade_in = _optional_float(params, "ssr_fade_in", 0.15) if params.has("ssr_fade_in") else env.ssr_fade_in
		env.ssr_fade_out = _optional_float(params, "ssr_fade_out", 2.0) if params.has("ssr_fade_out") else env.ssr_fade_out

	# SDFGI
	if params.has("sdfgi_enabled"):
		env.sdfgi_enabled = optional_bool(params, "sdfgi_enabled", false)

	world_env.environment = env

	if not is_existing:
		_add_child_with_undo(world_env, parent, root, "MCP: Add WorldEnvironment")

	var features: Array = []
	if env.fog_enabled: features.append("fog")
	if env.glow_enabled: features.append("glow")
	if env.ssao_enabled: features.append("ssao")
	if env.ssr_enabled: features.append("ssr")
	if env.sdfgi_enabled: features.append("sdfgi")

	return success({
		"node_path": str(root.get_path_to(world_env)),
		"name": str(world_env.name),
		"background_mode": bg_mode,
		"features": features,
		"is_existing": is_existing,
	})


## ─── 5. setup_camera_3d ──────────────────────────────────────────────────

func _setup_camera_3d(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	# Check if we're configuring an existing camera
	var node_path: String = optional_string(params, "node_path", "")
	var camera: Camera3D = null
	var is_existing := false

	if not node_path.is_empty():
		var existing := find_node_by_path(node_path)
		if existing != null and existing is Camera3D:
			camera = existing as Camera3D
			is_existing = true
		elif existing != null:
			return error_invalid_params("Node '%s' is not a Camera3D (is %s)" % [node_path, existing.get_class()])

	if camera == null:
		camera = Camera3D.new()
		camera.name = optional_string(params, "name", "Camera3D")

	# Projection
	var projection_str: String = optional_string(params, "projection", "")
	if not projection_str.is_empty():
		match projection_str.to_lower():
			"perspective", "0":
				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			"orthogonal", "orthographic", "1":
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			"frustum", "2":
				camera.projection = Camera3D.PROJECTION_FRUSTUM

	# Properties
	if params.has("fov"):
		camera.fov = _optional_float(params, "fov", 75.0)
	if params.has("size"):
		camera.size = _optional_float(params, "size", 1.0)
	if params.has("near"):
		camera.near = _optional_float(params, "near", 0.05)
	if params.has("far"):
		camera.far = _optional_float(params, "far", 4000.0)
	if params.has("cull_mask"):
		camera.cull_mask = optional_int(params, "cull_mask", 1048575)

	# Make current
	camera.current = optional_bool(params, "current", false)

	# Transform
	camera.position = _parse_vector3_param(params, "position", camera.position if is_existing else Vector3(0, 1, 3))
	if params.has("rotation"):
		camera.rotation_degrees = _parse_vector3_param(params, "rotation", camera.rotation_degrees)
	if params.has("look_at"):
		var target := _parse_vector3_param(params, "look_at", Vector3.ZERO)
		# We need to set position first, then use look_at
		camera.look_at(target)

	# Environment override
	if params.has("environment_path"):
		var env_path: String = params["environment_path"]
		if ResourceLoader.exists(env_path):
			var env_res: Resource = load(env_path)
			if env_res is Environment:
				camera.environment = env_res as Environment

	if not is_existing:
		_add_child_with_undo(camera, parent, root, "MCP: Add Camera3D")

	return success({
		"node_path": str(root.get_path_to(camera)),
		"name": str(camera.name),
		"projection": "perspective" if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else "orthogonal",
		"fov": camera.fov,
		"position": str(camera.position),
		"is_existing": is_existing,
	})


## ─── 6. add_gridmap ──────────────────────────────────────────────────────

func _add_gridmap(params: Dictionary) -> Dictionary:
	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var parent_path: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(parent_path)
	if parent == null:
		return error_not_found("Parent node '%s'" % parent_path)

	var node_name: String = optional_string(params, "name", "GridMap")

	# Check for existing GridMap to configure
	var node_path: String = optional_string(params, "node_path", "")
	var gridmap: GridMap = null
	var is_existing := false

	if not node_path.is_empty():
		var existing := find_node_by_path(node_path)
		if existing != null and existing is GridMap:
			gridmap = existing as GridMap
			is_existing = true
		elif existing != null:
			return error_invalid_params("Node '%s' is not a GridMap (is %s)" % [node_path, existing.get_class()])

	if gridmap == null:
		gridmap = GridMap.new()
		gridmap.name = node_name

	# Mesh library
	if params.has("mesh_library_path"):
		var lib_path: String = params["mesh_library_path"]
		if not ResourceLoader.exists(lib_path):
			if not is_existing:
				gridmap.queue_free()
			return error_not_found("MeshLibrary '%s'" % lib_path, "Provide a valid res:// path to a .meshlib or .tres file")
		var lib: Resource = load(lib_path)
		if lib is MeshLibrary:
			gridmap.mesh_library = lib as MeshLibrary
		else:
			if not is_existing:
				gridmap.queue_free()
			return error_invalid_params("'%s' is not a MeshLibrary" % lib_path)

	# Cell size
	if params.has("cell_size"):
		gridmap.cell_size = _parse_vector3_param(params, "cell_size", Vector3(2, 2, 2))

	# Position
	gridmap.position = _parse_vector3_param(params, "position", gridmap.position if is_existing else Vector3.ZERO)

	if not is_existing:
		_add_child_with_undo(gridmap, parent, root, "MCP: Add GridMap")

	# Set cells
	var cells: Array = params.get("cells", [])
	var cells_set: int = 0
	for cell in cells:
		if cell is Dictionary:
			var x: int = int(cell.get("x", 0))
			var y: int = int(cell.get("y", 0))
			var z: int = int(cell.get("z", 0))
			var item: int = int(cell.get("item", 0))
			var orientation: int = int(cell.get("orientation", 0))
			gridmap.set_cell_item(Vector3i(x, y, z), item, orientation)
			cells_set += 1

	return success({
		"node_path": str(root.get_path_to(gridmap)),
		"name": str(gridmap.name),
		"cells_set": cells_set,
		"is_existing": is_existing,
		"has_mesh_library": gridmap.mesh_library != null,
	})


## ─── 7. get_gridmap_info ─────────────────────────────────────────────────

## Parses a cell-space AABB given as {position:{x,y,z}, size:{x,y,z}} or
## {min:{x,y,z}, max:{x,y,z}} (both inclusive of the min corner). Returns
## [aabb_or_null, error_or_null].
func _parse_cell_bounds(value: Variant) -> Array:
	if not value is Dictionary:
		return [null, error_invalid_params("'bounds' must be {position:{x,y,z}, size:{x,y,z}} or {min:{x,y,z}, max:{x,y,z}} in cell coordinates")]
	var d: Dictionary = value
	var zero := Vector3.ZERO
	if d.has("min") and d.has("max"):
		var mn := _parse_vector3_param(d, "min", zero)
		var mx := _parse_vector3_param(d, "max", zero)
		return [AABB(mn, mx - mn).abs(), null]
	if d.has("position") and d.has("size"):
		return [AABB(_parse_vector3_param(d, "position", zero), _parse_vector3_param(d, "size", zero)).abs(), null]
	return [null, error_invalid_params("'bounds' needs either position+size or min+max")]


## Inclusive integer containment: a bounds of min (0,0,0) max (3,0,0) holds
## cells x = 0..3.
func _cell_in_bounds(cell: Vector3i, bounds: AABB) -> bool:
	var mn := bounds.position
	var mx := bounds.end
	return cell.x >= mn.x and cell.x <= mx.x \
		and cell.y >= mn.y and cell.y <= mx.y \
		and cell.z >= mn.z and cell.z <= mx.z


func _vec3i_dict(v: Vector3i) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


func _get_gridmap_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var root := get_edited_root()
	if root == null:
		return error_no_scene()

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node '%s'" % node_path, "Use find_nodes_by_type with type 'GridMap'")
	if not node is GridMap:
		return error_invalid_params("Node '%s' is not a GridMap (is %s)" % [node_path, node.get_class()])
	var gridmap := node as GridMap

	var has_item_filter := params.has("item")
	var item_filter: int = optional_int(params, "item", -1)
	var has_bounds := params.has("bounds")
	var bounds := AABB()
	if has_bounds:
		var b := _parse_cell_bounds(params["bounds"])
		if b[1] != null:
			return b[1]
		bounds = b[0]
	var list_cells: bool = optional_bool(params, "list_cells", has_item_filter or has_bounds)
	var max_cells: int = maxi(optional_int(params, "max_cells", 500), 0)
	var include_octants: bool = optional_bool(params, "include_octants", true)
	var max_octants: int = maxi(optional_int(params, "max_octants", 200), 0)

	var lib := gridmap.mesh_library
	var info := {
		"node_path": str(root.get_path_to(gridmap)),
		"godot_version": Engine.get_version_info().get("string", ""),
		"mesh_library": (lib.resource_path if not lib.resource_path.is_empty() else "<embedded>") if lib != null else null,
		"cell_size": {"x": gridmap.cell_size.x, "y": gridmap.cell_size.y, "z": gridmap.cell_size.z},
		"cell_center": {"x": gridmap.cell_center_x, "y": gridmap.cell_center_y, "z": gridmap.cell_center_z},
		"octant_size": gridmap.cell_octant_size,
	}

	var used: Array[Vector3i] = gridmap.get_used_cells()
	info["used_cell_count"] = used.size()

	# Bounds of all used cells (cell coordinates, inclusive) and per-item counts.
	var item_counts := {}
	var has_any := false
	var mn := Vector3i.ZERO
	var mx := Vector3i.ZERO
	for cell: Vector3i in used:
		var item := gridmap.get_cell_item(cell)
		item_counts[item] = int(item_counts.get(item, 0)) + 1
		if not has_any:
			mn = cell
			mx = cell
			has_any = true
		else:
			mn = mn.min(cell)
			mx = mx.max(cell)
	if has_any:
		info["bounds"] = {
			"min": _vec3i_dict(mn),
			"max": _vec3i_dict(mx),
			"size": _vec3i_dict(mx - mn + Vector3i.ONE),
		}
	else:
		info["bounds"] = null

	var items: Array = []
	var item_ids := item_counts.keys()
	item_ids.sort()
	for item_id: int in item_ids:
		var entry := {"item": item_id, "count": item_counts[item_id]}
		if lib != null and lib.get_item_list().has(item_id):
			entry["name"] = lib.get_item_name(item_id)
		items.append(entry)
	info["items"] = items

	# Cell listing, filtered and capped so the response stays small.
	if list_cells:
		var cells: Array = []
		var matched := 0
		for cell: Vector3i in used:
			var item := gridmap.get_cell_item(cell)
			if has_item_filter and item != item_filter:
				continue
			if has_bounds and not _cell_in_bounds(cell, bounds):
				continue
			matched += 1
			if cells.size() < max_cells:
				cells.append({
					"x": cell.x, "y": cell.y, "z": cell.z,
					"item": item,
					"orientation": gridmap.get_cell_item_orientation(cell),
				})
		info["cells"] = cells
		info["matched_cell_count"] = matched
		info["cells_truncated"] = matched > cells.size()
		if has_item_filter:
			info["item_filter"] = item_filter
		if has_bounds:
			info["bounds_filter"] = {
				"min": {"x": bounds.position.x, "y": bounds.position.y, "z": bounds.position.z},
				"max": {"x": bounds.end.x, "y": bounds.end.y, "z": bounds.end.z},
			}

	# Octant summary: the octant query API only exists on Godot 4.7+.
	if include_octants:
		if gridmap.has_method("get_used_octants") and gridmap.has_method("get_octant_coords_from_cell_coords"):
			var octants: Array = gridmap.call("get_used_octants_by_item", item_filter) if has_item_filter \
				else gridmap.call("get_used_octants")
			# Cell counts per octant are grouped from the used cells through the
			# engine's own cell->octant mapping.
			var per_octant := {}
			for cell: Vector3i in used:
				if has_item_filter and gridmap.get_cell_item(cell) != item_filter:
					continue
				var oc: Vector3i = gridmap.call("get_octant_coords_from_cell_coords", cell)
				per_octant[oc] = int(per_octant.get(oc, 0)) + 1
			var octant_list: Array = []
			for oc: Vector3i in octants:
				if octant_list.size() >= max_octants:
					break
				octant_list.append({"x": oc.x, "y": oc.y, "z": oc.z, "cell_count": int(per_octant.get(oc, 0))})
			var octant_info := {
				"available": true,
				"used_octant_count": octants.size(),
				"octants": octant_list,
				"octants_truncated": octants.size() > octant_list.size(),
			}
			if has_bounds and gridmap.has_method("get_used_octants_in_bounds"):
				# The engine's bounds query takes GridMap-local space, so convert
				# the inclusive cell bounds into local-space extents first.
				var cs := gridmap.cell_size
				var local := AABB(bounds.position * cs, (bounds.size + Vector3.ONE) * cs)
				var in_bounds: Array = gridmap.call("get_used_octants_in_bounds", local)
				var ib: Array = []
				for oc: Vector3i in in_bounds:
					if ib.size() >= max_octants:
						break
					ib.append(_vec3i_dict(oc))
				octant_info["used_octants_in_bounds"] = ib
			info["octants"] = octant_info
		else:
			info["octants"] = {
				"available": false,
				"reason": "Octant queries (get_used_octants etc.) require Godot 4.7+; running %s" % Engine.get_version_info().get("string", "unknown"),
			}

	return success(info)
