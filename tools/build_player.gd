# Ferramenta de build: monta a cena do personagem.
# Uso: godot --headless --path . --script tools/build_player.gd
extends SceneTree

func _init() -> void:
	var corpo := CharacterBody3D.new()
	corpo.name = "Personagem"
	corpo.set_script(load("res://scripts/player/personagem.gd"))
	corpo.collision_layer = 2   # camada "personagem"
	corpo.collision_mask = 1 | 4  # colide com "mundo" e "limite_da_ilha"
	corpo.floor_max_angle = deg_to_rad(50.0)
	corpo.slide_on_ceiling = true

	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.8
	var colisao := CollisionShape3D.new()
	colisao.name = "Colisao"
	colisao.shape = capsula
	colisao.position = Vector3(0.0, 0.9, 0.0)
	corpo.add_child(colisao)
	colisao.owner = corpo

	var pivo := Node3D.new()
	pivo.name = "PivoDaCamera"
	pivo.position = Vector3(0.0, 1.65, 0.0)
	corpo.add_child(pivo)
	pivo.owner = corpo

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = 75.0
	camera.near = 0.1
	camera.far = 6000.0
	camera.current = true
	pivo.add_child(camera)
	camera.owner = corpo

	var cena := PackedScene.new()
	var err := cena.pack(corpo)
	if err == OK:
		err = ResourceSaver.save(cena, "res://scenes/player/personagem.tscn")
	print("scenes/player/personagem.tscn -> ", error_string(err))
	quit(0 if err == OK else 1)
