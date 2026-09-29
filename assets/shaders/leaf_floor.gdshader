// Suelo pulido con patrón procedural de hojas verdes (sin texturas).
// Las hojas se colocan en una rejilla con posición, giro y tamaño aleatorios por celda,
// en dos capas superpuestas para que no se note la repetición.
shader_type spatial;
render_mode cull_back;

uniform vec3 base_color : source_color = vec3(0.80, 0.92, 0.98);
uniform vec3 leaf_color : source_color = vec3(0.40, 0.86, 0.42);
uniform vec3 vein_color : source_color = vec3(0.78, 0.98, 0.72);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.03;
uniform float leaf_roughness : hint_range(0.0, 1.0) = 0.08;
uniform float specular_value : hint_range(0.0, 1.0) = 1.0;
// Algo de metallic hace que el suelo refleje el entorno como un pulido de verdad
// (con specular solo, un dieléctrico refleja apenas un 4-8 %).
uniform float metallic_value : hint_range(0.0, 1.0) = 0.45;

uniform float cell_size = 1.25;          // metros por celda de la rejilla
uniform float leaf_half_length = 0.46;   // semi-longitud de la hoja (m)
uniform float leaf_half_width = 0.19;    // semi-anchura de la hoja (m)
uniform float leaf_density : hint_range(0.0, 1.0) = 0.85;
uniform float edge_softness = 0.012;
uniform float vein_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec2 pattern_offset = vec2(0.0, 0.0);

// Reflejo planar (calidad Alta): lo pone PlanarReflection. En la zona plana sustituye al
// reflejo del motor (sondas/SDFGI); donde el suelo empieza a curvarse hacia la pared
// se funde de vuelta al material normal.
uniform sampler2D planar_tex : filter_linear, repeat_disable;
uniform mat4 planar_view_proj;
uniform float planar_strength : hint_range(0.0, 1.0) = 0.0;   // 0 = sin reflejo planar
uniform float planar_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float planar_blur = 0.0022;          // radio del desenfoque (fracción de pantalla)
uniform float planar_leaf_blur = 2.5;        // las hojas, algo más rugosas, desenfocan más
uniform float planar_flat_angle = 10.0;      // pendiente (grados) hasta la que el reflejo es planar
uniform float planar_fade_angle = 18.0;      // pendiente a la que ya solo queda el reflejo del motor

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Reflejo planar desenfocado: disco de 8 muestras más el centro
vec3 planar_sample(vec2 uv, float radius) {
	const vec2 TAPS[8] = vec2[8](vec2(1.0, 0.0), vec2(0.707, 0.707), vec2(0.0, 1.0), vec2(-0.707, 0.707),
			vec2(-1.0, 0.0), vec2(-0.707, -0.707), vec2(0.0, -1.0), vec2(0.707, -0.707));
	vec3 acc = textureLod(planar_tex, uv, 0.0).rgb * 2.0;
	for (int i = 0; i < 8; i++) {
		vec2 o = TAPS[i] * radius * (i % 2 == 0 ? 1.0 : 0.6);
		acc += textureLod(planar_tex, clamp(uv + o, vec2(0.001), vec2(0.999)), 0.0).rgb;
	}
	return acc / 10.0;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// SDF de una vesica (dos arcos de círculo): forma de hoja alargada en el eje Y.
float sd_vesica(vec2 p, float r, float d) {
	p = abs(p);
	float b = sqrt(max(r * r - d * d, 0.0001));
	return ((p.y - b) * d > p.x * b) ? length(p - vec2(0.0, b)) : length(p - vec2(-d, 0.0)) - r;
}

// Devuelve (máscara de hoja, máscara de vena) de una capa de hojas.
vec2 leaf_layer(vec2 p, float cell, float seed, float half_len, float half_wid, float density) {
	// Parámetros de la vesica a partir de semi-longitud y semi-anchura
	float r = 0.5 * (half_wid + half_len * half_len / half_wid);
	float d = r - half_wid;

	vec2 cell_id = floor(p / cell);
	float mask = 0.0;
	float vein = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = cell_id + vec2(float(i), float(j));
			float h1 = hash21(id + seed);
			if (h1 > density) {
				continue;
			}
			float h2 = hash21(id * 1.7 + seed + 3.1);
			float h3 = hash21(id * 2.3 + seed + 7.7);
			float h4 = hash21(id * 3.1 + seed + 11.3);
			vec2 center = (id + 0.5 + (vec2(h2, h3) - 0.5) * 0.55) * cell;
			float ang = h4 * TAU;
			float sc = 0.8 + 0.45 * h3;
			vec2 q = p - center;
			float ca = cos(ang);
			float sa = sin(ang);
			q = vec2(ca * q.x - sa * q.y, sa * q.x + ca * q.y) / sc;
			float dist = sd_vesica(q, r, d) * sc;
			float m = 1.0 - smoothstep(-edge_softness, edge_softness, dist);
			// Vena central que se desvanece hacia la punta
			float tip_fade = 1.0 - smoothstep(half_len * 0.55, half_len * 0.95, abs(q.y));
			float v = (1.0 - smoothstep(0.0, 0.014 / sc, abs(q.x))) * tip_fade;
			// Venas laterales finas en espiga
			float side_wave = sin((q.y * 1.6 + abs(q.x) * 1.1) * PI * 4.0 / half_len);
			float side = smoothstep(0.96, 1.0, side_wave) * tip_fade * 0.55;
			v = max(v, side) * m;
			mask = max(mask, m);
			vein = max(vein, v);
		}
	}
	return vec2(mask, vein);
}

