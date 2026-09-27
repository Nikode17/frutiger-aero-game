shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
// Telón de fondo de la escena 3D del acuario: degradado de agua, rayos de luz que bajan,
// silueta difusa de ciudad al fondo y arena con cáusticas abajo. Va en un plano lejano
// detrás de peces y medusas; no le afecta la niebla (ya es el color del agua lejana).

uniform vec3 top_color : source_color = vec3(0.42, 0.86, 1.0);
uniform vec3 deep_color : source_color = vec3(0.04, 0.3, 0.66);
uniform vec3 city_color : source_color = vec3(0.45, 0.72, 0.95);
uniform vec3 sand_color : source_color = vec3(0.78, 0.86, 0.72);
uniform float aspect = 2.44;          // ancho / alto del viewport
uniform float ray_strength = 0.22;
uniform float city_strength = 0.45;
uniform float sand_height = 0.1;      // fracción de la altura ocupada por la arena

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

// Una fila de edificios: dos por celda, con ancho, altura y posición pseudoaleatorios y
// bordes difusos. Devuelve la máscara (0..1) de la silueta.
float city_row(vec2 uv, float scale, float seed, float h_min, float h_max, float blur, float baseline) {
	float x = uv.x * aspect * scale + seed;
	float cell = floor(x);
	float f = fract(x);
	float blur_x = blur * aspect * scale;
	float mask = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int b = 0; b < 2; b++) {
			float id = (cell + float(k)) * 2.0 + float(b) + seed * 13.0;
			float center = float(k) + 0.25 + 0.5 * float(b) + (hash11(id * 3.1) - 0.5) * 0.3;
			float w = mix(0.2, 0.5, hash11(id * 5.7));
			float h = mix(h_min, h_max, pow(hash11(id * 9.3), 1.4));
			if (hash11(id * 2.3) > 0.86) {
				h *= 1.55;   // alguna torre
				w *= 0.6;
			}
			float dx = abs(f - center) - w * 0.5;
			float mx = 1.0 - smoothstep(-blur_x, blur_x, dx);
			float my = smoothstep(baseline - h - blur, baseline - h + blur, uv.y);
			mask = max(mask, mx * my);
		}
	}
	return mask;
}

void fragment() {
	vec2 uv = UV;                     // y = 0 arriba
	vec3 col = mix(top_color, deep_color, smoothstep(0.0, 1.0, uv.y));

	// Silueta de ciudad difusa: una fila lejana más alta y brumosa y otra más cercana
	float baseline = 1.0 - sand_height + 0.01;
	float far_city = city_row(uv, 4.2, 1.7, 0.16, 0.38, 0.012, baseline);
	float near_city = city_row(uv, 2.6, 7.3, 0.08, 0.24, 0.008, baseline);
	col = mix(col, mix(city_color, top_color, 0.35), far_city * city_strength * 0.7);
	col = mix(col, city_color * 0.92, near_city * city_strength);

	// Rayos de luz inclinados desde la superficie
	float rays = pow(0.5 + 0.5 * sin((uv.x * aspect + uv.y * 0.6) * 5.0 + TIME * 0.25), 6.0);
	rays += pow(0.5 + 0.5 * sin((uv.x * aspect + uv.y * 0.45) * 8.3 - TIME * 0.17 + 1.3), 8.0) * 0.7;
	col += vec3(0.75, 0.95, 1.0) * rays * ray_strength * (1.0 - smoothstep(0.0, 0.85, uv.y));

	// Arena con cáusticas
	float sand = smoothstep(1.0 - sand_height - 0.02, 1.0 - sand_height + 0.02, uv.y);
	vec2 cp = vec2(uv.x * aspect, uv.y) * 14.0;
	float c = sin(cp.x + sin(cp.y * 1.7 + TIME) * 1.4) * sin(cp.y * 2.1 + sin(cp.x * 0.8 - TIME * 0.7));
	vec3 sand_col = sand_color * (0.85 + 0.25 * pow(abs(c), 2.0));
	col = mix(col, mix(sand_col, deep_color, 0.25), sand);

	ALBEDO = col;
}
