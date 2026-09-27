shader_type spatial;
render_mode cull_back;
// Rascacielos de cristal azul muy reflectante. El reflejo del cielo se calcula aquí con el
// mismo degradado y la misma función de nubes que aero_sky.gdshader (mismos parámetros y
// deriva), así las nubes reflejadas coinciden con las del cielo; se pondera con Fresnel
// sobre un cuerpo de cristal azul oscuro. Los montantes son líneas finas antialiasadas
// (UV.x = metros a lo largo de la fachada, UV.y = metros de altura) que se desvanecen
// cuando son más finas que un píxel, y cada panel está levemente inclinado para que el
// reflejo no sea un espejo perfecto. El color de vértice varía el tinte de cada torre.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform vec3 glass_tint : source_color = vec3(0.45, 0.66, 1.0);   // tinte del reflejo
uniform vec3 body_color : source_color = vec3(0.03, 0.1, 0.3);  // cristal visto de frente
uniform float reflectance : hint_range(0.0, 1.0) = 0.3;          // reflejo de frente (Fresnel F0)
uniform float reflection_strength = 1.25;
// Las fachadas se recuestan un poco al calcular el reflejo: a ras de suelo una pared
// vertical solo reflejaría la franja pálida del horizonte, así recoge cielo azul y nubes
uniform float reflection_lean : hint_range(0.0, 0.5) = 0.1;
uniform float panel_tilt = 0.035;         // desorientación de cada panel
uniform float mullion_spacing = 1.5;      // m entre montantes finos
uniform float fin_spacing = 7.5;          // m entre montantes principales
uniform float floor_spacing = 4.0;        // m entre forjados
uniform float mullion_width = 0.07;       // m
uniform float mullion_strength : hint_range(0.0, 1.0) = 0.5;
uniform float floor_strength : hint_range(0.0, 1.0) = 0.2;
uniform vec3 mullion_color : source_color = vec3(0.75, 0.86, 0.98);

// Cielo reflejado (copiar de aero_sky.gdshader si allí cambian los valores)
uniform vec3 sky_top : source_color = vec3(0.06, 0.32, 0.9);
uniform vec3 sky_horizon : source_color = vec3(0.62, 0.85, 1.0);
uniform vec3 ground_reflection : source_color = vec3(0.25, 0.55, 0.2);
uniform float sky_horizon_sharpness = 0.55;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade_color : source_color = vec3(0.68, 0.82, 0.97);
uniform float cloud_coverage = 0.5;
uniform float cloud_softness = 0.1;
uniform float cloud_scale = 0.75;
uniform float cloud_speed = 0.012;

// Ruido de valor idéntico al del cielo (hash entero PCG)
float sky_hash(ivec2 cell) {
	uvec2 v = uvec2(cell + ivec2(65536));
	uint n = v.x * 1664525u + v.y * 1013904223u;
	n = n * 747796405u + 2891336453u;
	n = ((n >> ((n >> 28u) + 4u)) ^ n) * 277803737u;
	n = (n >> 22u) ^ n;
	return float(n) / 4294967295.0;
}

float sky_value_noise(vec2 p) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = sky_hash(i);
	float b = sky_hash(i + ivec2(1, 0));
	float c = sky_hash(i + ivec2(0, 1));
	float d = sky_hash(i + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float sky_fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * sky_value_noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return v;
}

vec3 reflected_sky(vec3 r) {
	float h = r.y;
	vec3 col = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), sky_horizon_sharpness));
	if (h < 0.0) {
		return mix(sky_horizon, ground_reflection, clamp(-h * 5.0, 0.0, 1.0));
	}
	vec2 uv = r.xz / (h + 0.12) * cloud_scale;
	uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
	float n = sky_fbm(uv);
	float density = smoothstep(cloud_coverage, cloud_coverage + cloud_softness, n) * smoothstep(0.0, 0.16, h);
	float shade = smoothstep(cloud_coverage, cloud_coverage + cloud_softness * 2.5, n);
	return mix(col, mix(cloud_shade_color, cloud_color, shade), density);
}

// Línea antialiasada cada `spacing` metros; se apaga cuando las líneas se juntan en pantalla
float grid_line(float coord, float spacing, float width) {
	float fw = max(fwidth(coord), 1e-4);
	float d = abs(fract(coord / spacing + 0.5) - 0.5) * spacing;
	float w = max(width, fw);
	float l = 1.0 - smoothstep(w * 0.5, w * 0.5 + fw, d);
	float fade = 1.0 - smoothstep(spacing * 0.12, spacing * 0.35, fw);
	return l * fade * (width / w);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float mull = max(grid_line(UV.x, mullion_spacing, mullion_width), grid_line(UV.x, fin_spacing, mullion_width * 2.2));
	float flr = grid_line(UV.y, floor_spacing, mullion_width * 1.6) * floor_strength;
	float frame = clamp(max(mull, flr), 0.0, 1.0) * mullion_strength;
	// Normal del panel: inclinación aleatoria y recostada hacia atrás para el reflejo
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 side = normalize(cross(wn, vec3(0.0, 1.0, 0.0)) + vec3(1e-5));
	vec3 upv = cross(side, wn);
	vec2 cell = floor(vec2(UV.x / mullion_spacing, UV.y / floor_spacing));
	vec2 tilt = vec2(sky_hash(ivec2(cell)), sky_hash(ivec2(cell) + ivec2(71, 13))) - 0.5;
	// Sin inclinación cuando los paneles ocupan menos de un píxel (evita parpadeo)
	float tilt_fade = 1.0 - smoothstep(mullion_spacing * 0.5, mullion_spacing * 1.5, fwidth(UV.x));
	vec3 rn = normalize(wn + (side * tilt.x + upv * tilt.y) * panel_tilt * 2.0 * tilt_fade + vec3(0.0, reflection_lean, 0.0));
	vec3 v = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 r = reflect(v, rn);
	float cos_t = clamp(dot(-v, rn), 0.0, 1.0);
	float fres = reflectance + (1.0 - reflectance) * pow(1.0 - cos_t, 5.0);
	vec3 refl = reflected_sky(r) * glass_tint * COLOR.rgb * fres * reflection_strength;
	ALBEDO = mix(body_color * COLOR.rgb, mullion_color, frame);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.2, 0.4, frame);
	SPECULAR = 0.3;
	EMISSION = refl * (1.0 - frame);
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
