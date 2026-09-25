// Cielo procedural Frutiger Aero: degradado azul saturado, sol suave y nubes
// esponjosas con ruido fBm (sin texturas). Menos octavas en el paso de cubemap.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.16, 0.46, 0.94);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.88, 1.0);
uniform vec3 ground_color : source_color = vec3(0.62, 0.84, 0.94);
uniform float horizon_sharpness : hint_range(0.1, 3.0) = 0.65;

uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade_color : source_color = vec3(0.74, 0.86, 0.98);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_softness : hint_range(0.01, 0.6) = 0.2;
uniform float cloud_scale = 1.4;
uniform float cloud_speed = 0.012;

uniform float sun_size : hint_range(0.0, 0.2) = 0.015;
uniform float sun_glow : hint_range(0.0, 3.0) = 0.5;

// Hash entero (PCG): exacto en cualquier precisión, sin artefactos por celda.
float hash_cell(ivec2 cell) {
	uvec2 v = uvec2(cell + ivec2(65536));
	uint n = v.x * 1664525u + v.y * 1013904223u;
	n = n * 747796405u + 2891336453u;
	n = ((n >> ((n >> 28u) + 4u)) ^ n) * 277803737u;
	n = (n >> 22u) ^ n;
	return float(n) / 4294967295.0;
}

float value_noise(vec2 p) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash_cell(i);
	float b = hash_cell(i + ivec2(1, 0));
	float c = hash_cell(i + ivec2(0, 1));
	float d = hash_cell(i + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, bool cheap) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		if (cheap && i >= 3) {
			break;
		}
		v += amp * value_noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;

	float t = pow(clamp(h, 0.0, 1.0), horizon_sharpness);
	vec3 col = mix(horizon_color, top_color, t);
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}

	// Sol: disco suave y halo
	if (LIGHT0_ENABLED) {
		float sd = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		float disc = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.4, sd);
		float glow = pow(sd, 48.0) * sun_glow;
		col += LIGHT0_COLOR * LIGHT0_ENERGY * (disc * 2.0 + glow * 0.5);
	}

	// Nubes proyectadas sobre un plano alto
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * cloud_scale;
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		float n = fbm(uv, AT_CUBEMAP_PASS);
		float density = smoothstep(cloud_coverage, cloud_coverage + cloud_softness, n);
		density *= smoothstep(0.0, 0.16, h);
		float shade = smoothstep(cloud_coverage, cloud_coverage + cloud_softness * 2.5, n);
		vec3 cloud = mix(cloud_shade_color, cloud_color, shade);
		col = mix(col, cloud, density);
	}

	COLOR = col;
}
