shader_type spatial;
// Fondo de disco retroiluminado (backlit_disc): luz propia con degradado radial (más
// clara arriba a un lado, más profunda en el borde) y unas burbujas claras que suben muy
// despacio. Color, intensidad y semilla por instancia. Usa UV (0-1 sobre el disco).
render_mode unshaded, cull_back;

instance uniform vec3 disc_color : source_color = vec3(0.25, 0.8, 1.0);
instance uniform float disc_energy = 1.0;
instance uniform float disc_seed = 0.0;
uniform float center_boost : hint_range(0.0, 1.5) = 0.35;  // luz extra hacia el centro
uniform float rim_level : hint_range(0.0, 1.0) = 0.45;     // intensidad en el borde
uniform float bubble_strength : hint_range(0.0, 1.0) = 0.3;
uniform float bubble_speed = 0.02;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	q.y = -q.y;
	float r = length(q);
	// Centro de luz algo desplazado hacia arriba
	float g = mix(1.0 + center_boost, rim_level, smoothstep(0.0, 1.0, length(q - vec2(-0.15, 0.25))));
	// Burbujas: aros claros que suben y reaparecen abajo
	float b = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i) + disc_seed * 7.13;
		float size = mix(0.1, 0.22, hash(fi * 3.7));
		float x = mix(-0.55, 0.55, hash(fi * 1.3));
		float y = fract(hash(fi * 5.1) + TIME * bubble_speed * (0.7 + hash(fi * 2.9))) * 2.4 - 1.2;
		float d = length(q - vec2(x, y));
		b += smoothstep(size, size * 0.8, d) * smoothstep(size * 0.55, size * 0.85, d);
	}
	vec3 col = disc_color * disc_energy * g;
	col += disc_color * disc_energy * b * bubble_strength + vec3(b * bubble_strength * 0.25);
	ALBEDO = col * smoothstep(1.0, 0.97, r);
}
