// Oceano do prototipo: plano unico e barato, com ondulacao feita apenas no
// fragment shader (a malha de agua do pacote tem 2 triangulos, entao nao ha
// vertices para deslocar). Pensado para rodar em WebGL2 / renderizador
// Compatibility.
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

uniform vec3 cor_rasa : source_color = vec3(0.13, 0.47, 0.55);
uniform vec3 cor_profunda : source_color = vec3(0.02, 0.11, 0.22);
uniform float escala_das_ondas = 0.018;
uniform float velocidade_das_ondas = 0.18;
uniform float intensidade_da_normal = 0.025;
uniform float rugosidade = 0.52;

varying vec3 posicao_no_mundo;

float onda(vec2 p, float t) {
	return sin(p.x + t) * 0.50
		+ sin(p.y * 1.3 + t * 1.17) * 0.35
		+ sin((p.x + p.y) * 0.6 - t * 0.83) * 0.15;
}

void vertex() {
	posicao_no_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = posicao_no_mundo.xz * escala_das_ondas;
	float t = TIME * velocidade_das_ondas;
	// Uma amostra mais larga produz ondulacao suave e evita que varias faixas
	// especulares atravessem pixels diferentes a cada passo da camera.
	float e = 0.75;
	float h = onda(p, t);
	float dx = onda(p + vec2(e, 0.0), t) - h;
	float dz = onda(p + vec2(0.0, e), t) - h;

	// Normal montada em espaco de mundo e levada para espaco de visao: nao
	// depende das tangentes da malha importada.
	vec3 n = normalize(vec3(-dx * intensidade_da_normal, 1.0, -dz * intensidade_da_normal));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	ALBEDO = mix(cor_profunda, cor_rasa,
		clamp(0.34 + fresnel * 0.22 + h * 0.008, 0.0, 1.0));
	ROUGHNESS = rugosidade;
	METALLIC = 0.0;
	SPECULAR = 0.08;
}
