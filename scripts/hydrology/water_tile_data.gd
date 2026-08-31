class_name WaterTileData
extends RefCounted

enum WaterType { NONE, RIVER, LAKE }

var cell := Vector2i.ZERO
var tile_size := 100.0
var terrain_type: StringName = &"terrain"
var water_type := WaterType.NONE
var water_height := 0.0
var river_width := 12.0
var rotation_quarters := 0
var water_mask := PackedVector2Array()
var river_connections: Array[RiverConnection] = []
var control_points := PackedVector3Array()
var metadata := {}


func world_origin() -> Vector3:
	return Vector3(float(cell.x) * tile_size, 0.0, float(cell.y) * tile_size)


func add_connection(connection: RiverConnection) -> void:
	river_connections.append(connection.rotated(rotation_quarters))


func connection_on(side: int) -> RiverConnection:
	for connection in river_connections:
		if connection.side == side:
			return connection
	return null


func world_position(connection: RiverConnection) -> Vector3:
	var origin := world_origin()
	return origin + Vector3(connection.local_position.x, connection.height,
		connection.local_position.y)


func build_default_mask() -> void:
	water_mask.clear()
	if water_type == WaterType.LAKE:
		var radius := tile_size * 0.38
		for i in range(48):
			var angle := TAU * float(i) / 48.0
			water_mask.append(Vector2(cos(angle), sin(angle)) * radius)
	elif water_type == WaterType.RIVER and not control_points.is_empty():
		# A linha central mais a largura e a mascara procedural do tile.
		for point in control_points:
			water_mask.append(Vector2(point.x, point.z))
