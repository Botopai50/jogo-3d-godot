class_name GeradorDaIlha
extends Node3D

## Monta a ilha a partir dos modulos Grid de 100x100.
##
## Todos os modulos do pacote tem as quatro bordas na altura zero, entao eles
## encaixam entre si em qualquer combinacao e em qualquer rotacao multipla de
## 90 graus. A ilha e desenhada como um disco de raio irregular sobre a grade,
## e cada celula recebe um modulo escolhido pela faixa de relevo em que ela cai
## (praia na borda, montanhas e picos no miolo).
##
## Para expandir o mapa depois basta aumentar [member raio_em_modulos] ou
## acrescentar nomes as listas de [constant FAIXAS]: nada precisa ser
## reconstruido a mao.

const PASTA_TERRENO := "res://scenes/modules/terrain/"
const PASTA_PROPS := "res://scenes/modules/props/"
const PASTA_ILHOTAS := "res://scenes/modules/islets/"

## Modulos por faixa de relevo, do centro para a borda.
##
## Todos os nomes daqui foram escolhidos entre os modulos do pacote que nao
## descem abaixo do nivel do mar: boa parte dos modulos Grid sao bacias (o
## grupo "d", por exemplo, sao enseadas que afundam ate 6 metros) e usa-las no
## miolo da ilha abriria pocos alagados.
const FAIXAS := {
	"pico": ["CPT_Terrain_L_b_37", "CPT_Terrain_L_b_36", "CPT_Terrain_L_b_39",
		"CPT_Terrain_L_g_03", "CPT_Terrain_L_g_04"],
	"montanha": ["CPT_Terrain_L_e_17", "CPT_Terrain_L_b_14", "CPT_Terrain_L_b_30",
		"CPT_Terrain_L_b_16", "CPT_Terrain_L_g_02", "CPT_Terrain_L_b_45", "CPT_Terrain_L_b_31"],
	"morro": ["CPT_Terrain_L_e_16", "CPT_Terrain_L_e_14", "CPT_Terrain_L_e_15",
		"CPT_Terrain_L_e_02", "CPT_Terrain_L_e_09", "CPT_Terrain_L_b_08", "CPT_Terrain_L_f_01"],
	"colina": ["CPT_Terrain_L_b_05", "CPT_Terrain_L_e_11", "CPT_Terrain_L_f_11",
		"CPT_Terrain_L_f_06", "CPT_Terrain_L_f_10", "CPT_Terrain_L_e_10"],
	"planicie": ["CPT_Terrain_L_a_01"],
	"rochedo": ["CPT_Terrain_L_a_02"],
	"praia": ["CPT_Terrain_L_a_03"],
}

## Montanhas isoladas usadas como ponto de referencia visual.
const MARCOS := ["CPT_Mountain_L_e_01", "CPT_Mountain_L_d_02"]
## Rochas menores espalhadas pelas celulas planas.
const ROCHAS := ["CPT_Mountain_S_a_01", "CPT_Mountain_S_b_01", "CPT_Mountain_S_c_02"]
## Ilhotas fundeadas no mar em volta da ilha.
const ILHOTAS := ["CPT_Island_S_c_01", "CPT_Island_S_c_02", "CPT_Island_S_c_03", "CPT_Island_M_a_02"]

@export_group("Formato da ilha")
## Raio medio da ilha, contado em modulos de 100x100.
@export_range(2, 20, 1) var raio_em_modulos := 6
## Lado de cada modulo, em metros. Os modulos Grid grandes tem 100.
@export var tamanho_do_modulo := 100.0
## Quanto a linha de costa foge do circulo perfeito (0 = circulo).
@export_range(0.0, 0.5, 0.01) var irregularidade_da_costa := 0.18
## Mesma semente sempre gera exatamente a mesma ilha.
@export var semente := 20260830

@export_group("Detalhes")
## Quantas montanhas isoladas colocar sobre celulas planas.
@export_range(0, 8, 1) var quantidade_de_marcos := 4
## Quantas rochas menores espalhar.
@export_range(0, 80, 1) var quantidade_de_rochas := 26
## Quantas ilhotas fundear no mar.
@export_range(0, 12, 1) var quantidade_de_ilhotas := 5
## Altura das paredes invisiveis que seguram o personagem na ilha.
@export var altura_do_limite := 60.0

var _cache: Dictionary = {}
var _celulas: Dictionary = {}
var _celula_de_nascimento := Vector2i.ZERO
var _aleatorio := RandomNumberGenerator.new()


func _ready() -> void:
	gerar()


## Reconstroi a ilha inteira. Pode ser chamado de novo depois de mudar os
## parametros exportados.
func gerar() -> void:
	for filho in get_children():
		filho.queue_free()
	_cache.clear()
	_celulas.clear()
	_aleatorio.seed = semente

	_marcar_terra()
	var raiz_terreno := _novo_grupo("Terreno")
	var raiz_detalhes := _novo_grupo("Detalhes")
	var raiz_ilhotas := _novo_grupo("Ilhotas")

	_montar_terreno(raiz_terreno)
	_montar_limite()
	_montar_marcos(raiz_detalhes)
	_montar_rochas(raiz_detalhes)
	_montar_ilhotas(raiz_ilhotas)


