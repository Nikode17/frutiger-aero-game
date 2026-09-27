shader_type spatial;
render_mode unshaded, cull_back;
// Pantalla encendida procedural: agua con degradado, rayos de luz, cáusticas y burbujas
// que suben. Cada pantalla usa su posición en el mundo como semilla para no ser idénticas.

uniform vec3 deep_color : source_color = vec3(0.03, 0.28, 0.62);
uniform vec3 top_color : source_color = vec3(0.45, 0.9, 1.0);
uniform vec3 bubble_color : source_color = vec3(0.85, 0.97, 1.0);
uniform float brightness = 1.0;
uniform float bubble_speed = 0.05;
uniform float ray_strength = 0.18;
uniform float caustic_strength = 0.22;
uniform float scanline_strength = 0.05;
uniform float vignette_strength = 0.9;
uniform float aspect = 1.33;   // ancho / alto de la pantalla

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Una capa de burbujas: la pantalla se divide en celdas que suben y algunas contienen una burbuja.
float bubble_layer(vec2 uv, float scale, float speed, float seed) {
	vec2 p = vec2(uv.x * aspect, uv.y) * scale;
	p.y -= TIME * speed * scale;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash21(cell + seed);
	if (h < 0.5) {
		return 0.0;
	}
	vec2 off = (vec2(hash21(cell + 7.1 + seed), hash21(cell + 3.7 + seed)) - 0.5) * 0.4;
	off.x += sin(TIME * 1.3 + h * 25.0) * 0.07;
	float r = mix(0.1, 0.28, fract(h * 13.7));
	float d = length(f - off);
	float body = smoothstep(r, r - 0.03, d);
	float rim = smoothstep(r - 0.08, r - 0.01, d) * body;
	float spec = smoothstep(r * 0.4, 0.0, length(f - off - vec2(-r * 0.4, r * 0.4)));
	return body * 0.12 + rim * 0.55 + spec * 0.9;
}

void fragment() {
	// UV con la y hacia arriba
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float seed = dot(NODE_POSITION_WORLD, vec3(1.37, 0.0, 2.71));

	vec3 col = mix(deep_color, top_color, smoothstep(0.0, 1.0, uv.y));

	// Rayos de luz inclinados que bajan desde la superficie
	float rays = 0.0;
	rays += sin((uv.x + uv.y * 0.35) * 18.0 + TIME * 0.35 + seed) * 0.5 + 0.5;
	rays *= sin((uv.x - uv.y * 0.2) * 7.0 - TIME * 0.2 + seed * 0.5) * 0.5 + 0.5;
	col += top_color * rays * ray_strength * smoothstep(0.1, 1.0, uv.y);

	// Cáusticas cerca de la superficie
	vec2 cp = vec2(uv.x * aspect, uv.y) * 9.0;
	float c = sin(cp.x + sin(cp.y * 1.3 + TIME * 0.8) * 1.2 + TIME * 0.5);
	c *= sin(cp.y * 1.1 + sin(cp.x * 0.9 - TIME * 0.6) * 1.2 - TIME * 0.4);
	col += vec3(0.8, 1.0, 1.0) * pow(abs(c), 3.0) * caustic_strength * smoothstep(0.55, 1.0, uv.y);

	// Tres capas de burbujas con distinto tamaño y velocidad
	float b = bubble_layer(uv, 5.0, bubble_speed * 1.6, seed);
	b += bubble_layer(uv, 9.0, bubble_speed * 1.1, seed + 17.0) * 0.8;
	b += bubble_layer(uv, 16.0, bubble_speed * 0.8, seed + 31.0) * 0.5;
	col = mix(col, bubble_color, clamp(b, 0.0, 1.0));

	// Aspecto de CRT: líneas de barrido suaves y viñeta
	col *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(UV.y * 700.0));
	vec2 v = UV - 0.5;
	col *= 1.0 - vignette_strength * dot(v, v);

	ALBEDO = col * brightness;
}
