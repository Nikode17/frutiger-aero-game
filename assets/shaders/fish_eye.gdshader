shader_type spatial;
render_mode cull_back;
// Ojo de pez: pupila e iris del color de vértice, muy brillante.
#include "res://assets/shaders/fish_swim.gdshaderinc"

void vertex() {
	obj_pos = VERTEX;
	VERTEX += swim_offset(VERTEX);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = vertex_albedo(COLOR.rgb);
	ROUGHNESS = 0.03;
	SPECULAR = 1.0;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
