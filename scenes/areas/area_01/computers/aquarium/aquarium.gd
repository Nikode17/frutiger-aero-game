extends Node3D
## Escena 3D del salvapantallas de acuario de la pantalla grande del entrante. Se
## renderiza en un SubViewport con su propio mundo. Aquí se genera todo: cámara, luz desde
## arriba y niebla azul, telón de fondo (agua, rayos y ciudad difusa), arena con cáusticas,
## algas, haces de luz y burbujas, y se mueven peces y medusas.

@export var random_seed: int = 2003

@export_group("Encuadre")
@export var camera_distance: float = 1.45      # La cámara mira hacia -Z desde z = camera_distance
@export var camera_fov: float = 40.0
@export var view_aspect: float = 2.63         # Ancho / alto de la pantalla
@export var floor_height: float = -0.6
@export var camera_pitch_deg: float = 5.0     # Inclinación hacia arriba para ver más agua
@export var backdrop_z: float = -3.0
@export var near_z: float = 0.75               # Profundidad más cercana para peces y medusas
@export var far_z: float = -1.6               # Profundidad más lejana

@export_group("Peces")
@export var fish_scenes: Array[PackedScene] = [
	preload("res://assets/models/area_01/aquarium/fish_yellow_tang.glb"),
	preload("res://assets/models/area_01/aquarium/fish_flame_angel.glb"),
	preload("res://assets/models/area_01/aquarium/fish_clark_clown.glb"),
	preload("res://assets/models/area_01/aquarium/fish_butterfly.glb"),
]
## Longitud de cada especie (m), en el mismo orden que fish_scenes
@export var fish_lengths: Array[float] = [0.2, 0.12, 0.12, 0.17]
## Grupos: cada entrada es [especie, número de peces]
@export var fish_groups: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 3), Vector2i(0, 1)]
@export var fish_speed_range: Vector2 = Vector2(0.1, 0.22)   # m/s
@export var fish_scale: float = 1.25                          # Tamaño de los peces respecto al real

@export_group("Medusas")
@export var jelly_scene: PackedScene = preload("res://assets/models/area_01/aquarium/jellyfish.glb")
@export_range(0, 6) var jelly_count: int = 3
@export var jelly_scale_range: Vector2 = Vector2(0.7, 1.1)

@export_group("Entorno")
@export var backdrop_shader: Shader = preload("res://assets/shaders/aquarium_backdrop.gdshader")
@export var sand_shader: Shader = preload("res://assets/shaders/aquarium_sand.gdshader")
@export var seaweed_shader: Shader = preload("res://assets/shaders/aquarium_seaweed.gdshader")
@export var shaft_shader: Shader = preload("res://assets/shaders/aquarium_light_shaft.gdshader")
@export_range(0, 80) var seaweed_count: int = 34
@export_range(0, 12) var shaft_count: int = 5
@export_range(0, 300) var bubble_amount: int = 70
@export var water_color: Color = Color(0.1, 0.4, 0.72)
@export var fog_density: float = 0.16

var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
var _swimmers: Array = []   # Diccionarios con el estado de cada pez
var _jellies: Array = []


func _ready() -> void:
	_rng.seed = random_seed
	_build_environment()
	_build_backdrop_and_sand()
	_build_seaweed()
	_build_light_shafts()
	_build_bubbles()
	_spawn_fish()
	_spawn_jellies()


func _process(delta: float) -> void:
	_time += delta
	for s in _swimmers:
		_update_swimmer(s, delta)
	for j in _jellies:
		_update_jelly(j, delta)


# --- Encuadre -----------------------------------------------------------------------

## Mitad del ancho visible a la profundidad z.
func _half_width(z: float) -> float:
	return (camera_distance - z) * tan(deg_to_rad(camera_fov * 0.5)) * view_aspect


func _half_height(z: float) -> float:
	return (camera_distance - z) * tan(deg_to_rad(camera_fov * 0.5))


# --- Entorno ------------------------------------------------------------------------

func _build_environment() -> void:
	var cam := Camera3D.new()
	cam.fov = camera_fov
	cam.position = Vector3(0.0, 0.0, camera_distance)
	cam.rotation_degrees.x = camera_pitch_deg
	cam.far = camera_distance - backdrop_z + 2.0
	cam.current = true
	add_child(cam)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = water_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.68, 0.95)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = water_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Luz desde la superficie, algo inclinada
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-68.0, 20.0, 0.0)
	sun.light_color = Color(0.85, 0.97, 1.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)


