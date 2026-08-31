class_name Personagem
extends CharacterBody3D

## Personagem em primeira pessoa do prototipo.
##
## Movimento com aceleracao/desaceleracao, corrida enquanto a tecla estiver
## pressionada, gravidade propria e pulo permitido apenas com os pes no chao.
## A camera gira com o mouse, com a inclinacao vertical limitada.

@export_group("Movimento")
## Velocidade alvo ao caminhar, em metros por segundo.
@export_range(1.0, 20.0, 0.1) var velocidade_de_caminhada := 5.0
## Velocidade alvo com a tecla de corrida pressionada.
@export_range(1.0, 40.0, 0.1) var velocidade_de_corrida := 9.5
## Quao rapido a velocidade sobe ate o alvo (m/s^2).
@export_range(1.0, 100.0, 0.5) var aceleracao := 14.0
## Quao rapido a velocidade cai ate parar (m/s^2).
@export_range(1.0, 100.0, 0.5) var desaceleracao := 18.0
## Fracao do controle de solo disponivel no ar (0 = nenhum, 1 = total).
@export_range(0.0, 1.0, 0.05) var controle_no_ar := 0.3

@export_group("Voo")
## Velocidade do modo de voo ativado com F.
@export_range(10.0, 200.0, 1.0) var velocidade_de_voo := 45.0
## Velocidade do voo segurando Shift.
@export_range(20.0, 400.0, 1.0) var velocidade_de_voo_turbo := 120.0
## Quao rapido o voo chega a velocidade alvo.
@export_range(10.0, 400.0, 1.0) var aceleracao_do_voo := 90.0

@export_group("Pulo e gravidade")
## Velocidade vertical aplicada no instante do pulo.
@export_range(1.0, 20.0, 0.1) var forca_do_pulo := 6.5
## Gravidade em m/s^2. Mais alta que a da Terra para dar um pulo menos flutuante.
@export_range(1.0, 80.0, 0.5) var gravidade := 20.0
## Velocidade maxima de queda, para nao ganhar velocidade sem limite.
@export_range(5.0, 200.0, 1.0) var velocidade_maxima_de_queda := 60.0

@export_group("Camera")
## Radianos de rotacao por pixel de movimento do mouse.
@export_range(0.0005, 0.01, 0.0001) var sensibilidade_do_mouse := 0.0022
## Limite de quanto a camera pode olhar para baixo, em graus.
@export_range(-89.9, 0.0, 0.1) var angulo_vertical_minimo := -89.0
## Limite de quanto a camera pode olhar para cima, em graus.
@export_range(0.0, 89.9, 0.1) var angulo_vertical_maximo := 89.0
## Deslocamento maximo aceito de um unico evento de mouse, em pixels. Serve de
## trava contra o salto que o navegador dispara ao travar o ponteiro.
@export_range(20.0, 2000.0, 1.0) var salto_maximo_do_mouse := 200.0
## Quanto tempo ignorar o mouse logo depois de capturar o ponteiro, em segundos.
@export_range(0.0, 1.0, 0.01) var carencia_apos_capturar := 0.2

@export_group("Seguranca")
## Abaixo desta altura o personagem volta ao ponto de partida.
@export var altura_de_resgate := -40.0

@onready var pivo_da_camera: Node3D = $PivoDaCamera

var _transformada_inicial: Transform3D
var _inclinacao := 0.0
var _instante_da_captura := 0.0
var _modo_voo := false


func _ready() -> void:
	_transformada_inicial = global_transform
	capturar_mouse()


## Define onde o personagem comeca e para onde ele volta se cair do cenario.
## Chamado pelo mundo depois que a ilha ja foi gerada.
func definir_nascimento(posicao: Vector3) -> void:
	global_position = posicao
	velocity = Vector3.ZERO
	_transformada_inicial = global_transform


func capturar_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_instante_da_captura = Time.get_ticks_msec() / 1000.0


func liberar_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func mouse_esta_capturado() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _input(evento: InputEvent) -> void:
	# Consome atalhos perigosos enquanto a gameplay esta com o mouse preso.
	if mouse_esta_capturado() and atalho_protegido(evento):
		get_viewport().set_input_as_handled()


