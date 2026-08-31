class_name WaterGeometryGenerator
extends RefCounted


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
