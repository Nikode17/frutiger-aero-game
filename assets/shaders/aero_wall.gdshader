// Paredes y techo glossy blanco-azulados. Los huecos (tragaluz orgánico y ventanas
// ovaladas) se recortan con discard usando la posición local del vértice; la escena
// (room_shell.gd) pasa aquí los mismos parámetros que usa para generar los marcos.
shader_type spatial;
render_mode cull_back;

uniform vec3 wall_color : source_color = vec3(0.62, 0.82, 1.0);
uniform vec3 ceiling_color : source_color = vec3(0.76, 0.89, 1.0);
uniform float gradient_start = 0.0;
uniform float gradient_end = 4.8;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.09;
uniform float specular_value : hint_range(0.0, 1.0) = 0.85;
uniform float clearcoat_value : hint_range(0.0, 1.0) = 0.7;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.2;

// Tragaluz: elipse deformada por dos ondas en el plano XZ del techo
uniform bool skylight_enabled = true;
uniform vec2 skylight_center = vec2(0.0, 0.3);
uniform vec2 skylight_radius = vec2(3.2, 2.2);
uniform vec2 skylight_wave1 = vec2(0.18, 0.4);   // amplitud, fase (3 lóbulos)
uniform vec2 skylight_wave2 = vec2(0.08, 1.9);   // amplitud, fase (5 lóbulos)
uniform float skylight_min_height = 2.8;

// Ventanas ovaladas (hasta 4): pos = (ángulo rad, altura centro, radio de pared, activa)
// y size = (semieje horizontal, semieje vertical)
const int MAX_WINDOWS = 4;
uniform vec4 window_pos[4];
uniform vec2 window_size[4];

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

bool in_window(vec3 p, vec4 pos, vec2 size) {
	if (pos.w < 0.5 || size.x <= 0.0 || size.y <= 0.0) {
		return false;
	}
	float ang = atan(p.z, p.x);
	float d = ang - pos.x;
	d = atan(sin(d), cos(d));   // diferencia angular envuelta a [-PI, PI]
	vec2 q = vec2(d * pos.z / size.x, (p.y - pos.y) / size.y);
	return length(q) < 1.0;
}

void fragment() {
	if (skylight_enabled && in_skylight(local_pos)) {
		discard;
	}
	for (int i = 0; i < MAX_WINDOWS; i++) {
		if (in_window(local_pos, window_pos[i], window_size[i])) {
			discard;
		}
	}

	float t = smoothstep(gradient_start, gradient_end, local_pos.y);
	ALBEDO = mix(wall_color, ceiling_color, t);
	METALLIC = 0.0;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	CLEARCOAT = clearcoat_value;
	CLEARCOAT_ROUGHNESS = 0.05;
	RIM = rim_strength;
	RIM_TINT = 0.5;
}