func atalho_protegido(evento: InputEvent) -> bool:
	if not evento is InputEventKey:
		return false
	var tecla := evento as InputEventKey
	return tecla.pressed and tecla.ctrl_pressed and tecla.keycode in [KEY_W, KEY_R]


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and mouse_esta_capturado():
		olhar((evento as InputEventMouseMotion).relative)
		return

	if evento.is_action_pressed("release_mouse"):
		liberar_mouse()
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("capture_mouse") and not mouse_esta_capturado():
		# No navegador o travamento do ponteiro so pode ser pedido a partir de
		# um gesto do usuario, entao a recaptura acontece no clique.
		capturar_mouse()
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("toggle_flight"):
		alternar_voo()
		get_viewport().set_input_as_handled()


## Liga ou desliga o voo. Ao desligar, a gravidade volta no quadro seguinte.
func alternar_voo() -> void:
	_modo_voo = not _modo_voo
	velocity = Vector3.ZERO


func esta_voando() -> bool:
	return _modo_voo


## Aplica um movimento de mouse a visao. Horizontal gira o corpo inteiro, para
## que o deslocamento acompanhe para onde se olha; vertical gira apenas a
## camera, com a inclinacao presa entre os limites configurados.
##
## Ao travar o ponteiro, o navegador dispara um evento de movimento com o
## deslocamento acumulado ate ali, que pode valer meia tela e jogaria a visao
## direto para o ceu no primeiro clique. Por isso o mouse fica ignorado por um
## instante depois da captura e cada evento tem o deslocamento limitado.
func olhar(movimento: Vector2) -> void:
	if Time.get_ticks_msec() / 1000.0 - _instante_da_captura < carencia_apos_capturar:
		return
	movimento = movimento.clampf(-salto_maximo_do_mouse, salto_maximo_do_mouse)
	rotate_y(-movimento.x * sensibilidade_do_mouse)
	_inclinacao = clampf(
		_inclinacao - movimento.y * sensibilidade_do_mouse,
		deg_to_rad(angulo_vertical_minimo),
		deg_to_rad(angulo_vertical_maximo)
	)
	pivo_da_camera.rotation.x = _inclinacao


func _physics_process(delta: float) -> void:
	if _modo_voo:
		_processar_voo(delta)
		move_and_slide()
		return

	var no_chao := is_on_floor()

	if no_chao:
		# Pequena velocidade para baixo mantem o personagem colado em rampas.
		velocity.y = -0.1
		# O pulo so existe com os pes no chao: nada de pulo duplo ou no ar.
		if Input.is_action_just_pressed("jump"):
			velocity.y = forca_do_pulo
	else:
		velocity.y = maxf(velocity.y - gravidade * delta, -velocidade_maxima_de_queda)

	var entrada := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direcao := (transform.basis * Vector3(entrada.x, 0.0, entrada.y))
	direcao.y = 0.0
	if direcao.length_squared() > 1.0:
		direcao = direcao.normalized()

	var correndo := Input.is_action_pressed("sprint")
	var velocidade_alvo := velocidade_de_corrida if correndo else velocidade_de_caminhada
	var horizontal_atual := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_alvo := direcao * velocidade_alvo

	var taxa := aceleracao if direcao != Vector3.ZERO else desaceleracao
	if not no_chao:
		taxa *= controle_no_ar
	var horizontal := horizontal_atual.move_toward(horizontal_alvo, taxa * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	if global_position.y < altura_de_resgate:
		voltar_ao_inicio()


func _processar_voo(delta: float) -> void:
	var entrada := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direcao := transform.basis * Vector3(entrada.x, 0.0, entrada.y)
	if Input.is_action_pressed("jump"):
		direcao.y += 1.0
	if Input.is_action_pressed("fly_down"):
		direcao.y -= 1.0
	if direcao.length_squared() > 1.0:
		direcao = direcao.normalized()
	var turbo := Input.is_action_pressed("sprint")
	var rapidez := velocidade_de_voo_turbo if turbo else velocidade_de_voo
	velocity = velocity.move_toward(direcao * rapidez, aceleracao_do_voo * delta)


## Recoloca o personagem no ponto de partida. Rede de seguranca caso ele saia
## do cenario por algum caminho nao previsto.
func voltar_ao_inicio() -> void:
	velocity = Vector3.ZERO
	global_transform = _transformada_inicial
