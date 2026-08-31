# Ferramenta de build: monta as cenas do oceano, da ilha e do mundo.
# Uso: godot --headless --path . --script tools/build_world.gd
extends SceneTree

const MALHA_AGUA := "res://scenes/modules/malhas/Water_H_a_01.res"
const LADO_DA_MALHA_DE_AGUA := 400.0
## Lado do oceano em metros. Fica dentro do alcance da camera (6000) mesmo nas
## quinas, e a neblina esconde o fim do plano.
const LADO_DO_OCEANO := 8000.0
## O oceano fica logo abaixo de zero: as bordas dos modulos de terreno terminam
## exatamente na altura zero e nenhum modulo escolhido afunda alem de -0.3,
## entao a agua nao briga em profundidade com o terreno nem alaga o miolo.
const NIVEL_DO_MAR := -0.35


func salvar(cena_raiz: Node, caminho: String) -> Error:
	var empacotada := PackedScene.new()
	var err := empacotada.pack(cena_raiz)
	if err != OK:
		return err
	err = ResourceSaver.save(empacotada, caminho)
	print("%s -> %s" % [caminho, error_string(err)])
	return err


func preparar_malha_de_agua() -> bool:
	var cena: PackedScene = load("res://assets/grid/terrain_assets/Water/Water_H_a_01.fbx")
	if cena == null:
		push_error("malha de agua do pacote nao encontrada")
		return false
	var raiz := cena.instantiate()
	var achada: Mesh = null
	var pilha: Array = [raiz]
	while not pilha.is_empty():
		var n = pilha.pop_back()
		for c in n.get_children():
			pilha.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			achada = (n as MeshInstance3D).mesh
			break
	if achada == null:
		push_error("nenhuma malha dentro do .fbx de agua")
		raiz.free()
		return false
	var copia: ArrayMesh = achada.duplicate(true)
	for si in range(copia.get_surface_count()):
		copia.surface_set_material(si, load("res://materials/oceano.tres"))
	var err := ResourceSaver.save(copia, MALHA_AGUA)
	raiz.free()
	print("%s -> %s" % [MALHA_AGUA, error_string(err)])
	return err == OK


func construir_oceano() -> Error:
	var raiz := Node3D.new()
	raiz.name = "Oceano"

	var agua := MeshInstance3D.new()
	agua.name = "Superficie"
	agua.mesh = load(MALHA_AGUA)
	agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	agua.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# A malha do pacote ocupa x de 0 a 400 e z de -400 a 0: centraliza e amplia.
	var escala := LADO_DO_OCEANO / LADO_DA_MALHA_DE_AGUA
	agua.scale = Vector3(escala, 1.0, escala)
	agua.position = Vector3(-LADO_DO_OCEANO * 0.5, NIVEL_DO_MAR, LADO_DO_OCEANO * 0.5)
	raiz.add_child(agua)
	agua.owner = raiz

	var err := salvar(raiz, "res://scenes/world/ocean/oceano.tscn")
	raiz.free()
	return err


func construir_ilha() -> Error:
	var raiz := Node3D.new()
	raiz.name = "Ilha"
	raiz.set_script(load("res://scripts/world/gerador_da_ilha.gd"))
	var err := salvar(raiz, "res://scenes/world/island/ilha.tscn")
	raiz.free()
	return err


func construir_ambiente() -> WorldEnvironment:
	var ceu_material := ProceduralSkyMaterial.new()
	ceu_material.sky_top_color = Color(0.22, 0.45, 0.78)
	ceu_material.sky_horizon_color = Color(0.72, 0.83, 0.90)
	ceu_material.ground_bottom_color = Color(0.13, 0.22, 0.29)
	ceu_material.ground_horizon_color = Color(0.72, 0.83, 0.90)
	ceu_material.sun_angle_max = 12.0
	ceu_material.sun_curve = 0.15

	var ceu := Sky.new()
	ceu.sky_material = ceu_material

	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = ceu
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ambiente.ambient_light_sky_contribution = 1.0
	# A luz ambiente vinda do ceu e forte: acima de ~0.15 ela satura o verde do
	# atlas e o terreno inteiro sai branco. O tonemap fica linear de proposito,
	# para as cores chapadas da paleta chegarem a tela como sao.
	ambiente.ambient_light_energy = 0.09
	ambiente.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Neblina distante: esconde onde o plano do oceano acaba e da profundidade.
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color(0.66, 0.78, 0.88)
	ambiente.fog_density = 0.00025
	ambiente.fog_sky_affect = 0.0
	ambiente.fog_aerial_perspective = 0.2

	var no := WorldEnvironment.new()
	no.name = "Ambiente"
	no.environment = ambiente
	return no


func construir_interface() -> CanvasLayer:
	var camada := CanvasLayer.new()
	camada.name = "Interface"

	var aviso := PanelContainer.new()
	aviso.name = "Aviso"
	aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	aviso.offset_left = -300.0
	aviso.offset_right = 300.0
	aviso.offset_top = -70.0
	aviso.offset_bottom = -20.0
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texto := Label.new()
	texto.name = "Texto"
	texto.text = "Clique para jogar\nWASD mover  |  Shift correr  |  Espaco pular  |  Esc liberar o mouse"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.add_child(texto)
	camada.add_child(aviso)
	return camada


func construir_mundo() -> Error:
	var raiz := Node3D.new()
	raiz.name = "Mundo"
	raiz.set_script(load("res://scripts/world/mundo.gd"))

	var ambiente := construir_ambiente()
	raiz.add_child(ambiente)
	ambiente.owner = raiz

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-135.0), 0.0)
	sol.light_energy = 0.55
	sol.light_color = Color(1.0, 0.97, 0.90)
	sol.shadow_enabled = true
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sol.directional_shadow_max_distance = 260.0
	sol.shadow_bias = 0.06
	raiz.add_child(sol)
	sol.owner = raiz

	for dupla in [
		["Ilha", "res://scenes/world/island/ilha.tscn"],
		["Oceano", "res://scenes/world/ocean/oceano.tscn"],
		["Personagem", "res://scenes/player/personagem.tscn"],
	]:
		var no := (load(dupla[1]) as PackedScene).instantiate()
		no.name = dupla[0]
		raiz.add_child(no)
		no.owner = raiz

	var interface := construir_interface()
	raiz.add_child(interface)
	interface.owner = raiz
	for filho in interface.get_children():
		filho.owner = raiz
		for neto in filho.get_children():
			neto.owner = raiz

	var err := salvar(raiz, "res://scenes/main.tscn")
	raiz.free()
	return err


func _init() -> void:
	if not preparar_malha_de_agua():
		quit(1)
		return
	for err in [construir_oceano(), construir_ilha(), construir_mundo()]:
		if err != OK:
			quit(1)
			return
	quit(0)
