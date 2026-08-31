# Ferramenta de build: converte os modulos do pacote Grid em cenas reutilizaveis
# do Godot.
#
# O pacote inteiro (3.263 arquivos) fica no projeto e e indexado por
# assets/grid/catalogo.json. So entram no build do jogo os modulos que a ilha
# realmente pode usar, escolhidos pelo que foi medido no catalogo: quem tem
# pegada de 100 metros, as quatro bordas na altura zero e nao afunda abaixo do
# nivel do mar. O resto continua disponivel no projeto para uso futuro.
#
# A colisao nao e assada aqui: o gerador da ilha deforma os vertices de cada
# peca com a altura global do terreno e reconstroi a forma de colisao a partir
# da malha ja deformada, entao uma colisao assada seria descartada.
#
# Uso: godot --headless --path . --script tools/build_modules.gd
extends SceneTree

const CATALOGO := "res://assets/grid/catalogo.json"
const DIR_MALHAS := "res://scenes/modules/malhas"
const DIR_FAIXAS := "res://scenes/modules/faixas.json"

const DIR_ACERVO := "res://scenes/modules/acervo.json"

## Pastas de destino por tipo de peca.
const DESTINOS := {
	"terreno": "res://scenes/modules/terrain",
	"props": "res://scenes/modules/props",
	"ilhotas": "res://scenes/modules/islets",
	"nuvens": "res://scenes/modules/clouds",
	"rio": "res://scenes/modules/river",
}

## Categoria do pacote que alimenta cada tipo de peca solta. Elas nao encaixam
## na grade: sao pousadas sobre o terreno, no mar ou no ceu, entao entram todas
## as variantes que nao sao copia de LOD.
const CATEGORIAS_SOLTAS := {
	"props": "Mountains",
	"ilhotas": "Islands",
	"nuvens": "Clouds",
}


func ler_catalogo() -> Array:
	var arquivo := FileAccess.open(CATALOGO, FileAccess.READ)
	if arquivo == null:
		push_error("catalogo ausente; rode tools/build_catalogo.gd antes")
		return []
	var dados: Variant = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	return dados if dados is Array else []


## Dentro de um .fbx de LOD ha tres malhas sobrepostas. So a LOD0 interessa.
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
	var lod0: Array = []
	for m in todas:
		if String(m["nome"]).ends_with("LOD0"):
			lod0.append(m)
	return lod0 if not lod0.is_empty() else todas


## Gera uma cena de modulo: um StaticBody3D com a malha ja centrada na origem.
## Centrar a pegada permite posicionar por celula da grade e girar em multiplos
## de 90 graus sem a peca sair do lugar.
func construir(entrada: Dictionary, destino: String, recentrar: bool) -> bool:
	var caminho: String = entrada["caminho"]
	var cena: PackedScene = load(caminho)
	if cena == null:
		push_error("nao consegui carregar " + caminho)
		return false
	var origem := cena.instantiate()
	var malhas := malhas_uteis(origem)
	if malhas.is_empty():
		origem.free()
		push_error("sem malhas em " + caminho)
		return false

	var caixa := AABB()
	for i in range(malhas.size()):
		var a: AABB = (malhas[i]["transformada"] as Transform3D) * (malhas[i]["malha"] as Mesh).get_aabb()
		caixa = a if i == 0 else caixa.merge(a)

	var deslocamento := Transform3D.IDENTITY
	if recentrar:
		var centro := caixa.position + caixa.size * 0.5
		deslocamento.origin = Vector3(-centro.x, 0.0, -centro.z)

	var nome: String = entrada["nome"]
	var raiz := StaticBody3D.new()
	raiz.name = nome

	for i in range(malhas.size()):
		var t: Transform3D = deslocamento * (malhas[i]["transformada"] as Transform3D)
		var sufixo := "" if malhas.size() == 1 else "_%d" % (i + 1)

		# A malha vem embutida no .fbx importado. Salva-la como recurso binario
		# proprio mantem a cena de modulo pequena e legivel em texto.
		var copia := _malha_enxuta(malhas[i]["malha"] as Mesh)
		var caminho_malha := "%s/%s%s.res" % [DIR_MALHAS, nome, sufixo]
		var err := ResourceSaver.save(copia, caminho_malha)
		if err != OK:
			push_error("falha ao salvar malha %s: %s" % [caminho_malha, error_string(err)])
			origem.free()
			return false

		var mi := MeshInstance3D.new()
		mi.name = "Malha" if malhas.size() == 1 else "Malha%d" % (i + 1)
		mi.mesh = load(caminho_malha)
		mi.transform = t
		raiz.add_child(mi)
		mi.owner = raiz

	var empacotada := PackedScene.new()
	if empacotada.pack(raiz) != OK:
		origem.free()
		raiz.free()
		push_error("falha ao empacotar " + nome)
		return false
	var destino_cena := "%s/%s.tscn" % [destino, nome]
	var err2 := ResourceSaver.save(empacotada, destino_cena)
	origem.free()
	raiz.free()
	if err2 != OK:
		push_error("falha ao salvar %s: %s" % [destino_cena, error_string(err2)])
		return false
	return true


