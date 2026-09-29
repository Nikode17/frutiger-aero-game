shader_type spatial;
// Cromo "de estudio" (chrome_bezel): metal pulido que mezcla el reflejo real de la sala con
// un entorno de estudio falso según la dirección reflejada (mundo): fondo gris neutro,
// franja oscura en el horizonte, suelo algo más oscuro, brillo blanco arriba y unas tiras
// verticales de luz. Así el cromo muestra brillos y zonas oscuras y se lee como metal
// aunque la sala entera sea azul (el cromo liso solo refleja azul y parece plástico).
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.95, 0.94, 0.91);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.09;
uniform float reflection_amount : hint_range(0.0, 1.0) = 0.5;   // cuánto queda del reflejo real (azul)
uniform float studio_level : hint_range(0.0, 1.0) = 0.3;        // gris neutro del entorno falso
uniform float horizon_dark : hint_range(0.0, 1.0) = 0.12;       // multiplicador en la franja del horizonte
uniform float horizon_width : hint_range(0.02, 0.6) = 0.14;
uniform float horizon_height : hint_range(-0.5, 0.5) = -0.03;
uniform float floor_level : hint_range(0.0, 1.0) = 0.55;        // multiplicador de lo que refleja el suelo
uniform vec3 light_color : source_color = vec3(1.0, 0.99, 0.96);
uniform float top_strength : hint_range(0.0, 2.0) = 0.7;        // brillo de la "luz cenital"
uniform float strip_strength : hint_range(0.0, 2.0) = 0.6;      // tiras verticales de luz
uniform float strip_count = 3.0;
uniform float strip_sharpness = 40.0;


void fragment() {
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v_w, n_w);
	float y = r.y;
	float az = atan(r.z, r.x);

	float horizon = exp(-pow((y - horizon_height) / horizon_width, 2.0));
	float env = mix(floor_level, 1.0, smoothstep(-0.4, 0.05, y));
	env *= 1.0 - (1.0 - horizon_dark) * horizon;

	float top_box = smoothstep(0.5, 0.85, y);
	float strips = pow(max(cos(az * strip_count + 0.7), 0.0), strip_sharpness)
			* smoothstep(-0.1, 0.25, y) * (1.0 - top_box);

	ALBEDO = base_color * reflection_amount * env;
	METALLIC = 1.0;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.5;
	EMISSION = light_color * (env * studio_level + (top_box * top_strength + strips * strip_strength) * (1.0 - horizon));
}
