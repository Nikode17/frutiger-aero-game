shader_type spatial;
render_mode cull_disabled;
// Mariposa genérica: las alas (|x| > 0) giran alrededor del eje del cuerpo (Z) para
// aletear. Color de ala por instancia; el patrón viene del color de vértice
// (blanco = color del ala, oscuro = dibujo).
#include "res://assets/shaders/exterior_common.gdshaderinc"

instance uniform float flap_phase = 0.0;
instance uniform vec3 wing_color : source_color = vec3(0.3, 0.7, 1.0);
uniform float flap_speed = 14.0;
uniform float flap_angle = 1.1;         // rad

void vertex() {
	float s = sign(VERTEX.x);
	float a = (0.5 + 0.5 * sin(TIME * flap_speed + flap_phase)) * flap_angle * s;
	if (abs(VERTEX.x) > 0.0005) {
		float x = VERTEX.x;
		float y = VERTEX.y;
		VERTEX.x = x * cos(a) - y * sin(a);
		VERTEX.y = x * sin(a) + y * cos(a);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = mix(vec3(0.05, 0.05, 0.08), wing_color, COLOR.r);
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
	BACKLIGHT = wing_color * 0.5 * COLOR.r;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
