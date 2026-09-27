// Burbuja: centro casi transparente, borde con fresnel iridiscente y un brillo fijo
// en pantalla para que siempre se lea como una esfera brillante. COLOR.a viene de la
// rampa de color de las partículas (aparecer y desvanecerse).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform vec3 tint : source_color = vec3(0.82, 0.96, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float rim_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float center_alpha : hint_range(0.0, 1.0) = 0.14;
uniform float iridescence : hint_range(0.0, 1.0) = 0.6;
uniform float highlight_strength : hint_range(0.0, 3.0) = 1.6;
uniform float emission_strength : hint_range(0.0, 2.0) = 0.7;
// Altura (mundo) a la que las burbujas desaparecen y tramo de desvanecimiento previo
uniform float clip_top = 100.0;
uniform float fade_height = 0.4;

void fragment() {
	float world_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	if (world_y > clip_top) {
		discard;
	}
	float top_fade = smoothstep(clip_top, clip_top - fade_height, world_y);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, rim_power);
	vec3 irid = 0.5 + 0.5 * cos(TAU * (fres * 1.2 + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(tint, irid, iridescence * fres);
	// Brillo fijo arriba a la izquierda (en espacio de vista)
	vec3 h_dir = normalize(vec3(-0.45, 0.75, 0.5));
	float hl = pow(max(dot(NORMAL, h_dir), 0.0), 48.0) * highlight_strength;

	ALBEDO = col;
	ALPHA = clamp(mix(center_alpha, rim_alpha, fres) + hl, 0.0, 1.0) * COLOR.a * top_fade;
	EMISSION = col * (emission_strength * fres + hl);
	METALLIC = 0.0;
	ROUGHNESS = 0.05;
	SPECULAR = 1.0;
}