void fragment() {
	vec2 p = world_pos.xz + pattern_offset;
	vec2 l1 = leaf_layer(p, cell_size, 0.0, leaf_half_length, leaf_half_width, leaf_density);
	vec2 l2 = leaf_layer(p + vec2(0.37, 0.61) * cell_size, cell_size * 0.78, 5.0,
			leaf_half_length * 0.72, leaf_half_width * 0.72, leaf_density * 0.6);
	float leaf = max(l1.x, l2.x);
	float vein = max(l1.y, l2.y) * vein_strength;

	vec3 col = mix(base_color, leaf_color, leaf);
	col = mix(col, vein_color, vein);

	// La curva suelo-pared es muy suave: se decide por la pendiente, no por la altura
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = degrees(acos(clamp(world_normal.y, -1.0, 1.0)));
	float planar = planar_strength * (1.0 - smoothstep(planar_flat_angle, planar_fade_angle, slope));
	ALBEDO = col;
	METALLIC = metallic_value;
	ROUGHNESS = mix(roughness_value, leaf_roughness, leaf);
	SPECULAR = specular_value;
	if (planar > 0.001) {
		// Punto del suelo proyectado con la cámara reflejada (está en el plano, así que
		// coincide con su reflejo): no depende de hacia dónde mira el jugador
		vec4 clip = planar_view_proj * vec4(world_pos, 1.0);
		vec2 uv = clip.xy / clip.w * vec2(0.5, -0.5) + 0.5;
		// Más desenfoque en las hojas y donde el suelo empieza a curvarse
		float blur = planar_blur * mix(1.0, planar_leaf_blur, leaf) * (1.0 + slope * 0.15);
		vec3 refl = planar_sample(uv, blur);
		// Fresnel con la misma reflectancia que daba el metallic sobre este color
		vec3 f0 = mix(vec3(0.04), col, metallic_value);
		float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		vec3 fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
		EMISSION = refl * fres * planar_intensity * planar;
		// Sin reflejo del motor en la zona plana, manteniendo el difuso
		ALBEDO = col * mix(1.0, 1.0 - metallic_value, planar);
		METALLIC = mix(metallic_value, 0.0, planar);
		SPECULAR = mix(specular_value, 0.0, planar);
	}
}
