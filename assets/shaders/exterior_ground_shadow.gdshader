shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Sombra suave de contacto bajo los árboles lejanos (que no proyectan sombra real): un
// óvalo oscuro con borde difuminado apoyado en el césped.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform vec3 shadow_color : source_color = vec3(0.05, 0.25, 0.03);
uniform float strength : hint_range(0.0, 1.0) = 0.45;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = shadow_color;
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * strength;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