## Copia a malha guardando so o que o jogo usa: posicao, normal e indices.
##
## O material que veio do .fbx aponta para o atlas guardado ao lado do arquivo
## de origem, e essas texturas ficam fora do build; como o cenario pinta tudo
## com o shader continuo, o material e as coordenadas de textura nao sao lidos
## por ninguem. Descartar as UV corta cerca de um quarto do tamanho de cada
## malha. Os .fbx originais continuam no projeto com tudo, entao voltar atras e
## so reassar.
func _malha_enxuta(origem: Mesh) -> ArrayMesh:
	var enxuta := ArrayMesh.new()
	for si in range(origem.get_surface_count()):
		var antigo: Array = origem.surface_get_arrays(si)
		var novo: Array = []
		novo.resize(Mesh.ARRAY_MAX)
		novo[Mesh.ARRAY_VERTEX] = antigo[Mesh.ARRAY_VERTEX]
		novo[Mesh.ARRAY_NORMAL] = antigo[Mesh.ARRAY_NORMAL]
		novo[Mesh.ARRAY_INDEX] = antigo[Mesh.ARRAY_INDEX]
		enxuta.add_surface_from_arrays(origem.surface_get_primitive_type(si), novo)
	return enxuta


## Faixa de relevo de um modulo, pela altura maxima medida no catalogo.
func faixa_de(entrada: Dictionary) -> String:
	var altura: float = entrada["y_max"]
	if altura <= 0.3:
		return "planicie"
	if altura <= 6.0:
		return "colina"
	if altura <= 13.0:
		return "morro"
	if altura <= 26.0:
		return "montanha"
	return "pico"


func _init() -> void:
	var catalogo := ler_catalogo()
	if catalogo.is_empty():
		quit(1)
		return
	for destino: String in DESTINOS.values():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_MALHAS))

	# Terreno: tudo que encaixa na grade de 100 metros, nao e copia de LOD e nao
	# afunda. Boa parte do pacote sao bacias que virariam pocos alagados.
	var terreno: Array = []
	for entrada: Dictionary in catalogo:
		if entrada["categoria"] != "Terrain":
			continue
		if not entrada["encaixavel"] or entrada["pegada"] != 100.0:
			continue
		if entrada["lod"] or entrada["y_min"] < -0.3:
			continue
		terreno.append(entrada)
	terreno.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["nome"] < b["nome"])

	var falhas := 0
	var faixas := {"planicie": [], "colina": [], "morro": [], "montanha": [], "pico": []}
	for entrada: Dictionary in terreno:
		if construir(entrada, DESTINOS["terreno"], true):
			(faixas[faixa_de(entrada)] as Array).append(entrada["nome"])
		else:
			falhas += 1

	# Rio e lago encaixam na grade como o terreno, mas com bordas abertas: o
	# canal tem 2 metros de fundo e a bacia do lago 6. Cada peca so pode ficar
	# ao lado de outra cuja borda vizinha tenha a mesma profundidade, e e a
	# assinatura gravada aqui que permite o gerador montar o tracado.
	var rio: Array = []
	for entrada: Dictionary in catalogo:
		if entrada["categoria"] != "River" or entrada["lod"] or entrada["estilo"] != "CPT":
			continue
		if entrada["pegada"] != 100.0:
			continue
		rio.append(entrada)
	rio.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["nome"] < b["nome"])
	var pecas_de_rio: Array = []
	for entrada: Dictionary in rio:
		if construir(entrada, DESTINOS["rio"], true):
			pecas_de_rio.append({
				"nome": entrada["nome"],
				"bordas": entrada["bordas"],
				"cruzamentos": entrada["cruzamentos"],
				"y_min": entrada["y_min"],
			})
		else:
			falhas += 1

	# Montanhas, ilhas e nuvens nao encaixam na grade: sao pousadas sobre o
	# terreno, no mar e no ceu. Entram todas, menos as copias de LOD. O gerador
	# escolhe cada peca pela largura e pela altura registradas no acervo.
	var acervo := {}
	for tipo: String in CATEGORIAS_SOLTAS:
		var categoria: String = CATEGORIAS_SOLTAS[tipo]
		var lista: Array = []
		for entrada: Dictionary in catalogo:
			if entrada["categoria"] != categoria or entrada["lod"]:
				continue
			# As ilhas "H" sao massas de 445 metros com quase 10 mil triangulos
			# cada: foram feitas para ser a ilha principal, nao enfeite no
			# horizonte. As 47 sozinhas pesariam mais que todo o terreno.
			if categoria == "Islands" and "_H_" in String(entrada["nome"]):
				continue
			lista.append(entrada)
		lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["nome"] < b["nome"])
		var registradas: Array = []
		for entrada: Dictionary in lista:
			if construir(entrada, DESTINOS[tipo], true):
				registradas.append({
					"nome": entrada["nome"],
					"largura": entrada["largura"],
					"y_min": entrada["y_min"],
					"y_max": entrada["y_max"],
				})
			else:
				falhas += 1
		acervo[tipo] = registradas
	acervo["rio"] = pecas_de_rio

	if not _salvar_json(DIR_FAIXAS, faixas) or not _salvar_json(DIR_ACERVO, acervo):
		quit(1)
		return

	print("modulos de terreno no build: %d" % terreno.size())
	for faixa: String in faixas:
		print("  %-10s %d" % [faixa, (faixas[faixa] as Array).size()])
	for tipo: String in acervo:
		print("%-10s %d" % [tipo + ":", (acervo[tipo] as Array).size()])
	print("falhas: %d" % falhas)
	quit(0 if falhas == 0 else 1)


func _salvar_json(caminho: String, dados: Variant) -> bool:
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		push_error("nao consegui escrever " + caminho)
		return false
	arquivo.store_string(JSON.stringify(dados, "  "))
	arquivo.close()
	return true
