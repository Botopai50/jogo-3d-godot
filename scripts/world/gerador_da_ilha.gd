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
const PASTA_RIO := "res://scenes/modules/river/"
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
@export_range(2, 40, 1) var raio_em_modulos := 8
## Distancia entre os centros das celulas, em metros. Os assets originais tem
## 100 m; valores maiores ampliam malha e colisao para manter o encaixe.
@export_range(60.0, 300.0, 5.0) var tamanho_do_modulo := 125.0
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

@export_group("Rio e lago")
## Liga o rio e o lago. Eles ocupam celulas que seriam de terreno comum.
@export var gerar_rio := true
## Tamanho do lago em celulas. As margens do pacote sao rampas que descem de
## uma borda a outra, entao um lago fechado tem exatamente duas celulas de
## profundidade: as margens opostas se encontram no meio, ambas no fundo.
@export_range(2, 6, 1) var comprimento_do_lago := 3
## Caimento minimo do rio a cada celula, para ele sempre descer para o lago.
@export_range(0.2, 4.0, 0.1) var caimento_do_rio := 1.0
## Quanto a lamina do lago fica abaixo da borda da bacia, em metros.
@export_range(0.5, 8.0, 0.1) var lamina_do_lago := 4.2
## Quantas celulas o rio percorre subindo da margem do lago ate a nascente.
@export_range(2, 20, 1) var comprimento_do_rio := 7
## Quanto a lamina de agua do rio fica acima do fundo do canal, em metros.
@export_range(0.1, 3.0, 0.1) var lamina_do_rio := 0.7
## Largura da agua do rio, como fracao da celula.
@export_range(0.05, 0.4, 0.01) var largura_da_agua_do_rio := 0.13

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
## Quanto cada peca solta afunda no chao. As montanhas do pacote sao cascas sem
## fundo: enterrar a base garante que a abertura nunca fique visivel.
@export_range(0.0, 5.0, 0.1) var afundamento_das_pecas := 0.6
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
var _modulo_da_celula: Dictionary = {}
var _celulas_de_agua: Dictionary = {}
var _caminho_do_rio: Array = []
var _pecas_escolhidas: Array = []
var _celulas_do_lago: Array = []
var _celula_de_saida := Vector2i.ZERO
var _centro_do_lago := Vector2i.ZERO
var _altura_do_lago := 0.0
var _lago_pronto := false
var _corredor_do_rio: Array = []
var _rio_pronto := false
var _superficie_da_celula: Dictionary = {}
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
	_modulo_da_celula.clear()
	_superficie_da_celula.clear()
	_celulas_de_agua.clear()
	_caminho_do_rio.clear()
	_pecas_escolhidas.clear()
	_celulas_do_lago.clear()
	_lago_pronto = false
	_corredor_do_rio.clear()
	_rio_pronto = false
	_aleatorio.seed = semente
	_configurar_ruido_de_altura()

	_carregar_faixas()
	_carregar_acervo()
	_marcar_terra()
	if gerar_rio:
		_planejar_agua()
	var raiz_terreno := _novo_grupo("Terreno")
	var raiz_detalhes := _novo_grupo("Detalhes")
	var raiz_ilhotas := _novo_grupo("Ilhotas")

	_montar_base_organica()
	_montar_terreno(raiz_terreno)
	if gerar_rio:
		_montar_agua(_novo_grupo("Agua"))
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
func _sortear(lista: Array, sorte: float) -> Dictionary:
	if lista.is_empty():
		return {}
	var indice := int(sorte * float(lista.size())) % lista.size()
	return lista[indice]


## Quanto uma peca solta deve afundar no chao.
##
## As montanhas do pacote sao cascas sem fundo. Enterrar so alguns centimetros
## resolve no plano, mas uma peca larga sobre encosta continua boiando de um
## lado: o afundamento cresce com a largura. O limite pela propria altura evita
## que uma pedra baixa suma dentro do terreno.
func _afundamento(largura: float, altura: float) -> float:
	return minf(afundamento_das_pecas + largura * 0.04, maxf(altura * 0.35, 0.2))


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
	var resultado := maxf(altura * influencia, 0.0)
	if _lago_pronto:
		# A bacia e geometria das pecas do pacote; aqui so aplaino o relevo sob
		# o bloco do lago. Sem isso a borda da bacia sobe alguns metros de uma
		# ponta a outra e a lamina, que e plana, fica enterrada de um lado e
		# boiando do outro.
		var deslocamento := Vector2(
			x - float(_centro_do_lago.x) * tamanho_do_modulo,
			z - float(_centro_do_lago.y) * tamanho_do_modulo)
		var meia_extensao := float(maxi(comprimento_do_lago, 2)) * 0.5 * tamanho_do_modulo
		var peso := 1.0 - smoothstep(meia_extensao * 1.0, meia_extensao * 2.4, deslocamento.length())
		resultado = lerpf(resultado, _altura_do_lago, peso)
	if _rio_pronto:
		# O canal das pecas so desce 2 m nas bordas. O relevo macro inclina cada
		# celula cerca de 1,8 m, o que quase anula esse entalhe: a soleira entre
		# duas pecas sobe ate a altura do campo em volta e o rio fica partido,
		# com agua dos dois lados e uma lombada seca no meio. Aplainando o
		# corredor a geometria da peca volta a mandar, e o entalhe vira um vale.
		var alvo := 0.0
		var soma_dos_pesos := 0.0
		var maior_peso := 0.0
		for no: Dictionary in _corredor_do_rio:
			var distancia: float = (Vector2(x, z) - (no["centro"] as Vector2)).length()
			var peso_do_no := 1.0 - smoothstep(
				tamanho_do_modulo * 0.30, tamanho_do_modulo * 1.20, distancia)
			if peso_do_no <= 0.0:
				continue
			alvo += float(no["altura"]) * peso_do_no
			soma_dos_pesos += peso_do_no
			maior_peso = maxf(maior_peso, peso_do_no)
		if soma_dos_pesos > 0.0:
			resultado = lerpf(resultado, alvo / soma_dos_pesos, maior_peso)
	return resultado


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
		if _celulas_de_agua.has(celula):
			continue
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
		_modulo_da_celula[Vector2i(gx, gz)] = modulo


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
		if celula == _celula_de_nascimento or _celulas_de_agua.has(celula):
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
		if _celulas_de_agua.has(celula):
			continue
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
		var peca := _sortear(_marcos, _ruido(celula.x, celula.y, 200 + usadas))
		if peca.is_empty():
			break
		var marco := _cena(PASTA_PROPS, peca["nome"]).instantiate() as Node3D
		marco.name = "Marco_%d_%d" % [celula.x, celula.y]
		marco.position = Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo)
		var escala_do_marco := escala_dos_marcos * (tamanho_do_modulo / 100.0)
		marco.scale = Vector3.ONE * escala_do_marco
		marco.position.y = _altura_do_chao(marco.position.x, marco.position.z) - _afundamento(
			float(peca["largura"]) * escala_do_marco,
			(float(peca["y_max"]) - float(peca["y_min"])) * escala_do_marco)
		marco.rotation.y = _ruido(celula.x, celula.y, 5) * TAU
		_aplicar_material_continuo(marco)
		_dar_colisao(marco)
		raiz.add_child(marco)
		usadas += 1