func _build_backdrop_and_sand() -> void:
	# Telón: la línea de la arena (90 % de la altura) coincide con el suelo 3D
	var h := _half_height(backdrop_z) * 2.0 * 1.45
	var w := _half_width(backdrop_z) * 2.0 * 1.1
	var backdrop := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	backdrop.mesh = quad
	backdrop.position = Vector3(0.0, floor_height + h * 0.4, backdrop_z)
	var bmat := ShaderMaterial.new()
	bmat.shader = backdrop_shader
	bmat.set_shader_parameter("aspect", w / h)
	backdrop.material_override = bmat
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)

	var sand := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var depth := camera_distance - backdrop_z
	plane.size = Vector2(w, depth)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	sand.mesh = plane
	sand.position = Vector3(0.0, floor_height, backdrop_z + depth * 0.5)
	var smat := ShaderMaterial.new()
	smat.shader = sand_shader
	sand.material_override = smat
	add_child(sand)


func _build_seaweed() -> void:
	if seaweed_count <= 0:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var greens := [Color(0.18, 0.62, 0.3), Color(0.4, 0.78, 0.25), Color(0.12, 0.5, 0.38), Color(0.55, 0.8, 0.3)]
	var base_index := 0
	for k in seaweed_count:
		var z := _rng.randf_range(backdrop_z + 0.4, near_z)
		var x := _rng.randf_range(-_half_width(z), _half_width(z))
		var height := _rng.randf_range(0.18, 0.55)
		var width := _rng.randf_range(0.025, 0.06)
		var yaw := _rng.randf_range(-0.6, 0.6)
		var col: Color = greens[_rng.randi() % greens.size()].srgb_to_linear()
		var phase := _rng.randf() * TAU
		var bend := _rng.randf_range(-0.08, 0.08)
		var right := Vector3(cos(yaw), 0.0, sin(yaw))
		var segs := 10
		for s in segs + 1:
			var t := float(s) / float(segs)
			var center := Vector3(x + bend * t * t, floor_height + t * height, z)
			var half := width * 0.5 * (1.0 - 0.8 * t) * (0.7 + 0.3 * sin(t * 9.0 + phase))
			for side in [-1.0, 1.0]:
				st.set_color(col.darkened(0.25 * (1.0 - t)))
				st.set_uv(Vector2(0.5 + 0.5 * side, t))
				st.set_uv2(Vector2(phase, 0.0))
				st.set_normal(Vector3(-sin(yaw), 0.0, cos(yaw)))
				st.add_vertex(center + right * half * side)
		for s in segs:
			var a := base_index + s * 2
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + 3)
			st.add_index(a)
			st.add_index(a + 3)
			st.add_index(a + 2)
		base_index += (segs + 1) * 2
	var weeds := MeshInstance3D.new()
	weeds.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = seaweed_shader
	weeds.material_override = mat
	add_child(weeds)


func _build_light_shafts() -> void:
	for k in shaft_count:
		var shaft := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(_rng.randf_range(0.25, 0.5), 3.2)
		shaft.mesh = quad
		var z := _rng.randf_range(far_z, 0.0)
		shaft.position = Vector3(_rng.randf_range(-_half_width(z), _half_width(z)), 0.6, z)
		shaft.rotation = Vector3(0.0, 0.0, deg_to_rad(_rng.randf_range(12.0, 22.0)))
		var mat := ShaderMaterial.new()
		mat.shader = shaft_shader
		shaft.material_override = mat
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shaft)
		shaft.set_instance_shader_parameter("shaft_phase", _rng.randf() * TAU)


func _build_bubbles() -> void:
	if bubble_amount <= 0:
		return
	var particles := GPUParticles3D.new()
	particles.amount = bubble_amount
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.visibility_aabb = AABB(Vector3(-5, -2, -4), Vector3(10, 5, 6))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(_half_width(far_z), 0.02, (near_z - far_z) * 0.5)
	process.direction = Vector3(0, 1, 0)
	process.spread = 8.0
	process.initial_velocity_min = 0.12
	process.initial_velocity_max = 0.22
	process.gravity = Vector3(0, 0.02, 0)
	process.scale_min = 0.4
	process.scale_max = 1.2
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.3
	process.turbulence_noise_scale = 1.5
	process.turbulence_influence_min = 0.02
	process.turbulence_influence_max = 0.06
	particles.process_material = process
	particles.position = Vector3(0.0, floor_height + 0.02, (near_z + far_z) * 0.5)
	# Burbuja: aro claro con el centro casi transparente (gradiente radial, sin imágenes)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 0.85, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.albedo_texture = tex
	mat.albedo_color = Color(0.9, 0.98, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.018)
	quad.material = mat
	particles.draw_pass_1 = quad
	add_child(particles)


# --- Peces --------------------------------------------------------------------------

