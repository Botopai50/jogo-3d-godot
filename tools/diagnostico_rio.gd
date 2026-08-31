# Ferramenta de diagnostico: desenha por cima do cenario o leito de verdade dos
# modulos CPT_River e a lamina de agua gerada, em cores fortes, para dar para
# ver a olho onde uma coisa se afasta da outra.
#
#   magenta  leito medido nos modulos, varrendo a celula inteira de lado a lado
#   ciano    linha de agua que o gerador produz
#   amarelo  onde o canal cruza a borda de cada celula, medido no catalogo
#   branco   contorno das celulas que tem peca de rio ou de lago
#
# Uso: xvfb-run godot --path . --rendering-driver opengl3 --resolution 1600x900 \
#        --script tools/diagnostico_rio.gd -- /caminho/da/captura
extends SceneTree

var destino := "/home/user/shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		destino = args[0]
	call_deferred("rodar")


func esperar(n: int) -> void:
	for i in range(n):
		await process_frame


func material(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Sempre por cima do terreno: a linha e para ser vista, nao para ser
	# ocultada pelo relevo em que ela se apoia.
	m.no_depth_test = true
	m.render_priority = 10
	return m


## Fita horizontal larga o bastante para aparecer numa vista de cima.
func fita(pontos: Array, largura: float, cor: Color) -> MeshInstance3D:
	if pontos.size() < 2:
		return null
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(pontos.size()):
		var p: Vector3 = pontos[i]
		var direcao: Vector3
		if i == 0:
			direcao = pontos[1] - p
		elif i == pontos.size() - 1:
			direcao = p - pontos[i - 1]
		else:
			direcao = pontos[i + 1] - pontos[i - 1]
		direcao.y = 0.0
		if direcao.length_squared() < 0.0001:
			direcao = Vector3.FORWARD
		var lado := direcao.normalized().cross(Vector3.UP).normalized() * largura * 0.5
		vertices.append(p - lado)
		vertices.append(p + lado)
		if i > 0:
			var b := (i - 1) * 2
			indices.append_array([b, b + 2, b + 1, b + 1, b + 2, b + 3])
	var malha := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	malha.surface_set_material(0, material(cor))
	var visual := MeshInstance3D.new()
	visual.mesh = malha
	return visual


func marcador(centro: Vector3, tamanho: float, cor: Color) -> MeshInstance3D:
	var caixa := BoxMesh.new()
	caixa.size = Vector3(tamanho, tamanho * 0.2, tamanho)
	caixa.material = material(cor)
	var visual := MeshInstance3D.new()
	visual.mesh = caixa
	visual.position = centro
	return visual


func contorno(centro: Vector3, lado: float, cor: Color) -> Node3D:
	var grupo := Node3D.new()
	var meia := lado * 0.5
	var cantos := [
		centro + Vector3(-meia, 0.0, -meia), centro + Vector3(meia, 0.0, -meia),
		centro + Vector3(meia, 0.0, meia), centro + Vector3(-meia, 0.0, meia),
	]
	for i in range(4):
		var a: Vector3 = cantos[i]
		var b: Vector3 = cantos[(i + 1) % 4]
		var f := fita([a, b], lado * 0.02, cor)
		if f != null:
			grupo.add_child(f)
	return grupo


## Leito de verdade: para cada passo ao longo do trecho, varre a celula inteira
## de lado a lado e fica com o ponto mais baixo. Nao usa o encaixe do gerador,
## para poder mostrar quando o gerador erra.
func leito_medido(ilha: Node3D) -> Array:
	var pontos: Array = []
	var lado: float = ilha.tamanho_do_modulo
	for item: Dictionary in ilha._pecas_escolhidas:
		if item["tipo"] != "rio":
			continue
		var celula: Vector2i = item["celula"]
		var escolha: Dictionary = item["escolha"]
		var centro := Vector3(celula.x * lado, 0.0, celula.y * lado)
		var entrada: Vector3 = centro + ilha._ponto_no_mundo(
			int(escolha["borda_entrada"]), float(escolha["fracao_entrada"]))
		var saida: Vector3 = centro
		if int(escolha["borda_saida"]) >= 0:
			saida = centro + ilha._ponto_no_mundo(
				int(escolha["borda_saida"]), float(escolha["fracao_saida"]))
		for k in range(9):
			var t := float(k) / 8.0
			var p: Vector3 = entrada.lerp(saida, t)
			var frente: Vector3 = saida - entrada
			frente.y = 0.0
			if frente.length_squared() < 0.0001:
				continue
			var perpendicular := frente.normalized().cross(Vector3.UP).normalized()
			var melhor := p
			var melhor_altura := INF
			for j in range(-20, 21):
				var candidato: Vector3 = p + perpendicular * (float(j) / 20.0) * lado * 0.5
				var celula_do_ponto := Vector2i(
					roundi(candidato.x / lado), roundi(candidato.z / lado))
				if celula_do_ponto != celula:
					continue
				var altura: float = ilha._altura_do_chao(candidato.x, candidato.z)
				if altura < melhor_altura:
					melhor_altura = altura
					melhor = candidato
			if melhor_altura < INF:
				melhor.y = melhor_altura
				pontos.append(melhor)
	return pontos


func rodar() -> void:
	var mundo := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(mundo)
	await esperar(30)
	var ilha: Node3D = mundo.get_node("Ilha")
	var lado: float = ilha.tamanho_do_modulo
	var marcas := Node3D.new()
	marcas.name = "Diagnostico"
	mundo.add_child(marcas)

	# Contorno de cada celula com peca de agua.
	for celula: Vector2i in ilha._celulas_de_agua.keys():
		var altura: float = ilha._altura_do_chao(celula.x * lado, celula.y * lado) + 6.0
		marcas.add_child(contorno(
			Vector3(celula.x * lado, altura, celula.y * lado), lado, Color(1, 1, 1)))

	# Leito medido, em magenta.
	var leito := leito_medido(ilha)
	for i in range(leito.size()):
		leito[i] = (leito[i] as Vector3) + Vector3(0.0, 3.0, 0.0)
	var f_leito := fita(leito, lado * 0.06, Color(1.0, 0.0, 0.8))
	if f_leito != null:
		marcas.add_child(f_leito)

	# Cobertura de agua por celula: e o que diz se alguma peca ficou seca.
	var por_celula := {}
	for nome_da_lamina in ["LaminaDoRio", "LaminaDoLago"]:
		var lamina := ilha.get_node_or_null("Agua/" + nome_da_lamina) as MeshInstance3D
		if lamina == null or lamina.mesh == null:
			continue
		for p: Vector3 in lamina.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var c := Vector2i(roundi(p.x / lado), roundi(p.z / lado))
			por_celula[c] = int(por_celula.get(c, 0)) + 1

	# Cruzamentos de borda, em amarelo: e ali que uma peca entrega o leito para
	# a proxima, e onde o desalinho do pacote aparece.
	for item: Dictionary in ilha._pecas_escolhidas:
		if item["tipo"] != "rio":
			continue
		var celula: Vector2i = item["celula"]
		var escolha: Dictionary = item["escolha"]
		var centro := Vector3(celula.x * lado, 0.0, celula.y * lado)
		for par in [[int(escolha["borda_entrada"]), float(escolha["fracao_entrada"])],
				[int(escolha["borda_saida"]), float(escolha["fracao_saida"])]]:
			if int(par[0]) < 0:
				continue
			var p: Vector3 = centro + ilha._ponto_no_mundo(int(par[0]), float(par[1]))
			p.y = ilha._altura_do_chao(p.x, p.z) + 5.0
			marcas.add_child(marcador(p, lado * 0.1, Color(1.0, 0.95, 0.0)))

	# Camera de cima, enquadrando as celulas de agua.
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for celula: Vector2i in ilha._celulas_de_agua.keys():
		minimo.x = minf(minimo.x, celula.x * lado)
		minimo.y = minf(minimo.y, celula.y * lado)
		maximo.x = maxf(maximo.x, celula.x * lado)
		maximo.y = maxf(maximo.y, celula.y * lado)
	var meio := (minimo + maximo) * 0.5
	var extensao := maxf(maximo.x - minimo.x, maximo.y - minimo.y) + lado * 2.0

	var camera: Camera3D = mundo.get_node("Personagem/PivoDaCamera/Camera")
	camera.top_level = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extensao
	camera.far = 4000.0
	camera.global_position = Vector3(meio.x, 900.0, meio.y)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	await esperar(20)
	await RenderingServer.frame_post_draw
	var imagem := root.get_texture().get_image()
	var err := imagem.save_png("%s/diagnostico_rio.png" % destino)
	print("%-16s %-6s %s" % ["celula", "tipo", "vertices de agua"])
	var secas := 0
	for item: Dictionary in ilha._pecas_escolhidas:
		var celula: Vector2i = item["celula"]
		var quantos: int = int(por_celula.get(celula, 0))
		if quantos == 0:
			secas += 1
		print("%-16s %-6s %d%s" % [str(celula), item["tipo"], quantos,
			"   SECA" if quantos == 0 else ""])
	print("pecas secas: %d de %d" % [secas, ilha._pecas_escolhidas.size()])
	print("captura -> ", error_string(err))
	quit()
