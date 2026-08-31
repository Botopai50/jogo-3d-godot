# Ferramenta de build: varre todos os .fbx do pacote Grid e escreve um catalogo
# com o que cada modulo e, medido de verdade a partir da malha importada.
#
# O catalogo e o que torna os 3.263 modulos utilizaveis: com ele da para
# escolher pecas por pegada, altura e encaixe sem abrir uma a uma no editor.
#
# Uso: godot --headless --path . --script tools/build_catalogo.gd
extends SceneTree

const RAIZ := "res://assets/grid"
const DESTINO := "res://assets/grid/catalogo.json"
## Tolerancia para considerar um vertice encostado na borda do modulo.
const EPSILON := 0.01
## Pegadas de grade reconhecidas, em metros.
const PEGADAS := [100.0, 50.0, 25.0]


func listar(caminho: String, saida: Array) -> void:
	var d := DirAccess.open(caminho)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := caminho.path_join(f)
		if d.current_is_dir():
			listar(p, saida)
		elif f.ends_with(".fbx"):
			saida.append(p)
		f = d.get_next()
	d.list_dir_end()


## Dentro de um .fbx de LOD ha tres malhas sobrepostas (LOD0, LOD1 e LOD2).
## So a LOD0 interessa: o Godot cuida do nivel de detalhe sozinho, e usar as
## tres de uma vez desenharia geometria repetida no mesmo lugar.
func malhas_uteis(raiz: Node) -> Array:
	var todas: Array = []
	var pilha: Array = [{"no": raiz, "transformada": Transform3D.IDENTITY}]
	while not pilha.is_empty():
		var item: Dictionary = pilha.pop_back()
		var no: Node = item["no"]
		var t: Transform3D = item["transformada"]
		if no is Node3D:
			t = t * (no as Node3D).transform
		if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
			todas.append({"nome": no.name, "malha": (no as MeshInstance3D).mesh, "transformada": t})
		for filho in no.get_children():
			pilha.append({"no": filho, "transformada": t})

	var apenas_lod0: Array = []
	for m in todas:
		if String(m["nome"]).ends_with("LOD0"):
			apenas_lod0.append(m)
	return apenas_lod0 if not apenas_lod0.is_empty() else todas


## Classe de profundidade de uma borda. Zero e borda fechada, que encosta em
## qualquer modulo comum; os outros valores sao aberturas que so encaixam
## contra outra abertura da mesma profundidade. No pacote sao duas: o canal de
## rio, com 2 metros, e a bacia de lago, com 6.
func classe_da_borda(fundo: float) -> int:
	if fundo > -0.5:
		return 0
	if fundo > -4.0:
		return 2
	return 6


## Um modulo encaixa na grade quando a pegada bate com um tamanho conhecido e
## os quatro lados estao na altura zero. Ai ele pode ficar ao lado de qualquer
## outro, em qualquer rotacao de 90 graus, sem abrir fresta.
##
## Devolve tambem a assinatura das quatro bordas, na ordem norte, leste, sul e
## oeste. E ela que permite montar rio e lago: cada peca so pode ficar ao lado
## de outra cuja borda vizinha tenha a mesma classe.
func medir_encaixe(malhas: Array, caixa: AABB) -> Dictionary:
	var pegada := 0.0
	for candidata in PEGADAS:
		if absf(caixa.size.x - candidata) < 0.5 and absf(caixa.size.z - candidata) < 0.5:
			pegada = candidata
			break
	if pegada == 0.0:
		return {"pegada": 0.0, "encaixavel": false, "bordas": [], "cruzamentos": [], "perfis": []}

	var x0 := caixa.position.x
	var x1 := caixa.position.x + caixa.size.x
	var z0 := caixa.position.z
	var z1 := caixa.position.z + caixa.size.z
	var limites := [INF, -INF]
	# fundo de cada borda, na ordem norte (z minimo), leste, sul e oeste
	var fundos := [INF, INF, INF, INF]
	var cruzamentos := [0.0, 0.0, 0.0, 0.0]
	# Perfil de cada borda em cinco faixas ao longo dela. Duas pecas so encaixam
	# sem fresta quando os perfis das bordas vizinhas batem: comparar so o ponto
	# mais fundo trata uma rampa e um degrau como se fossem a mesma coisa.
	var perfis: Array = []
	for _b in range(4):
		perfis.append([INF, INF, INF, INF, INF])
	var lado := maxf(caixa.size.x, 0.001)
	var borda := 0.5
	for m in malhas:
		var t: Transform3D = m["transformada"]
		var malha: Mesh = m["malha"]
		for si in range(malha.get_surface_count()):
			for v in malha.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = t * v
				if absf(p.x - x0) < EPSILON or absf(p.x - x1) < EPSILON \
						or absf(p.z - z0) < EPSILON or absf(p.z - z1) < EPSILON:
					limites[0] = minf(limites[0], p.y)
					limites[1] = maxf(limites[1], p.y)
				var centro_x := x0 + caixa.size.x * 0.5
				var centro_z := z0 + caixa.size.z * 0.5
				var faixa_x := clampi(int((p.x - x0) / maxf(caixa.size.x, 0.001) * 5.0), 0, 4)
				var faixa_z := clampi(int((p.z - z0) / maxf(caixa.size.z, 0.001) * 5.0), 0, 4)
				if absf(p.z - z0) < borda:
					(perfis[0] as Array)[faixa_x] = minf(float((perfis[0] as Array)[faixa_x]), p.y)
				if absf(p.x - x1) < borda:
					(perfis[1] as Array)[faixa_z] = minf(float((perfis[1] as Array)[faixa_z]), p.y)
				if absf(p.z - z1) < borda:
					(perfis[2] as Array)[faixa_x] = minf(float((perfis[2] as Array)[faixa_x]), p.y)
				if absf(p.x - x0) < borda:
					(perfis[3] as Array)[faixa_z] = minf(float((perfis[3] as Array)[faixa_z]), p.y)
				if absf(p.z - z0) < borda and p.y < fundos[0]:
					fundos[0] = p.y
					cruzamentos[0] = (p.x - centro_x) / lado
				if absf(p.x - x1) < borda and p.y < fundos[1]:
					fundos[1] = p.y
					cruzamentos[1] = (p.z - centro_z) / lado
				if absf(p.z - z1) < borda and p.y < fundos[2]:
					fundos[2] = p.y
					cruzamentos[2] = (p.x - centro_x) / lado
				if absf(p.x - x0) < borda and p.y < fundos[3]:
					fundos[3] = p.y
					cruzamentos[3] = (p.z - centro_z) / lado
	if limites[0] == INF:
		return {"pegada": pegada, "encaixavel": false, "bordas": [], "cruzamentos": [], "perfis": []}
	var bordas: Array = []
	for i in range(4):
		bordas.append(classe_da_borda(fundos[i]) if fundos[i] != INF else 0)
	# Onde a abertura cruza cada borda, em fracao do lado. O pacote nao
	# padroniza isso: o canal fica fora do centro e varia de peca para peca,
	# entao encadear duas pecas quaisquer desalinha o leito. Guardar a posicao
	# permite escolher a sequencia que menos desencontra.
	var posicoes: Array = []
	for i in range(4):
		posicoes.append(snappedf(cruzamentos[i], 0.001))
	var perfis_limpos: Array = []
	for i in range(4):
		var faixa: Array = []
		for k in range(5):
			var valor: float = float((perfis[i] as Array)[k])
			faixa.append(snappedf(0.0 if valor == INF else valor, 0.01))
		perfis_limpos.append(faixa)
	var plano: bool = absf(limites[0]) < 0.05 and absf(limites[1]) < 0.05
	return {"pegada": pegada, "encaixavel": plano, "bordas": bordas,
		"cruzamentos": posicoes, "perfis": perfis_limpos}


