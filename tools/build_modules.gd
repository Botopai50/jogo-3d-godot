# Ferramenta de build: converte cada .fbx do pacote Grid em uma cena de modulo
# reutilizavel do Godot (StaticBody3D + malha + colisao trimesh assada).
#
# Os modulos de terreno sao recentrados para que a pegada de 100x100 fique
# centrada na origem: assim da para posicionar por celula da grade e girar em
# multiplos de 90 graus sem sair do lugar.
#
# Uso: godot --headless --path . --script tools/build_modules.gd
extends SceneTree

const MATERIAL_TERRENO := "res://materials/terreno_atlas.tres"
const DIR_COLISAO := "res://scenes/modules/colisao"
const DIR_MALHAS := "res://scenes/modules/malhas"

# origem -> (destino, recentrar_xz)
const GRUPOS := {
	"res://assets/grid/terrain": ["res://scenes/modules/terrain", true],
	"res://assets/grid/props": ["res://scenes/modules/props", true],
	"res://assets/grid/islets": ["res://scenes/modules/islets", true],
}

var material: Material


func coletar_malhas(node: Node, acumulado: Transform3D, saida: Array) -> void:
	var t := acumulado
	if node is Node3D:
		t = acumulado * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		saida.append({"mesh": (node as MeshInstance3D).mesh, "transform": t})
	for filho in node.get_children():
		coletar_malhas(filho, t, saida)


func construir(caminho_fbx: String, destino: String, recentrar: bool) -> bool:
	var cena: PackedScene = load(caminho_fbx)
	if cena == null:
		push_error("nao consegui carregar " + caminho_fbx)
		return false
	var origem := cena.instantiate()
	var malhas: Array = []
	coletar_malhas(origem, Transform3D.IDENTITY, malhas)
	if malhas.is_empty():
		push_error("sem malhas em " + caminho_fbx)
		origem.free()
		return false

	var caixa := AABB()
	for i in range(malhas.size()):
		var a: AABB = (malhas[i]["transform"] as Transform3D) * (malhas[i]["mesh"] as Mesh).get_aabb()
		caixa = a if i == 0 else caixa.merge(a)

	var deslocamento := Transform3D.IDENTITY
	if recentrar:
		var centro := caixa.position + caixa.size * 0.5
		deslocamento.origin = Vector3(-centro.x, 0.0, -centro.z)

	var nome := caminho_fbx.get_file().get_basename()
	var raiz := StaticBody3D.new()
	raiz.name = nome

	for i in range(malhas.size()):
		var t: Transform3D = deslocamento * (malhas[i]["transform"] as Transform3D)
		var m: Mesh = malhas[i]["mesh"]

		var sufixo := "" if malhas.size() == 1 else "_%d" % (i + 1)

		# A malha vem embutida no .fbx importado. Salva-la como recurso binario
		# proprio mantem as cenas de modulo pequenas e legiveis em texto, e faz
		# todos os modulos compartilharem o mesmo material do atlas.
		var malha_salva: ArrayMesh = m.duplicate(true)
		for si in range(malha_salva.get_surface_count()):
			malha_salva.surface_set_material(si, material)
		var caminho_malha := "%s/%s%s.res" % [DIR_MALHAS, nome, sufixo]
		var err_malha := ResourceSaver.save(malha_salva, caminho_malha)
		if err_malha != OK:
			push_error("falha ao salvar malha %s: %s" % [caminho_malha, error_string(err_malha)])
			origem.free()
			return false

		var mi := MeshInstance3D.new()
		mi.name = "Malha" if malhas.size() == 1 else "Malha%d" % (i + 1)
		mi.mesh = load(caminho_malha)
		mi.transform = t
		raiz.add_child(mi)
		mi.owner = raiz

		var forma: ConcavePolygonShape3D = m.create_trimesh_shape()
		var caminho_forma := "%s/%s%s.res" % [DIR_COLISAO, nome, sufixo]
		var err := ResourceSaver.save(forma, caminho_forma)
		if err != OK:
			push_error("falha ao salvar colisao %s: %s" % [caminho_forma, error_string(err)])
			origem.free()
			return false

		var cs := CollisionShape3D.new()
		cs.name = "Colisao" if malhas.size() == 1 else "Colisao%d" % (i + 1)
		cs.shape = load(caminho_forma)
		cs.transform = t
		raiz.add_child(cs)
		cs.owner = raiz

	var empacotada := PackedScene.new()
	if empacotada.pack(raiz) != OK:
		push_error("falha ao empacotar " + nome)
		origem.free()
		return false
	var destino_cena := "%s/%s.tscn" % [destino, nome]
	var err2 := ResourceSaver.save(empacotada, destino_cena)
	origem.free()
	raiz.free()
	if err2 != OK:
		push_error("falha ao salvar %s: %s" % [destino_cena, error_string(err2)])
		return false
	return true


func _init() -> void:
	material = load(MATERIAL_TERRENO)
	if material == null:
		push_error("material do terreno nao encontrado; rode tools/build_materials.gd antes")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_COLISAO))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_MALHAS))

	var total := 0
	var falhas := 0
	for origem in GRUPOS:
		var destino: String = GRUPOS[origem][0]
		var recentrar: bool = GRUPOS[origem][1]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
		var d := DirAccess.open(origem)
		if d == null:
			push_error("pasta ausente: " + origem)
			falhas += 1
			continue
		var arquivos: Array = []
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".fbx"):
				arquivos.append(f)
			f = d.get_next()
		arquivos.sort()
		for arquivo in arquivos:
			if construir(origem.path_join(arquivo), destino, recentrar):
				total += 1
			else:
				falhas += 1
		print("%s -> %s: %d arquivos" % [origem, destino, arquivos.size()])

	print("modulos gerados: %d | falhas: %d" % [total, falhas])
	quit(0 if falhas == 0 else 1)
