shader_type spatial;
render_mode diffuse_burley, specular_disabled;

varying vec3 posicao_mundo;


void vertex() {
	posicao_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	// Repete exatamente a variacao usada pelo terreno modular. Assim a base
	// procedural e os modulos deixam de formar retangulos de cores diferentes.
	float onda_a = sin(posicao_mundo.x * 0.012 + posicao_mundo.z * 0.006);
	float onda_b = sin(posicao_mundo.z * 0.015 - posicao_mundo.x * 0.004);
	float variacao = clamp(onda_a * 0.28 + onda_b * 0.22 + 0.5, 0.0, 1.0);

	vec3 grama_escura = vec3(0.19, 0.43, 0.20);
	vec3 grama_clara = vec3(0.36, 0.64, 0.31);
	vec3 terreno = mix(grama_escura, grama_clara, variacao);

	vec3 areia_escura = vec3(0.48, 0.42, 0.25);
	vec3 areia_clara = vec3(0.66, 0.59, 0.38);
	vec3 areia = mix(areia_escura, areia_clara, variacao);

	// O alpha da cor dos vertices vai de zero no interior a um na beirada.
	ALBEDO = mix(terreno, areia, smoothstep(0.0, 1.0, COLOR.a));
	ROUGHNESS = 0.96;
}
