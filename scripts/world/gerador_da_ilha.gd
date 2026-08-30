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
const SHADER_TERRENO_CONTINUO := preload("res://shaders/terreno_continuo.gdshader")

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
## Largura aproximada da faixa costeira organica que aparece alem dos modulos.
@export_range(20.0, 160.0, 5.0) var largura_da_costa := 55.0
## Quantidade de lados da silhueta costeira. Valores altos deixam a curva suave.
@export_range(32, 192, 8) var segmentos_da_costa := 96
## Quanto a beirada da praia mergulha sob o nivel do mar.
@export_range(0.1, 3.0, 0.05) var profundidade_da_beirada := 0.8

@export_group("Detalhes")
## Quantas montanhas isoladas colocar sobre celulas planas.
@export_range(0, 8, 1) var quantidade_de_marcos := 1
## Quantas rochas menores espalhar.
@export_range(0, 80, 1) var quantidade_de_rochas := 10
## Quantas ilhotas fundear no mar.
@export_range(0, 12, 1) var quantidade_de_ilhotas := 5
## Altura das paredes invisiveis que seguram o personagem na ilha.
@export var altura_do_limite := 60.0

var _cache: Dictionary = {}
var _celulas: Dictionary = {}
var _celula_de_nascimento := Vector2i.ZERO
var _aleatorio := RandomNumberGenerator.new()
var _material_terreno_continuo: ShaderMaterial


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

	_montar_base_organica()
	_montar_terreno(raiz_terreno)
	_montar_limite()
	_montar_marcos(raiz_detalhes)
	_montar_rochas(raiz_detalhes)
	_montar_ilhotas(raiz_ilhotas)


