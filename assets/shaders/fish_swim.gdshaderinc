// Parte común de los shaders de peces: ondulación de nado y cáusticas.
// El pez mira hacia +Z en su espacio local (morro en +Z, cola en -Z).

instance uniform float swim_phase = 0.0;     // desfase de cada pez
instance uniform float swim_speed = 1.0;     // multiplica la frecuencia de aleteo
instance uniform float body_length = 0.15;   // longitud del pez (m)

uniform float swim_frequency = 7.0;          // rad/s a swim_speed = 1
uniform float swim_amplitude = 0.1;          // desplazamiento de la cola, en fracción de la longitud
uniform float wave_number = 4.5;             // cuántas ondas recorren el cuerpo
uniform float caustic_strength = 0.35;

varying vec3 obj_pos;
varying vec3 world_pos;

// Desplazamiento lateral (X) de un vértice: casi nulo en la cabeza y máximo en la cola
vec3 swim_offset(vec3 v) {
	float t = clamp((body_length * 0.5 - v.z) / body_length, 0.0, 1.3);
	float w = smoothstep(0.1, 1.0, t);
	float phase = TIME * swim_frequency * swim_speed + swim_phase;
	float wave = sin(phase - t * wave_number);
	float head = sin(phase) * 0.012 * body_length * (1.0 - t);
	return vec3(wave * swim_amplitude * body_length * w * w + head, 0.0, 0.0);
}

// Patrón de cáusticas en el plano horizontal
float caustics(vec3 p) {
	vec2 q = p.xz * 9.0;
	float c = sin(q.x + sin(q.y * 1.3 + TIME * 0.9) * 1.3 + TIME * 0.5);
	c *= sin(q.y * 1.1 + sin(q.x * 0.8 - TIME * 0.7) * 1.3 - TIME * 0.4);
	return pow(abs(c), 3.0);
}

// Los colores de vértice se pintaron en espacio sRGB
vec3 vertex_albedo(vec3 c) {
	return pow(c, vec3(2.2));
}
