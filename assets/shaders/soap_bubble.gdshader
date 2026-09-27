shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;
// Pompa de jabón: casi invisible de frente, bordes iridiscentes (película fina) con remolinos
// de color que se mueven, y un brillo especular marcado.
#include "res://assets/shaders/exterior_common.gdshaderinc"

instance uniform float swirl_phase = 0.0;
uniform float base_alpha = 0.04;
uniform float rim_alpha = 0.55;
uniform float iridescence = 1.2;

vec3 thin_film(float t) {
	// Paleta arcoíris suave (cian, magenta, amarillo) según el "grosor" de la película
	return 0.5 + 0.5 * cos(6.2831 * (t + vec3(0.0, 0.33, 0.67)));
}

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 lp = normalize(local_pos);
	float swirl = ext_noise(lp.xy * 3.0 + vec2(TIME * 0.15 + swirl_phase, lp.z * 2.0)) * 0.6
			+ lp.y * 0.4 + TIME * 0.05;
	vec3 film = thin_film(swirl + fres * 0.8);
	ALBEDO = vec3(1.0);
	ALPHA = clamp(base_alpha + fres * rim_alpha, 0.0, 1.0);
	ROUGHNESS = 0.02;
	SPECULAR = 1.0;
	EMISSION = film * fres * iridescence * 0.5;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
