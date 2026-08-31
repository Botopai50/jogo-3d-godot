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
## As faixas de relevo nao sao escritas a mao: vem de
## scenes/modules/faixas.json, que o build monta a partir do catalogo do pacote
## medindo a altura de cada peca. Sao 173 modulos, todos os do pacote que
## encaixam na grade e nao afundam abaixo do nivel do mar.
##
## Para expandir o mapa depois basta aumentar [member raio_em_modulos]: nada
## precisa ser reconstruido a mao.

const PASTA_TERRENO := "res://scenes/modules/terrain/"
const PASTA_PROPS := "res://scenes/modules/props/"
const PASTA_ILHOTAS := "res://scenes/modules/islets/"
const PASTA_NUVENS := "res://scenes/modules/clouds/"
const SHADER_TERRENO_CONTINUO := preload("res://shaders/terreno_continuo.gdshader")
const SHADER_COSTA_ORGANICA := preload("res://shaders/costa_organica.gdshader")

## Faixas de relevo montadas pelo build a partir do catalogo do pacote.
const FAIXAS_GERADAS := "res://scenes/modules/faixas.json"

## Pecas soltas do pacote montadas pelo build: montanhas, ilhas e nuvens.
## Cada entrada traz a largura e a altura medidas, que sao o que decide se uma
## montanha vira marco na paisagem, afloramento no meio do campo ou pedra.
const ACERVO_GERADO := "res://scenes/modules/acervo.json"
## Largura minima, em metros, para uma montanha valer como marco da paisagem.
const LARGURA_DE_MARCO := 70.0
## Abaixo desta largura a peca e tratada como pedra solta.
const LARGURA_DE_ROCHA := 30.0

@export_group("Formato da ilha")
## Raio medio da ilha, contado em modulos de 100x100.
@export_range(2, 20, 1) var raio_em_modulos := 4
## Distancia entre os centros das celulas, em metros. Os assets originais tem
## 100 m; valores maiores ampliam malha e colisao para manter o encaixe.
@export_range(60.0, 300.0, 5.0) var tamanho_do_modulo := 250.0
## Quanto a linha de costa foge do circulo perfeito (0 = circulo).
@export_range(0.0, 0.5, 0.01) var irregularidade_da_costa := 0.18
## Mesma semente sempre gera exatamente a mesma ilha.
@export var semente := 20260830
## Largura aproximada da faixa costeira organica que aparece alem dos modulos.
@export_range(20.0, 200.0, 5.0) var largura_da_costa := 110.0
## Quantidade de lados da silhueta costeira. Valores altos deixam a curva suave.
@export_range(32, 192, 8) var segmentos_da_costa := 96
## Quanto a beirada da praia mergulha sob o nivel do mar.
@export_range(0.1, 3.0, 0.05) var profundidade_da_beirada := 0.8

@export_group("Altura procedural")
## Altura do domo central que sustenta a massa principal da ilha.
@export_range(0.0, 50.0, 1.0) var altura_base_do_miolo := 18.0
## Intensidade de vales e elevacoes grandes gerados pela semente.
@export_range(0.0, 40.0, 1.0) var variacao_ampla_da_altura := 16.0
## Intensidade das ondulacoes menores sobre o relevo amplo.
@export_range(0.0, 20.0, 0.5) var variacao_fina_da_altura := 5.0

@export_group("Detalhes")
## Multiplica apenas a altura dos modulos acidentados. A largura continua em
## 100 m para preservar o encaixe perfeito do grid.
@export_range(0.5, 4.0, 0.1) var escala_do_relevo := 1.0
## Escala uniforme das grandes montanhas usadas como pontos de referencia.
@export_range(0.5, 5.0, 0.1) var escala_dos_marcos := 1.0
## Quantas montanhas isoladas colocar sobre celulas planas.
@export_range(0, 40, 1) var quantidade_de_marcos := 6
## Quantos afloramentos de porte medio espalhar pelo campo.
@export_range(0, 120, 1) var quantidade_de_afloramentos := 24
## Quantas rochas menores espalhar.
@export_range(0, 200, 1) var quantidade_de_rochas := 60
## Quantas ilhotas fundear no mar.
@export_range(0, 60, 1) var quantidade_de_ilhotas := 14
## Quantas nuvens pousar no ceu.
@export_range(0, 80, 1) var quantidade_de_nuvens := 28
## Altura em que as nuvens flutuam, em metros.
@export_range(60.0, 600.0, 10.0) var altura_das_nuvens := 260.0
## Altura das paredes invisiveis que seguram o personagem na ilha.
@export var altura_do_limite := 60.0

