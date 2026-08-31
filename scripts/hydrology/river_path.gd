class_name RiverPath
extends RefCounted

var points := PackedVector3Array()
var widths := PackedFloat32Array()
var tile_cells: Array[Vector2i] = []
var terminal_start := RiverConnection.Kind.SOURCE
var terminal_end := RiverConnection.Kind.LAKE
var drop_segments: Array[int] = []


func append_point(point: Vector3, width: float, cell := Vector2i.ZERO) -> void:
	if not points.is_empty() and points[points.size() - 1].distance_to(point) < 0.01:
		widths[widths.size() - 1] = (widths[widths.size() - 1] + width) * 0.5
		return
	points.append(point)
	widths.append(width)
	tile_cells.append(cell)


func detect_drops(threshold := 3.0) -> void:
	drop_segments.clear()
	for i in range(points.size() - 1):
		if absf(points[i + 1].y - points[i].y) >= threshold:
			drop_segments.append(i)


func smoothed(samples_per_segment := 10) -> RiverPath:
	var result := RiverPath.new()
	if points.size() < 2:
		return self
	for i in range(points.size() - 1):
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		for sample in range(samples_per_segment):
			var t := float(sample) / float(samples_per_segment)
			var point := p1.cubic_interpolate(p2, p0, p3, t)
			var width := lerpf(widths[i], widths[i + 1], t)
			result.append_point(point, width, tile_cells[i])
	result.append_point(points[points.size() - 1], widths[widths.size() - 1], tile_cells[tile_cells.size() - 1])
	result.terminal_start = terminal_start
	result.terminal_end = terminal_end
	result.detect_drops()
	return result

