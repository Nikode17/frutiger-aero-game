// Destello de estrella y lens flare del sol, estilo foto de mediados de los 2000.
// Quad a pantalla completa en el pase transparente: se dibuja antes del glow y del
// tonemap, así que los valores HDR del destello reciben bloom como un brillo más.
// La oclusión se mide en el buffer de profundidad alrededor del sol (profundidad 0 =
// cielo con Z invertida), así que solo aparece cuando el sol se ve de verdad.
// La posición del sol en pantalla y el desvanecimiento los pone CameraFx.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled,
		fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

uniform vec2 sun_uv = vec2(0.5);          // posición del sol en pantalla (0-1)
uniform float sun_fade = 0.0;             // 0 = sol fuera de vista, 1 = de frente
uniform float aspect = 1.7778;            // ancho / alto de la pantalla
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.88);
uniform float intensity : hint_range(0.0, 4.0) = 1.0;

group_uniforms Oclusion;
uniform float occlusion_radius = 0.012;   // radio de muestreo alrededor del sol (alto de pantalla)

group_uniforms Estrella;
uniform float core_strength = 2.5;        // núcleo muy brillante
uniform float halo_strength = 0.15;       // halo ancho y suave
uniform int ray_count = 6;
uniform float ray_strength = 2.2;
uniform float ray_length = 0.6;          // en alturas de pantalla
uniform float ray_sharpness = 900.0;      // más alto = rayos más finos
uniform float ray_rotation = 0.35;        // radianes
uniform float veil_strength = 0.06;       // velo luminoso en toda la imagen

group_uniforms Flare;
uniform float ring_strength = 0.12;       // anillo iridiscente alrededor del sol
uniform float ring_radius = 0.2;
uniform float ghost_strength = 0.3;
uniform vec3 ghost_tint_a : source_color = vec3(0.35, 0.9, 1.0);   // cian
uniform vec3 ghost_tint_b : source_color = vec3(0.6, 1.0, 0.45);   // lima
uniform vec3 ghost_tint_c : source_color = vec3(0.45, 0.6, 1.0);   // azul

void vertex() {
	// Cubre la pantalla entera sin depender de la cámara
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Fracción de muestras de cielo alrededor del sol (1 = sol despejado).
float sun_visibility() {
	float vis = 0.0;
	const int RINGS = 3;
	const int PER_RING = 8;
	float total = 0.0;
	for (int r = 0; r <= RINGS; r++) {
		float rr = occlusion_radius * float(r) / float(RINGS);
		int n = r == 0 ? 1 : PER_RING;
		for (int k = 0; k < n; k++) {
			float a = 6.2831853 * (float(k) + 0.5 * float(r)) / float(n);
			vec2 uv = sun_uv + vec2(cos(a) / aspect, sin(a)) * rr;
			// Fuera de pantalla no hay datos: cuenta como tapado, así el destello se
			// apaga al salir el sol del encuadre en vez de verse a través de las paredes
			float sky = 0.0;
			if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
				sky = step(textureLod(depth_tex, uv, 0.0).r, 1e-7);
			}
			vis += sky;
			total += 1.0;
		}
	}
	return vis / total;
}

// Arcoíris suave (tono 0-1)
vec3 spectrum(float h) {
	return clamp(abs(fract(h + vec3(0.0, 0.667, 0.333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// Disco suave con el borde algo más brillante, como los fantasmas de un objetivo
float ghost(vec2 p, vec2 c, float radius) {
	float d = length(p - c) / radius;
	float disc = 1.0 - smoothstep(0.75, 1.0, d);
	float rim = smoothstep(0.7, 0.95, d) * (1.0 - smoothstep(0.95, 1.05, d));
	return disc * 0.55 + rim * 0.45;
}

void fragment() {
	float vis = sun_visibility() * sun_fade;
	if (vis <= 0.001) {
		discard;
	}
	// Coordenadas con el alto de pantalla como unidad y el centro en el medio
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	vec2 s = (sun_uv - 0.5) * vec2(aspect, 1.0);
	vec2 d = p - s;
	float r = length(d);

	// Núcleo y halo
	float core = exp(-r * r * 2200.0) * core_strength;
	float halo = exp(-r * 7.0) * halo_strength;

	// Rayos de la estrella: finos y largos, más otro juego corto a medio camino
	float ang = atan(d.y, d.x) + ray_rotation;
	float n = float(ray_count);
	float fall = exp(-r / max(ray_length, 1e-3) * 3.0);
	float rays = pow(abs(cos(ang * n * 0.5)), ray_sharpness * (0.3 + r * 4.0)) * fall;
	float rays2 = pow(abs(cos(ang * n * 0.5 + 1.5708)), ray_sharpness) * exp(-r / max(ray_length, 1e-3) * 7.0) * 0.45;
	float star = (rays + rays2) * ray_strength;

	// Anillo iridiscente fino alrededor del sol
	float ring_d = (r - ring_radius) / (ring_radius * 0.12);
	float ring = exp(-ring_d * ring_d) * ring_strength;
	vec3 ring_col = mix(vec3(1.0), spectrum(r / ring_radius * 0.6 + 0.2), 0.7);

	// Fantasmas en la línea sol-centro, más débiles cuanto más al borde está el sol
	float centered = 1.0 - smoothstep(0.3, 0.95, length(s));
	vec3 ghosts = vec3(0.0);
	ghosts += ghost_tint_a * ghost(p, s * -0.35, 0.05);
	ghosts += ghost_tint_b * ghost(p, s * -0.7, 0.028) * 1.3;
	ghosts += ghost_tint_c * ghost(p, s * -1.15, 0.11) * 0.55;
	ghosts += ghost_tint_a * ghost(p, s * 0.45, 0.02) * 1.2;
	ghosts += ghost_tint_b * ghost(p, s * -1.6, 0.065) * 0.6;
	ghosts *= ghost_strength * centered;

	// Velo: toda la imagen se aclara un poco al mirar al sol
	float veil = veil_strength * (1.0 - smoothstep(0.0, 1.2, r));

	vec3 col = sun_color * (core + halo + star + veil) + ring_col * ring * sun_color + ghosts;
	ALBEDO = col * intensity * vis;
}
