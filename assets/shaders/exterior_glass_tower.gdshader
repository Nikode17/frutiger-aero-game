shader_type spatial;
render_mode cull_disabled;
// Rascacielos de cristal azul reflectante: el reflejo del cielo se simula con el vector de
// reflexión (a esa distancia no llegan sondas ni SSR), con retícula de montantes y forjados
// a partir de las UV (x = metros a lo largo de la fachada, y = metros de altura).
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform vec3 glass_color : source_color = vec3(0.08, 0.3, 0.7);
uniform vec3 sky_top : source_color = vec3(0.1, 0.38, 0.92);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.88, 1.0);
uniform vec3 frame_color : source_color = vec3(0.75, 0.88, 1.0);
uniform float panel_width = 3.0;       // m entre montantes
uniform float floor_height = 3.8;      // m entre forjados
uniform float reflection_strength = 0.9;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 r = reflect(-v, n);
	float up = clamp(r.y, 0.0, 1.0);
	vec3 refl = mix(sky_horizon, sky_top, pow(up, 0.55));
	// Nubes difusas en el reflejo
	float cl = smoothstep(0.55, 0.8, ext_noise(r.xz / (abs(r.y) + 0.2) * 2.0 + world_pos.xz * 0.002));
	refl = mix(refl, vec3(1.0), cl * 0.5 * step(0.0, r.y));
	float fres = 0.25 + 0.75 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	// Retícula: montantes verticales y bandas de forjado
	vec2 g = UV / vec2(panel_width, floor_height);
	float mull = step(fract(g.x), 0.06) + step(fract(g.y), 0.1);
	float tint = 0.9 + 0.2 * ext_hash(floor(g));   // paneles con leve variación
	vec3 glass = glass_color * tint;
	ALBEDO = mix(glass, frame_color * 0.5, clamp(mull, 0.0, 1.0));
	METALLIC = 0.6;
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
	EMISSION = refl * fres * reflection_strength * (1.0 - clamp(mull, 0.0, 1.0) * 0.6);
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
