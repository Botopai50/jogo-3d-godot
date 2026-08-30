# Ferramenta de build: grava o mapa de entrada e as configuracoes do projeto.
# Uso: godot --headless --path . --script tools/setup_project.gd
extends SceneTree

func key_event(physical_keycode: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1  # -1 = vale para qualquer dispositivo; o padrao nao casa com o teclado real
	e.physical_keycode = physical_keycode
	return e

func mouse_event(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = button
	return e

func action(events: Array, deadzone: float = 0.2) -> Dictionary:
	return {"deadzone": deadzone, "events": events}

func _init() -> void:
	var actions := {
		"move_forward": [key_event(KEY_W), key_event(KEY_UP)],
		"move_back": [key_event(KEY_S), key_event(KEY_DOWN)],
		"move_left": [key_event(KEY_A), key_event(KEY_LEFT)],
		"move_right": [key_event(KEY_D), key_event(KEY_RIGHT)],
		"jump": [key_event(KEY_SPACE)],
		"sprint": [key_event(KEY_SHIFT)],
		"release_mouse": [key_event(KEY_ESCAPE)],
		"capture_mouse": [mouse_event(MOUSE_BUTTON_LEFT)],
	}
	for name in actions:
		ProjectSettings.set_setting("input/" + name, action(actions[name]))

	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main.tscn")
	ProjectSettings.set_setting("application/config/name", "Jogo 3D Godot")
	ProjectSettings.set_setting("display/window/size/viewport_width", 1280)
	ProjectSettings.set_setting("display/window/size/viewport_height", 720)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "gl_compatibility")
	ProjectSettings.set_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	# O terreno usa faces planas: sem anti-aliasing caro no navegador.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)
	# Camadas de fisica com nomes legiveis.
	ProjectSettings.set_setting("layer_names/3d_physics/layer_1", "mundo")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_2", "personagem")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_3", "limite_da_ilha")

	var err := ProjectSettings.save()
	print("ProjectSettings.save() -> ", error_string(err))
	quit(0 if err == OK else 1)
