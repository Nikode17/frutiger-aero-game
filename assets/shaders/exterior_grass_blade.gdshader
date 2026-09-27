shader_type spatial;
render_mode cull_disabled;
// Briznas de hierba (MultiMesh) cerca de las ventanas: degradado de la base a la punta,
// color por instancia y vaivén con el viento. UV.y = altura relativa de la brizna.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.07, 0.4, 0.01);
uniform vec3 tip_color : source_color = vec3(0.4, 0.78, 0.04);
uniform float wind_strength = 0.07;
uniform float wind_speed = 1.6;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.06;
uniform float backlight_amount : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = ext_wind(wp, wind_speed);
	VERTEX.x += w * wind_strength * UV.y * UV.y;
	VERTEX.z += w * wind_strength * 0.4 * UV.y * UV.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, UV.y) * COLOR.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = specular_amount;
	BACKLIGHT = tip_color * backlight_amount;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
