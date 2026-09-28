// Viñeta ligera sobre la imagen final (después del tonemap), como en las fotos de
// los 2000: oscurece un poco las esquinas con un tono azul marino, no negro.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.25;
uniform float radius : hint_range(0.2, 1.5) = 0.85;      // donde empieza a oscurecer
uniform float softness : hint_range(0.05, 1.5) = 0.7;    // anchura del degradado
uniform vec3 tint : source_color = vec3(0.02, 0.1, 0.22);

void fragment() {
	// Elipse que sigue la forma de la pantalla (0 en el centro, ~1.41 en las esquinas)
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float v = smoothstep(radius - softness * 0.5, radius + softness * 0.5, d);
	COLOR = vec4(tint, v * strength);
}
