shader_type spatial;
// Alfombra de pelo largo con espiral cobalto → turquesa → verde césped. Sin emisión y
// rugosa. El dibujo se calcula en espacio local (plano XZ, centro en el origen), así que no
// necesita UV.
// - Versión plana (Media/Baja): mechones con relieve en la normal y oclusión en el color.
// - Capas shell (Alta, ver scenes/fx/shag_shells.gd): el mismo shader con shell_mode activo;
//   shell_layer va de 0 (raíz, capa completa y oscura) a 1 (puntas). Cada capa se desplaza
//   a lo largo de la normal y descarta lo que queda entre mechones. Bajo los muebles el
//   pelo se aplasta (flatten_areas, lo rellena ShagShells).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms colores;
uniform vec3 color_a : source_color = vec3(0.08, 0.24, 0.8);   // cobalto
uniform vec3 color_b : source_color = vec3(0.0, 0.6, 0.62);    // turquesa
uniform vec3 color_c : source_color = vec3(0.12, 0.46, 0.13);  // verde césped
uniform float color_variation : hint_range(0.0, 0.5) = 0.16;   // brillo distinto por mechón
uniform float saturation : hint_range(0.0, 1.5) = 0.9;          // saturación general
uniform float root_shade : hint_range(0.0, 1.0) = 0.42;        // oscuridad entre mechones

group_uniforms espiral;
uniform float spiral_arms = 3.0;               // número de brazos (entero)
uniform float spiral_turns_per_meter = 0.8;     // cuántas bandas se cruzan por metro de radio
uniform float center_radius = 0.28;             // radio del centro liso (color turquesa)
uniform float spiral_warp : hint_range(0.0, 1.0) = 0.3;   // irregularidad de las bandas
uniform float band_softness : hint_range(0.05, 1.0) = 0.7; // transición entre colores

group_uniforms pelo;
uniform float tuft_size = 0.015;                // separación entre mechones (m)
uniform float bump_strength : hint_range(0.0, 2.0) = 0.9;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float specular_value : hint_range(0.0, 1.0) = 0.2;
uniform float sheen : hint_range(0.0, 1.0) = 0.25;

group_uniforms shells;
uniform bool shell_mode = false;
uniform float shell_layer : hint_range(0.0, 1.0) = 0.0;
uniform float pile_height = 0.032;              // largo del pelo (m)
uniform float strand_bend = 0.02;               // inclinación común de las puntas, "peinado" (m)
uniform float strand_lean : hint_range(0.0, 0.8) = 0.55;   // inclinación propia de cada mechón (en celdas)
// Zonas donde un mueble aplasta el pelo, en espacio local: (x, z, radio, transición)
uniform vec4 flatten_areas[4];
uniform int flatten_count = 0;
uniform float flatten_height : hint_range(0.0, 1.0) = 0.2;   // altura del pelo aplastado (fracción)

varying vec3 v_pos;
varying vec3 v_nrm;


vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Mechón más cercano (celdas de Worley): x = distancia al centro (en celdas),
// y = valor aleatorio del mechón, zw = vector del punto al centro del mechón.
// Cada mechón se inclina en su propia dirección según la altura (lean = 0 en la raíz).
vec4 tuft(vec2 p, float lean) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	vec2 best_id = vec2(0.0);
	vec2 best_r = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = hash22(cell + g);
			vec2 dir = vec2(cos(h.x * 37.7), sin(h.x * 37.7));
			vec2 r = g + 0.2 + h * 0.6 + dir * lean - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				best_id = cell + g;
				best_r = r;
			}
		}
	}
	return vec4(sqrt(best), hash12(best_id), best_r);
}