var _cache: Dictionary = {}
var _celulas: Dictionary = {}
var _celula_de_nascimento := Vector2i.ZERO
var _aleatorio := RandomNumberGenerator.new()
var _material_terreno_continuo: ShaderMaterial
var _faixas: Dictionary = {}
var _marcos: Array = []
var _afloramentos: Array = []
var _rochas: Array = []
var _ilhotas: Array = []
var _nuvens: Array = []
var _material_das_nuvens: StandardMaterial3D
var _ruido_de_altura_amplo := FastNoiseLite.new()
var _ruido_de_altura_fino := FastNoiseLite.new()


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
	_configurar_ruido_de_altura()

	_carregar_faixas()
	_carregar_acervo()
	_marcar_terra()
	var raiz_terreno := _novo_grupo("Terreno")
	var raiz_detalhes := _novo_grupo("Detalhes")
	var raiz_ilhotas := _novo_grupo("Ilhotas")

	_montar_base_organica()
	_montar_terreno(raiz_terreno)
	_montar_limite()
	_montar_marcos(raiz_detalhes)
	# Afloramentos de porte medio e pedras pequenas saem do mesmo acervo de
	# montanhas, separadas pela largura medida no build.
	_espalhar(raiz_detalhes, _afloramentos, quantidade_de_afloramentos, "Afloramento", 1.0, 1.8, 400)
	_espalhar(raiz_detalhes, _rochas, quantidade_de_rochas, "Rocha", 1.4, 3.0, 700)
	_montar_ilhotas(raiz_ilhotas)
	_montar_nuvens(_novo_grupo("Nuvens"))


## Le as faixas de relevo montadas pelo build. Cada faixa e a lista de modulos
## do pacote cuja altura maxima cai naquele intervalo.
func _carregar_faixas() -> void:
	var arquivo := FileAccess.open(FAIXAS_GERADAS, FileAccess.READ)
	if arquivo == null:
		push_error("faixas ausentes; rode tools/build_modules.gd antes")
		return
	var dados: Variant = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if dados is Dictionary:
		_faixas = dados


## Le o acervo de pecas soltas e separa as montanhas por porte. O pacote traz
## 480 montanhas, de pedras de 8 metros a macicos de 105: usar todas na mesma
## funcao deixaria pedra do tamanho de morro e morro do tamanho de pedra.
func _carregar_acervo() -> void:
	var arquivo := FileAccess.open(ACERVO_GERADO, FileAccess.READ)
	if arquivo == null:
		push_error("acervo ausente; rode tools/build_modules.gd antes")
		return
	var dados: Variant = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not dados is Dictionary:
		return
	_ilhotas = dados.get("ilhotas", [])
	_nuvens = dados.get("nuvens", [])
	_marcos.clear()
	_afloramentos.clear()
	_rochas.clear()
	for peca: Dictionary in dados.get("props", []):
		var largura: float = peca["largura"]
		if largura >= LARGURA_DE_MARCO:
			_marcos.append(peca)
		elif largura >= LARGURA_DE_ROCHA:
			_afloramentos.append(peca)
		else:
			_rochas.append(peca)


## Escolhe uma peca do acervo de forma estavel, a partir de um numero de ruido.
func _sortear(lista: Array, sorte: float) -> String:
	if lista.is_empty():
		return ""
	var indice := int(sorte * float(lista.size())) % lista.size()
	return (lista[indice] as Dictionary)["nome"]


## Quantos modulos distintos o cenario tem a disposicao.
func modulos_disponiveis() -> int:
	var total := 0
	for faixa: String in _faixas:
		total += (_faixas[faixa] as Array).size()
	return total + _marcos.size() + _afloramentos.size() + _rochas.size() \
		+ _ilhotas.size() + _nuvens.size()


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


func _configurar_ruido_de_altura() -> void:
	_ruido_de_altura_amplo.seed = semente
	_ruido_de_altura_amplo.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_de_altura_amplo.frequency = 0.0018
	_ruido_de_altura_amplo.fractal_type = FastNoiseLite.FRACTAL_FBM
	_ruido_de_altura_amplo.fractal_octaves = 4
	_ruido_de_altura_amplo.fractal_gain = 0.52

	_ruido_de_altura_fino.seed = semente + 7919
	_ruido_de_altura_fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_de_altura_fino.frequency = 0.007
	_ruido_de_altura_fino.fractal_type = FastNoiseLite.FRACTAL_FBM
	_ruido_de_altura_fino.fractal_octaves = 3
	_ruido_de_altura_fino.fractal_gain = 0.45


