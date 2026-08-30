shader_type spatial;
render_mode diffuse_burley, specular_disabled;

varying vec3 posicao_mundo;


void vertex() {
	posicao_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	// Manchas amplas em coordenadas globais atravessam as emendas dos modulos.
	float onda_a = sin(posicao_mundo.x * 0.012 + posicao_mundo.z * 0.006);
	float onda_b = sin(posicao_mundo.z * 0.015 - posicao_mundo.x * 0.004);
	float variacao = clamp(onda_a * 0.28 + onda_b * 0.22 + 0.5, 0.0, 1.0);

	vec3 grama_escura = vec3(0.19, 0.43, 0.20);
	vec3 grama_clara = vec3(0.36, 0.64, 0.31);
	vec3 terreno = mix(grama_escura, grama_clara, variacao);

	// A rocha aparece aos poucos com a altitude, sem trocar de material de uma
	// celula para outra. Dois limiares evitam uma linha horizontal muito nítida.
	float rocha_baixa = smoothstep(7.0, 19.0, posicao_mundo.y);
	float rocha_alta = smoothstep(22.0, 42.0, posicao_mundo.y);
	vec3 rocha = mix(vec3(0.34, 0.38, 0.40), vec3(0.49, 0.53, 0.55), variacao);
	ALBEDO = mix(terreno, rocha, clamp(rocha_baixa * 0.72 + rocha_alta * 0.28, 0.0, 1.0));
	ROUGHNESS = 0.96;
}
