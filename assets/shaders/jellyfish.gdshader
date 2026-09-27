shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
// Medusa translúcida estilo Frutiger Aero: casi transparente de frente y más visible en
// los bordes (fresnel), iridiscencia suave cian-rosa-violeta y brillo interno opcional.
// La campana late (se contrae hacia el borde) y lo que cuelga por debajo ondula.
// Espacio local: ápice de la campana en y = 0, todo lo demás por debajo.

instance uniform float pulse_phase = 0.0;

uniform vec3 tint : source_color = vec3(0.8, 0.92, 1.0);
uniform float base_alpha = 0.08;
uniform float fresnel_alpha = 0.55;
uniform float iridescence = 0.6;
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.9);
uniform float glow = 0.0;
uniform float bell_height = 0.075;           // altura de la campana (m)
uniform float pulse_frequency = 1.5;         // rad/s
uniform float pulse_amount = 0.12;           // contracción del borde
uniform float sway_amount = 0.0;             // ondulación por metro colgado bajo el borde

vec3 iridescent(float t) {
	vec3 cyan = vec3(0.35, 0.95, 1.0);
	vec3 pink = vec3(1.0, 0.55, 0.85);
	vec3 violet = vec3(0.65, 0.45, 1.0);
	t = fract(t) * 3.0;
	if (t < 1.0) return mix(cyan, pink, t);
	if (t < 2.0) return mix(pink, violet, t - 1.0);
	return mix(violet, cyan, t - 2.0);
}

void vertex() {
	float y = VERTEX.y;
	float w = smoothstep(0.0, -bell_height, y);        // 0 en el ápice, 1 en el borde y abajo
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_frequency + pulse_phase);
	VERTEX.xz *= 1.0 - pulse_amount * w * pulse;
	VERTEX.y += pulse_amount * 0.25 * bell_height * w * pulse;
	float below = max(-bell_height - y, 0.0);
	VERTEX.x += sway_amount * below * sin(TIME * 1.3 + pulse_phase + below * 16.0 + VERTEX.z * 25.0);
	VERTEX.z += sway_amount * below * cos(TIME * 1.1 + pulse_phase + below * 13.0 + VERTEX.x * 25.0);
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	ALBEDO = tint;
	ALPHA = clamp(base_alpha + fres * fresnel_alpha, 0.0, 1.0);
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	EMISSION = iridescent(fres * 1.4 + TIME * 0.03 + pulse_phase * 0.1) * fres * iridescence * 0.6 + glow_color * glow;
}
