# Ferramenta de build: cria os materiais nativos do Godot usados pelo cenario.
# Os materiais do pacote original sao .mat da Unity e nao podem ser lidos aqui,
# entao sao recriados a partir do mesmo atlas de textura.
# Uso: godot --headless --path . --script tools/build_materials.gd
extends SceneTree

const ATLAS := "res://assets/grid/textures/CPT_Terrain_Texture_Atlas_01.png"

func _init() -> void:
	var terreno := StandardMaterial3D.new()
	terreno.resource_name = "Atlas do terreno (Grid)"
	terreno.albedo_texture = load(ATLAS)
	# O atlas tem 4 quadrantes de cor chapada (grama, neve, rocha, areia).
	# Filtro "nearest" mantem as cores puras; os mipmaps evitam cintilacao ao longe.
	terreno.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	terreno.roughness = 0.95
	terreno.metallic = 0.0
	var e1 := ResourceSaver.save(terreno, "res://materials/terreno_atlas.tres")
	print("materials/terreno_atlas.tres -> ", error_string(e1))

	var oceano := ShaderMaterial.new()
	oceano.resource_name = "Oceano"
	oceano.shader = load("res://shaders/oceano.gdshader")
	var e2 := ResourceSaver.save(oceano, "res://materials/oceano.tres")
	print("materials/oceano.tres -> ", error_string(e2))

	quit(0 if e1 == OK and e2 == OK else 1)
