shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// Aletas de pez: finas y semitranslúcidas, con radios que salen de la base (UV.x a lo
// largo de la base, UV.y hacia el borde) y algo de luz que las atraviesa.
#include "res://assets/shaders/fish_swim.gdshaderinc"

uniform float fin_alpha = 0.55;
uniform float ray_count = 16.0;

void vertex() {
	obj_pos = VERTEX;
	VERTEX += swim_offset(VERTEX);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = vertex_albedo(COLOR.rgb);
	float rays = 0.5 + 0.5 * cos(UV.x * 3.14159 * ray_count);
	ALBEDO = base * (0.8 + 0.2 * rays);
	ALPHA = fin_alpha * (0.55 + 0.45 * rays) * (1.0 - 0.35 * smoothstep(0.75, 1.0, UV.y));
	ROUGHNESS = 0.3;
	SPECULAR = 0.5;
	BACKLIGHT = base * 0.6;
	EMISSION = base * caustics(world_pos) * caustic_strength * 0.5;
}
