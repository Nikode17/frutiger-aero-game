shader_type spatial;
render_mode cull_disabled;
// Algas del acuario: cintas que se mecen más cuanto más altas (UV.y = altura relativa,
// UV2.x = desfase de cada alga). Color de vértice y algo de luz que las atraviesa.

uniform float sway_amount = 0.06;   // m en la punta
uniform float sway_speed = 1.1;

void vertex() {
	float h = UV.y;
	float ph = UV2.x;
	VERTEX.x += sin(TIME * sway_speed + ph + h * 2.5) * sway_amount * h * h;
	VERTEX.z += cos(TIME * sway_speed * 0.8 + ph * 1.7 + h * 2.0) * sway_amount * 0.5 * h * h;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.5;
	SPECULAR = 0.4;
	BACKLIGHT = COLOR.rgb * 0.6;
}
