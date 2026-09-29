extends CanvasLayer
## Autoload GraphicsQuality: selector de calidad gráfica Alta / Media / Baja para comparar
## rendimiento. Se cambia en ciclo con la acción "cycle_quality" (F4) y se guarda en
## user://graficos.cfg. "Alta" usa los valores tal como están en la escena; Media y Baja
## abaratan a partir de ellos. Alta: SDFGI a resolución completa y reflejo planar en el
## suelo (PlanarReflection); Media y Baja: sin SDFGI y el suelo con las sondas de reflexión.

signal level_changed(level: int)

enum Level { BAJA, MEDIA, ALTA }
const LEVEL_NAMES: Array[String] = ["Baja", "Media", "Alta"]
const CONFIG_PATH := "user://graficos.cfg"

@export var label_seconds: float = 2.0

var level: int = Level.ALTA

var _label: Label
var _label_time: float = 0.0
# Valores originales de cada Environment (por id de instancia), para volver a Alta
var _env_defaults: Dictionary = {}


func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.12, 0.25, 0.8))
	_label.add_theme_constant_override("outline_size", 6)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_label.position = Vector2(16.0, 12.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		level = clampi(int(cfg.get_value("graficos", "calidad", Level.ALTA)), Level.BAJA, Level.ALTA)
	# Esperar a que la escena principal tenga su WorldEnvironment y sus luces
	_apply.call_deferred(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_quality"):
		# Alta -> Media -> Baja -> Alta
		set_level((level + 2) % 3)


func _process(delta: float) -> void:
	if _label.visible:
		_label_time -= delta
		if _label_time <= 0.0:
			_label.visible = false


func set_level(new_level: int) -> void:
	level = clampi(new_level, Level.BAJA, Level.ALTA)
	var cfg := ConfigFile.new()
	cfg.set_value("graficos", "calidad", level)
	cfg.save(CONFIG_PATH)
	_apply(true)


func _apply(show_label: bool) -> void:
	var high := level == Level.ALTA
	var low := level == Level.BAJA
	var vp := get_viewport()

	# Ajustes globales del renderizador
	vp.use_taa = not low
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if low else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.gi_set_use_half_resolution(false)
	RenderingServer.environment_set_ssr_half_size(true)
	RenderingServer.environment_set_ssao_quality(
			RenderingServer.ENV_SSAO_QUALITY_MEDIUM if high else RenderingServer.ENV_SSAO_QUALITY_LOW,
			true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(48 if high else 32, 48 if high else 32)
	RenderingServer.directional_shadow_atlas_set_size(4096 if high else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_LOW if not low else RenderingServer.SHADOW_QUALITY_HARD)

	# Entorno de la escena
	var world := vp.find_world_3d()
	var env := world.environment if world else null
	if env:
		var d := _defaults_for(env)
		env.sdfgi_enabled = d.sdfgi_enabled and high
		env.ssr_enabled = d.ssr_enabled and not low
		env.ssr_max_steps = d.ssr_max_steps if high else mini(d.ssr_max_steps, 20)
		env.ssao_enabled = d.ssao_enabled and not low
		env.volumetric_fog_enabled = d.volumetric_fog_enabled and not low

	# Luces LED reales (los tubos emisivos siguen brillando)
	for light in get_tree().get_nodes_in_group(LedStrip.LIGHT_GROUP):
		(light as Light3D).visible = not low

	if show_label:
		_label.text = "Calidad gráfica: %s  (F4)" % LEVEL_NAMES[level]
		_label.visible = true
		_label_time = label_seconds
	level_changed.emit(level)


func _defaults_for(env: Environment) -> Dictionary:
	var id := env.get_instance_id()
	if not _env_defaults.has(id):
		_env_defaults[id] = {
			"sdfgi_enabled": env.sdfgi_enabled,
			"ssr_enabled": env.ssr_enabled,
			"ssr_max_steps": env.ssr_max_steps,
			"ssao_enabled": env.ssao_enabled,
			"volumetric_fog_enabled": env.volumetric_fog_enabled,
		}
	return _env_defaults[id]
