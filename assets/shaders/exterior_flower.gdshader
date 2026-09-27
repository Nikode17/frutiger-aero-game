shader_type spatial;
render_mode cull_disabled;
// Flores (MultiMesh): color de vértice, pétalos algo translúcidos y vaivén con el viento
// que crece con la altura. UV.y = altura relativa dentro de la flor.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform float wind_strength = 0.06;
uniform float wind_speed = 1.4;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = ext_wind(wp, wind_speed);
	VERTEX.x += w * wind_strength * UV.y * UV.y;
	VERTEX.z += w * wind_strength * 0.5 * UV.y * UV.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.6;
	SPECULAR = 0.15;
	BACKLIGHT = COLOR.rgb * 0.45;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