## Altura de grande escala compartilhada por todos os modulos. Ela zera antes
## da praia, mas ergue e ondula o interior da ilha. Como a funcao depende da
## posicao global, dois vertices coincidentes recebem exatamente a mesma altura
## mesmo quando pertencem a cenas diferentes.
func _altura_macro_do_terreno(x: float, z: float) -> float:
	var ponto := Vector2(x, z)
	var raio := _raio_na_direcao(ponto.x, ponto.y) * tamanho_do_modulo
	var distancia_normalizada := ponto.length() / maxf(raio, 1.0)
	var influencia := 1.0 - smoothstep(0.48, 0.78, distancia_normalizada)
	if influencia <= 0.0:
		return 0.0

	var domo := pow(maxf(1.0 - distancia_normalizada, 0.0), 1.35) * altura_base_do_miolo
	var ruido_amplo := _ruido_de_altura_amplo.get_noise_2d(x, z) * variacao_ampla_da_altura
	var ruido_fino := _ruido_de_altura_fino.get_noise_2d(x, z) * variacao_fina_da_altura
	# A base baixa permite vales sem abrir buracos ou lagos acidentais.
	var altura := domo + 5.0 + ruido_amplo + ruido_fino
	return maxf(altura * influencia, 0.0)


## Incorpora a escala vertical e a altura macro aos vertices de uma instancia
## e refaz sua colisao. Isso evita tanto as emendas em degrau quanto a diferenca
## entre o que o jogador ve e a superficie onde ele pisa.
func _deformar_modulo(modulo: Node3D, escala_vertical: float) -> void:
	var visual := modulo.get_node_or_null("Malha") as MeshInstance3D
	if visual == null or visual.mesh == null:
		return
	# A cena de modulo vem sem colisao: assar uma no build seria desperdicio,
	# porque a forma so fica correta depois que os vertices recebem a escala e a
	# altura global do terreno, o que acontece aqui.
	var colisao := modulo.get_node_or_null("Colisao") as CollisionShape3D
	if colisao == null:
		colisao = CollisionShape3D.new()
		colisao.name = "Colisao"
		modulo.add_child(colisao)

	var origem := visual.mesh
	var transformacao_original := visual.transform
	var escala_horizontal := tamanho_do_modulo / 100.0
	# A escala horizontal dos modulos nao deve multiplicar a altura: isso deixa
	# os relevos estreitos e pontudos demais. A altura continua independente.
	var escala_vertical_final := escala_vertical
	var base_deformada := Basis.IDENTITY.scaled(
		Vector3(escala_horizontal, escala_vertical_final, escala_horizontal)
	) * transformacao_original.basis
	var transformacao_da_normal := base_deformada.inverse().transposed()
	var malha_deformada := ArrayMesh.new()

	for superficie in range(origem.get_surface_count()):
		var arrays: Array = origem.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normais: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

		for indice in range(vertices.size()):
			var vertice := transformacao_original * vertices[indice]
			vertice.x *= escala_horizontal
			vertice.y *= escala_vertical_final
			vertice.z *= escala_horizontal
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
	return "colina" if sorte > 0.96 else "planicie"


func _escala_vertical(faixa: String, gx: int, gz: int) -> float:
	var intensidade := _intensidade_do_relevo(gx, gz)
	var variacao := (_ruido(gx, gz, 120) - 0.5) * 0.12
	var escala_base: float
	match faixa:
		"pico":
			escala_base = 1.15 + intensidade * 0.55 + variacao
		"montanha":
			escala_base = 0.72 + intensidade * 0.62 + variacao
		"morro":
			escala_base = 0.48 + intensidade * 0.68 + variacao
		"colina":
			escala_base = 0.30 + intensidade * 0.72 + variacao
		_:
			return 0.34 + variacao
	return escala_base * escala_do_relevo


func _montar_terreno(raiz: Node3D) -> void:
	var chaves: Array = _celulas.keys()
	chaves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for celula in chaves:
		var gx: int = celula.x
		var gz: int = celula.y
		var faixa := _faixa_da_celula(gx, gz)
		var opcoes: Array = _faixas.get(faixa, _faixas.get("planicie", []))
		if opcoes.is_empty():
			continue
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
	# O alpha informa ao shader quanto misturar com areia: zero no miolo e um
	# na beirada. A cor RGB fica disponivel para depuracao da malha.
	var cor_terreno := Color(0.28, 0.54, 0.26, 0.0)
	var cor_areia := Color(0.56, 0.50, 0.31, 1.0)

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

	var material := ShaderMaterial.new()
	material.shader = SHADER_COSTA_ORGANICA
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
		if faixa == "planicie" or faixa == "colina":
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
		var nome := _sortear(_marcos, _ruido(celula.x, celula.y, 200 + usadas))
		if nome == "":
			break
		var marco := _cena(PASTA_PROPS, nome).instantiate() as Node3D
		marco.name = "Marco_%d_%d" % [celula.x, celula.y]
		marco.position = Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo)
		marco.position.y = _altura_macro_do_terreno(marco.position.x, marco.position.z)
		marco.rotation.y = _ruido(celula.x, celula.y, 5) * TAU
		marco.scale = Vector3.ONE * escala_dos_marcos * (tamanho_do_modulo / 100.0)
		_aplicar_material_continuo(marco)
		raiz.add_child(marco)
		usadas += 1


