shader_type spatial;
render_mode cull_back;
// Fondo de arena del acuario con pequeñas ondulaciones y cáusticas que se mueven.

uniform vec3 sand_color : source_color = vec3(0.6, 0.68, 0.6);
uniform float caustic_strength = 0.3;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = world_pos.xz * 9.0;
	float c = sin(q.x + sin(q.y * 1.3 + TIME * 0.9) * 1.3 + TIME * 0.5);
	c *= sin(q.y * 1.1 + sin(q.x * 0.8 - TIME * 0.7) * 1.3 - TIME * 0.4);
	float ripples = 0.5 + 0.5 * sin(world_pos.x * 40.0 + sin(world_pos.z * 12.0) * 2.0);
	ALBEDO = sand_color * (0.9 + 0.1 * ripples);
	ROUGHNESS = 0.9;
	EMISSION = sand_color * pow(abs(c), 3.0) * caustic_strength;
}
