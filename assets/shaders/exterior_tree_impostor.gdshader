shader_type spatial;
render_mode unshaded, cull_disabled;
// Árboles lejanos como impostores: cada instancia (MultiMesh) es un rectángulo vertical que
// gira sobre el eje Y hacia la cámara y muestra una de las vistas del atlas (renderizado
// del árbol destacado con sus materiales, ver scripts/tools/bake_tree_impostors.gd).
// INSTANCE_CUSTOM.r = índice de la vista; INSTANCE_CUSTOM.g = variación de brillo.
#include "res://assets/shaders/exterior_common.gdshaderinc"

uniform sampler2D atlas_texture : source_color, filter_linear_mipmap;
uniform vec2 atlas_grid = vec2(2.0, 2.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.35;
uniform float exposure = 2.0;               // el atlas se renderiza a media exposición
uniform float sway_strength = 0.012;        // vaivén de la copa (fracción de la altura)
uniform float alpha_mip_scale = 0.35;

// Nivel de mip aproximado: a distancia los mipmaps promedian el alpha de las hojas finas
// por debajo del umbral y la copa se vacía; se compensa subiendo el alpha con el mip.
float leaf_mip_level(vec2 uv, vec2 size) {
	vec2 dx = dFdx(uv * size);
	vec2 dy = dFdy(uv * size);
	return max(0.5 * log2(max(dot(dx, dx), dot(dy, dy))), 0.0);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(1e-4, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	float top = clamp(VERTEX.y / 12.0, 0.0, 1.0);
	float sway = sin(TIME * 0.8 + origin.x * 0.05) * sway_strength * top * top;
	vec3 wp = origin + right * (VERTEX.x + sway * 12.0) * sx + vec3(0.0, VERTEX.y * sy, 0.0);
	world_pos = wp;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	float cell = floor(INSTANCE_CUSTOM.r + 0.5);
	vec2 grid_pos = vec2(mod(cell, atlas_grid.x), floor(cell / atlas_grid.x));
	UV = (UV + grid_pos) / atlas_grid;
	COLOR = vec4(INSTANCE_CUSTOM.g);
}

void fragment() {
	vec4 tex = texture(atlas_texture, UV);
	ALBEDO = tex.rgb * exposure * (0.85 + 0.3 * COLOR.r);
	ALPHA = tex.a * (1.0 + leaf_mip_level(UV, vec2(textureSize(atlas_texture, 0))) * alpha_mip_scale);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	FOG = exterior_haze(world_pos, CAMERA_POSITION_WORLD);
}
