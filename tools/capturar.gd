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
	var mundo := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(mundo)
	var personagem: CharacterBody3D = mundo.get_node("Personagem")
	var pivo: Node3D = personagem.get_node("PivoDaCamera")
	await esperar(120)

	await capturar("01_nascimento")

	personagem.olhar(Vector2(0.0, -60.0))      # levanta um pouco a visao
	await esperar(10)
	await capturar("02_para_o_interior")

	personagem.rotation.y += PI
	await esperar(10)
	await capturar("03_para_o_mar")

	# Vista aerea da ilha inteira, so para conferir o formato e a costa.
	var camera: Camera3D = pivo.get_node("Camera")
	camera.top_level = true
	camera.global_position = Vector3(0.0, 900.0, 950.0)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	await esperar(20)
	await capturar("04_ilha_de_cima")

	camera.global_position = Vector3(700.0, 120.0, 700.0)
	camera.look_at(Vector3(0.0, 40.0, 0.0), Vector3.UP)
	await esperar(20)
	await capturar("05_da_agua")

	quit()