## Altura da superficie onde o jogador pisa, num ponto qualquer.
##
## Nao basta a altura macro: cada modulo tem o proprio relevo por cima dela, de
## alguns centimetros numa planicie a dezenas de metros num pico. Pousar uma
## peca solta pela altura macro deixava as montanhas boiando, e como elas sao
## cascas sem fundo dava para ver por baixo, para dentro delas.
func _altura_do_chao(x: float, z: float) -> float:
	var celula := Vector2i(roundi(x / tamanho_do_modulo), roundi(z / tamanho_do_modulo))
	var superficie: Variant = _superficie_da_celula.get(celula)
	if superficie == null:
		superficie = _preparar_superficie(celula)
		if superficie == null:
			return _altura_macro_do_terreno(x, z)

	var dados: Dictionary = superficie
	var modulo: Node3D = _modulo_da_celula[celula]
	var local: Vector3 = modulo.transform.affine_inverse() * Vector3(x, 0.0, z)
	var vertices: PackedVector3Array = dados["vertices"]
	var indices: PackedInt32Array = dados["indices"]
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		var peso := _baricentricas(local.x, local.z, a, b, c)
		if peso == Vector3.INF:
			continue
		return modulo.position.y + a.y * peso.x + b.y * peso.y + c.y * peso.z
	return _altura_macro_do_terreno(x, z)


func _preparar_superficie(celula: Vector2i) -> Variant:
	if not _modulo_da_celula.has(celula):
		return null
	var modulo: Node3D = _modulo_da_celula[celula]
	var visual := modulo.get_node_or_null("Malha") as MeshInstance3D
	if visual == null or visual.mesh == null:
		return null
	var arrays: Array = visual.mesh.surface_get_arrays(0)
	var dados := {"vertices": arrays[Mesh.ARRAY_VERTEX], "indices": arrays[Mesh.ARRAY_INDEX]}
	_superficie_da_celula[celula] = dados
	return dados


## Coordenadas baricentricas do ponto (x, z) dentro do triangulo, olhando de
## cima. Devolve Vector3.INF quando o ponto cai fora.
func _baricentricas(x: float, z: float, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0x := b.x - a.x
	var v0z := b.z - a.z
	var v1x := c.x - a.x
	var v1z := c.z - a.z
	var denominador := v0x * v1z - v1x * v0z
	if absf(denominador) < 0.000001:
		return Vector3.INF
	var v2x := x - a.x
	var v2z := z - a.z
	var beta := (v2x * v1z - v1x * v2z) / denominador
	var gama := (v0x * v2z - v2x * v0z) / denominador
	if beta < -0.0001 or gama < -0.0001 or beta + gama > 1.0001:
		return Vector3.INF
	return Vector3(1.0 - beta - gama, beta, gama)


## Da colisao a uma peca solta, a partir da propria malha. Sem isto o jogador
## atravessa montanhas e afloramentos como se fossem cenario de fundo.
func _dar_colisao(peca: Node3D) -> void:
	var visual := peca.get_node_or_null("Malha") as MeshInstance3D
	if visual == null or visual.mesh == null or not (peca is StaticBody3D):
		return
	if peca.get_node_or_null("Colisao") != null:
		return
	var forma := CollisionShape3D.new()
	forma.name = "Colisao"
	forma.shape = visual.mesh.create_trimesh_shape()
	forma.transform = visual.transform
	peca.add_child(forma)


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
		var peca := _sortear(lista, _ruido(celula.x, celula.y, sal + i * 13))
		var rocha := _cena(PASTA_PROPS, peca["nome"]).instantiate() as Node3D
		rocha.name = "%s_%d" % [prefixo, i]
		var desvio := Vector3(
			(_ruido(celula.x, celula.y, sal + 10 + i) - 0.5) * tamanho_do_modulo * 0.8,
			0.0,
			(_ruido(celula.x, celula.y, sal + 40 + i) - 0.5) * tamanho_do_modulo * 0.8
		)
		rocha.position = Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo) + desvio
		rocha.rotation.y = _ruido(celula.x, celula.y, sal + 70 + i) * TAU
		var faixa_de_escala := escala_max - escala_min
		var escala := (escala_min + _ruido(celula.x, celula.y, sal + 90 + i) * faixa_de_escala) \
			* (tamanho_do_modulo / 100.0)
		rocha.scale = Vector3(escala, escala, escala)
		# A altura vem depois da escala: a peca precisa pousar na superficie de
		# verdade, e nao na altura macro, senao fica boiando com o fundo aberto
		# a mostra.
		rocha.position.y = _altura_do_chao(rocha.position.x, rocha.position.z) - _afundamento(
			float(peca["largura"]) * escala,
			(float(peca["y_max"]) - float(peca["y_min"])) * escala)
		_aplicar_material_continuo(rocha)
		_dar_colisao(rocha)
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
		var peca := _sortear(_nuvens, _ruido(i, i * 3, 900))
		if peca.is_empty():
			break
		var nuvem := _cena(PASTA_NUVENS, peca["nome"]).instantiate() as Node3D
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
		var peca := _sortear(_ilhotas, _ruido(i, i * 3, 800))
		if peca.is_empty():
			break
		var ilhota := _cena(PASTA_ILHOTAS, peca["nome"]).instantiate() as Node3D
		ilhota.name = "Ilhota_%d" % i
		var angulo := TAU * (float(i) / maxf(float(quantidade_de_ilhotas), 1.0)) + 0.6
		var distancia := raio + 180.0 + _ruido(i, i * 3, 200) * 320.0
		ilhota.position = Vector3(cos(angulo) * distancia, 0.0, sin(angulo) * distancia)
		ilhota.rotation.y = _ruido(i, i * 5, 300) * TAU
		# Sem isto as ilhotas ficam brancas: elas nao passam pelo mesmo caminho
		# do terreno, entao precisam receber o material continuo aqui.
		_aplicar_material_continuo(ilhota)
		# As ilhotas ficam alem das paredes do limite, entao hoje o jogador nao
		# alcanca nenhuma. A colisao entra assim mesmo: sai barato e evita que
		# um ajuste futuro no limite deixe ilha atravessavel sem ninguem notar.
		_dar_colisao(ilhota)
		raiz.add_child(ilhota)


