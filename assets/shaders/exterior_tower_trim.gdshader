shader_type spatial;
render_mode cull_back;
// Remates y bandas de los rascacielos: blanco-azulado glossy (coronas, cornisas, agujas).
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform vec3 trim_color : source_color = vec3(0.88, 0.94, 1.0);
uniform float trim_roughness : hint_range(0.0, 1.0) = 0.18;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = trim_color;
	METALLIC = 0.2;
	ROUGHNESS = trim_roughness;
	SPECULAR = 0.7;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
