# Teste automatizado do prototipo, rodado sem janela.
# Uso: godot --headless --path . --script tools/testar.gd
extends SceneTree

var falhas := 0

func checar(condicao: bool, descricao: String, detalhe: String = "") -> void:
	if condicao:
		print("  OK   %s %s" % [descricao, detalhe])
	else:
		print("  FALHA %s %s" % [descricao, detalhe])
		falhas += 1

func soltar_tudo() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]:
		Input.action_release(a)

func avancar(quadros: int) -> void:
	for i in range(quadros):
		await physics_frame

func _init() -> void:
	call_deferred("rodar")

func rodar() -> void:
	var mundo := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(mundo)
	await physics_frame

	var ilha: Node3D = mundo.get_node("Ilha")
	var terreno: Node3D = ilha.get_node("Terreno")
	var limite: Node3D = ilha.get_node("LimiteDaIlha")
	var personagem: CharacterBody3D = mundo.get_node("Personagem")

	print("--- cenario ---")
	var modulos := terreno.get_child_count()
	var triangulos := 0
	var corpos := 0
	var pilha: Array = [ilha]
	while not pilha.is_empty():
		var n = pilha.pop_back()
		for c in n.get_children():
			pilha.append(c)
		if n is StaticBody3D:
			corpos += 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var m: Mesh = (n as MeshInstance3D).mesh
			for si in range(m.get_surface_count()):
				triangulos += m.surface_get_arrays(si)[Mesh.ARRAY_INDEX].size() / 3
	print("  modulos de terreno: %d" % modulos)
	print("  corpos estaticos:   %d" % corpos)
	print("  paredes de limite:  %d" % limite.get_child_count())
	print("  triangulos na cena: %d" % triangulos)
	print("  nascimento:         %s" % str(ilha.posicao_de_nascimento()))
	checar(modulos > 60, "a ilha tem modulos suficientes", "(%d)" % modulos)
	checar(limite.get_child_count() > 20, "a costa esta cercada por limites", "(%d)" % limite.get_child_count())
	checar(ilha.has_node("CostaOrganica"), "a costa organica foi gerada")
	checar(limite.get_child_count() == ilha.segmentos_da_costa,
		"o limite fisico acompanha o contorno organico", "(%d segmentos)" % limite.get_child_count())

	var planicies := 0
	var relevos_altos := 0
	for modulo in terreno.get_children():
		var nome: String = modulo.name
		if nome.begins_with("planicie"):
			planicies += 1
		if nome.begins_with("montanha") or nome.begins_with("pico"):
			relevos_altos += 1
	print("  planicies:          %d | montanhas/picos: %d" % [planicies, relevos_altos])
	var altura_do_miolo: float = ilha._altura_macro_do_terreno(0.0, 0.0)
	var altura_da_costa: float = ilha._altura_macro_do_terreno(0.0, ilha.raio_em_metros() * 0.85)
	print("  altura macro:       miolo %.2f m | costa %.2f m" % [altura_do_miolo, altura_da_costa])
	checar(planicies > relevos_altos * 2, "as planicies predominam sobre relevos altos")
	checar(altura_do_miolo - altura_da_costa > 15.0, "o terreno base tem alturas variadas")

	var props_sem_material := 0
	var nos_de_detalhe: Array = [ilha.get_node("Detalhes")]
	while not nos_de_detalhe.is_empty():
		var detalhe: Node = nos_de_detalhe.pop_back()
		for filho in detalhe.get_children():
			nos_de_detalhe.append(filho)
		if detalhe is MeshInstance3D and (detalhe as MeshInstance3D).material_override == null:
			props_sem_material += 1
	checar(props_sem_material == 0, "montanhas e rochas usam o material continuo")

	print("--- assentar no chao ---")
	await avancar(90)
	var altura_parado := personagem.global_position.y
	print("  altura apos assentar: %.3f" % altura_parado)
	checar(personagem.is_on_floor(), "o personagem esta no chao")
	checar(altura_parado > -1.0 and altura_parado < 5.0, "nao atravessou o terreno", "(y=%.2f)" % altura_parado)

	print("--- caminhada ---")
	var partida := personagem.global_position
	Input.action_press("move_forward")
	await avancar(60)
	soltar_tudo()
	var caminhou := Vector2(personagem.global_position.x - partida.x, personagem.global_position.z - partida.z).length()
	await avancar(30)
	print("  distancia em 1s de caminhada: %.2f m" % caminhou)
	checar(caminhou > 2.5, "andou para frente", "(%.2f m)" % caminhou)

	print("--- corrida ---")
	partida = personagem.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await avancar(60)
	soltar_tudo()
	var correu := Vector2(personagem.global_position.x - partida.x, personagem.global_position.z - partida.z).length()
	await avancar(30)
	print("  distancia em 1s de corrida:   %.2f m" % correu)
	checar(correu > caminhou * 1.3, "a corrida e mais rapida que a caminhada", "(%.2f vs %.2f)" % [correu, caminhou])

	print("--- pulo ---")
	await avancar(30)
	var altura_base := personagem.global_position.y
	checar(personagem.is_on_floor(), "esta no chao antes de pular")
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var altura_maxima := personagem.global_position.y
	for i in range(40):
		await physics_frame
		altura_maxima = maxf(altura_maxima, personagem.global_position.y)
	print("  ganho de altura no pulo: %.2f m" % (altura_maxima - altura_base))
	checar(altura_maxima - altura_base > 0.4, "o pulo levanta o personagem", "(%.2f m)" % (altura_maxima - altura_base))

	print("--- pulo no ar (nao pode) ---")
	await avancar(60)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await avancar(6)
	# No sexto quadro depois do primeiro pulo o personagem esta subindo; pedir
	# outro pulo nao pode acrescentar velocidade nenhuma.
	var subindo := personagem.velocity.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var depois := personagem.velocity.y
	print("  vy antes=%.2f depois=%.2f (no ar: %s)" % [subindo, depois, str(not personagem.is_on_floor())])
	checar(depois <= subindo, "o segundo pulo no ar foi ignorado")
	await avancar(90)

	print("--- limite da ilha ---")
	var antes_do_limite := personagem.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await avancar(60 * 12)
	soltar_tudo()
	await avancar(60)
	var fim := personagem.global_position
	var distancia_do_centro := Vector2(fim.x, fim.z).length()
	print("  saiu de %s para %s" % [str(antes_do_limite.round()), str(fim.round())])
	print("  distancia do centro: %.0f m (raio da ilha ~%.0f m)" % [distancia_do_centro, ilha.raio_em_metros()])
	checar(fim.y > -20.0, "nao caiu para fora do cenario", "(y=%.2f)" % fim.y)
	checar(distancia_do_centro <= ilha.raio_em_metros() + 60.0, "continua dentro da ilha")

	print("--- camera ---")
	var pivo: Node3D = personagem.get_node("PivoDaCamera")
	var giro_inicial := personagem.rotation.y
	for i in range(20):
		personagem.olhar(Vector2(50.0, 200.0))
	print("  giro horizontal: %.3f rad | inclinacao: %.2f graus" % [
		personagem.rotation.y - giro_inicial, rad_to_deg(pivo.rotation.x)])
	checar(absf(personagem.rotation.y - giro_inicial) > 0.01, "o mouse gira a visao horizontal")
	checar(rad_to_deg(pivo.rotation.x) >= personagem.angulo_vertical_minimo - 0.01,
		"a inclinacao vertical respeita o limite", "(%.2f graus)" % rad_to_deg(pivo.rotation.x))
	for i in range(20):
		personagem.olhar(Vector2(0.0, -200.0))
	checar(rad_to_deg(pivo.rotation.x) <= personagem.angulo_vertical_maximo + 0.01,
		"a inclinacao para cima respeita o limite", "(%.2f graus)" % rad_to_deg(pivo.rotation.x))

	print("")
	print("falhas: %d" % falhas)
	quit(0 if falhas == 0 else 1)