// Color de la espiral en el punto p (plano XZ local, metros)
vec3 spiral_color(vec2 p, float jitter) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float s = spiral_arms * a / TAU - r * spiral_turns_per_meter * spiral_arms * 0.5;
	s += (value_noise(p * 2.5) - 0.5) * spiral_warp + jitter;
	float t = fract(s) * 3.0;
	int i = int(floor(t));
	float f = smoothstep(0.5 - band_softness * 0.5, 0.5 + band_softness * 0.5, fract(t));
	vec3 cols[3] = vec3[3](color_a, color_b, color_c);
	vec3 col = mix(cols[i % 3], cols[(i + 1) % 3], f);
	// Centro liso, para que los brazos no se junten en un pellizco
	float rn = r + (value_noise(p * 9.0) - 0.5) * 0.06;
	return mix(color_b, col, smoothstep(center_radius * 0.55, center_radius, rn));
}

// Fracción de altura del pelo en p (1 = pelo completo)
float pile_scale(vec2 p) {
	float k = 1.0;
	for (int i = 0; i < 4; i++) {
		if (i >= flatten_count) {
			break;
		}
		vec4 a = flatten_areas[i];
		float d = distance(p, a.xy);
		k = min(k, mix(flatten_height, 1.0, smoothstep(a.z, a.z + max(a.w, 1e-3), d)));
	}
	return k;
}

vec3 local_to_view(vec3 v, mat4 view_matrix, mat4 model_matrix) {
	return normalize((view_matrix * model_matrix * vec4(v, 0.0)).xyz);
}


void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	if (shell_mode) {
		VERTEX += NORMAL * (0.001 + shell_layer * pile_height);
	}
}


void fragment() {
	vec2 p = v_pos.xz;
	bool top = v_nrm.y > 0.5;
	float layer = shell_mode ? shell_layer : 0.0;

	// Las puntas se inclinan siguiendo un "peinado" suave
	vec2 flow = vec2(value_noise(p * 1.7), value_noise(p * 1.7 + 17.3)) * 2.0 - 1.0;
	vec2 q = (p + flow * strand_bend * layer * layer) / tuft_size;
	vec4 t = tuft(q, strand_lean * layer * layer);
	float d = t.x;
	float id = t.y;
	float tuft_height = (0.6 + 0.4 * id) * (shell_mode ? pile_scale(p) : 1.0);
	// De lejos los mechones son más pequeños que un píxel: se funden para que no parpadeen
	float px = fwidth(q.x) + fwidth(q.y);
	float detail = 1.0 - smoothstep(0.3, 0.9, px);

	vec3 col = spiral_color(p, (id - 0.5) * 0.04);
	col *= 1.0 + (fract(id * 7.13) - 0.5) * 2.0 * color_variation * detail;

	vec3 n_local = vec3(0.0, 1.0, 0.0);
	vec2 out_dir = -t.zw / max(d, 1e-4);   // del centro del mechón hacia el punto
	float shade;
	if (shell_mode) {
		if (layer > 0.0) {
			if (!top) {
				discard;
			}
			float h = layer / tuft_height;
			float radius = mix(0.6, 0.22, clamp(h, 0.0, 1.0));
			radius = mix(0.95, radius, detail);
			if (h > 1.0 || d > radius) {
				discard;
			}
		}
		shade = mix(root_shade, 0.94, smoothstep(0.0, 1.0, layer / tuft_height));
		n_local = normalize(vec3(out_dir.x * 0.5, 1.0, out_dir.y * 0.5));
	} else {
		// Cúpula por mechón: más alto en el centro, oscuro en los huecos
		float dome = 1.0 - smoothstep(0.0, 0.62, d);
		shade = mix(1.0 - (1.0 - root_shade) * 0.35, mix(root_shade + 0.25, 1.0, dome * tuft_height), detail);
		float slope = smoothstep(0.1, 0.45, d) * (1.0 - smoothstep(0.5, 0.7, d));
		n_local = normalize(vec3(out_dir.x * slope * bump_strength * detail, 1.0, out_dir.y * slope * bump_strength * detail));
	}

	if (top) {
		NORMAL = local_to_view(n_local, VIEW_MATRIX, MODEL_MATRIX);
	}
	col *= shade;
	ALBEDO = max(mix(vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), col, saturation), vec3(0.0));
	METALLIC = 0.0;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	RIM = sheen;
	RIM_TINT = 0.6;
}