# ---------------------------------------------------------------------------
# Rio e lago
#
# Tudo que e agua fica dentro dos modulos CPT_River e CPT_River_End: o canal do
# rio e a bacia do lago sao geometria do pacote, e as laminas so aparecem onde
# essas pecas estao.
#
# As pecas de bacia nao sao tigelas: sao rampas de margem, medidas no build.
# CPT_River_End_L_d_01 desce de -6 na borda norte inteira ate 0 na sul, com as
# bordas leste e oeste na mesma rampa; _d_05 afunda so no canto noroeste; _d_03
# afunda no norte e no leste. Por isso um lago fechado tem duas celulas de
# profundidade: duas margens opostas se encontram no meio, ambas no fundo, e nao
# sobra miolo para o qual o pacote nao tem peca.
#
# O encaixe e resolvido comparando o perfil inteiro de cada borda, em cinco
# faixas. Comparar so o ponto mais fundo trata uma rampa e um degrau como iguais
# e deixa fresta.
# ---------------------------------------------------------------------------

const DIRECOES: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]
## Perfil de uma borda que encosta em terreno comum: tudo na altura zero.
const BORDA_DE_TERRA: Array = [0.0, 0.0, 0.0, 0.0, 0.0]


func _direcao_para_borda(direcao: Vector2i) -> int:
	for i in range(4):
		if DIRECOES[i] == direcao:
			return i
	return -1


func _ponto_da_borda(borda: int, fracao: float) -> Vector2:
	match borda:
		0: return Vector2(fracao, -0.5)
		1: return Vector2(0.5, fracao)
		2: return Vector2(fracao, 0.5)
		_: return Vector2(-0.5, fracao)


func _girar_ponto(p: Vector2, voltas: int) -> Vector2:
	var atual := p
	for _i in range(voltas % 4):
		atual = Vector2(atual.y, -atual.x)
	return atual


## Descobre em que borda do mundo um ponto local cai depois de girado, e em que
## posicao ao longo dela. Deduzir isso por tabela de rotacao e onde se erra o
## sinal; aqui a propria geometria responde.
func _borda_no_mundo(p: Vector2) -> Dictionary:
	if absf(p.y + 0.5) < 0.01:
		return {"borda": 0, "fracao": p.x}
	if absf(p.x - 0.5) < 0.01:
		return {"borda": 1, "fracao": p.y}
	if absf(p.y - 0.5) < 0.01:
		return {"borda": 2, "fracao": p.x}
	if absf(p.x + 0.5) < 0.01:
		return {"borda": 3, "fracao": p.y}
	return {"borda": -1, "fracao": 0.0}


## Perfis e aberturas de uma peca ja girada, por borda do mundo.
func _peca_no_mundo(peca: Dictionary, voltas: int) -> Dictionary:
	var perfis: Array = peca["perfis"]
	var bordas: Array = peca["bordas"]
	var cruzamentos: Array = peca["cruzamentos"]
	var saida := {}
	for k in range(4):
		var amostras: Array = perfis[k] if perfis.size() == 4 else BORDA_DE_TERRA
		var destino: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
		var borda_mundo := -1
		for j in range(5):
			var t := (float(j) + 0.5) / 5.0 - 0.5
			var achado := _borda_no_mundo(_girar_ponto(_ponto_da_borda(k, t), voltas))
			if int(achado["borda"]) < 0:
				continue
			borda_mundo = achado["borda"]
			var indice := clampi(int((float(achado["fracao"]) + 0.5) * 5.0), 0, 4)
			destino[indice] = float(amostras[j])
		if borda_mundo < 0:
			continue
		var cruzamento := _borda_no_mundo(
			_girar_ponto(_ponto_da_borda(k, float(cruzamentos[k])), voltas))
		saida[borda_mundo] = {
			"perfil": destino,
			"classe": int(bordas[k]),
			"fracao": float(cruzamento["fracao"]),
		}
	return saida


func _erro_entre_perfis(a: Array, b: Array) -> float:
	var soma := 0.0
	for i in range(5):
		soma += absf(float(a[i]) - float(b[i]))
	return soma


func _acervo_de_rio() -> Array:
	var arquivo := FileAccess.open(ACERVO_GERADO, FileAccess.READ)
	if arquivo == null:
		return []
	var dados: Variant = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if not dados is Dictionary:
		return []
	return (dados as Dictionary).get("rio", [])


## Altura do terreno no centro da celula com o lago ja aplainado, mas sem o
## corredor do rio: e a altura que o corredor tem de acompanhar para nao virar
## um aterro no meio do campo.
func _altura_da_celula_sem_corredor(celula: Vector2i) -> float:
	var lembrete := _rio_pronto
	_rio_pronto = false
	var altura := _altura_macro_do_terreno(
		celula.x * tamanho_do_modulo, celula.y * tamanho_do_modulo)
	_rio_pronto = lembrete
	return altura


func _altura_bruta_da_celula(celula: Vector2i) -> float:
	var lembrete := _lago_pronto
	var lembrete_do_rio := _rio_pronto
	_lago_pronto = false
	_rio_pronto = false
	var altura := _altura_macro_do_terreno(
		celula.x * tamanho_do_modulo, celula.y * tamanho_do_modulo)
	_lago_pronto = lembrete
	_rio_pronto = lembrete_do_rio
	return altura


