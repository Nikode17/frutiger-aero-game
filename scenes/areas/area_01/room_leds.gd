@tool
class_name RoomLeds
extends Node3D
## LED y focos de la propia sala, generados a partir de la geometría de RoomShell:
## halo en la junta del borde del tragaluz con el techo, tira de zócalo a ras de suelo
## que sigue toda la planta, anillo verde en la base de la columna y unos pocos focos
## empotrados en el techo. Las tiras son LedStrip (tubo emisivo y luces pequeñas).

@export_tool_button("Reconstruir LED") var rebuild_action: Callable = build

@export var room_shell: RoomShell
@export var cyan_material: Material
@export var green_material: Material
@export var downlight_material: Material
@export var bezel_material: Material

@export_group("Tragaluz")
@export var skylight_enabled: bool = true
@export var skylight_led_radius: float = 0.012
@export var skylight_gap: float = 0.02            # separación entre la tira y el tubo del borde
@export_range(0, 32) var skylight_lights: int = 10
@export var skylight_light_energy: float = 0.4
@export var skylight_light_range: float = 1.4

@export_group("Zócalo")
@export var skirting_enabled: bool = true
@export var skirting_height: float = 0.05         # altura de la tira sobre el suelo
@export var skirting_led_radius: float = 0.007
@export var skirting_gap: float = 0.005           # separación de la superficie
@export_range(0, 64) var skirting_lights: int = 24
@export var skirting_light_energy: float = 0.13
@export var skirting_light_range: float = 1.9
@export var skirting_light_inset: float = 0.3     # las luces van algo por dentro para bañar el suelo

@export_group("Columna")
@export var column_enabled: bool = true
@export var column_center: Vector3 = Vector3.ZERO
@export var column_ring_radius: float = 1.02
@export var column_led_radius: float = 0.008
@export_range(0, 12) var column_lights: int = 4
@export var column_light_energy: float = 0.2
@export var column_light_range: float = 1.0

@export_group("Focos")
@export var spots_enabled: bool = true
@export var spot_positions: PackedVector2Array = PackedVector2Array()   # (x, z) en el mundo del área
@export var spot_color: Color = Color(1.0, 0.97, 0.9)
@export var spot_energy: float = 1.5
@export var spot_range: float = 6.0
@export_range(5.0, 80.0, 0.5) var spot_angle_deg: float = 32.0
@export var spot_attenuation: float = 1.0
@export var spot_disk_radius: float = 0.07

const META_GENERATED := &"room_leds_generated"


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	if room_shell == null:
		return
	if room_shell._plan.is_empty():
		room_shell._build_plan()
	if skylight_enabled and room_shell.skylight_enabled:
		_build_skylight()
	if skirting_enabled:
		_build_skirting()
	if column_enabled:
		_build_column()
	if spots_enabled:
		_build_spots()


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


func _add_strip(node_name: String, pts: PackedVector3Array, mat: Material, radius: float,
		lights: int, color: Color, energy: float, light_range: float, offset: Vector3) -> LedStrip:
	var strip := LedStrip.new()
	strip.name = node_name
	strip.points = pts
	strip.closed = true
	strip.radius = radius
	strip.material = mat
	strip.light_count = lights
	strip.light_color = color
	strip.light_energy = energy
	strip.light_range = light_range
	strip.light_offset = offset
	strip.light_specular = 0.0
	_add_generated(strip)
	return strip


func _emission_color(mat: Material, fallback: Color) -> Color:
	var sm := mat as StandardMaterial3D
	return sm.emission if sm else fallback


# --- Tragaluz -------------------------------------------------------------------------

## Tira en la junta entre el tubo del borde y el techo, por el lado de fuera del hueco:
## desde abajo se ve como una línea de luz que dibuja el contorno del tragaluz.
func _build_skylight() -> void:
	var s := room_shell
	var n := s.skylight_rim_points
	var rim := PackedVector3Array()
	var nrm := PackedVector3Array()
	for k in n:
		var ang := TAU * float(k) / float(n)
		var limit := 1.0 + s.skylight_wave1.x * sin(3.0 * ang + s.skylight_wave1.y) \
				+ s.skylight_wave2.x * sin(5.0 * ang + s.skylight_wave2.y)
		var x := s.skylight_center.x + s.skylight_radius.x * limit * cos(ang)
		var z := s.skylight_center.y + s.skylight_radius.y * limit * sin(ang)
		var theta := atan2(z, x)
		var psi := s._ceiling_psi(x, z)
		rim.append(s._surface_point(theta, psi))
		nrm.append(s._interior_normal(theta, psi))
	var pts := PackedVector3Array()
	var center := Vector3(s.skylight_center.x, 0.0, s.skylight_center.y)
	for k in n:
		var tangent := rim[(k + 1) % n] - rim[(k - 1 + n) % n]
		var out := tangent.cross(nrm[k]).normalized()
		# Que apunte hacia fuera del hueco
		var radial := rim[k] - center
		radial.y = 0.0
		if out.dot(radial) < 0.0:
			out = -out
		var dist := s.skylight_rim_radius + skylight_gap + skylight_led_radius
		pts.append(rim[k] + out * dist + nrm[k] * skylight_led_radius)
	var col := _emission_color(cyan_material, Color(0.3, 0.85, 1.0))
	_add_strip("SkylightLed", pts, cyan_material, skylight_led_radius, skylight_lights, col,
			skylight_light_energy, skylight_light_range, Vector3(0.0, -0.12, 0.0))


# --- Zócalo ---------------------------------------------------------------------------

