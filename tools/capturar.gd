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

	quit()
