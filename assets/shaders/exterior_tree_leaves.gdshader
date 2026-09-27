shader_type spatial;
render_mode cull_disabled;
// Hojas del árbol del exterior (tarjetas con atlas de hojas y alpha scissor): tono avivado
// hacia un verde Frutiger Aero, translucidez (la luz del sol atraviesa las hojas),
// vaivén con el viento y un aleteo fino. Proyecta sombra moteada con el mismo recorte.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform vec3 leaf_tint = vec3(0.62, 1.55, 0.42);     // multiplica el color (lineal)
uniform float saturation = 1.45;
uniform float brightness = 1.0;
uniform float normal_strength = 0.45;
uniform float translucency : hint_range(0.0, 1.0) = 0.65;
uniform float flutter_strength = 0.015;              // m
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.55;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.3;
uniform float alpha_mip_scale = 0.4;

// Nivel de mip aproximado: a distancia los mipmaps promedian el alpha de las hojas finas
// por debajo del umbral y la copa se vacía; se compensa subiendo el alpha con el mip.
float leaf_mip_level(vec2 uv, vec2 size) {
	vec2 dx = dFdx(uv * size);
	vec2 dy = dFdy(uv * size);
	return max(0.5 * log2(max(dot(dx, dx), dot(dy, dy))), 0.0);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	VERTEX += tree_wind(VERTEX, origin);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * sin(TIME * 5.3 + dot(wp, vec3(2.1, 1.7, 1.3))) * flutter_strength;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 c = tex.rgb;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = max(mix(vec3(l), c, saturation), vec3(0.0)) * leaf_tint * brightness;
	ALBEDO = c;
	ALPHA = tex.a * (1.0 + leaf_mip_level(UV, vec2(textureSize(albedo_texture, 0))) * alpha_mip_scale);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = roughness_amount;
	SPECULAR = specular_amount;
	BACKLIGHT = c * translucency;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