func _init() -> void:
	var arquivos: Array = []
	listar(RAIZ, arquivos)
	arquivos.sort()
	print("modulos encontrados: %d" % arquivos.size())

	var catalogo: Array = []
	var falhas := 0
	var feitos := 0
	for caminho in arquivos:
		var cena: PackedScene = load(caminho)
		if cena == null:
			falhas += 1
			continue
		var raiz := cena.instantiate()
		var malhas := malhas_uteis(raiz)
		if malhas.is_empty():
			raiz.free()
			falhas += 1
			continue

		var caixa := AABB()
		var triangulos := 0
		for i in range(malhas.size()):
			var t: Transform3D = malhas[i]["transformada"]
			var malha: Mesh = malhas[i]["malha"]
			var a: AABB = t * malha.get_aabb()
			caixa = a if i == 0 else caixa.merge(a)
			for si in range(malha.get_surface_count()):
				triangulos += malha.surface_get_arrays(si)[Mesh.ARRAY_INDEX].size() / 3

		var encaixe := medir_encaixe(malhas, caixa)
		var partes: PackedStringArray = caminho.replace(RAIZ + "/", "").split("/")
		catalogo.append({
			"caminho": caminho,
			"nome": caminho.get_file().get_basename(),
			"categoria": partes[1] if partes.size() > 2 else partes[0],
			"estilo": "CPT" if "/CPT/" in caminho else ("MT" if "/MT/" in caminho else "-"),
			"lod": "/LOD/" in caminho and "/NoLOD/" not in caminho,
			"largura": snappedf(caixa.size.x, 0.01),
			"profundidade": snappedf(caixa.size.z, 0.01),
			"y_min": snappedf(caixa.position.y, 0.01),
			"y_max": snappedf(caixa.position.y + caixa.size.y, 0.01),
			"triangulos": triangulos,
			"pegada": encaixe["pegada"],
			"encaixavel": encaixe["encaixavel"],
			"bordas": encaixe["bordas"],
			"cruzamentos": encaixe["cruzamentos"],
			"perfis": encaixe["perfis"],
		})
		feitos += 1
		if feitos % 400 == 0:
			print("  %d/%d" % [feitos, arquivos.size()])
		raiz.free()

	var arquivo := FileAccess.open(DESTINO, FileAccess.WRITE)
	if arquivo == null:
		push_error("nao consegui escrever " + DESTINO)
		quit(1)
		return
	arquivo.store_string(JSON.stringify(catalogo, "  "))
	arquivo.close()

	var encaixaveis := 0
	for e in catalogo:
		if e["encaixavel"]:
			encaixaveis += 1
	print("catalogo escrito: %d modulos (%d encaixam na grade), %d falhas" % [
		catalogo.size(), encaixaveis, falhas])
	quit(0 if falhas == 0 else 1)