## Tira continua a ras de suelo en la curva suelo-pared, siguiendo toda la planta
## (incluido el entrante de ordenadores).
func _build_skirting() -> void:
	var s := room_shell
	var plan := s._plan
	var n := plan.size()
	var psi := s._wall_psi(skirting_height)
	var prof := s._profile(psi)
	# Derivada del perfil para la normal en el plano vertical
	var d := 1e-3
	var pa := s._profile(psi - d)
	var pb := s._profile(psi + d)
	var step := maxi(int(float(n) / 144.0), 1)
	var pts := PackedVector3Array()
	for k in range(0, n, step):
		var p2 := plan[k]
		var surface := Vector3(p2.x * prof.x, prof.y, p2.y * prof.x)
		# Normal: producto de las tangentes a lo largo de la planta y del perfil
		var t_plan := plan[(k + 1) % n] - plan[(k - 1 + n) % n]
		var t_around := Vector3(t_plan.x, 0.0, t_plan.y) * prof.x
		var t_up := Vector3(p2.x * (pb.x - pa.x), pb.y - pa.y, p2.y * (pb.x - pa.x))
		var normal := t_up.cross(t_around).normalized()
		# Hacia dentro de la sala: hacia arriba en la curva del suelo
		if normal.y < 0.0:
			normal = -normal
		pts.append(surface + normal * (skirting_led_radius + skirting_gap))
	var col := _emission_color(cyan_material, Color(0.3, 0.85, 1.0))
	var strip := _add_strip("SkirtingLed", pts, cyan_material, skirting_led_radius, 0, col,
			skirting_light_energy, skirting_light_range, Vector3.ZERO)
	strip.spacing = 0.08
	_build_skirting_lights(pts, col)


## Luces del zócalo repartidas por longitud y desplazadas hacia el centro de la sala
## para que bañen el suelo junto a la pared.
func _build_skirting_lights(pts: PackedVector3Array, col: Color) -> void:
	if skirting_lights <= 0:
		return
	var n := pts.size()
	var acc := PackedFloat32Array([0.0])
	for j in range(1, n + 1):
		acc.append(acc[j - 1] + pts[j % n].distance_to(pts[j - 1]))
	var total := acc[n]
	var k := 0
	for i in skirting_lights:
		var target := total * float(i) / float(skirting_lights)
		while k < n - 1 and acc[k + 1] < target:
			k += 1
		var a := pts[k]
		var b := pts[(k + 1) % n]
		var span := acc[k + 1] - acc[k]
		var p := a.lerp(b, 0.0 if span <= 0.0 else (target - acc[k]) / span)
		var inward := Vector3(-p.x, 0.0, -p.z).normalized()
		var tangent := (b - a).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.dot(inward) < 0.0:
			side = -side
		var light := OmniLight3D.new()
		light.name = "SkirtingLight%d" % i
		light.position = p + side * skirting_light_inset + Vector3(0.0, 0.25, 0.0)
		light.light_color = col
		light.light_energy = skirting_light_energy
		light.light_specular = 0.0
		light.omni_range = skirting_light_range
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		LedStrip.setup_light(light)
		_add_generated(light)


# --- Columna --------------------------------------------------------------------------

func _build_column() -> void:
	var pts := PackedVector3Array()
	var n := 48
	for k in n:
		var a := TAU * float(k) / float(n)
		pts.append(column_center + Vector3(cos(a) * column_ring_radius, column_led_radius + 0.004, sin(a) * column_ring_radius))
	var col := _emission_color(green_material, Color(0.35, 1.0, 0.45))
	_add_strip("ColumnLed", pts, green_material, column_led_radius, column_lights, col,
			column_light_energy, column_light_range, Vector3(0.0, 0.1, 0.0))


# --- Focos empotrados -----------------------------------------------------------------

func _build_spots() -> void:
	var s := room_shell
	for i in spot_positions.size():
		var xz := spot_positions[i]
		var theta := atan2(xz.y, xz.x)
		var psi := s._ceiling_psi(xz.x, xz.y)
		var p := s._surface_point(theta, psi)
		var root := Node3D.new()
		root.name = "Downlight%d" % i
		root.position = p
		_add_generated(root)
		# Disco luminoso casi enrasado con el techo y aro fino
		var disk := MeshInstance3D.new()
		disk.name = "Disk"
		var cyl := CylinderMesh.new()
		cyl.top_radius = spot_disk_radius
		cyl.bottom_radius = spot_disk_radius
		cyl.height = 0.01
		cyl.radial_segments = 24
		cyl.rings = 1
		disk.mesh = cyl
		disk.position = Vector3(0.0, -0.004, 0.0)
		disk.material_override = downlight_material
		disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(disk)
		if bezel_material:
			var bezel := MeshInstance3D.new()
			bezel.name = "Bezel"
			var torus := TorusMesh.new()
			torus.inner_radius = spot_disk_radius
			torus.outer_radius = spot_disk_radius + 0.018
			torus.rings = 32
			torus.ring_segments = 8
			bezel.mesh = torus
			bezel.position = Vector3(0.0, -0.004, 0.0)
			bezel.material_override = bezel_material
			bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(bezel)
		var spot := SpotLight3D.new()
		spot.name = "Spot"
		spot.position = Vector3(0.0, -0.02, 0.0)
		# SpotLight3D alumbra hacia su -Z: girado para mirar al suelo
		spot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		spot.light_color = spot_color
		spot.light_energy = spot_energy
		spot.light_specular = 0.5
		spot.spot_range = spot_range
		spot.spot_angle = spot_angle_deg
		spot.spot_attenuation = spot_attenuation
		spot.spot_angle_attenuation = 0.9
		spot.shadow_enabled = false
		spot.light_volumetric_fog_energy = 0.0
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 16.0
		spot.distance_fade_length = 4.0
		root.add_child(spot)
