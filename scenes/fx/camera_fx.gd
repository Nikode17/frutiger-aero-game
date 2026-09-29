class_name CameraFx
extends Node
## Efectos de cámara comunes a las áreas con sol: destello de estrella y lens flare
## (quad a pantalla completa con sun_flare.gdshader, que se oculta solo con lo que tapa
## el sol), una viñeta ligera y un enfoque suave que compensa el TAA cuando está activo.
## Sigue a la cámara activa del viewport en cada frame.

## DirectionalLight3D que hace de sol. Si está vacío, se usa el primero que haya en la escena.
@export var sun_path: NodePath

@export_group("Destello")
@export var flare_enabled: bool = true
@export_range(0.0, 4.0, 0.05) var flare_intensity: float = 1.0
## Ángulo (grados) entre la mirada y el sol a partir del cual el destello empieza a apagarse
@export_range(10.0, 90.0, 1.0) var fade_start_deg: float = 30.0
## Ángulo a partir del cual el destello ya no se dibuja
@export_range(10.0, 120.0, 1.0) var fade_end_deg: float = 55.0

@export_group("Viñeta")
@export var vignette_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.25

@export_group("Enfoque")
## Enfoque del pase final; solo se aplica con TAA, que suaviza la imagen
@export_range(0.0, 1.5, 0.05) var taa_sharpen: float = 0.8

@onready var _flare: MeshInstance3D = $Flare
@onready var _vignette: CanvasItem = $Vignette/Rect

var _sun: DirectionalLight3D


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun == null:
		_sun = _find_sun(get_tree().current_scene if get_tree().current_scene else get_tree().root)
	# El quad cubre la pantalla desde el vertex shader: que nunca se descarte por frustum
	_flare.extra_cull_margin = 16384.0
	_flare.visible = false


func _process(_delta: float) -> void:
	var mat := _vignette.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("strength", vignette_strength if vignette_enabled else 0.0)
		mat.set_shader_parameter("sharpen", taa_sharpen if get_viewport().use_taa else 0.0)
	_update_flare()


func _update_flare() -> void:
	var cam := get_viewport().get_camera_3d()
	if not flare_enabled or cam == null or _sun == null or not _sun.is_visible_in_tree():
		_flare.visible = false
		return
	var to_sun := _sun.global_transform.basis.z.normalized()
	var forward := -cam.global_transform.basis.z.normalized()
	var angle := rad_to_deg(forward.angle_to(to_sun))
	var fade := 1.0 - smoothstep(fade_start_deg, fade_end_deg, angle)
	var sun_point := cam.global_position + to_sun * cam.far * 0.5
	if fade <= 0.0 or cam.is_position_behind(sun_point):
		_flare.visible = false
		return
	var size := get_viewport().get_visible_rect().size
	var uv := cam.unproject_position(sun_point) / size
	# Se apaga también si el sol queda bastante fuera del encuadre
	var outside := maxf(maxf(-uv.x, uv.x - 1.0), maxf(-uv.y, uv.y - 1.0))
	fade *= 1.0 - smoothstep(0.0, 0.25, outside)
	if fade <= 0.001:
		_flare.visible = false
		return
	_flare.visible = true
	_flare.global_position = cam.global_position
	var fm := _flare.material_override as ShaderMaterial
	fm.set_shader_parameter("sun_uv", uv)
	fm.set_shader_parameter("sun_fade", fade)
	fm.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	fm.set_shader_parameter("intensity", flare_intensity)
	fm.set_shader_parameter("sun_color", _sun.light_color)


func _find_sun(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D and (node as DirectionalLight3D).sky_mode != DirectionalLight3D.SKY_MODE_SKY_ONLY:
		return node
	for child in node.get_children():
		var found := _find_sun(child)
		if found:
			return found
	return null
