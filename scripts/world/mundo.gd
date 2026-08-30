class_name Mundo
extends Node3D

## Raiz do prototipo: liga a ilha gerada, o oceano e o personagem.

@onready var ilha: GeradorDaIlha = $Ilha
@onready var oceano: Node3D = $Oceano
@onready var personagem: Personagem = $Personagem
@onready var aviso: Control = $Interface/Aviso


func _ready() -> void:
	# A ilha se monta no proprio _ready, que roda antes deste por ser filho,
	# entao o ponto de nascimento ja esta disponivel aqui.
	personagem.definir_nascimento(ilha.posicao_de_nascimento())


func _process(_delta: float) -> void:
	# O aviso so aparece quando o mouse esta livre: no navegador o travamento
	# do ponteiro depende de um clique do usuario.
	aviso.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
