@tool
extends "res://addons/godot_mcp/commands/base_command.gd"


func get_commands() -> Dictionary:
	return {
		"tilemap_set_cell": _tilemap_set_cell,
		"tilemap_fill_rect": _tilemap_fill_rect,
		"tilemap_get_cell": _tilemap_get_cell,
		"tilemap_clear": _tilemap_clear,
		"tilemap_get_info": _tilemap_get_info,
		"tilemap_get_used_cells": _tilemap_get_used_cells,
	}


func _find_tilemap(node_path: String) -> TileMapLayer:
	var node := find_node_by_path(node_path)
	if node is TileMapLayer:
		return node as TileMapLayer
	return null


func _tilemap_set_cell(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap(node_path)
	if tilemap == null:
		return error_not_found("TileMapLayer at '%s'" % node_path)

	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var source_id: int = int(params.get("source_id", 0))
	var atlas_x: int = int(params.get("atlas_x", 0))
	var atlas_y: int = int(params.get("atlas_y", 0))
	var alternative: int = int(params.get("alternative", 0))

	tilemap.set_cell(Vector2i(x, y), source_id, Vector2i(atlas_x, atlas_y), alternative)

	return success({"x": x, "y": y, "source_id": source_id, "atlas_coords": [atlas_x, atlas_y]})


func _tilemap_fill_rect(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap(node_path)
	if tilemap == null:
		return error_not_found("TileMapLayer at '%s'" % node_path)

	var x1: int = int(params.get("x1", 0))
	var y1: int = int(params.get("y1", 0))
	var x2: int = int(params.get("x2", 0))
	var y2: int = int(params.get("y2", 0))
	var source_id: int = int(params.get("source_id", 0))
	var atlas_x: int = int(params.get("atlas_x", 0))
	var atlas_y: int = int(params.get("atlas_y", 0))
	var alternative: int = int(params.get("alternative", 0))

	var count := 0
	for cx in range(mini(x1, x2), maxi(x1, x2) + 1):
		for cy in range(mini(y1, y2), maxi(y1, y2) + 1):
			tilemap.set_cell(Vector2i(cx, cy), source_id, Vector2i(atlas_x, atlas_y), alternative)
			count += 1

	return success({"filled": count, "rect": [x1, y1, x2, y2]})


func _tilemap_get_cell(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap(node_path)
	if tilemap == null:
		return error_not_found("TileMapLayer at '%s'" % node_path)

	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var coords := Vector2i(x, y)

	var source_id := tilemap.get_cell_source_id(coords)
	var atlas_coords := tilemap.get_cell_atlas_coords(coords)
	var alternative := tilemap.get_cell_alternative_tile(coords)

	return success({
		"x": x, "y": y,
		"source_id": source_id,
		"atlas_coords": [atlas_coords.x, atlas_coords.y],
		"alternative": alternative,
		"empty": source_id == -1,
	})


func _tilemap_clear(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap(node_path)
	if tilemap == null:
		return error_not_found("TileMapLayer at '%s'" % node_path)

	tilemap.clear()
	return success({"cleared": true})


func _tilemap_get_info(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap(node_path)
	if tilemap == null:
		return error_not_found("TileMapLayer at '%s'" % node_path)

	var tile_set := tilemap.tile_set
	var sources: Array = []
	if tile_set:
		for i in tile_set.get_source_count():
			var source_id := tile_set.get_source_id(i)
			var source := tile_set.get_source(source_id)
			var info := {"id": source_id, "type": source.get_class()}
			if source is TileSetAtlasSource:
				var atlas: TileSetAtlasSource = source
				info["texture"] = atlas.texture.resource_path if atlas.texture else ""
				info["tile_count"] = atlas.get_tiles_count()
			sources.append(info)

	return success({
		"node_path": node_path,
		"used_cells": tilemap.get_used_cells().size(),
		"tile_set_sources": sources,
		"tile_size": [tile_set.tile_size.x, tile_set.tile_size.y] if tile_set else [0, 0],
	})


func _tilemap_get_used_cells(params: Dictionary) -> Dictionary:
	var result := require_string(params, "node_path")
	if result[1] != null:
		return result[1]
	var node_path: String = result[0]

	var tilemap := _find_tilemap(node_path)
	if tilemap == null:
		return error_not_found("TileMapLayer at '%s'" % node_path)

	var max_count: int = optional_int(params, "max_count", 500)
	var cells: Array = []
	var used := tilemap.get_used_cells()

	for i in mini(used.size(), max_count):
		var pos: Vector2i = used[i]
		cells.append({"x": pos.x, "y": pos.y, "source_id": tilemap.get_cell_source_id(pos)})

	return success({"cells": cells, "total": used.size(), "returned": cells.size()})
