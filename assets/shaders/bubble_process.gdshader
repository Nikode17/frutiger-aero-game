// Proceso de partículas de las burbujas de la columna de agua.
// Cada burbuja nace en la base, sube a velocidad constante (las grandes algo más
// rápido), se bambolea con amplitud acotada y se desvanece antes del tope; al llegar
// arriba vuelve a nacer abajo con nuevos valores. Todo en coordenadas locales del
// emisor y siempre dentro del radio interior del agua. No depende de la vida del
// sistema de partículas (que se deja enorme) ni del precálculo.
shader_type particles;
render_mode disable_velocity;

uniform float travel = 4.3;              // Altura recorrible (m): base -> tope de fundido
uniform float base_speed = 0.45;         // Velocidad de las burbujas más lentas (m/s)
uniform float speed_variation = 0.3;     // Las grandes suben hasta (1 + variación) veces
uniform float emit_radius = 0.4;         // Radio del disco de nacimiento (m)
uniform float inner_radius = 0.6;        // Radio interior del agua (m): límite absoluto
uniform float size_min = 0.05;           // Diámetro mínimo (m)
uniform float size_max = 0.14;           // Diámetro máximo (m)
uniform float wobble_amplitude = 0.04;   // Amplitud del bamboleo lateral (m)
uniform float wobble_frequency = 1.5;    // Velocidad del bamboleo (rad/s)
uniform float fade_in = 0.3;             // Tramo de aparición desde la base (m)
uniform float fade_out = 0.5;            // Tramo de desvanecimiento bajo el tope (m)

// Hash entero (PCG): valores repetibles por burbuja y ciclo
uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// id = NUMBER + RANDOM_SEED (los built-ins solo se leen en start/process)
float rand01(uint id, uint cycle, uint salt) {
	return float(pcg(id * 1664525u + cycle * 1013904223u + salt * 69069u)) / 4294967295.0;
}

float bubble_size(uint id, uint cycle) {
	float t = rand01(id, cycle, 1u);
	return mix(size_min, size_max, t * t);   // más pequeñas que grandes
}

float speed_factor(uint id, uint cycle) {
	float size_t = (bubble_size(id, cycle) - size_min) / max(size_max - size_min, 0.0001);
	return 1.0 + speed_variation * mix(rand01(id, cycle, 2u), size_t, 0.6);
}

vec2 base_xz(uint id, uint cycle) {
	float ang = rand01(id, cycle, 3u) * TAU;
	float r = sqrt(rand01(id, cycle, 4u)) * emit_radius;
	return vec2(cos(ang), sin(ang)) * r;
}

// Devuelve transform y color de la burbuja para su edad y ciclo
void place(uint id, float age, uint cycle, out mat4 xform, out vec4 color) {
	float size = bubble_size(id, cycle);
	float y = age * base_speed * speed_factor(id, cycle);
	y = min(y, travel);

	float phase = rand01(id, cycle, 5u) * TAU;
	vec2 wobble = vec2(sin(age * wobble_frequency + phase),
			cos(age * wobble_frequency * 0.83 + phase * 1.7)) * wobble_amplitude;
	vec2 xz = base_xz(id, cycle) + wobble;
	// Nunca fuera del agua: el centro se recorta al radio interior menos el radio de la burbuja
	float limit = max(inner_radius - size * 0.5, 0.01);
	float len = length(xz);
	if (len > limit) {
		xz *= limit / len;
	}

	float alpha = smoothstep(0.0, fade_in, y) * (1.0 - smoothstep(travel - fade_out, travel, y));

	xform = mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0),
			vec4(0.0, 0.0, size, 0.0), vec4(xz.x, y, xz.y, 1.0));
	color = vec4(1.0, 1.0, 1.0, alpha);
}

void start() {
	// Edad inicial aleatoria: la columna arranca ya llena y repartida
	uint id = NUMBER + RANDOM_SEED;
	uint cycle = 0u;
	float cycle_time = travel / (base_speed * speed_factor(id, cycle));
	float age = rand01(id, cycle, 6u) * cycle_time;
	CUSTOM = vec4(age, 0.0, 0.0, 0.0);
	mat4 xform;
	vec4 color;
	place(id, age, cycle, xform, color);
	TRANSFORM = xform;
	COLOR = color;
}

void process() {
	uint id = NUMBER + RANDOM_SEED;
	uint cycle = uint(CUSTOM.z);
	float age = CUSTOM.x + DELTA;
	if (age * base_speed * speed_factor(id, cycle) >= travel) {
		// Llegó al tope: renace en la base con nuevos valores
		cycle += 1u;
		age = 0.0;
	}
	CUSTOM.x = age;
	CUSTOM.z = float(cycle);
	mat4 xform;
	vec4 color;
	place(id, age, cycle, xform, color);
	TRANSFORM = xform;
	COLOR = color;
}