## Onde o personagem deve nascer: centro da celula reservada, um pouco acima do
## chao para ele assentar com a propria gravidade.
func posicao_de_nascimento() -> Vector3:
	var x := _celula_de_nascimento.x * tamanho_do_modulo
	var z := _celula_de_nascimento.y * tamanho_do_modulo
	return Vector3(
		x,
		_altura_macro_do_terreno(x, z) + 2.5,
		z
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


func _material_do_terreno() -> ShaderMaterial:
	if _material_terreno_continuo == null:
		_material_terreno_continuo = ShaderMaterial.new()
		_material_terreno_continuo.shader = SHADER_TERRENO_CONTINUO
	return _material_terreno_continuo


## Altura de grande escala compartilhada por todos os modulos. Ela zera antes
## da praia, mas ergue e ondula o interior da ilha. Como a funcao depende da
## posicao global, dois vertices coincidentes recebem exatamente a mesma altura
## mesmo quando pertencem a cenas diferentes.
func _altura_macro_do_terreno(x: float, z: float) -> float:
	var ponto := Vector2(x, z)
	if ponto.is_zero_approx():
		return 22.0
	var raio := _raio_na_direcao(ponto.x, ponto.y) * tamanho_do_modulo
	var distancia_normalizada := ponto.length() / maxf(raio, 1.0)
	var influencia := 1.0 - smoothstep(0.50, 0.72, distancia_normalizada)
	if influencia <= 0.0:
		return 0.0

	var domo := pow(maxf(1.0 - distancia_normalizada, 0.0), 1.5) * 22.0
	var ondas := (
		sin(x * 0.007 + z * 0.002 + 0.8)
		+ sin(z * 0.009 - x * 0.001 - 1.1)
		+ sin((x - z) * 0.005 + 2.0)
	) * 2.0
	return maxf((domo + ondas) * influencia, 0.0)


## Incorpora a escala vertical e a altura macro aos vertices de uma instancia
## e refaz sua colisao. Isso evita tanto as emendas em degrau quanto a diferenca
## entre o que o jogador ve e a superficie onde ele pisa.
func _deformar_modulo(modulo: Node3D, escala_vertical: float) -> void:
	var visual := modulo.get_node_or_null("Malha") as MeshInstance3D
	var colisao := modulo.get_node_or_null("Colisao") as CollisionShape3D
	if visual == null or visual.mesh == null or colisao == null:
		return

	var origem := visual.mesh
	var transformacao_original := visual.transform
	var base_deformada := Basis.IDENTITY.scaled(Vector3(1.0, escala_vertical, 1.0)) * transformacao_original.basis
	var transformacao_da_normal := base_deformada.inverse().transposed()
	var malha_deformada := ArrayMesh.new()

	for superficie in range(origem.get_surface_count()):
		var arrays: Array = origem.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normais: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

		for indice in range(vertices.size()):
			var vertice := transformacao_original * vertices[indice]
			vertice.y *= escala_vertical
			var ponto_na_ilha := modulo.transform * vertice
			vertice.y += _altura_macro_do_terreno(ponto_na_ilha.x, ponto_na_ilha.z)
			vertices[indice] = vertice

		for indice in range(normais.size()):
			normais[indice] = (transformacao_da_normal * normais[indice]).normalized()

		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normais
		malha_deformada.add_surface_from_arrays(origem.surface_get_primitive_type(superficie), arrays)

	visual.transform = Transform3D.IDENTITY
	visual.mesh = malha_deformada
	colisao.transform = Transform3D.IDENTITY
	colisao.shape = malha_deformada.create_trimesh_shape()


## Percorre a cena inteira porque alguns props guardam a malha mais de um
## nivel abaixo da raiz. Assim terreno, montanhas isoladas e rochas recebem
## exatamente o mesmo material em coordenadas globais.
func _aplicar_material_continuo(raiz: Node) -> void:
	if raiz is MeshInstance3D:
		(raiz as MeshInstance3D).material_override = _material_do_terreno()
	for filho: Node in raiz.get_children():
		_aplicar_material_continuo(filho)


## Ruido barato e estavel por celula, no lugar de uma textura de ruido.
func _ruido(gx: int, gz: int, sal: int) -> float:
	var n := sin(float(gx) * 12.9898 + float(gz) * 78.233 + float(sal + semente) * 0.137) * 43758.5453
	return n - floor(n)


## Raio da ilha na direcao de uma celula, com a costa ondulada.
func _raio_na_direcao(gx: float, gz: float) -> float:
	if is_zero_approx(gx) and is_zero_approx(gz):
		return float(raio_em_modulos)
	var angulo := atan2(gz, gx)
	var ondulacao := (
		sin(angulo * 3.0 + float(semente % 17)) * 0.55
		+ sin(angulo * 5.0 - float(semente % 29)) * 0.30
		+ sin(angulo * 7.0 + float(semente % 41)) * 0.15
	)
	return raio_em_modulos * (1.0 + irregularidade_da_costa * ondulacao)


## So usa um modulo quadrado quando todos os seus cantos cabem dentro da
## costa. A praia procedural preenche a faixa restante e passa a definir a
## silhueta da ilha, sem os antigos degraus de 100 metros.
func _modulo_cabe_na_ilha(gx: int, gz: int) -> bool:
	var recuo := largura_da_costa / tamanho_do_modulo
	var cantos: Array[Vector2] = [Vector2(-0.5, -0.5), Vector2(0.5, -0.5),
			Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	for canto: Vector2 in cantos:
		var ponto: Vector2 = Vector2(float(gx), float(gz)) + canto
		if ponto.length() + recuo > _raio_na_direcao(ponto.x, ponto.y):
			return false
	return true


func _marcar_terra() -> void:
	var alcance := raio_em_modulos + 3
	for gz in range(-alcance, alcance + 1):
		for gx in range(-alcance, alcance + 1):
			var distancia := Vector2(gx, gz).length()
			var raio := _raio_na_direcao(float(gx), float(gz))
			if _modulo_cabe_na_ilha(gx, gz):
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


func _intensidade_do_relevo(gx: int, gz: int) -> float:
	var t: float = _celulas[Vector2i(gx, gz)]
	var distancia_do_eixo := absf(float(gz) * 0.88 - float(gx) * 0.34)
	var forca_da_cadeia := clampf(1.0 - distancia_do_eixo / 2.2, 0.0, 1.0)
	forca_da_cadeia *= clampf(1.15 - t, 0.0, 1.0)
	# Ruido baixo quebra a simetria sem permitir saltos de planicie direto para
	# montanha entre duas celulas vizinhas.
	forca_da_cadeia += (_ruido(gx, gz, 6) - 0.5) * 0.08
	return clampf(forca_da_cadeia, 0.0, 1.0)


func _faixa_da_celula(gx: int, gz: int) -> String:
	if Vector2i(gx, gz) == _celula_de_nascimento:
		return "planicie"
	var t: float = _celulas[Vector2i(gx, gz)]
	var intensidade := _intensidade_do_relevo(gx, gz)
	var sorte := _ruido(gx, gz, 18)

	if t > 0.72:
		return "planicie"
	if intensidade > 0.84:
		return "pico"
	if intensidade > 0.64:
		return "montanha"
	if intensidade > 0.44:
		return "morro"
	if intensidade > 0.23:
		return "colina"
	return "rochedo" if sorte > 0.96 else "planicie"


func _escala_vertical(faixa: String, gx: int, gz: int) -> float:
	var intensidade := _intensidade_do_relevo(gx, gz)
	var variacao := (_ruido(gx, gz, 120) - 0.5) * 0.12
	match faixa:
		"pico":
			return 1.15 + intensidade * 0.55 + variacao
		"montanha":
			return 0.72 + intensidade * 0.62 + variacao
		"morro":
			return 0.48 + intensidade * 0.68 + variacao
		"colina":
			return 0.30 + intensidade * 0.72 + variacao
		"rochedo":
			return 0.48 + intensidade * 0.45 + variacao
		_:
			return 0.34 + variacao


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
		_deformar_modulo(modulo, _escala_vertical(faixa, gx, gz))
		_aplicar_material_continuo(modulo)
		raiz.add_child(modulo)


## Cria uma praia continua com contorno arredondado. O miolo fica alguns
## centimetros abaixo dos modulos, enquanto a borda mergulha no oceano; isso
## esconde a geometria quadrada sem causar z-fighting.
func _montar_base_organica() -> void:
	var malha := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var indices := PackedInt32Array()
	var segmentos := maxi(segmentos_da_costa, 32)
	# O tom interno acompanha a media do shader continuo para que a borda dos
	# modulos desapareca visualmente sobre a base.
	var cor_terreno := Color(0.28, 0.54, 0.26)
	var cor_areia := Color(0.56, 0.50, 0.31)

	vertices.append(Vector3(0.0, -0.03, 0.0))
	normais.append(Vector3.UP)
	cores.append(cor_terreno)
	for i in range(segmentos):
		var angulo := TAU * float(i) / float(segmentos)
		var direcao := Vector2(cos(angulo), sin(angulo))
		var raio_externo := _raio_na_direcao(direcao.x, direcao.y) * tamanho_do_modulo
		var raio_interno := maxf(raio_externo - largura_da_costa, 1.0)
		vertices.append(Vector3(direcao.x * raio_interno, -0.03, direcao.y * raio_interno))
		normais.append(Vector3.UP)
		cores.append(cor_terreno)
		vertices.append(Vector3(direcao.x * raio_externo, -profundidade_da_beirada, direcao.y * raio_externo))
		normais.append(Vector3.UP)
		cores.append(cor_areia)

	for i in range(segmentos):
		var proximo := (i + 1) % segmentos
		var interno := 1 + i * 2
		var externo := interno + 1
		var interno_proximo := 1 + proximo * 2
		var externo_proximo := interno_proximo + 1

		indices.append_array([0, interno, interno_proximo])
		indices.append_array([interno, externo_proximo, interno_proximo])
		indices.append_array([interno, externo, externo_proximo])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_COLOR] = cores
	arrays[Mesh.ARRAY_INDEX] = indices
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	malha.surface_set_material(0, material)

	var corpo := StaticBody3D.new()
	corpo.name = "CostaOrganica"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)

	var visual := MeshInstance3D.new()
	visual.name = "Malha"
	visual.mesh = malha
	corpo.add_child(visual)

	var colisao := CollisionShape3D.new()
	colisao.name = "Colisao"
	colisao.shape = malha.create_trimesh_shape()
	corpo.add_child(colisao)


