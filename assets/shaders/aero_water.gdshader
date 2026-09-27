// Agua azul-cian de la columna: refracta el fondo (textura de pantalla) con
// ondulaciones lentas, lo tiñe de cian y añade un poco de luz propia. Es "unshaded"
// para no iluminar dos veces el fondo ya iluminado; los brillos los pone el cristal.
// La refracción va aquí y no en el cristal para no borrar las burbujas.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 water_color : source_color = vec3(0.22, 0.72, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.5;
uniform float fresnel_tint : hint_range(0.0, 1.0) = 0.35;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.3;
uniform float refraction_strength : hint_range(0.0, 0.2) = 0.05;
uniform float wave_speed = 0.25;
uniform float wave_scale = 1.6;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.35;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

void fragment() {
	vec3 p = local_pos * wave_scale - vec3(0.0, TIME * wave_speed, 0.0);
	float n = vnoise3(p * 2.0) * 0.6 + vnoise3(p * 4.3 + 7.1) * 0.4;
	float n2 = vnoise3(p * 3.1 + vec3(11.0, 0.0, 5.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

	// Fondo refractado: desplazamiento por la curvatura (normal en vista) y por las ondas
	vec2 offset = NORMAL.xy * refraction_strength + (vec2(n, n2) - 0.5) * refraction_strength * 0.8;
	vec3 bg = texture(screen_texture, SCREEN_UV - offset).rgb;

	vec3 col = water_color * (0.85 + wave_strength * (n - 0.5));
	float t = clamp(tint_amount + fres * fresnel_tint, 0.0, 1.0);
	ALBEDO = mix(bg, col, t) + col * emission_strength * (0.6 + 0.8 * n);
	ALPHA = 1.0;
}
