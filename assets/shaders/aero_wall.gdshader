// Paredes y techo glossy blanco-azulados. Los huecos (tragaluz orgánico y ventanas
// ovaladas) se recortan con discard usando la posición local del vértice; la escena
// (room_shell.gd) pasa aquí los mismos parámetros que usa para generar los marcos.
shader_type spatial;
render_mode cull_back;

uniform vec3 wall_color : source_color = vec3(0.76, 0.90, 1.0);
uniform vec3 ceiling_color : source_color = vec3(0.90, 0.96, 1.0);
uniform float gradient_start = 0.0;
uniform float gradient_end = 4.4;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.2;
uniform float specular_value : hint_range(0.0, 1.0) = 0.6;
uniform float clearcoat_value : hint_range(0.0, 1.0) = 0.5;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.2;

// Tragaluz: elipse deformada por dos ondas en el plano XZ del techo
uniform bool skylight_enabled = true;
uniform vec2 skylight_center = vec2(0.6, -0.4);
uniform vec2 skylight_radius = vec2(2.3, 1.6);
uniform vec2 skylight_wave1 = vec2(0.18, 0.4);   // amplitud, fase (3 lóbulos)
uniform vec2 skylight_wave2 = vec2(0.08, 1.9);   // amplitud, fase (5 lóbulos)
uniform float skylight_min_height = 2.6;

// Ventanas ovaladas: axis 0 = pared en X, 2 = pared en Z
uniform bool window_a_enabled = true;
uniform int window_a_axis = 2;
uniform vec3 window_a_center = vec3(-2.0, 1.7, -5.0);
uniform vec2 window_a_radius = vec2(0.7, 1.0);
uniform bool window_b_enabled = true;
uniform int window_b_axis = 0;
uniform vec3 window_b_center = vec3(6.0, 1.7, 1.0);
uniform vec2 window_b_radius = vec2(0.75, 1.05);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

bool in_skylight(vec3 p) {
	if (p.y < skylight_min_height) {
		return false;
	}
	vec2 q = (p.xz - skylight_center) / skylight_radius;
	float ang = atan(q.y, q.x);
	float limit = 1.0 + skylight_wave1.x * sin(3.0 * ang + skylight_wave1.y)
			+ skylight_wave2.x * sin(5.0 * ang + skylight_wave2.y);
	return length(q) < limit;
}

bool in_window(vec3 p, int axis, vec3 center, vec2 radius) {
	vec2 q;
	if (axis == 0) {
		if (sign(p.x) != sign(center.x) || abs(p.x) < 0.4 * abs(center.x)) {
			return false;
		}
		q = vec2(p.z - center.z, p.y - center.y) / radius;
	} else {
		if (sign(p.z) != sign(center.z) || abs(p.z) < 0.4 * abs(center.z)) {
			return false;
		}
		q = vec2(p.x - center.x, p.y - center.y) / radius;
	}
	return length(q) < 1.0;
}

void fragment() {
	if (skylight_enabled && in_skylight(local_pos)) {
		discard;
	}
	if (window_a_enabled && in_window(local_pos, window_a_axis, window_a_center, window_a_radius)) {
		discard;
	}
	if (window_b_enabled && in_window(local_pos, window_b_axis, window_b_center, window_b_radius)) {
		discard;
	}

	float t = smoothstep(gradient_start, gradient_end, local_pos.y);
	ALBEDO = mix(wall_color, ceiling_color, t);
	METALLIC = 0.0;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	CLEARCOAT = clearcoat_value;
	CLEARCOAT_ROUGHNESS = 0.1;
	RIM = rim_strength;
	RIM_TINT = 0.5;
}
