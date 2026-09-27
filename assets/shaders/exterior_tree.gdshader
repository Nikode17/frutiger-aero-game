shader_type spatial;
render_mode cull_back;
// Árboles del exterior: color de vértice (pintado en sRGB), hojas glossy con un grano de
// hojitas, algo de luz que atraviesa la copa y vaivén suave con el viento. La corteza usa
// el mismo shader con is_leaf = false.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform bool is_leaf = true;
uniform float wind_strength = 0.08;    // m en la copa
uniform float wind_start = 2.5;        // altura a partir de la que se mueve (m)

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = max(VERTEX.y - wind_start, 0.0) / 6.0;
	float w = ext_wind(wp * 0.3, 0.9);
	VERTEX.x += w * wind_strength * k;
	VERTEX.z += w * wind_strength * 0.5 * k;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	if (is_leaf) {
		float leaves = ext_noise(world_pos.xy * 7.0 + world_pos.zz * 5.0);
		ALBEDO = base * (0.85 + 0.3 * leaves);
		ROUGHNESS = 0.4;
		SPECULAR = 0.55;
		BACKLIGHT = base * 0.5;
	} else {
		ALBEDO = base * (0.85 + 0.2 * ext_noise(world_pos.xy * 12.0));
		ROUGHNESS = 0.85;
		SPECULAR = 0.2;
	}
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