## Espalha pecas soltas sobre as celulas planas. Serve tanto para as pedras
## pequenas quanto para os afloramentos de porte medio: a unica diferenca e a
## lista de onde as pecas saem e o quanto elas sao ampliadas.
func _espalhar(raiz: Node3D, lista: Array, quantidade: int, prefixo: String,
		escala_min: float, escala_max: float, sal: int) -> void:
	var planas := _celulas_planas()
	if planas.is_empty() or lista.is_empty():
		return
	for i in range(quantidade):
		var celula: Vector2i = planas[(i * 7 + 3) % planas.size()]
		var nome := _sortear(lista, _ruido(celula.x, celula.y, sal + i * 13))
		var rocha := _cena(PASTA_PROPS, nome).instantiate() as Node3D
		rocha.name = "%s_%d" % [prefixo, i]
		var desvio := Vector3(
			(_ruido(celula.x, celula.y, sal + 10 + i) - 0.5) * tamanho_do_modulo * 0.8,
			0.0,
			(_ruido(celula.x, celula.y, sal + 40 + i) - 0.5) * tamanho_do_modulo * 0.8
		)
		rocha.position = Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo) + desvio
		rocha.position.y = _altura_macro_do_terreno(rocha.position.x, rocha.position.z)
		rocha.rotation.y = _ruido(celula.x, celula.y, sal + 70 + i) * TAU
		var faixa_de_escala := escala_max - escala_min
		var escala := (escala_min + _ruido(celula.x, celula.y, sal + 90 + i) * faixa_de_escala) \
			* (tamanho_do_modulo / 100.0)
		rocha.scale = Vector3(escala, escala, escala)
		_aplicar_material_continuo(rocha)
		raiz.add_child(rocha)


## Nuvens pousadas em anel no ceu. Nao levam o material do terreno: naquela
## altura ele as pintaria de rocha.
func _montar_nuvens(raiz: Node3D) -> void:
	if _nuvens.is_empty():
		return
	if _material_das_nuvens == null:
		_material_das_nuvens = StandardMaterial3D.new()
		_material_das_nuvens.albedo_color = Color(1.0, 1.0, 1.0)
		_material_das_nuvens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_das_nuvens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_das_nuvens.albedo_color.a = 0.85
	var raio := raio_em_metros()
	for i in range(quantidade_de_nuvens):
		var nome := _sortear(_nuvens, _ruido(i, i * 3, 900))
		var nuvem := _cena(PASTA_NUVENS, nome).instantiate() as Node3D
		nuvem.name = "Nuvem_%d" % i
		var angulo := TAU * _ruido(i, i * 5, 910)
		var distancia := raio * (0.15 + _ruido(i, i * 7, 920) * 1.1)
		nuvem.position = Vector3(
			cos(angulo) * distancia,
			altura_das_nuvens + _ruido(i, i * 11, 930) * 90.0,
			sin(angulo) * distancia
		)
		nuvem.rotation.y = _ruido(i, i * 13, 940) * TAU
		var escala := 3.0 + _ruido(i, i * 17, 950) * 5.0
		nuvem.scale = Vector3(escala, escala * 0.6, escala)
		for filho: Node in nuvem.get_children():
			if filho is MeshInstance3D:
				(filho as MeshInstance3D).material_override = _material_das_nuvens
				(filho as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(nuvem)


func _montar_ilhotas(raiz: Node3D) -> void:
	var raio := raio_em_metros()
	for i in range(quantidade_de_ilhotas):
		var nome := _sortear(_ilhotas, _ruido(i, i * 3, 800))
		if nome == "":
			break
		var ilhota := _cena(PASTA_ILHOTAS, nome).instantiate() as Node3D
		ilhota.name = "Ilhota_%d" % i
		var angulo := TAU * (float(i) / maxf(float(quantidade_de_ilhotas), 1.0)) + 0.6
		var distancia := raio + 180.0 + _ruido(i, i * 3, 200) * 320.0
		ilhota.position = Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		ilhota.rotation.y = _ruido(i, i * 5, 300) * TAU
		# Sem isto as ilhotas ficam brancas: elas nao passam pelo mesmo caminho
		# do terreno, entao precisam receber o material continuo aqui.
		_aplicar_material_continuo(ilhota)
		raiz.add_child(ilhota)
