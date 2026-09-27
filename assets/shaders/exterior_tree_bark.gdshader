shader_type spatial;
render_mode cull_back;
// Corteza del tronco y las ramas del árbol del exterior: textura de color y normal, algo
// oscurecida, con el mismo viento que las hojas para que se muevan juntas.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform vec3 bark_tint = vec3(0.7, 0.66, 0.62);      // multiplica el color (tronco oscuro)
uniform float normal_strength = 1.0;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.85;

void vertex() {
	VERTEX += tree_wind(VERTEX, MODEL_MATRIX[3].xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * bark_tint;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = roughness_amount;
	SPECULAR = 0.25;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