func _dentro_do_lago(celula: Vector2i) -> bool:
	return _celulas_do_lago.has(celula)


## Escolhe onde cai o lago: meia encosta, com o bloco inteiro em terra e longe
## da borda da ilha.
func _escolher_canto_do_lago(largura: int, altura: int) -> Variant:
	var candidatos: Array = []
	for celula: Vector2i in _celulas.keys():
		var t: float = _celulas[celula]
		if t < 0.30 or t > 0.62 or celula == _celula_de_nascimento:
			continue
		var serve := true
		for dz in range(-1, altura + 1):
			for dx in range(-1, largura + 1):
				var c := celula + Vector2i(dx, dz)
				if not _celulas.has(c) or _e_borda(c.x, c.y):
					serve = false
					break
			if not serve:
				break
		if not serve:
			continue
		candidatos.append({
			"celula": celula,
			"relevo": _intensidade_do_relevo(celula.x, celula.y),
			"distancia": t,
		})
	if candidatos.is_empty():
		return null
	candidatos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["relevo"]) - float(b["relevo"])) > 0.05:
			return a["relevo"] < b["relevo"]
		if not is_equal_approx(a["distancia"], b["distancia"]):
			return a["distancia"] > b["distancia"]
		var ca: Vector2i = a["celula"]
		var cb: Vector2i = b["celula"]
		return ca.y < cb.y if ca.y != cb.y else ca.x < cb.x)
	return candidatos[0]["celula"]


## Resolve o bloco do lago peca por peca: para cada celula testa todas as pecas
## de bacia nas quatro rotacoes e fica com a que menos abre fresta contra os
## vizinhos ja decididos e contra o terreno em volta.
func _resolver_lago(pecas: Array, celula_de_saida: Vector2i, direcao_de_saida: Vector2i) -> Dictionary:
	var bacias: Array = []
	for peca: Dictionary in pecas:
		var bordas: Array = peca["bordas"]
		if bordas.size() != 4:
			continue
		var tem_bacia := false
		for classe in bordas:
			if int(classe) == 6:
				tem_bacia = true
				break
		if tem_bacia:
			bacias.append(peca)

	var decididas := {}
	# Duas passadas: na primeira metade das celulas ainda faltam vizinhos, e a
	# segunda passada refaz a escolha ja com o bloco inteiro no lugar.
	for _passada in range(2):
		for celula: Vector2i in _celulas_do_lago:
			var melhor := {}
			var melhor_erro := INF
			for peca: Dictionary in bacias:
				for voltas in range(4):
					var mundo := _peca_no_mundo(peca, voltas)
					var erro := 0.0
					var valida := true
					for i in range(4):
						var vizinha: Vector2i = celula + DIRECOES[i]
						var minha: Dictionary = mundo.get(i, {"perfil": BORDA_DE_TERRA, "classe": 0})
						var meu_perfil: Array = minha["perfil"]
						if celula == celula_de_saida and DIRECOES[i] == direcao_de_saida:
							# Exatamente aqui o lago tem que verter para o rio.
							if int(minha["classe"]) != 2:
								valida = false
								break
							continue
						if _dentro_do_lago(vizinha):
							if not decididas.has(vizinha):
								continue
							var outra: Dictionary = decididas[vizinha]
							var perfil_vizinho: Array = (outra["mundo"] as Dictionary).get(
								(i + 2) % 4, {"perfil": BORDA_DE_TERRA})["perfil"]
							erro += _erro_entre_perfis(meu_perfil, perfil_vizinho)
						else:
							erro += _erro_entre_perfis(meu_perfil, BORDA_DE_TERRA)
					if not valida:
						continue
					if erro < melhor_erro:
						melhor_erro = erro
						melhor = {"nome": peca["nome"], "voltas": voltas, "mundo": mundo, "erro": erro}
			if not melhor.is_empty():
				decididas[celula] = melhor
	return decididas


func _planejar_agua() -> void:
	var pecas := _acervo_de_rio()
	if pecas.is_empty():
		return
	var largura := comprimento_do_lago
	var altura := 2
	var canto: Variant = _escolher_canto_do_lago(largura, altura)
	if canto == null:
		return
	var origem: Vector2i = canto
	_celulas_do_lago.clear()
	for dz in range(altura):
		for dx in range(largura):
			_celulas_do_lago.append(origem + Vector2i(dx, dz))
	_centro_do_lago = origem + Vector2i(largura / 2, 0)

	# Media das alturas do bloco: e nela que o lago fica aplainado, para a
	# lamina nao ficar enterrada de um lado e boiando do outro.
	var soma := 0.0
	for celula: Vector2i in _celulas_do_lago:
		soma += _altura_bruta_da_celula(celula)
	_altura_do_lago = soma / float(_celulas_do_lago.size())
	_lago_pronto = true

	# A saida fica na celula do meio da margem mais alta: e de la que o rio desce.
	var celula_de_saida: Vector2i = _celulas_do_lago[0]
	var direcao_de_saida := Vector2i(0, -1)
	var melhor_altura := -INF
	for celula: Vector2i in _celulas_do_lago:
		for direcao: Vector2i in DIRECOES:
			var fora: Vector2i = celula + direcao
			if _dentro_do_lago(fora) or not _celulas.has(fora) or _e_borda(fora.x, fora.y):
				continue
			var altura_fora := _altura_bruta_da_celula(fora)
			if altura_fora > melhor_altura:
				melhor_altura = altura_fora
				celula_de_saida = celula
				direcao_de_saida = direcao

	_celula_de_saida = celula_de_saida
	var decididas := _resolver_lago(pecas, celula_de_saida, direcao_de_saida)
	for celula: Vector2i in _celulas_do_lago:
		if not decididas.has(celula):
			continue
		_pecas_escolhidas.append({"celula": celula, "tipo": "lago", "escolha": decididas[celula]})
		_celulas_de_agua[celula] = {"tipo": "lago"}

	_caminho_do_rio = _tracar_rio(celula_de_saida + direcao_de_saida, direcao_de_saida)
	if _caminho_do_rio.is_empty():
		return
	var fracao_anterior := 0.0
	var tem_anterior := false
	for indice in range(_caminho_do_rio.size()):
		var celula: Vector2i = _caminho_do_rio[indice]
		var anterior: Vector2i = _caminho_do_rio[indice - 1] if indice > 0 else celula_de_saida
		var entrada := _direcao_para_borda(anterior - celula)
		var saida := -1
		if indice + 1 < _caminho_do_rio.size():
			saida = _direcao_para_borda(_caminho_do_rio[indice + 1] - celula)
		var escolha := _melhor_peca(pecas, entrada, saida, fracao_anterior, tem_anterior)
		if escolha.is_empty():
			break
		escolha["borda_entrada"] = entrada
		escolha["borda_saida"] = saida
		_pecas_escolhidas.append({"celula": celula, "tipo": "rio", "escolha": escolha})
		_celulas_de_agua[celula] = {"tipo": "rio"}
		fracao_anterior = float(escolha["fracao_saida"])
		tem_anterior = saida >= 0

	_montar_corredor_do_rio()


