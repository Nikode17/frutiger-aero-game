shader_type spatial;
render_mode unshaded, cull_back;
// Pantalla grande del acuario: muestra la textura del SubViewport con esquinas muy
// redondeadas (recorte), un brillo suave de cristal y una ligera viñeta.

uniform sampler2D screen_tex : source_color, filter_linear, repeat_disable;
uniform float brightness = 1.0;
uniform float aspect = 2.44;           // ancho / alto de la pantalla
uniform float corner_radius = 0.17;    // radio de las esquinas en fracción de la altura
uniform float sheen_strength = 0.08;

void fragment() {
	// Esquinas redondeadas: distancia a un rectángulo redondeado en unidades de altura
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec2 half_size = vec2(aspect * 0.5, 0.5);
	vec2 q = abs(p - half_size) - (half_size - vec2(corner_radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	if (d > 0.0) {
		discard;
	}
	vec3 col = texture(screen_tex, UV).rgb;
	// Brillo de cristal en diagonal y viñeta suave
	float sheen = smoothstep(0.35, 0.0, abs(UV.x * 0.6 - UV.y * 0.9 + 0.1));
	col += vec3(0.8, 0.95, 1.0) * sheen * sheen_strength;
	vec2 v = (UV - 0.5) * vec2(1.0, 1.3);
	col *= 1.0 - 0.3 * dot(v, v);
	ALBEDO = col * brightness;
}
