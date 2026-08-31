class_name HydrologyTestMap
extends Node3D

@export var debug_enabled := true
var manager: HydrologyManager

const CELLS := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
const HEIGHTS := [20.0, 20.0, 18.0, 15.0, 15.0, 0.5]


func _ready() -> void:
	manager = HydrologyManager.new()
	manager.name = "HydrologyManager"
	manager.debug_enabled = debug_enabled
	add_child(manager)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.35, 0.75)
	material.roughness = 0.2
	manager.water_material = material
	for i in range(CELLS.size()):
		manager.register_tile(_make_tile(i))
	manager._harmonize_shared_connections()
	manager.build_paths()
	manager.validate_network()
	manager.build_geometry()


func _make_tile(index: int) -> WaterTileData:
	var tile := WaterTileData.new()
	tile.cell = CELLS[index]
	tile.tile_size = 100.0
	tile.water_height = HEIGHTS[index]
	tile.river_width = 14.0 if index != 4 else 22.0
	tile.water_type = WaterTileData.WaterType.LAKE if index == 4 else WaterTileData.WaterType.RIVER
	if index > 0:
		var direction: Vector2i = CELLS[index - 1] - CELLS[index]
		_add_connection(tile, direction, RiverConnection.Kind.RIVER)
	if index + 1 < CELLS.size():
		var direction: Vector2i = CELLS[index + 1] - CELLS[index]
		_add_connection(tile, direction, RiverConnection.Kind.RIVER)
	elif index == CELLS.size() - 1:
		_add_connection(tile, Vector2i(0, 1), RiverConnection.Kind.OCEAN)
	for connection in tile.river_connections:
		tile.control_points.append(Vector3(
			connection.local_position.x, connection.height, connection.local_position.y))
	if tile.control_points.size() >= 2:
		tile.control_points.insert(1, Vector3(0.0, tile.water_height, 0.0))
	else:
		tile.control_points.append(Vector3.ZERO + Vector3.UP * tile.water_height)
	tile.build_default_mask()
	return tile


func _add_connection(tile: WaterTileData, direction: Vector2i,
		kind: int) -> void:
	var side := RiverConnection.Side.NORTH
	var position := Vector2.ZERO
	if direction == Vector2i(1, 0):
		side = RiverConnection.Side.EAST
		position = Vector2(50.0, 0.0)
	elif direction == Vector2i(0, 1):
		side = RiverConnection.Side.SOUTH
		position = Vector2(0.0, 50.0)
	elif direction == Vector2i(-1, 0):
		side = RiverConnection.Side.WEST
		position = Vector2(-50.0, 0.0)
	else:
		position = Vector2(0.0, -50.0)
	tile.add_connection(RiverConnection.new(
		side, position, tile.river_width, tile.water_height, kind))


func validation_report() -> Dictionary:
	return {
		"tiles": manager.tiles.size(),
		"paths": manager.paths.size(),
		"errors": manager.validation_errors,
		"drops": manager.paths[0].drop_segments if not manager.paths.is_empty() else [],
		"has_lake": manager._tile_array().any(func(tile):
			return tile.water_type == WaterTileData.WaterType.LAKE),
		"has_ocean_connection": manager._tile_array().any(func(tile):
			return tile.river_connections.any(func(connection):
				return connection.kind == RiverConnection.Kind.OCEAN)),
	}