## Marca o corredor por onde o relevo macro fica aplainado, uma altura por
## celula de rio, subindo da foz para a nascente.
func _montar_corredor_do_rio() -> void:
	_corredor_do_rio.clear()
	var cadeia: Array = []
	for item: Dictionary in _pecas_escolhidas:
		if item["tipo"] == "rio":
			cadeia.append(item["celula"])
	if cadeia.is_empty():
		return
	# A altura de cada celula e a natural do proprio ponto: aplainar tira a
	# inclinacao de dentro da celula, que e a que engole o entalhe, sem erguer
	# um aterro no meio do campo. So o caimento minimo e imposto, para o rio
	# sempre descer para o lago.
	var altura_anterior := _altura_do_lago
	for celula: Vector2i in cadeia:
		var altura := maxf(_altura_da_celula_sem_corredor(celula), altura_anterior + caimento_do_rio)
		_corredor_do_rio.append({
			"centro": Vector2(float(celula.x) * tamanho_do_modulo,
				float(celula.y) * tamanho_do_modulo),
			"altura": altura,
		})
		altura_anterior = altura
	_rio_pronto = true


## Traca o rio subindo da margem do lago ate uma nascente.
func _tracar_rio(inicio: Vector2i, primeira_direcao: Vector2i) -> Array:
	var caminho: Array = []
	var atual := inicio
	var ocupadas := {}
	var direcao_anterior := primeira_direcao
	while caminho.size() < comprimento_do_rio:
		if not _celulas.has(atual) or ocupadas.has(atual) or _e_borda(atual.x, atual.y):
			break
		if _dentro_do_lago(atual):
			break
		caminho.append(atual)
		ocupadas[atual] = true
		var altura_atual := _altura_bruta_da_celula(atual)
		var melhor: Variant = null
		var melhor_nota := -INF
		for direcao: Vector2i in DIRECOES:
			if direcao == -direcao_anterior:
				continue
			var vizinha: Vector2i = atual + direcao
			if not _celulas.has(vizinha) or ocupadas.has(vizinha) or _e_borda(vizinha.x, vizinha.y):
				continue
			if _dentro_do_lago(vizinha):
				continue
			var altura := _altura_bruta_da_celula(vizinha)
			# Um degrau para baixo de meio metro passa: a ondulacao fina do
			# terreno cria pocas que interromperiam a subida sem motivo. Queda
			# de verdade nao, senao o tracado espirala em volta do cume.
			if altura < altura_atual - 0.6:
				continue
			var nota := altura + (0.75 if direcao == direcao_anterior else 0.0)
			if nota > melhor_nota:
				melhor_nota = nota
				melhor = {"celula": vizinha, "direcao": direcao}
		if melhor == null:
			break
		var escolha: Dictionary = melhor
		direcao_anterior = escolha["direcao"]
		atual = escolha["celula"]
	return caminho


## Peca de canal que abre exatamente nas bordas pedidas e que menos desalinha o
## leito em relacao a celula anterior.
func _melhor_peca(pecas: Array, entrada: int, saida: int, fracao_anterior: float,
		tem_anterior: bool) -> Dictionary:
	var alvo := {}
	if entrada >= 0:
		alvo[entrada] = true
	if saida >= 0:
		alvo[saida] = true
	var melhor := {}
	var melhor_erro := INF
	for peca: Dictionary in pecas:
		var bordas: Array = peca["bordas"]
		if bordas.size() != 4:
			continue
		var so_canal := true
		for classe in bordas:
			if int(classe) == 6:
				so_canal = false
				break
		if not so_canal:
			continue
		for voltas in range(4):
			var mundo := _peca_no_mundo(peca, voltas)
			var abertas := {}
			for borda: int in mundo:
				if int((mundo[borda] as Dictionary)["classe"]) != 0:
					abertas[borda] = true
			if abertas.size() != alvo.size():
				continue
			var combina := true
			for borda: int in alvo:
				if not abertas.has(borda):
					combina = false
					break
			if not combina:
				continue
			var fracao_de_entrada := float((mundo[entrada] as Dictionary)["fracao"]) if entrada >= 0 else 0.0
			var fracao_de_saida := float((mundo[saida] as Dictionary)["fracao"]) if saida >= 0 else 0.0
			var erro := 0.0
			if tem_anterior and entrada >= 0:
				erro = absf(fracao_de_entrada - fracao_anterior)
			# Entre as pecas que servem, algumas atravessam a celula na diagonal
			# (CPT_River_L_c_01 entra a +0.37 e sai a -0.34). Num trecho reto
			# elas fazem o leito serpentear meia celula, e a lamina, que segue
			# uma linha, nao acompanha. Penalizar a travessia deixa o leito
			# previsivel.
			if entrada >= 0 and saida >= 0 and _mesma_direcao(entrada, saida):
				erro += absf(fracao_de_entrada - fracao_de_saida) * 0.8
			# Algumas pecas de ponta terminam num poco fundo em vez de so fechar
			# o canal: CPT_River_End_L_a_01 desce 5,5 m e a variante _R quase 7,2,
			# contra 2,1 de CPT_River_L_d_01. Encher esse poco ate a soleira faz
			# a agua escorrer para o campo, e nao encher deixa canal seco. Sai
			# mais barato preferir a peca rasa.
			erro += maxf(0.0, -float(peca["y_min"]) - 2.5) * 0.08
			if erro < melhor_erro:
				melhor_erro = erro
				melhor = {
					"nome": peca["nome"],
					"voltas": voltas,
					"fracao_entrada": fracao_de_entrada,
					"fracao_saida": fracao_de_saida,
					"desalinho": absf(fracao_de_entrada - fracao_anterior) if tem_anterior and entrada >= 0 else 0.0,
				}
	return melhor


