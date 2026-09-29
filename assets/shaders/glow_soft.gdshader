shader_type spatial;
// Brillo interior suave (glow_soft): volumen aditivo sin luz, más intenso en el centro de
// la silueta y que se desvanece hacia los bordes. Pensado para ir dentro de un cristal
// (núcleo de la gota colgante): usa render_priority 1 para dibujarse después del cristal,
// que lee la pantalla y no vería lo transparente de dentro. Color e intensidad por
// instancia (set_instance_shader_parameter).
render_mode blend_add, unshaded, depth_draw_never, cull_back;

instance uniform vec3 glow_color : source_color = vec3(0.35, 0.85, 1.0);
instance uniform float glow_energy = 0.8;
uniform float falloff : hint_range(0.3, 6.0) = 1.8;     // cuánto se concentra en el centro
uniform float flicker : hint_range(0.0, 0.3) = 0.06;    // respiración lenta
uniform float flicker_speed = 0.6;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float breath = 1.0 + flicker * sin(TIME * flicker_speed);
	ALBEDO = glow_color * glow_energy * pow(ndv, falloff) * breath;
}
