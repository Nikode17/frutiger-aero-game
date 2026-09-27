shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Haz de luz que baja desde la superficie: franja aditiva que se desvanece hacia abajo y
// hacia los lados, con un leve parpadeo.

instance uniform float shaft_phase = 0.0;
uniform vec3 shaft_color : source_color = vec3(0.7, 0.95, 1.0);
uniform float intensity = 0.12;

void fragment() {
	float side = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 2.0);
	float down = pow(1.0 - UV.y, 1.5);
	float flicker = 0.75 + 0.25 * sin(TIME * 0.6 + shaft_phase);
	ALBEDO = shaft_color * side * down * flicker * intensity;
}