## Duas bordas opostas, ou seja, trecho reto.
func _mesma_direcao(a: int, b: int) -> bool:
	return (a + 2) % 4 == b


func _montar_agua(raiz: Node3D) -> void:
	var escala_uniforme := tamanho_do_modulo / 100.0
	for item: Dictionary in _pecas_escolhidas:
		var celula: Vector2i = item["celula"]
		var escolha: Dictionary = item["escolha"]
		var peca := _cena(PASTA_RIO, escolha["nome"]).instantiate() as Node3D
		peca.name = "%s_%d_%d" % [item["tipo"], celula.x, celula.y]
		peca.position = Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo)
		peca.rotation.y = float(escolha["voltas"]) * PI * 0.5
		# Escala vertical igual a horizontal: canal e bacia precisam manter a
		# propria proporcao, senao viram riscos rasos no chao.
		_deformar_modulo(peca, escala_uniforme)
		_aplicar_material_continuo(peca)
		raiz.add_child(peca)
		_modulo_da_celula[celula] = peca
	_montar_laminas(raiz)


## Deslocamento, dentro da celula, do ponto em que o canal cruza uma borda.
func _ponto_no_mundo(borda: int, fracao: float) -> Vector3:
	if borda < 0:
		return Vector3.ZERO
	var p := _ponto_da_borda(borda, fracao) * tamanho_do_modulo
	return Vector3(p.x, 0.0, p.y)


## O ponto cai numa celula que tem peca de rio ou de lago?
func _tem_peca_de_agua(p: Vector3) -> bool:
	var celula := Vector2i(
		roundi(p.x / tamanho_do_modulo), roundi(p.z / tamanho_do_modulo))
	return _celulas_de_agua.has(celula)


func _material_da_agua() -> Material:
	return load("res://materials/oceano.tres")


func _nivel_do_lago() -> float:
	return _altura_do_lago - lamina_do_lago


## Grade de alturas de uma celula, tirada da malha ja deformada.
##
## Rasteriza os triangulos uma vez, em vez de procurar o triangulo de cada
## amostra: com mil amostras por celula a busca ponto a ponto levaria segundos.
func _grade_de_altura(celula: Vector2i, lado_da_grade: int) -> PackedFloat32Array:
	var grade := PackedFloat32Array()
	grade.resize(lado_da_grade * lado_da_grade)
	grade.fill(INF)
	if not _modulo_da_celula.has(celula):
		return grade
	var modulo: Node3D = _modulo_da_celula[celula]
	var visual := modulo.get_node_or_null("Malha") as MeshInstance3D
	if visual == null or visual.mesh == null:
		return grade
	var arrays: Array = visual.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var para_o_mundo := modulo.transform
	var canto := Vector2(
		float(celula.x) * tamanho_do_modulo - tamanho_do_modulo * 0.5,
		float(celula.y) * tamanho_do_modulo - tamanho_do_modulo * 0.5)
	var passo := tamanho_do_modulo / float(lado_da_grade - 1)

	for t in range(0, indices.size(), 3):
		var a: Vector3 = para_o_mundo * vertices[indices[t]]
		var b: Vector3 = para_o_mundo * vertices[indices[t + 1]]
		var c: Vector3 = para_o_mundo * vertices[indices[t + 2]]
		var x0 := clampi(int(floor((minf(a.x, minf(b.x, c.x)) - canto.x) / passo)), 0, lado_da_grade - 1)
		var x1 := clampi(int(ceil((maxf(a.x, maxf(b.x, c.x)) - canto.x) / passo)), 0, lado_da_grade - 1)
		var z0 := clampi(int(floor((minf(a.z, minf(b.z, c.z)) - canto.y) / passo)), 0, lado_da_grade - 1)
		var z1 := clampi(int(ceil((maxf(a.z, maxf(b.z, c.z)) - canto.y) / passo)), 0, lado_da_grade - 1)
		var denominador := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(denominador) < 0.000001:
			continue
		for gz in range(z0, z1 + 1):
			for gx in range(x0, x1 + 1):
				var px := canto.x + float(gx) * passo
				var pz := canto.y + float(gz) * passo
				var beta := ((px - a.x) * (c.z - a.z) - (c.x - a.x) * (pz - a.z)) / denominador
				var gama := ((b.x - a.x) * (pz - a.z) - (px - a.x) * (b.z - a.z)) / denominador
				if beta < -0.001 or gama < -0.001 or beta + gama > 1.001:
					continue
				var altura := a.y * (1.0 - beta - gama) + b.y * beta + c.y * gama
				var indice := gz * lado_da_grade + gx
				if altura < grade[indice]:
					grade[indice] = altura
	return grade