## Onde o personagem deve nascer: centro da celula reservada, um pouco acima do
## chao para ele assentar com a propria gravidade.
func posicao_de_nascimento() -> Vector3:
	return Vector3(
		_celula_de_nascimento.x * tamanho_do_modulo,
		2.5,
		_celula_de_nascimento.y * tamanho_do_modulo
	)


## Raio aproximado da ilha em metros, util para dimensionar o oceano.
func raio_em_metros() -> float:
	return raio_em_modulos * tamanho_do_modulo * (1.0 + irregularidade_da_costa)


func _novo_grupo(nome: String) -> Node3D:
	var n := Node3D.new()
	n.name = nome
	add_child(n)
	return n


func _cena(pasta: String, nome: String) -> PackedScene:
	var caminho := pasta + nome + ".tscn"
	if not _cache.has(caminho):
		_cache[caminho] = load(caminho)
	return _cache[caminho]


## Ruido barato e estavel por celula, no lugar de uma textura de ruido.
func _ruido(gx: int, gz: int, sal: int) -> float:
	var n := sin(float(gx) * 12.9898 + float(gz) * 78.233 + float(sal + semente) * 0.137) * 43758.5453
	return n - floor(n)


## Raio da ilha na direcao de uma celula, com a costa ondulada.
func _raio_na_direcao(gx: int, gz: int) -> float:
	if gx == 0 and gz == 0:
		return float(raio_em_modulos)
	var angulo := atan2(float(gz), float(gx))
	var ondulacao := (
		sin(angulo * 3.0 + float(semente % 17)) * 0.55
		+ sin(angulo * 5.0 - float(semente % 29)) * 0.30
		+ sin(angulo * 7.0 + float(semente % 41)) * 0.15
	)
	return raio_em_modulos * (1.0 + irregularidade_da_costa * ondulacao)


func _marcar_terra() -> void:
	var alcance := raio_em_modulos + 3
	for gz in range(-alcance, alcance + 1):
		for gx in range(-alcance, alcance + 1):
			var distancia := Vector2(gx, gz).length()
			var raio := _raio_na_direcao(gx, gz)
			if distancia <= raio:
				_celulas[Vector2i(gx, gz)] = distancia / maxf(raio, 0.001)

	# O personagem nasce numa celula plana perto da costa sul, de onde da para
	# ver o mar de um lado e o miolo da ilha do outro.
	for gz in range(raio_em_modulos, 0, -1):
		if _celulas.has(Vector2i(0, gz)):
			_celula_de_nascimento = Vector2i(0, gz)
			break


func _e_terra(gx: int, gz: int) -> bool:
	return _celulas.has(Vector2i(gx, gz))


func _e_borda(gx: int, gz: int) -> bool:
	return not (_e_terra(gx + 1, gz) and _e_terra(gx - 1, gz)
		and _e_terra(gx, gz + 1) and _e_terra(gx, gz - 1))


func _faixa_da_celula(gx: int, gz: int) -> String:
	if Vector2i(gx, gz) == _celula_de_nascimento:
		return "planicie"
	if _e_borda(gx, gz):
		return "praia"
	var t: float = _celulas[Vector2i(gx, gz)] + (_ruido(gx, gz, 1) - 0.5) * 0.12
	if t > 0.86:
		return "praia" if _ruido(gx, gz, 2) < 0.45 else "planicie"
	if t > 0.70:
		return "planicie" if _ruido(gx, gz, 2) < 0.25 else "colina"
	if t > 0.52:
		return "colina" if _ruido(gx, gz, 6) < 0.80 else "morro"
	if t > 0.34:
		return "morro" if _ruido(gx, gz, 6) < 0.65 else "montanha"
	if t > 0.16:
		return "montanha" if _ruido(gx, gz, 6) < 0.80 else "rochedo"
	return "pico"


func _montar_terreno(raiz: Node3D) -> void:
	var chaves: Array = _celulas.keys()
	chaves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for celula in chaves:
		var gx: int = celula.x
		var gz: int = celula.y
		var faixa := _faixa_da_celula(gx, gz)
		var opcoes: Array = FAIXAS[faixa]
		var nome: String = opcoes[int(_ruido(gx, gz, 3) * opcoes.size()) % opcoes.size()]
		var modulo := _cena(PASTA_TERRENO, nome).instantiate() as Node3D
		modulo.name = "%s_%d_%d" % [faixa, gx, gz]
		modulo.position = Vector3(gx * tamanho_do_modulo, 0.0, gz * tamanho_do_modulo)
		# Girar em multiplos de 90 graus quebra a repeticao sem abrir fresta,
		# porque a pegada e quadrada e as bordas ficam todas na altura zero.
		modulo.rotation.y = float(int(_ruido(gx, gz, 4) * 4.0) % 4) * PI * 0.5
		raiz.add_child(modulo)


