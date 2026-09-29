shader_type spatial;
// Halo de luz en la pared (glow_halo): anillo aditivo sin luz sobre un quad, del borde de
// una pieza retroiluminada hacia fuera, con caída suave. Color e intensidad por instancia.
// inner_radius es la fracción del quad (0-1) donde empieza el halo (borde de la pieza).
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

instance uniform vec3 halo_color : source_color = vec3(0.3, 0.85, 1.0);
instance uniform float halo_energy = 0.35;
instance uniform float inner_radius = 0.5;
uniform float falloff : hint_range(0.5, 6.0) = 2.2;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float t = clamp((r - inner_radius) / max(1.0 - inner_radius, 0.001), 0.0, 1.0);
	float a = pow(1.0 - t, falloff) * step(inner_radius * 0.97, r);
	ALBEDO = halo_color * halo_energy * a;
}
