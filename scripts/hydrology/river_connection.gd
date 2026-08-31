class_name RiverConnection
extends RefCounted

enum Side { NORTH, EAST, SOUTH, WEST }
enum Kind { RIVER, LAKE, OCEAN, SOURCE, WATERFALL }

var side: int
var local_position: Vector2
var width: float
var height: float
var kind: int
var connection_id: StringName


func _init(p_side := Side.NORTH, p_position := Vector2.ZERO,
		p_width := 12.0, p_height := 0.0, p_kind := Kind.RIVER,
		p_id := &"river") -> void:
	side = int(p_side)
	local_position = p_position
	width = p_width
	height = p_height
	kind = int(p_kind)
	connection_id = p_id


func opposite_side() -> int:
	return (side + 2) % 4


func rotated(turns: int) -> RiverConnection:
	var normalized := posmod(turns, 4)
	var result := RiverConnection.new(
		(side + normalized) % 4, local_position,
		width, height, kind, connection_id)
	for _i in range(normalized):
		result.local_position = Vector2(-result.local_position.y, result.local_position.x)
	return result


func is_compatible_with(other: RiverConnection, position_tolerance := 1.0,
		width_tolerance := 2.0, height_tolerance := 1.0) -> bool:
	if other == null or other.side != opposite_side():
		return false
	if connection_id != other.connection_id:
		return false
	if absf(width - other.width) > width_tolerance:
		return false
	if absf(height - other.height) > height_tolerance:
		return false
	var axis_a := local_position.x if side in [Side.NORTH, Side.SOUTH] else local_position.y
	var axis_b := other.local_position.x if other.side in [Side.NORTH, Side.SOUTH] else other.local_position.y
	return absf(axis_a - axis_b) <= position_tolerance