## Nivel da agua em cada celula com peca.
##
## O rio e percorrido da foz para a nascente e o nivel nunca desce: uma poca no
## meio do leito enche e a agua segue, em vez de a lamina mergulhar atras do
## fundo. Em cada borda partilhada a lamina precisa cobrir a soleira, senao o
## rio fica partido; e o teto de cada celula e a altura em que a agua escaparia
## pelos lados fechados, medida na borda.
func _niveis_da_agua(grades: Dictionary) -> Dictionary:
	var niveis := {}
	for celula: Vector2i in _celulas_de_agua.keys():
		if _celulas_de_agua[celula]["tipo"] == "lago":
			niveis[celula] = {
				"entrada": _nivel_do_lago(), "saida": _nivel_do_lago(),
				"de": Vector2.ZERO, "para": Vector2.ZERO,
			}
	var corrente := _nivel_do_lago()
	for item: Dictionary in _pecas_escolhidas:
		if item["tipo"] != "rio":
			continue
		var celula: Vector2i = item["celula"]
		var escolha: Dictionary = item["escolha"]
		var grade: PackedFloat32Array = grades[celula]
		var fundo := INF
		for h in grade:
			if h != INF:
				fundo = minf(fundo, h)
		if fundo == INF:
			continue
		# Teto: a altura em que a agua escaparia pelos lados fechados da celula.
		# Media a borda, em vez de tirar uma fracao do relevo tipico: uma fracao
		# arbitraria fecha a lamina abaixo da soleira da peca seguinte e corta o
		# rio, que foi o que aconteceu na nascente (teto 12,66 contra soleira
		# 14,22).
		var teto := _transbordo(celula) - 0.05
		if teto == INF:
			teto = fundo + 6.0

		var borda_entrada := int(escolha["borda_entrada"])
		var borda_saida := int(escolha["borda_saida"])
		var centro := Vector3(celula.x * tamanho_do_modulo, 0.0, celula.y * tamanho_do_modulo)
		var p_entrada := centro + _ponto_no_mundo(
			borda_entrada, float(escolha["fracao_entrada"]))
		var p_saida := centro
		if borda_saida >= 0:
			p_saida = centro + _ponto_no_mundo(
				borda_saida, float(escolha["fracao_saida"]))

		# O canal das pecas do pacote e fundo no meio e so -2 nas bordas: entre
		# duas pecas o terreno sobe ate a soleira. Se a lamina nao a cobrir, o
		# rio fica partido, com agua dos dois lados e uma lombada seca no meio.
		var minimo_saida := _fundo_perto(grade, celula, p_saida) + lamina_do_rio
		if borda_saida >= 0:
			minimo_saida = maxf(minimo_saida, _soleira_da_borda(celula, borda_saida) + 0.10)
		var minimo_entrada := maxf(
			_fundo_perto(grade, celula, p_entrada) + lamina_do_rio,
			_soleira_da_borda(celula, borda_entrada) + 0.10)

		# As pecas sao encadeadas da foz para a nascente, entao a borda de
		# entrada e a de jusante e a de saida a de montante. Subindo o rio o
		# nivel nunca desce, e uma poca no meio do leito enche e a agua segue.
		var nivel_entrada := clampf(maxf(corrente, minimo_entrada), fundo, maxf(teto, fundo))
		var nivel_saida := clampf(maxf(nivel_entrada, minimo_saida), fundo, maxf(teto, fundo))
		corrente = nivel_saida
		niveis[celula] = {
			"entrada": nivel_entrada, "saida": nivel_saida,
			"de": Vector2(p_entrada.x, p_entrada.z), "para": Vector2(p_saida.x, p_saida.z),
		}

	# A foz cai numa peca de lago, o vertedouro. O lago e plano e o rio chega
	# 2,3 m acima dele, porque a borda entre os dois nao desce abaixo de 11,85.
	# Sem uma rampa a lamina do rio fica pendurada sobre a margem. A celula do
	# vertedouro passa a cair do nivel do rio, na borda partilhada, ate o nivel
	# do lago do outro lado.
	for item: Dictionary in _pecas_escolhidas:
		if item["tipo"] != "rio":
			continue
		var celula: Vector2i = item["celula"]
		if not niveis.has(celula):
			continue
		var nivel_do_rio: float = float((niveis[celula] as Dictionary)["entrada"])
		if nivel_do_rio <= _nivel_do_lago() + 0.05:
			continue
		for borda in range(4):
			var direcao := _direcao_da_borda(borda)
			var vizinha: Vector2i = celula + direcao
			if not _celulas_de_agua.has(vizinha):
				continue
			if _celulas_de_agua[vizinha]["tipo"] != "lago":
				continue
			var meio_da_borda := Vector2(
				(float(celula.x) + 0.5 * float(direcao.x)) * tamanho_do_modulo,
				(float(celula.y) + 0.5 * float(direcao.y)) * tamanho_do_modulo)
			var centro_vizinho := Vector2(
				float(vizinha.x) * tamanho_do_modulo, float(vizinha.y) * tamanho_do_modulo)
			niveis[vizinha] = {
				"entrada": nivel_do_rio, "saida": _nivel_do_lago(),
				"de": meio_da_borda,
				"para": centro_vizinho + (centro_vizinho - meio_da_borda),
			}
	return niveis


## Altura mais baixa do terreno ao longo de uma borda da celula. Entre duas
## celulas de agua e a soleira: a agua so passa de uma peca para a outra por
## cima dela.
func _soleira_da_borda(celula: Vector2i, borda: int) -> float:
	if borda < 0:
		return -INF
	var direcao := _direcao_da_borda(borda)
	var menor := INF
	for k in range(41):
		var t := float(k) / 40.0 - 0.5
		var x: float
		var z: float
		if direcao.x != 0:
			x = (float(celula.x) + 0.5 * float(direcao.x)) * tamanho_do_modulo
			z = (float(celula.y) + t) * tamanho_do_modulo
		else:
			x = (float(celula.x) + t) * tamanho_do_modulo
			z = (float(celula.y) + 0.5 * float(direcao.y)) * tamanho_do_modulo
		menor = minf(menor, _altura_do_chao(x, z))
	return menor


## Altura em que a agua transbordaria a celula por um lado que nao leva a outra
## peca de agua. Acima disso ela escorre para o campo.
func _transbordo(celula: Vector2i) -> float:
	var menor := INF
	for borda in range(4):
		if _celulas_de_agua.has(celula + _direcao_da_borda(borda)):
			continue
		menor = minf(menor, _soleira_da_borda(celula, borda))
	return menor


func _direcao_da_borda(borda: int) -> Vector2i:
	match borda:
		0: return Vector2i(0, -1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, 1)
		_: return Vector2i(-1, 0)


## Fundo do canal perto de um ponto, lido da grade da celula.
func _fundo_perto(grade: PackedFloat32Array, celula: Vector2i, ponto: Vector3) -> float:
	var lado_da_grade := int(sqrt(float(grade.size())))
	var passo := tamanho_do_modulo / float(lado_da_grade - 1)
	var canto := Vector2(
		float(celula.x) * tamanho_do_modulo - tamanho_do_modulo * 0.5,
		float(celula.y) * tamanho_do_modulo - tamanho_do_modulo * 0.5)
	var gx := clampi(int(round((ponto.x - canto.x) / passo)), 0, lado_da_grade - 1)
	var gz := clampi(int(round((ponto.z - canto.y) / passo)), 0, lado_da_grade - 1)
	var alcance := maxi(1, lado_da_grade / 8)
	var menor := INF
	for dz in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var x := gx + dx
			var z := gz + dz
			if x < 0 or z < 0 or x >= lado_da_grade or z >= lado_da_grade:
				continue
			var h: float = grade[z * lado_da_grade + x]
			if h != INF:
				menor = minf(menor, h)
	return 0.0 if menor == INF else menor


