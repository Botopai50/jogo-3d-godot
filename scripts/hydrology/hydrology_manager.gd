class_name HydrologyManager
extends Node3D

@export var debug_enabled := false:
	set(value):
		debug_enabled = value
		if is_inside_tree():
			_rebuild_debug()
@export var position_tolerance := 4.5
@export var width_tolerance := 4.0
@export var height_tolerance := 2.0
@export var waterfall_threshold := 3.0

var tiles: Dictionary = {}
var paths: Array[RiverPath] = []
var validation_errors: PackedStringArray = []
var geometry_generator := WaterGeometryGenerator.new()
var planner := HydrologyPlanner.new()
var water_material: Material
var placements: Array[Dictionary] = []

const DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func clear_hydrology() -> void:
	tiles.clear()
	paths.clear()
	validation_errors.clear()
	for child in get_children():
		child.queue_free()


func register_tile(tile: WaterTileData) -> void:
	tiles[tile.cell] = tile


func plan_world(land_cells: Dictionary, tile_size: float, height_sampler: Callable,
		catalog_path: String, seed: int, material: Material = null) -> void:
	clear_hydrology()
	planner.plan(land_cells, tile_size, height_sampler, catalog_path, seed)
	placements = planner.placements.duplicate(true)
	validation_errors.append_array(planner.errors)
	water_material = material
	for tile in planner.tiles:
		register_tile(tile)
	_harmonize_shared_connections()
	build_paths()
	validate_network()
	build_geometry()


func occupied_cells() -> Dictionary:
	var result := {}
	for cell: Vector2i in tiles:
		result[cell] = true
	return result


func _harmonize_shared_connections() -> void:
	for cell: Vector2i in tiles:
		var tile: WaterTileData = tiles[cell]
		for connection in tile.river_connections:
			var neighbor_cell: Vector2i = cell + DIRECTIONS[int(connection.side)]
			if not tiles.has(neighbor_cell):
				continue
			var neighbor: WaterTileData = tiles[neighbor_cell]
			var other := neighbor.connection_on(connection.opposite_side())
			if other == null:
				continue
			var shared_height := (connection.height + other.height) * 0.5
			var shared_width := (connection.width + other.width) * 0.5
			if connection.side in [RiverConnection.Side.EAST, RiverConnection.Side.WEST]:
				var shared_axis := (connection.local_position.y + other.local_position.y) * 0.5
				connection.local_position.y = shared_axis
				other.local_position.y = shared_axis
			else:
				var shared_axis := (connection.local_position.x + other.local_position.x) * 0.5
				connection.local_position.x = shared_axis
				other.local_position.x = shared_axis
			connection.height = shared_height
			other.height = shared_height
			connection.width = shared_width
			other.width = shared_width
	for tile: WaterTileData in tiles.values():
		tile.control_points.clear()
		for connection: RiverConnection in tile.river_connections:
			tile.control_points.append(Vector3(connection.local_position.x,
				connection.height, connection.local_position.y))
		if tile.control_points.size() == 1:
			tile.control_points.append(Vector3(0.0, tile.water_height, 0.0))
		elif tile.control_points.size() >= 2:
			tile.control_points.insert(1, Vector3(0.0, tile.water_height, 0.0))
		tile.build_default_mask()


func build_paths() -> void:
	paths.clear()
	var visited := {}
	for cell: Vector2i in tiles:
		if visited.has(cell):
			continue
		var path := RiverPath.new()
		var current := cell
		var previous := Vector2i(999999, 999999)
		while tiles.has(current) and not visited.has(current):
			visited[current] = true
			var tile: WaterTileData = tiles[current]
			var origin := tile.world_origin()
			var incoming: RiverConnection
			var outgoing: RiverConnection
			for connection in tile.river_connections:
				var neighbor: Vector2i = current + DIRECTIONS[int(connection.side)]
				if neighbor == previous:
					incoming = connection
				elif tiles.has(neighbor) and not visited.has(neighbor):
					outgoing = connection
			if incoming != null:
				path.append_point(tile.world_position(incoming), incoming.width, current)
			path.append_point(origin + Vector3(0.0, tile.water_height, 0.0), tile.river_width, current)
			if outgoing == null:
				break
			path.append_point(tile.world_position(outgoing), outgoing.width, current)
			previous = current
			current += DIRECTIONS[int(outgoing.side)]
		path.detect_drops(waterfall_threshold)
		if path.points.size() >= 2:
			paths.append(path)


