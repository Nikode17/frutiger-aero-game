// Parte común de los shaders del exterior: neblina atmosférica por distancia (se aplica
// con la salida FOG de cada material, sin tocar la niebla global del entorno, que
// cambiaría la luz del interior), ruido y viento.

uniform vec3 haze_color : source_color = vec3(0.74, 0.88, 1.0);
uniform float haze_distance = 1100.0;   // a esta distancia la neblina llega al 63 % de haze_max
uniform float haze_max = 0.8;

varying vec3 world_pos;

vec4 exterior_haze(vec3 p, vec3 cam) {
	float d = length(p - cam);
	return vec4(haze_color, (1.0 - exp(-d / haze_distance)) * haze_max);
}

float ext_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ext_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = ext_hash(i);
	float b = ext_hash(i + vec2(1.0, 0.0));
	float c = ext_hash(i + vec2(0.0, 1.0));
	float d = ext_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float ext_fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * ext_noise(p);
		p = p * 2.07 + vec2(13.1, 7.7);
		amp *= 0.5;
	}
	return v;
}

// Viento: valor suave entre -1 y 1 que recorre el prado
float ext_wind(vec3 p, float speed) {
	return sin(TIME * speed + p.x * 0.35 + p.z * 0.22) * 0.65 + sin(TIME * speed * 2.3 + p.x * 1.3 - p.z * 0.9) * 0.25;
}

// Viento de árbol en espacio local (y = altura desde la base): el vaivén crece con la
// altura por encima de trunk_height y con la distancia al eje del tronco. Ramas y hojas
// usan la misma función para que las hojas no se despeguen de las ramas.
uniform float tree_wind_strength = 0.05;
uniform float tree_wind_speed = 0.8;
uniform float tree_trunk_height = 2.2;

vec3 tree_wind(vec3 local, vec3 origin) {
	float h = max(local.y - tree_trunk_height, 0.0);
	float r = length(local.xz);
	float k = h * 0.12 + r * 0.05;
	float t = TIME * tree_wind_speed;
	float gust = 0.65 + 0.35 * sin(t * 0.37 + origin.x * 0.01);
	vec2 sway = vec2(sin(t + origin.x * 0.05 + local.y * 0.1), cos(t * 0.83 + origin.z * 0.05 + local.y * 0.08)) * gust;
	return vec3(sway.x, 0.0, sway.y) * tree_wind_strength * k;
}
