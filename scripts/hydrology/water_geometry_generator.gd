class_name WaterGeometryGenerator
extends RefCounted

const MASK_RESOLUTION := 64
const MINIMUM_CHANNEL_DEPTH := 0.4
const CLOSING_RADIUS := 1


func add_river(path: RiverPath, vertices: PackedVector3Array,
		normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	if path.points.size() < 2:
		return
	var start := vertices.size()
	for i in range(path.points.size()):
		var previous := path.points[maxi(i - 1, 0)]
		var following := path.points[mini(i + 1, path.points.size() - 1)]
		var tangent := following - previous
		tangent.y = 0.0
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.FORWARD
		var side := tangent.normalized().cross(Vector3.UP) * path.widths[i] * 0.5
		vertices.append(path.points[i] - side)
		vertices.append(path.points[i] + side)
		normals.append_array([Vector3.UP, Vector3.UP])
	for i in range(path.points.size() - 1):
		var a := start + i * 2
		indices.append_array([a, a + 3, a + 1, a, a + 2, a + 3])


func add_lake(tile: WaterTileData, vertices: PackedVector3Array,
		normals: PackedVector3Array, indices: PackedInt32Array) -> void:
	if tile.water_mask.size() < 3:
		return
	var triangles := Geometry2D.triangulate_polygon(tile.water_mask)
	var origin := tile.world_origin()
	var start := vertices.size()
	for point in tile.water_mask:
		vertices.append(origin + Vector3(point.x, tile.water_height, point.y))
		normals.append(Vector3.UP)
	for index in triangles:
		indices.append(start + index)


func build_mesh(tiles: Array[WaterTileData], paths: Array[RiverPath]) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for tile in tiles:
		if tile.water_type != WaterTileData.WaterType.NONE:
			add_lake(tile, vertices, normals, indices)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func build_terrain_masked_mesh(tiles: Array[WaterTileData],
		height_grid_provider: Callable, macro_height_sampler: Callable) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for tile in tiles:
		_add_masked_tile(tile, height_grid_provider, macro_height_sampler,
			vertices, normals, indices)
	return _mesh_from_arrays(vertices, normals, indices)


func _add_masked_tile(tile: WaterTileData, height_grid_provider: Callable,
		macro_height_sampler: Callable,
		vertices: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array) -> void:
	var resolution := MASK_RESOLUTION
	var mask: Array[bool] = []
	mask.resize(resolution * resolution)
	var origin := tile.world_origin()
	var half := tile.tile_size * 0.5
	var step := tile.tile_size / float(resolution - 1)
	var heights: PackedFloat32Array = height_grid_provider.call(tile.cell, resolution)
	var levels := PackedFloat32Array()
	levels.resize(resolution * resolution)
	for z in range(resolution):
		for x in range(resolution):
			var ground := heights[z * resolution + x]
			var world_x := origin.x - half + float(x) * step
			var world_z := origin.z - half + float(z) * step
			var macro_level := float(macro_height_sampler.call(world_x, world_z))
			var level := macro_level + HydrologyPlanner.WATER_LEVEL_OFFSET
			levels[z * resolution + x] = level
			mask[z * resolution + x] = ground < macro_level - MINIMUM_CHANNEL_DEPTH
	# Fecha pequenas cristas e falhas de triangulacao no leito sem liberar a
	# agua para o restante do quadrado.
	for iteration in range(CLOSING_RADIUS):
		mask = _dilate(mask, resolution)
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			if not mask[z * resolution + x]:
				continue
			var x0 := origin.x - half + float(x) * step
			var z0 := origin.z - half + float(z) * step
			var y00 := levels[z * resolution + x]
			var y10 := levels[z * resolution + x + 1]
			var y11 := levels[(z + 1) * resolution + x + 1]
			var y01 := levels[(z + 1) * resolution + x]
			var start := vertices.size()
			vertices.append_array([
				Vector3(x0, y00, z0), Vector3(x0 + step, y10, z0),
				Vector3(x0 + step, y11, z0 + step), Vector3(x0, y01, z0 + step)])
			normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
			indices.append_array([start, start + 2, start + 1,
				start, start + 3, start + 2])


func _dilate(source: Array[bool], resolution: int) -> Array[bool]:
	var result := source.duplicate()
	for z in range(resolution):
		for x in range(resolution):
			if not source[z * resolution + x]:
				continue
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var nz := z + dz
					if nx >= 0 and nx < resolution and nz >= 0 and nz < resolution:
						result[nz * resolution + nx] = true
	return result


func _mesh_from_arrays(vertices: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
