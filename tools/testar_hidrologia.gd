extends SceneTree

var failures := 0


func _init() -> void:
	var scene: Node = load("res://scenes/tests/hydrology_test.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var report: Dictionary = scene.validation_report()
	_check(report["tiles"] == 6, "mapa usa seis tiles")
	_check(report["paths"] == 1, "rio forma um caminho continuo")
	_check((report["errors"] as PackedStringArray).is_empty(), "sockets sao compativeis")
	_check(not (report["drops"] as Array).is_empty(), "queda de altitude foi detectada")
	_check(report["has_lake"], "rio entra e sai de um lago")
	_check(report["has_ocean_connection"], "rio possui conexao com oceano")
	var manager: Node = scene.manager
	var mesh := manager.get_node_or_null("WaterGeometry") as MeshInstance3D
	_check(mesh != null and mesh.mesh != null, "geometria independente foi criada")
	var full_tile_planes := true
	for tile: WaterTileData in manager.tiles.values():
		var half: float = tile.tile_size * 0.5
		full_tile_planes = full_tile_planes and tile.water_mask.size() == 4
		full_tile_planes = full_tile_planes and tile.water_mask.has(Vector2(-half, -half))
		full_tile_planes = full_tile_planes and tile.water_mask.has(Vector2(half, half))
	_check(full_tile_planes, "cada modulo usa uma lamina de agua do tamanho inteiro do tile")
	print("falhas de hidrologia: %d" % failures)
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		failures += 1
		print("  FALHA %s" % label)