func _spawn_fish() -> void:
	for g in fish_groups:
		var species := clampi(g.x, 0, fish_scenes.size() - 1)
		var count := maxi(g.y, 1)
		var length := fish_lengths[species] * _rng.randf_range(0.9, 1.1)
		var leader := {
			"direction": 1.0 if _rng.randf() < 0.5 else -1.0,
			"speed": _rng.randf_range(fish_speed_range.x, fish_speed_range.y),
			"depth": _rng.randf_range(far_z, near_z * 0.6),
			"base_y": _rng.randf_range(floor_height + 0.18, 0.45),
			"phase": _rng.randf() * TAU,
			"x": 0.0,
		}
		leader["x"] = _rng.randf_range(-_half_width(leader["depth"]), _half_width(leader["depth"]))
		for m in count:
			var fish: Node3D = fish_scenes[species].instantiate()
			fish.scale = Vector3.ONE * fish_scale
			add_child(fish)
			var offset := Vector3.ZERO
			if m > 0:
				offset = Vector3(-leader["direction"] * _rng.randf_range(0.12, 0.35), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.15, 0.15))
			var s := leader.duplicate()
			s["node"] = fish
			s["offset"] = offset
			s["own_phase"] = _rng.randf() * TAU
			s["length"] = length
			_swimmers.append(s)
			for mi: MeshInstance3D in fish.find_children("*", "MeshInstance3D", true, false):
				mi.set_instance_shader_parameter("swim_phase", s["own_phase"])
				mi.set_instance_shader_parameter("swim_speed", 0.7 + s["speed"] * 2.5)
				mi.set_instance_shader_parameter("body_length", length)
			_update_swimmer(s, 0.0)


func _update_swimmer(s: Dictionary, delta: float) -> void:
	var dir: float = s["direction"]
	s["x"] += dir * s["speed"] * delta
	var t := _time + float(s["phase"])
	var own: float = s["own_phase"]
	var off: Vector3 = s["offset"]
	var z: float = s["depth"] + sin(t * 0.23) * 0.25 + off.z
	var y: float = s["base_y"] + sin(t * 0.41) * 0.08 + sin(_time * 0.9 + own) * 0.015 + off.y
	var x: float = s["x"] + off.x + sin(_time * 0.7 + own) * 0.02
	# Reaparece por el otro lado cuando sale del encuadre
	var limit := _half_width(z) + 0.4
	if dir > 0.0 and s["x"] > limit + 0.4:
		s["x"] = -limit - 0.4
	elif dir < 0.0 and s["x"] < -limit - 0.4:
		s["x"] = limit + 0.4
	var node: Node3D = s["node"]
	var new_pos := Vector3(x, y, z)
	var vel := Vector3(dir * s["speed"], cos(t * 0.41) * 0.41 * 0.08, cos(t * 0.23) * 0.23 * 0.25)
	node.position = new_pos
	if vel.length_squared() > 1e-6:
		var target := Basis.looking_at(vel.normalized(), Vector3.UP, true)
		var current := node.basis.orthonormalized()
		node.basis = (current.slerp(target, clampf(delta * 3.0, 0.0, 1.0)) if delta > 0.0 else target).scaled(Vector3.ONE * fish_scale)


# --- Medusas ------------------------------------------------------------------------

func _spawn_jellies() -> void:
	for k in jelly_count:
		var jelly: Node3D = jelly_scene.instantiate()
		add_child(jelly)
		var z := _rng.randf_range(far_z * 0.8, near_z * 0.5)
		var sc := _rng.randf_range(jelly_scale_range.x, jelly_scale_range.y)
		jelly.scale = Vector3.ONE * sc
		var phase := _rng.randf() * TAU
		for mi: MeshInstance3D in jelly.find_children("*", "MeshInstance3D", true, false):
			mi.set_instance_shader_parameter("pulse_phase", phase)
		var j := {
			"node": jelly,
			"phase": phase,
			"pos": Vector3(_rng.randf_range(-_half_width(z) * 0.8, _half_width(z) * 0.8), _rng.randf_range(floor_height + 0.3, 0.4), z),
			"drift": _rng.randf_range(-0.02, 0.02),
		}
		_jellies.append(j)
		_update_jelly(j, 0.0)


func _update_jelly(j: Dictionary, delta: float) -> void:
	var phase: float = j["phase"]
	# Sube a impulsos, al ritmo de la pulsación de la campana (misma frecuencia que el shader)
	var pulse := maxf(sin(_time * 1.5 + phase + 1.2), 0.0)
	var pos: Vector3 = j["pos"]
	pos.y += (0.006 + pulse * 0.03) * delta
	pos.x += j["drift"] * delta
	if pos.y > _half_height(pos.z) + 0.25:
		pos.y = floor_height - 0.1
		pos.x = _rng.randf_range(-_half_width(pos.z) * 0.8, _half_width(pos.z) * 0.8)
	j["pos"] = pos
	var node: Node3D = j["node"]
	node.position = pos
	node.rotation = Vector3(sin(_time * 0.3 + phase) * 0.12, _time * 0.05 + phase, cos(_time * 0.27 + phase) * 0.1)