## Enche a depressao de cada peca ate o nivel da celula.
##
## A agua deixa de ser uma fita de largura fixa ao longo do leito: ela ocupa
## exatamente o que a peca escavou. Era a fita que deixava a peca de nascente
## seca, porque o poco dela e largo demais para uma faixa.
func _montar_laminas(raiz: Node3D) -> void:
	var lado_da_grade := 49
	var grades := {}
	for celula: Vector2i in _celulas_de_agua.keys():
		grades[celula] = _grade_de_altura(celula, lado_da_grade)
	var niveis := _niveis_da_agua(grades)

	var por_tipo := {"rio": [], "lago": []}
	var passo := tamanho_do_modulo / float(lado_da_grade - 1)
	for celula: Vector2i in _celulas_de_agua.keys():
		if not niveis.has(celula):
			continue
		var plano: Dictionary = niveis[celula]
		var grade: PackedFloat32Array = grades[celula]
		var canto := Vector2(
			float(celula.x) * tamanho_do_modulo - tamanho_do_modulo * 0.5,
			float(celula.y) * tamanho_do_modulo - tamanho_do_modulo * 0.5)
		var lista: Array = por_tipo[_celulas_de_agua[celula]["tipo"]]
		for gz in range(lado_da_grade - 1):
			for gx in range(lado_da_grade - 1):
				var cantos: Array = [Vector2i(gx, gz), Vector2i(gx + 1, gz),
					Vector2i(gx + 1, gz + 1), Vector2i(gx, gz + 1)]
				var pontos: Array = []
				var fundos: Array = []
				var alturas_da_agua: Array = []
				var valido := true
				for c: Vector2i in cantos:
					var h: float = grade[c.y * lado_da_grade + c.x]
					if h == INF:
						valido = false
						break
					var ponto := canto + Vector2(float(c.x), float(c.y)) * passo
					var nivel := _nivel_no_ponto(plano, ponto)
					pontos.append(ponto)
					alturas_da_agua.append(nivel)
					fundos.append(nivel - h)
				if not valido:
					continue
				# Cada quadrado da grade vira dois triangulos, e cada triangulo e
				# recortado no nivel da agua. O corte cai onde a superficie cruza
				# de verdade, entao a margem sai suave em vez de escadinha.
				_recortar(pontos[0], pontos[1], pontos[2], fundos[0], fundos[1], fundos[2],
					alturas_da_agua[0], alturas_da_agua[1], alturas_da_agua[2], lista)
				_recortar(pontos[0], pontos[2], pontos[3], fundos[0], fundos[2], fundos[3],
					alturas_da_agua[0], alturas_da_agua[2], alturas_da_agua[3], lista)

	for tipo: String in por_tipo:
		var triangulos: Array = por_tipo[tipo]
		if triangulos.is_empty():
			continue
		var vertices := PackedVector3Array()
		var normais := PackedVector3Array()
		for v: Vector3 in triangulos:
			vertices.append(v)
			normais.append(Vector3.UP)
		var malha := ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normais
		malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		malha.surface_set_material(0, _material_da_agua())
		var visual := MeshInstance3D.new()
		visual.name = "LaminaDoRio" if tipo == "rio" else "LaminaDoLago"
		visual.mesh = malha
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(visual)


## Recorta um triangulo da grade na linha d agua e guarda a parte submersa.
##
## Positivo em [param da] significa vertice abaixo do nivel. Onde o sinal muda
## entre dois vertices, o ponto de corte e interpolado pela profundidade: e isso
## que tira o serrilhado da margem.
func _recortar(a: Vector2, b: Vector2, c: Vector2, da: float, db: float, dc: float,
		na: float, nb: float, nc: float, saida: Array) -> void:
	var pontos: Array = [a, b, c]
	var profundidades: Array = [da, db, dc]
	var niveis: Array = [na, nb, nc]
	var recorte: Array = []
	for i in range(3):
		var j := (i + 1) % 3
		var di: float = profundidades[i]
		var dj: float = profundidades[j]
		if di >= 0.0:
			recorte.append(Vector3(pontos[i].x, niveis[i], pontos[i].y))
		if (di >= 0.0) != (dj >= 0.0):
			var t: float = di / (di - dj)
			var p: Vector2 = (pontos[i] as Vector2).lerp(pontos[j], t)
			recorte.append(Vector3(p.x, lerpf(niveis[i], niveis[j], t), p.y))
	if recorte.size() < 3:
		return
	for k in range(1, recorte.size() - 1):
		saida.append(recorte[0])
		saida.append(recorte[k])
		saida.append(recorte[k + 1])


## Nivel da agua num ponto: constante no lago, e acompanhando o caimento entre
## a borda de entrada e a de saida no canal do rio.
func _nivel_no_ponto(plano: Dictionary, ponto: Vector2) -> float:
	var de: Vector2 = plano["de"]
	var para: Vector2 = plano["para"]
	var eixo := para - de
	if eixo.length_squared() < 0.001:
		return float(plano["entrada"])
	var t := clampf((ponto - de).dot(eixo) / eixo.length_squared(), 0.0, 1.0)
	return lerpf(float(plano["entrada"]), float(plano["saida"]), t)


func tem_agua() -> bool:
	return _lago_pronto


func centro_do_lago_em_metros() -> Vector3:
	return Vector3(
		float(_centro_do_lago.x) * tamanho_do_modulo,
		_nivel_do_lago(),
		float(_centro_do_lago.y) * tamanho_do_modulo)


func ponto_do_rio_em_metros(fracao: float) -> Vector3:
	if _caminho_do_rio.is_empty():
		return centro_do_lago_em_metros()
	var indice := clampi(int(fracao * float(_caminho_do_rio.size())), 0, _caminho_do_rio.size() - 1)
	var celula: Vector2i = _caminho_do_rio[indice]
	var x := float(celula.x) * tamanho_do_modulo
	var z := float(celula.y) * tamanho_do_modulo
	return Vector3(x, _altura_do_chao(x, z) + lamina_do_rio, z)