## Paredes invisiveis ao longo do contorno organico. Sem elas o personagem
## poderia atravessar a linha da costa e cair para fora do cenario.
func _montar_limite() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "LimiteDaIlha"
	corpo.collision_layer = 4  # camada "limite_da_ilha"
	corpo.collision_mask = 0
	add_child(corpo)

	var segmentos := maxi(segmentos_da_costa, 32)
	for i in range(segmentos):
		var angulo_a := TAU * float(i) / float(segmentos)
		var angulo_b := TAU * float(i + 1) / float(segmentos)
		var direcao_a := Vector2(cos(angulo_a), sin(angulo_a))
		var direcao_b := Vector2(cos(angulo_b), sin(angulo_b))
		var raio_a := _raio_na_direcao(direcao_a.x, direcao_a.y) * tamanho_do_modulo
		var raio_b := _raio_na_direcao(direcao_b.x, direcao_b.y) * tamanho_do_modulo
		var ponto_a := Vector3(direcao_a.x * raio_a, 0.0, direcao_a.y * raio_a)
		var ponto_b := Vector3(direcao_b.x * raio_b, 0.0, direcao_b.y * raio_b)
		var trecho := ponto_b - ponto_a

		var caixa := BoxShape3D.new()
		caixa.size = Vector3(trecho.length() + 1.0, altura_do_limite, 2.0)
		var forma := CollisionShape3D.new()
		forma.name = "Limite%d" % i
		forma.shape = caixa
		forma.position = (ponto_a + ponto_b) * 0.5 + Vector3(0.0, altura_do_limite * 0.5 - 5.0, 0.0)
		forma.rotation.y = -atan2(trecho.z, trecho.x)
		corpo.add_child(forma)


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
		marco.position.y = _altura_macro_do_terreno(marco.position.x, marco.position.z)
		marco.rotation.y = _ruido(celula.x, celula.y, 5) * TAU
		_aplicar_material_continuo(marco)
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
		rocha.position.y = _altura_macro_do_terreno(rocha.position.x, rocha.position.z)
		rocha.rotation.y = _ruido(celula.x, celula.y, 70 + i) * TAU
		# Rochas maiores que o tamanho original: nas planicies de 100 m elas
		# so viram ponto de referencia se derem para ver de longe.
		var escala := 1.6 + _ruido(celula.x, celula.y, 90 + i) * 1.6
		rocha.scale = Vector3(escala, escala, escala)
		_aplicar_material_continuo(rocha)
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