## Paredes invisiveis em cada aresta de terra que da para o mar. Sem elas o
## personagem cairia da borda da ilha para fora do cenario.
func _montar_limite() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "LimiteDaIlha"
	corpo.collision_layer = 4  # camada "limite_da_ilha"
	corpo.collision_mask = 0
	add_child(corpo)

	var meio := tamanho_do_modulo * 0.5
	var espessura := 2.0
	var direcoes := [
		[Vector2i(1, 0), Vector3(meio, 0.0, 0.0), Vector3(espessura, altura_do_limite, tamanho_do_modulo)],
		[Vector2i(-1, 0), Vector3(-meio, 0.0, 0.0), Vector3(espessura, altura_do_limite, tamanho_do_modulo)],
		[Vector2i(0, 1), Vector3(0.0, 0.0, meio), Vector3(tamanho_do_modulo, altura_do_limite, espessura)],
		[Vector2i(0, -1), Vector3(0.0, 0.0, -meio), Vector3(tamanho_do_modulo, altura_do_limite, espessura)],
	]
	var quantidade := 0
	for celula in _celulas.keys():
		var base := Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo)
		for direcao in direcoes:
			var vizinho: Vector2i = celula + direcao[0]
			if _celulas.has(vizinho):
				continue
			var caixa := BoxShape3D.new()
			caixa.size = direcao[2]
			var forma := CollisionShape3D.new()
			forma.name = "Limite%d" % quantidade
			forma.shape = caixa
			forma.position = base + direcao[1] + Vector3(0.0, altura_do_limite * 0.5 - 5.0, 0.0)
			corpo.add_child(forma)
			quantidade += 1


func _celulas_planas() -> Array:
	var planas: Array = []
	for celula in _celulas.keys():
		if celula == _celula_de_nascimento:
			continue
		var faixa := _faixa_da_celula(celula.x, celula.y)
		if faixa == "planicie" or faixa == "praia" or faixa == "colina" or faixa == "rochedo":
			planas.append(celula)
	planas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return planas


func _montar_marcos(raiz: Node3D) -> void:
	var candidatas: Array = []
	for celula in _celulas.keys():
		if _faixa_da_celula(celula.x, celula.y) == "planicie":
			candidatas.append(celula)
	candidatas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.length_squared() < b.length_squared())
	var usadas := 0
	var indice := 0
	while usadas < quantidade_de_marcos and indice < candidatas.size():
		var celula: Vector2i = candidatas[indice]
		indice += maxi(1, candidatas.size() / maxi(quantidade_de_marcos, 1))
		if celula == _celula_de_nascimento:
			continue
		var nome: String = MARCOS[usadas % MARCOS.size()]
		var marco := _cena(PASTA_PROPS, nome).instantiate() as Node3D
		marco.name = "Marco_%d_%d" % [celula.x, celula.y]
		marco.position = Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo)
		marco.rotation.y = _ruido(celula.x, celula.y, 5) * TAU
		raiz.add_child(marco)
		usadas += 1


func _montar_rochas(raiz: Node3D) -> void:
	var planas := _celulas_planas()
	if planas.is_empty():
		return
	for i in range(quantidade_de_rochas):
		var celula: Vector2i = planas[(i * 7 + 3) % planas.size()]
		var nome: String = ROCHAS[i % ROCHAS.size()]
		var rocha := _cena(PASTA_PROPS, nome).instantiate() as Node3D
		rocha.name = "Rocha_%d" % i
		var desvio := Vector3(
			(_ruido(celula.x, celula.y, 10 + i) - 0.5) * tamanho_do_modulo * 0.5,
			0.0,
			(_ruido(celula.x, celula.y, 40 + i) - 0.5) * tamanho_do_modulo * 0.5
		)
		rocha.position = Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo) + desvio
		rocha.rotation.y = _ruido(celula.x, celula.y, 70 + i) * TAU
		# Rochas maiores que o tamanho original: nas planicies de 100 m elas
		# so viram ponto de referencia se derem para ver de longe.
		var escala := 1.6 + _ruido(celula.x, celula.y, 90 + i) * 1.6
		rocha.scale = Vector3(escala, escala, escala)
		raiz.add_child(rocha)


func _montar_ilhotas(raiz: Node3D) -> void:
	var raio := raio_em_metros()
	for i in range(quantidade_de_ilhotas):
		var nome: String = ILHOTAS[i % ILHOTAS.size()]
		var ilhota := _cena(PASTA_ILHOTAS, nome).instantiate() as Node3D
		ilhota.name = "Ilhota_%d" % i
		var angulo := TAU * (float(i) / maxf(float(quantidade_de_ilhotas), 1.0)) + 0.6
		var distancia := raio + 180.0 + _ruido(i, i * 3, 200) * 320.0
		ilhota.position = Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		ilhota.rotation.y = _ruido(i, i * 5, 300) * TAU
		raiz.add_child(ilhota)
