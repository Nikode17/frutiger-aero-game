// Pase final sobre la imagen (después del tonemap): enfoque suave para recuperar la
// nitidez que quita el TAA y viñeta ligera como en las fotos de los 2000, que
// oscurece un poco las esquinas con un tono azul marino, no negro.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float sharpen : hint_range(0.0, 1.5) = 0.0;      // 0 = sin enfoque
uniform float strength : hint_range(0.0, 1.0) = 0.25;
uniform float radius : hint_range(0.2, 1.5) = 0.85;      // donde empieza a oscurecer
uniform float softness : hint_range(0.05, 1.5) = 0.7;    // anchura del degradado
uniform vec3 tint : source_color = vec3(0.02, 0.1, 0.22);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (sharpen > 0.0) {
		// Enfoque en cruz con el contraste local limitado para no crear halos
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 n = textureLod(screen_tex, SCREEN_UV + vec2(0.0, -px.y), 0.0).rgb;
		vec3 s = textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), 0.0).rgb;
		vec3 e = textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), 0.0).rgb;
		vec3 w = textureLod(screen_tex, SCREEN_UV + vec2(-px.x, 0.0), 0.0).rgb;
		vec3 lo = min(c, min(min(n, s), min(e, w)));
		vec3 hi = max(c, max(max(n, s), max(e, w)));
		// Sin enfoque en luces y brillos, que si no se ven dentados
		float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
		float amount = sharpen * (1.0 - smoothstep(0.7, 0.95, lum));
		vec3 sharp = c + (c * 4.0 - n - s - e - w) * 0.25 * amount;
		c = clamp(sharp, lo, hi);
	}
	// Elipse que sigue la forma de la pantalla (0 en el centro, ~1.41 en las esquinas)
	vec2 p = (UV - 0.5) * 2.0;
	float v = smoothstep(radius - softness * 0.5, radius + softness * 0.5, length(p)) * strength;
	COLOR = vec4(mix(c, tint, v), 1.0);
}
