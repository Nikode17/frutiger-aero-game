class_name PlanarReflection
extends Node3D
## Reflejo planar para un suelo horizontal (calidad Alta). Una cámara reflejada respecto
## al plano del suelo renderiza la escena a un SubViewport de resolución reducida con un
## entorno barato (sin niebla volumétrica, SDFGI, SSR, SSAO ni glow). El shader del suelo
## (leaf_floor.gdshader) proyecta cada punto del suelo con la matriz de esa cámara y
## muestrea el reflejo, así que no depende de hacia dónde mira el jugador.
## La altura del plano es la posición Y de este nodo.

## Grupo de nodos que no aparecen en el reflejo (con todos sus descendientes): lo que
## queda por debajo del suelo, como el terreno exterior, y objetos pequeños.
const HIDDEN_GROUP := &"no_planar_reflection"
## Capa visual que usan los objetos ocultos al reflejo (la cámara principal la ve)
const HIDDEN_LAYER_BIT := 19

@export var floor_material: ShaderMaterial
@export_range(0.1, 1.0, 0.05) var resolution_scale: float = 0.5
@export var active: bool = true
## Oculta al reflejo todas las partículas (burbujas, etc.): son pequeñas y caras
@export var hide_particles: bool = true

var _viewport: SubViewport
var _camera: Camera3D
var _environment: Environment


func _ready() -> void:
	add_to_group(&"planar_reflection")
	process_priority = 100   # después del jugador, para usar la cámara de este frame
	_viewport = SubViewport.new()
	_viewport.name = "ReflectionViewport"
	_viewport.use_hdr_2d = true   # el reflejo se guarda en lineal, sin tonemap
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.positional_shadow_atlas_size = 0
	_viewport.world_3d = get_viewport().find_world_3d()
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.name = "ReflectionCamera"
	_camera.cull_mask = 0xFFFFF & ~(1 << HIDDEN_LAYER_BIT)
	_viewport.add_child(_camera)
	_camera.current = true
	if floor_material:
		floor_material.set_shader_parameter("planar_tex", _viewport.get_texture())
	# Esperar a que las demás escenas generen su geometría antes de marcar capas
	_setup_deferred.call_deferred()
	if has_node("/root/GraphicsQuality"):
		var gq := get_node("/root/GraphicsQuality")
		gq.level_changed.connect(_on_quality_changed)
		_on_quality_changed(gq.level)
	else:
		set_active(active)


func _setup_deferred() -> void:
	await get_tree().process_frame
	_environment = _make_cheap_environment()
	_camera.environment = _environment
	for node in get_tree().get_nodes_in_group(HIDDEN_GROUP):
		_hide_from_reflection(node)
	if hide_particles:
		_hide_particles(get_tree().root)


func _on_quality_changed(level: int) -> void:
	# Solo en Alta (2); en Media y Baja el suelo usa las sondas de reflexión
	set_active(level == 2)


func set_active(value: bool) -> void:
	active = value
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	if floor_material:
		floor_material.set_shader_parameter("planar_strength", 1.0 if value else 0.0)


func _process(_delta: float) -> void:
	if not active:
		return
	var main_cam := get_viewport().get_camera_3d()
	if main_cam == null:
		return
	var size := Vector2i((get_viewport().get_visible_rect().size * resolution_scale).round())
	if _viewport.size != size:
		_viewport.size = size
	_camera.fov = main_cam.fov
	_camera.near = main_cam.near
	_camera.far = main_cam.far
	_camera.keep_aspect = main_cam.keep_aspect
	# Cámara reflejada respecto al plano y = altura del nodo. Se construye como rotación
	# normal (la imagen sale volteada en horizontal), pero el shader proyecta con su propia
	# matriz, así que da igual.
	var h := global_position.y
	var t := main_cam.global_transform
	var pos := Vector3(t.origin.x, 2.0 * h - t.origin.y, t.origin.z)
	var fwd := -t.basis.z
	var up := t.basis.y
	fwd.y = -fwd.y
	up.y = -up.y
	_camera.global_transform = Transform3D(Basis.looking_at(fwd, up), pos)
	if floor_material:
		var view_proj := Projection(_camera.get_camera_projection()) * Projection(_camera.global_transform.affine_inverse())
		floor_material.set_shader_parameter("planar_view_proj", view_proj)


## Copia del entorno de la escena sin lo caro y sin tonemap (el reflejo se guarda en
## lineal y el tonemap y el glow se aplican luego en la imagen principal).
func _make_cheap_environment() -> Environment:
	var world := get_viewport().find_world_3d()
	var env: Environment = world.environment.duplicate() if world and world.environment else Environment.new()
	env.volumetric_fog_enabled = false
	env.sdfgi_enabled = false
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.glow_enabled = false
	env.fog_enabled = false
	env.adjustment_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	return env


func _hide_from_reflection(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = 1 << HIDDEN_LAYER_BIT
	for child in node.get_children():
		_hide_from_reflection(child)


func _hide_particles(node: Node) -> void:
	if node is GPUParticles3D or node is CPUParticles3D:
		(node as GeometryInstance3D).layers = 1 << HIDDEN_LAYER_BIT
	for child in node.get_children():
		_hide_particles(child)
