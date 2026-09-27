shader_type spatial;
render_mode cull_back;
// Cuerpo de pez: color de vértice, escamas procedurales, iridiscencia sutil por fresnel
// y cáusticas que caen desde arriba.
#include "res://assets/shaders/fish_swim.gdshaderinc"

uniform float scale_size = 0.006;            // tamaño de escama (m)
uniform float scale_contrast = 0.14;
uniform float iridescence = 0.35;

void vertex() {
	obj_pos = VERTEX;
	VERTEX += swim_offset(VERTEX);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = vertex_albedo(COLOR.rgb);
	// Escamas: celdas en filas desplazadas a lo largo del flanco
	vec2 sp = vec2(obj_pos.z, obj_pos.y) / scale_size;
	sp.y += mod(floor(sp.x), 2.0) * 0.5;
	vec2 f = fract(sp) - 0.5;
	float edge = smoothstep(0.32, 0.5, length(f * vec2(1.0, 1.25)));
	ALBEDO = base * (1.0 - edge * scale_contrast);
	ROUGHNESS = mix(0.25, 0.45, edge);
	SPECULAR = 0.6;
	CLEARCOAT = 0.4;
	CLEARCOAT_ROUGHNESS = 0.2;
	// Iridiscencia en los bordes y cáusticas en las caras que miran arriba
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 iri = 0.5 + 0.5 * cos(6.2831 * (fres * 1.2 + obj_pos.z * 5.0 + vec3(0.0, 0.33, 0.67)));
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float up = clamp(world_normal.y, 0.0, 1.0);
	EMISSION = iri * fres * iridescence * 0.25 + base * caustics(world_pos) * caustic_strength * up;
}
