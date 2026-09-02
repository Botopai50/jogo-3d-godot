# Ferramenta de conferencia visual: abre o mundo com renderizacao de verdade e
# grava algumas capturas em disco. Usada so no desenvolvimento.
# Uso: xvfb-run godot --path . --rendering-driver opengl3 --resolution 1280x720 \
#        --script tools/capturar.gd -- /caminho/das/capturas
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

func capturar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var imagem := root.get_texture().get_image()
	var err := imagem.save_png("%s/%s.png" % [destino, nome])
	print("captura %s -> %s" % [nome, error_string(err)])

func rodar() -> void:
	var destino_absoluto := ProjectSettings.globalize_path(destino)
	var erro_da_pasta := DirAccess.make_dir_recursive_absolute(destino_absoluto)
	if erro_da_pasta != OK:
		push_error("nao foi possivel criar a pasta de capturas: %s" % error_string(erro_da_pasta))
		quit(1)
		return
	destino = destino_absoluto

	var mundo := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(mundo)
	var personagem: CharacterBody3D = mundo.get_node("Personagem")
	var ilha = mundo.get_node("Ilha")
	var pivo: Node3D = personagem.get_node("PivoDaCamera")
	await esperar(120)

	await capturar("01_nascimento")

	personagem.olhar(Vector2(0.0, -60.0))      # levanta um pouco a visao
	await esperar(10)
	await capturar("02_para_o_interior")

	personagem.rotation.y += PI
	await esperar(10)
	await capturar("03_para_o_mar")

	# Vista superior ortografica da ilha inteira, para conferir o formato e a costa.
	var camera: Camera3D = pivo.get_node("Camera")
	# A partir daqui a ferramenta posiciona a camera manualmente; desliga apenas
	# o seguidor visual do personagem para ele nao sobrescrever esses enquadramentos.
	personagem.set_process(false)
	camera.top_level = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var raio_da_ilha: float = ilha.raio_em_metros()
	camera.size = raio_da_ilha * 2.35
	camera.global_position = Vector3(0.0, raio_da_ilha * 2.0, 0.0)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	await esperar(20)
	await capturar("ilha_de_cima")

	# Vista lateral em perspectiva, com mar, costa e relevo no mesmo quadro.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0
	camera.global_position = Vector3(0.0, raio_da_ilha * 0.25, raio_da_ilha * 1.75)
	camera.look_at(Vector3(0.0, 40.0, 0.0), Vector3.UP)
	await esperar(20)
	await capturar("ilha_de_lado")

	# Rio e lago: uma vista de cima do conjunto e outra rente ao canal.
	if ilha.has_method("centro_do_lago_em_metros") and ilha.tem_agua():
		var lago: Vector3 = ilha.centro_do_lago_em_metros()
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 60.0
		camera.global_position = lago + Vector3(0.0, 420.0, 520.0)
		camera.look_at(lago, Vector3.UP)
		await esperar(20)
		await capturar("lago_de_cima")

		var canal: Vector3 = ilha.ponto_do_rio_em_metros(0.5)
		camera.global_position = canal + Vector3(0.0, 330.0, 1.0)
		camera.look_at(canal, Vector3.UP)
		await esperar(20)
		await capturar("rio_de_perto")

		# Zoom dedicado na foz, centralizado no socket que liga o rio ao mar.
		var hydrology: HydrologyManager = ilha.get_node_or_null("Hydrology")
		if hydrology != null:
			var terminal: Dictionary = hydrology.ocean_terminal()
			if not terminal.is_empty():
				var debug_foz: Node3D = ilha.get_node_or_null("DebugCruzamentoDaFoz")
				if debug_foz != null:
					debug_foz.visible = true
				var foz: Vector3 = terminal["position"]
				var radial := Vector3(foz.x, 0.0, foz.z).normalized()
				var centro_da_foz: Vector3 = foz + radial * float(ilha.largura_da_costa) * 0.45
				camera.projection = Camera3D.PROJECTION_ORTHOGONAL
				camera.size = ilha.tamanho_do_modulo * 3.2
				camera.global_position = centro_da_foz + Vector3(0.0, 520.0, 0.0)
				camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				await esperar(20)
				await capturar("foz_zoom_de_cima")

				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
				camera.fov = 48.0
				camera.global_position = centro_da_foz - radial * 230.0 + Vector3(0.0, 145.0, 0.0)
				camera.look_at(centro_da_foz, Vector3.UP)
				await esperar(20)
				await capturar("foz_zoom_lateral")

				# Perfil paralelo a face do modulo, util para revelar deslocamentos
				# horizontais que ficam escondidos na vista frontal.
				var lado := int(terminal["side"])
				var eixo_lateral := Vector3.RIGHT if lado in [
					RiverConnection.Side.NORTH, RiverConnection.Side.SOUTH] else Vector3.FORWARD
				camera.global_position = foz + eixo_lateral * 210.0 + Vector3.UP * 38.0
				camera.look_at(foz + Vector3.UP * 2.0, Vector3.UP)
				await esperar(20)
				await capturar("foz_zoom_perfil")

	quit()
