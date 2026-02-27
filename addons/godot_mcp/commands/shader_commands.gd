@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"create_shader": _create_shader,
		"read_shader": _read_shader,
		"edit_shader": _edit_shader,
		"assign_shader_material": _assign_shader_material,
		"set_shader_param": _set_shader_param,
		"get_shader_params": _get_shader_params,
	}


func _create_shader(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	var content: String = optional_string(params, "content", "")
	var shader_type: String = optional_string(params, "shader_type", "spatial")

	if content.is_empty():
		match shader_type:
			"spatial":
				content = "shader_type spatial;\n\nvoid vertex() {\n\t// Called for every vertex\n}\n\nvoid fragment() {\n\t// Called for every pixel\n\tALBEDO = vec3(1.0);\n}\n"
			"canvas_item":
				content = "shader_type canvas_item;\n\nvoid vertex() {\n\t// Called for every vertex\n}\n\nvoid fragment() {\n\t// Called for every pixel\n\tCOLOR = vec4(1.0);\n}\n"
			"particles":
				content = "shader_type particles;\n\nvoid start() {\n\t// Called when particle spawns\n}\n\nvoid process() {\n\t// Called every frame per particle\n}\n"
			"sky":
				content = "shader_type sky;\n\nvoid sky() {\n\tCOLOR = vec3(0.3, 0.5, 0.8);\n}\n"

	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_internal("Cannot create shader: %s" % error_string(FileAccess.get_open_error()))

	file.store_string(content)
	file.close()

	get_editor().get_resource_filesystem().scan()

	return success({"path": path, "shader_type": shader_type, "created": true})


func _read_shader(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Shader '%s'" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return error_internal("Cannot read shader: %s" % error_string(FileAccess.get_open_error()))

	var content := file.get_as_text()
	file.close()

	return success({"path": path, "content": content, "size": content.length()})


func _edit_shader(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Shader '%s'" % path)

	var changes_made := 0

	if params.has("content"):
		# Full replacement
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return error_internal("Cannot write shader")
		file.store_string(str(params["content"]))
		file.close()
		changes_made = 1
	elif params.has("replacements") and params["replacements"] is Array:
		# Read current
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return error_internal("Cannot read shader")
		var content := file.get_as_text()
		file.close()

		for replacement in params["replacements"]:
			if replacement is Dictionary:
				var search: String = replacement.get("search", "")
				var replace: String = replacement.get("replace", "")
				if not search.is_empty() and content.contains(search):
					content = content.replace(search, replace)
					changes_made += 1

		file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()

	if changes_made > 0:
		# Reload shader resource
		get_editor().get_resource_filesystem().scan()
		if ResourceLoader.exists(path):
			var shader = load(path)
			if shader is Shader:
				shader.reload_from_file()

	return success({"path": path, "changes_made": changes_made})


func _assign_shader_material(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "shader_path")
	if result2[1] != null:
		return result2[1]
	var shader_path: String = result2[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	if not ResourceLoader.exists(shader_path):
		return error_not_found("Shader '%s'" % shader_path)

	var shader: Shader = load(shader_path)
	if shader == null:
		return error_internal("Failed to load shader")

	var material := ShaderMaterial.new()
	material.shader = shader

	if node is CanvasItem:
		(node as CanvasItem).material = material
	elif node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	else:
		# Try generic material property
		if "material" in node:
			node.set("material", material)
		else:
			return error_invalid_params("Node '%s' (%s) does not support materials" % [node_path, node.get_class()])

	return success({"node_path": node_path, "shader_path": shader_path, "assigned": true})


func _set_shader_param(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var result2 := require_string(params, "param")
	if result2[1] != null:
		return result2[1]
	var param_name: String = result2[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	var material: ShaderMaterial = null
	if node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		material = (node as CanvasItem).material
	elif node is MeshInstance3D and (node as MeshInstance3D).material_override is ShaderMaterial:
		material = (node as MeshInstance3D).material_override

	if material == null:
		return error(-32000, "Node has no ShaderMaterial")

	var value = params.get("value")
	if value is String:
		var s: String = value
		var expr := Expression.new()
		if expr.parse(s) == OK:
			var parsed = expr.execute()
			if parsed != null:
				value = parsed

	material.set_shader_parameter(param_name, value)

	return success({"node_path": node_path, "param": param_name, "value": str(value)})


func _get_shader_params(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var node := find_node_by_path(node_path)
	if node == null:
		return error_not_found("Node at '%s'" % node_path)

	var material: ShaderMaterial = null
	if node is CanvasItem and (node as CanvasItem).material is ShaderMaterial:
		material = (node as CanvasItem).material
	elif node is MeshInstance3D and (node as MeshInstance3D).material_override is ShaderMaterial:
		material = (node as MeshInstance3D).material_override

	if material == null:
		return error(-32000, "Node has no ShaderMaterial")

	var shader_params: Dictionary = {}
	for prop in material.get_property_list():
		var pname: String = prop["name"]
		if pname.begins_with("shader_parameter/"):
			var key := pname.substr(17)
			shader_params[key] = str(material.get(pname))

	return success({"node_path": node_path, "params": shader_params})
