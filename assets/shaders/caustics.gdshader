// Cáusticas suaves de agua proyectadas en el suelo alrededor de la columna:
// dos capas de Voronoi animado (bordes brillantes) en un anillo que se desvanece.
// Aditivo y sin iluminación: se suma sobre el suelo como si fuera luz.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;

uniform vec3 caustic_color : source_color = vec3(0.55, 0.9, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.55;
uniform float pattern_scale = 1.3;
uniform float speed = 0.35;
uniform float inner_radius = 0.9;
uniform float outer_radius = 2.6;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// Devuelve (F1, F2): distancias al punto más cercano y al segundo
vec2 voronoi(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = hash22(cell + g);
			vec2 o = 0.5 + 0.4 * sin(t + TAU * h);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f1, f2);
}

void fragment() {
	vec2 p = local_pos.xz;
	float r = length(p);
	float fade = smoothstep(outer_radius, inner_radius + 0.4, r)
			* smoothstep(inner_radius - 0.15, inner_radius + 0.25, r);
	vec2 uv = p * pattern_scale;
	vec2 v1 = voronoi(uv, TIME * speed);
	vec2 v2 = voronoi(uv * 1.6 + 5.3, -TIME * speed * 0.7);
	float c1 = exp(-(v1.y - v1.x) * 6.0);
	float c2 = exp(-(v2.y - v2.x) * 6.0);
	float c = c1 * 0.7 + c2 * 0.45;

	ALBEDO = caustic_color * c * intensity * fade;
	ALPHA = 1.0;
}