func validate_network() -> PackedStringArray:
	validation_errors.clear()
	for cell: Vector2i in tiles:
		var tile: WaterTileData = tiles[cell]
		for connection in tile.river_connections:
			var neighbor_cell: Vector2i = cell + DIRECTIONS[int(connection.side)]
			if not tiles.has(neighbor_cell):
				if connection.kind not in [RiverConnection.Kind.OCEAN,
						RiverConnection.Kind.SOURCE, RiverConnection.Kind.WATERFALL]:
					validation_errors.append("%s: rio termina sem destino no lado %d" % [cell, connection.side])
				continue
			var neighbor: WaterTileData = tiles[neighbor_cell]
			var other := neighbor.connection_on(connection.opposite_side())
			if other == null:
				validation_errors.append("%s: socket sem oposto em %s" % [cell, neighbor_cell])
			elif not connection.is_compatible_with(other, position_tolerance,
					width_tolerance, height_tolerance):
				validation_errors.append("%s <-> %s: posicao/largura/altura incompativel" % [cell, neighbor_cell])
	return validation_errors


func build_geometry() -> void:
	_install_geometry(geometry_generator.build_mesh(_tile_array(), paths))


func build_geometry_from_terrain(height_grid_provider: Callable,
		macro_height_sampler: Callable) -> void:
	_install_geometry(geometry_generator.build_terrain_masked_mesh(
		_tile_array(), height_grid_provider, macro_height_sampler))


func _install_geometry(mesh: ArrayMesh) -> void:
	var previous := get_node_or_null("WaterGeometry")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	if mesh.get_surface_count() > 0:
		var visual := MeshInstance3D.new()
		visual.name = "WaterGeometry"
		visual.mesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if water_material != null:
			mesh.surface_set_material(0, water_material)
		add_child(visual)
	_rebuild_debug()


func _tile_array() -> Array[WaterTileData]:
	var result: Array[WaterTileData] = []
	for tile: WaterTileData in tiles.values():
		result.append(tile)
	return result


func _rebuild_debug() -> void:
	var old := get_node_or_null("HydrologyDebug")
	if old != null:
		old.queue_free()
	if not debug_enabled:
		return
	var root := Node3D.new()
	root.name = "HydrologyDebug"
	add_child(root)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for tile: WaterTileData in tiles.values():
		for connection in tile.river_connections:
			var marker := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = maxf(connection.width * 0.12, 0.8)
			sphere.height = sphere.radius * 2.0
			marker.mesh = sphere
			marker.position = tile.world_position(connection) + Vector3.UP
			root.add_child(marker)
			var socket_point := tile.world_position(connection) + Vector3.UP * 0.4
			var outward := Vector3(
				DIRECTIONS[int(connection.side)].x, 0.0,
				DIRECTIONS[int(connection.side)].y)
			lines.surface_add_vertex(socket_point)
			lines.surface_add_vertex(socket_point + outward * 12.0)
		# Limite exato da mascara do tile.
		for i in range(tile.water_mask.size()):
			var a := tile.water_mask[i]
			var b := tile.water_mask[(i + 1) % tile.water_mask.size()]
			var origin := tile.world_origin() + Vector3.UP * (tile.water_height + 0.25)
			lines.surface_add_vertex(origin + Vector3(a.x, 0.0, a.y))
			lines.surface_add_vertex(origin + Vector3(b.x, 0.0, b.y))
		var label := Label3D.new()
		label.text = "%s  %s  h=%.1f" % [tile.cell,
			WaterTileData.WaterType.keys()[tile.water_type], tile.water_height]
		label.position = tile.world_origin() + Vector3(0.0, tile.water_height + 5.0, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(label)
	for path in paths:
		for i in range(path.points.size() - 1):
			lines.surface_add_vertex(path.points[i] + Vector3.UP)
			lines.surface_add_vertex(path.points[i + 1] + Vector3.UP)
	lines.surface_end()
	var line_visual := MeshInstance3D.new()
	line_visual.name = "PathsSocketsMasks"
	line_visual.mesh = lines
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(1.0, 0.15, 0.05)
	line_visual.material_override = line_material
	root.add_child(line_visual)
	for error in validation_errors:
		var error_label := Label3D.new()
		error_label.text = "ERRO: %s" % error
		error_label.modulate = Color.RED
		error_label.position = Vector3(0.0, 30.0 + root.get_child_count() * 2.0, 0.0)
		error_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(error_label)
