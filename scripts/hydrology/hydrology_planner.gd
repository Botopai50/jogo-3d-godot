class_name HydrologyPlanner
extends RefCounted

const DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var placements: Array[Dictionary] = []
var tiles: Array[WaterTileData] = []
var path_cells: Array[Vector2i] = []
var errors := PackedStringArray()

# Os modulos CPT de rio usam o topo do solo em y = 0 e escavam o canal para
# baixo. A lamina fica dentro dessa escavacao: acima do fundo, mas abaixo do
# solo seco, que naturalmente esconde as partes do plano fora do canal.
const WATER_LEVEL_OFFSET := -0.12


func plan(land_cells: Dictionary, tile_size: float, height_sampler: Callable,
		catalog_path: String, seed: int) -> void:
	placements.clear()
	tiles.clear()
	path_cells.clear()
	errors.clear()
	var catalog := _load_catalog(catalog_path)
	if catalog.is_empty() or land_cells.is_empty():
		errors.append("catalogo de hidrologia ou grid vazio")
		return
	var source := _highest_interior_cell(land_cells, height_sampler, tile_size)
	var ocean := _nearest_coast_cell(source, land_cells)
	path_cells = _find_path(source, ocean, land_cells, height_sampler, tile_size)
	if path_cells.size() < 4:
		errors.append("nao foi possivel criar um rio completo ate o oceano")
		return
	var lake_index := clampi(int(float(path_cells.size()) * 0.55), 2, path_cells.size() - 2)
	var previous_exit_fraction := 0.0
	var has_previous_exit := false
	for index in range(path_cells.size()):
		var cell := path_cells[index]
		var entry := -1 if index == 0 else _direction_index(path_cells[index - 1] - cell)
		var exit := -1 if index == path_cells.size() - 1 else _direction_index(path_cells[index + 1] - cell)
		if index == path_cells.size() - 1:
			exit = _ocean_side(cell, land_cells)
		var asset := _choose_asset(catalog, entry, exit,
			previous_exit_fraction, has_previous_exit)
		if asset.is_empty():
			errors.append("sem tile compativel em %s" % cell)
			continue
		var tile := WaterTileData.new()
		tile.cell = cell
		tile.tile_size = tile_size
		tile.terrain_type = StringName(asset["name"])
		tile.rotation_quarters = int(asset["rotation"])
		tile.river_width = tile_size * 0.14
		tile.water_type = WaterTileData.WaterType.LAKE if index == lake_index else WaterTileData.WaterType.RIVER
		var center_x := float(cell.x) * tile_size
		var center_z := float(cell.y) * tile_size
		# O modulo recebe a altura macro da ilha durante a deformacao. A agua
		# usa a mesma referencia ampla, sem copiar as irregularidades do leito.
		tile.water_height = float(height_sampler.call(center_x, center_z)) \
			+ WATER_LEVEL_OFFSET * (tile_size / 100.0)
		if entry >= 0:
			_add_socket(tile, entry, float(asset["entry_fraction"]) * tile_size,
				tile.water_height,
				RiverConnection.Kind.RIVER)
		if exit >= 0:
			_add_socket(tile, exit, float(asset["exit_fraction"]) * tile_size,
				tile.water_height,
				RiverConnection.Kind.OCEAN if index == path_cells.size() - 1 else RiverConnection.Kind.RIVER)
		if tile.water_type == WaterTileData.WaterType.LAKE:
			_build_lake_mask(tile)
		else:
			_build_river_controls_and_mask(tile)
		placements.append({
			"cell": cell, "name": asset["name"], "rotation": asset["rotation"],
			"water_type": tile.water_type})
		tiles.append(tile)
		previous_exit_fraction = float(asset["exit_fraction"])
		has_previous_exit = exit >= 0


