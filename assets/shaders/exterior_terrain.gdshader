shader_type spatial;
render_mode cull_back;
// Césped del terreno exterior: verde lima saturado con manchas suaves, grano fino y, a
// media distancia, puntitos de flores (más baratos que las flores de verdad).
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform vec3 grass_light : source_color = vec3(0.62, 0.96, 0.14);
uniform vec3 grass_dark : source_color = vec3(0.24, 0.72, 0.1);
uniform float patch_scale = 0.035;
uniform float speckle_density = 0.03;          // fracción de celdas con flor
uniform float speckle_fade_distance = 220.0;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = ext_fbm(p * patch_scale);
	vec3 col = mix(grass_dark, grass_light, smoothstep(0.28, 0.72, n));
	col *= 0.9 + 0.14 * ext_noise(p * 2.7);
	// Puntitos de flores en zonas de prado, desvaneciéndose con la distancia
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	vec2 cell = floor(p * 1.6);
	float h = ext_hash(cell);
	float field = smoothstep(0.45, 0.6, ext_fbm(p * 0.02 + 3.0));
	if (h < speckle_density * field) {
		vec2 f = fract(p * 1.6) - 0.5;
		float dot_mask = smoothstep(0.22, 0.12, length(f));
		float kind = ext_hash(cell + 7.0);
		vec3 petal = kind < 0.5 ? vec3(1.0) : (kind < 0.75 ? vec3(1.0, 0.45, 0.7) : vec3(1.0, 0.85, 0.15));
		col = mix(col, petal, dot_mask * (1.0 - smoothstep(20.0, speckle_fade_distance, dist)));
	}
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
