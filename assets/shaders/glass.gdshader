shader_type spatial;
// Cristal de la biblioteca (glass_clear, glass_cyan): deja ver el fondo tintado con una
// refracción sutil, se vuelve más opaco y reflectante en ángulo rasante (Fresnel) y
// conserva el reflejo especular completo (no se atenúa con la transparencia).
// Lee la pantalla: lo transparente que quede detrás (otros cristales, burbujas) no se ve
// a través de él.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.93, 0.98, 1.0);          // tiñe lo que se ve a través
uniform vec3 surface_color : source_color = vec3(0.8, 0.93, 1.0);  // color del propio cristal
uniform float body_opacity : hint_range(0.0, 1.0) = 0.04;   // opacidad propia mirando de frente
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.45;   // opacidad propia en ángulo rasante
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float refraction : hint_range(0.0, 0.1) = 0.015;    // desplazamiento del fondo
uniform float roughness_value : hint_range(0.0, 1.0) = 0.02;
uniform float specular_value : hint_range(0.0, 1.0) = 0.6;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;


void fragment() {
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, fresnel_power);
	float opacity = mix(body_opacity, edge_opacity, fres);

	// Refracción: desplaza el fondo según la normal; si lo desplazado queda delante del
	// cristal (un objeto más cercano), se usa el fondo sin desplazar para que no se "cuele"
	vec2 ref_uv = SCREEN_UV - NORMAL.xy * refraction;
	float depth = texture(depth_tex, ref_uv).r;
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ref_uv * 2.0 - 1.0, depth, 1.0);
	if (view_pos.z / view_pos.w > VERTEX.z) {
		ref_uv = SCREEN_UV;
	}
	vec3 back = textureLod(screen_tex, ref_uv, roughness_value * 6.0).rgb;

	ALBEDO = surface_color * opacity;
	EMISSION = back * tint * (1.0 - opacity) * EXPOSURE;
	METALLIC = 0.0;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	ALPHA = 1.0;
}