func _load_catalog(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return (parsed as Dictionary).get("rio", [])
	return []


func _highest_interior_cell(cells: Dictionary, sampler: Callable, size: float) -> Vector2i:
	var best := Vector2i.ZERO
	var best_height := -INF
	for cell: Vector2i in cells:
		var neighbors := 0
		for direction: Vector2i in DIRECTIONS:
			neighbors += 1 if cells.has(cell + direction) else 0
		if neighbors < 4:
			continue
		var height := float(sampler.call(float(cell.x) * size, float(cell.y) * size))
		if height > best_height:
			best_height = height
			best = cell
	return best


func _nearest_coast_cell(source: Vector2i, cells: Dictionary) -> Vector2i:
	var best := source
	var best_distance := INF
	for cell: Vector2i in cells:
		var coast := false
		for direction: Vector2i in DIRECTIONS:
			if not cells.has(cell + direction):
				coast = true
				break
		if not coast:
			continue
		var distance := source.distance_squared_to(cell)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


func _find_path(start: Vector2i, goal: Vector2i, cells: Dictionary,
		sampler: Callable, size: float) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var parent := {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		if current == goal:
			break
		var candidates: Array[Vector2i] = []
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = current + direction
			if cells.has(next) and not parent.has(next):
				candidates.append(next)
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var score_a := a.distance_squared_to(goal) + maxf(0.0,
				float(sampler.call(float(a.x) * size, float(a.y) * size))) * 0.02
			var score_b := b.distance_squared_to(goal) + maxf(0.0,
				float(sampler.call(float(b.x) * size, float(b.y) * size))) * 0.02
			return score_a < score_b)
		for next in candidates:
			parent[next] = current
			frontier.append(next)
	if not parent.has(goal):
		return []
	var reverse: Array[Vector2i] = []
	var current: Vector2i = goal
	while current != start:
		reverse.append(current)
		current = parent[current]
	reverse.append(start)
	reverse.reverse()
	return reverse


func _direction_index(direction: Vector2i) -> int:
	for i in range(4):
		if DIRECTIONS[i] == direction:
			return i
	return -1


func _ocean_side(cell: Vector2i, land_cells: Dictionary) -> int:
	for side in range(4):
		if not land_cells.has(cell + DIRECTIONS[side]):
			return side
	return RiverConnection.Side.SOUTH


func _edge_point(side: int, fraction: float) -> Vector2:
	match side:
		RiverConnection.Side.NORTH: return Vector2(fraction, -0.5)
		RiverConnection.Side.EAST: return Vector2(0.5, fraction)
		RiverConnection.Side.SOUTH: return Vector2(fraction, 0.5)
		_: return Vector2(-0.5, fraction)


func _rotate_point(point: Vector2, turns: int) -> Vector2:
	var result := point
	for unused in range(posmod(turns, 4)):
		result = Vector2(result.y, -result.x)
	return result


func _world_edge(point: Vector2) -> Dictionary:
	if absf(point.y + 0.5) < 0.01:
		return {"side": RiverConnection.Side.NORTH, "fraction": point.x}
	if absf(point.x - 0.5) < 0.01:
		return {"side": RiverConnection.Side.EAST, "fraction": point.y}
	if absf(point.y - 0.5) < 0.01:
		return {"side": RiverConnection.Side.SOUTH, "fraction": point.x}
	return {"side": RiverConnection.Side.WEST, "fraction": point.y}


func _rotated_edges(asset: Dictionary, rotation: int) -> Dictionary:
	var result := {}
	var borders: Array = asset.get("bordas", [])
	var crossings: Array = asset.get("cruzamentos", [])
	if borders.size() != 4 or crossings.size() != 4:
		return result
	for local_side in range(4):
		if int(borders[local_side]) == 0:
			continue
		var edge := _world_edge(_rotate_point(
			_edge_point(local_side, float(crossings[local_side])), rotation))
		result[int(edge["side"])] = {
			"fraction": float(edge["fraction"]),
			"class": int(borders[local_side])}
	return result


func _choose_asset(catalog: Array, entry: int, exit: int,
		previous_fraction: float, has_previous: bool) -> Dictionary:
	var desired := {}
	if entry >= 0: desired[entry] = true
	if exit >= 0: desired[exit] = true
	var best := {}
	var best_score := INF
	for asset: Dictionary in catalog:
		var borders: Array = asset.get("bordas", [])
		if borders.size() != 4:
			continue
		# Classe 6 representa grandes rebaixos/bacias do pacote e deixa blocos
		# retangulares de agua expostos. Para o curso usamos somente canais.
		if borders.any(func(value): return int(value) == 6):
			continue
		for rotation in range(4):
			var edges := _rotated_edges(asset, rotation)
			if edges.size() != desired.size() or not edges.keys().all(
					func(side): return desired.has(side)):
				continue
			var entry_fraction := float(edges[entry]["fraction"]) if entry >= 0 else 0.0
			var exit_fraction := float(edges[exit]["fraction"]) if exit >= 0 else 0.0
			var score := absf(entry_fraction - previous_fraction) * 20.0 if has_previous else absf(exit_fraction)
			if entry >= 0 and exit >= 0 and posmod(entry + 2, 4) == exit:
				score += absf(entry_fraction - exit_fraction) * 3.0
			score += maxf(0.0, -float(asset.get("y_min", -2.0)) - 2.5) * 0.1
			if score < best_score:
				best_score = score
				best = {"name": asset["nome"], "rotation": rotation,
					"entry_fraction": entry_fraction, "exit_fraction": exit_fraction}
	return best


func _add_socket(tile: WaterTileData, side: int, lateral: float, height: float,
		kind: int) -> void:
	var half := tile.tile_size * 0.5
	var position := Vector2.ZERO
	match side:
		RiverConnection.Side.NORTH: position = Vector2(lateral, -half)
		RiverConnection.Side.EAST: position = Vector2(half, lateral)
		RiverConnection.Side.SOUTH: position = Vector2(lateral, half)
		RiverConnection.Side.WEST: position = Vector2(-half, lateral)
	# O lado recebido ja esta no espaco do mundo. A rotacao guardada no tile e
	# aplicada somente ao asset visual, portanto nao deve girar o socket de novo.
	tile.river_connections.append(
		RiverConnection.new(side, position, tile.river_width, height, kind))


func _build_river_controls_and_mask(tile: WaterTileData) -> void:
	tile.control_points.clear()
	for connection in tile.river_connections:
		tile.control_points.append(Vector3(
			connection.local_position.x, connection.height, connection.local_position.y))
	if tile.control_points.size() == 1:
		tile.control_points.append(Vector3(0.0, tile.water_height, 0.0))
	elif tile.control_points.size() >= 2:
		tile.control_points.insert(1, Vector3(0.0, tile.water_height, 0.0))
	tile.build_default_mask()


func _build_lake_mask(tile: WaterTileData) -> void:
	_build_river_controls_and_mask(tile)
