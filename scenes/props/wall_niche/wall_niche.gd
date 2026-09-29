@tool
class_name WallNiche
extends Node3D
## Hornacina iluminada para pared: pieza de contorno redondeado que sale de la pared con
## un hueco también redondeado, LED en el labio del hueco y al fondo, balda(s) de cristal y
## una luz pequeña dentro. Origen en la pared, en el centro del hueco; +Z sale hacia la
## sala. Todo el cuerpo (canto, frente, labio, paredes interiores) es un único perfil
## barrido a lo largo del contorno (BezelMesh); el fondo es una tapa plana.
## Las piezas que se exponen dentro (esferas de cristal…) se añaden como hijos.

@export_tool_button("Reconstruir hornacina") var rebuild_action: Callable = build

@export_group("Forma")
## Tamaño exterior de la pieza (ancho, alto) en metros
@export var outer_size: Vector2 = Vector2(0.8, 1.3)
## Radio de las esquinas del contorno exterior
@export var corner_radius: float = 0.3
## Ancho del marco alrededor del hueco (igual en todo el contorno)
@export var frame_margin: float = 0.14
## Cuánto sale el frente de la pared
@export var protrusion: float = 0.25
## Fondo del hueco, medido desde la pared (debe quedar por delante de ella)
@export var back_offset: float = 0.025
## Cuánto se mete la pieza detrás de la pared (tapa huecos si la pared es curva)
@export var wall_embed: float = 0.05
@export var edge_radius: float = 0.07     # canto exterior del frente
@export var lip_radius: float = 0.02      # canto del hueco
@export var inner_corner_radius: float = 0.03   # unión de las paredes interiores con el fondo
@export_range(16, 256) var contour_points: int = 96

@export_group("Balda")
## Alturas de las baldas de cristal, desde el borde inferior del hueco (m)
@export var shelf_heights: PackedFloat32Array = PackedFloat32Array([0.48])
@export var shelf_thickness: float = 0.012

@export_group("Materiales")
@export var body_material: Material = preload("res://assets/materials/white_lacquer.tres")
@export var shelf_material: Material = preload("res://assets/materials/glass_clear.tres")
@export var lip_led_material: Material = preload("res://assets/materials/led_cyan.tres")
@export var back_led_material: Material = preload("res://assets/materials/led_green.tres")
@export var led_radius: float = 0.005

@export_group("Luz")
## Luz pequeña arriba y delante dentro del hueco (como un foco de hornacina)
@export var light_color: Color = Color(0.55, 0.9, 1.0)
@export var light_energy: float = 0.1
@export var light_range: float = 0.9
@export var light_attenuation: float = 1.6
@export var light_specular: float = 0.25

@export_group("Colisión")
@export var collision_enabled: bool = true

const META_GENERATED := &"wall_niche_generated"


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var contour := _rounded_rect(outer_size * 0.5, corner_radius)
	var normals := PackedVector3Array()
	normals.resize(contour.size())
	normals.fill(Vector3.BACK)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BezelMesh.sweep(contour, normals, _body_profile())
	body.material_override = body_material
	_add_generated(body)

	# Fondo del hueco: tapa plana (el contorno es convexo, basta un abanico)
	var inset := frame_margin + inner_corner_radius
	var back := MeshInstance3D.new()
	back.name = "Back"
	back.mesh = _fan(_rounded_rect(outer_size * 0.5 - Vector2.ONE * inset, maxf(corner_radius - inset, 0.005)), back_offset)
	back.material_override = body_material
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(back)

	var open_half := outer_size * 0.5 - Vector2.ONE * frame_margin
	var open_corner := maxf(corner_radius - frame_margin, 0.005)
	var cavity_depth := protrusion - back_offset
	for k in shelf_heights.size():
		var shelf := MeshInstance3D.new()
		shelf.name = "Shelf%d" % k
		var box := BoxMesh.new()
		box.size = Vector3(open_half.x * 2.0, shelf_thickness, cavity_depth - 0.01)
		shelf.mesh = box
		shelf.position = Vector3(0.0, -open_half.y + shelf_heights[k] - shelf_thickness * 0.5,
				back_offset + (cavity_depth - 0.01) * 0.5)
		shelf.material_override = shelf_material
		shelf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add_generated(shelf)

	# LED cian en el labio: aro metido en las paredes interiores, poco detrás del frente
	if lip_led_material:
		var led_inset := frame_margin + led_radius + 0.002
		var ring := _rounded_rect(outer_size * 0.5 - Vector2.ONE * led_inset, maxf(corner_radius - led_inset, 0.005))
		var z := protrusion - lip_radius - 0.012
		var pts := PackedVector3Array()
		for p in ring:
			pts.append(Vector3(p.x, p.y, z))
		var led := LedStrip.new()
		led.name = "LipLed"
		led.points = pts
		led.closed = true
		led.smooth = false
		led.radius = led_radius
		led.material = lip_led_material
		_add_generated(led)
	# LED verde al fondo, metido en la esquina redondeada entre el techo del hueco y el
	# fondo (baña el fondo de arriba abajo; abajo se vería a través de las esferas); solo
	# en el tramo recto del techo
	if back_led_material:
		var d := (inner_corner_radius - led_radius - 0.002) * 0.7071
		var y := open_half.y - inner_corner_radius + d
		var x := maxf(open_half.x - open_corner, 0.02)
		var zb := back_offset + inner_corner_radius - d
		var led2 := LedStrip.new()
		led2.name = "BackLed"
		led2.points = PackedVector3Array([Vector3(-x, y, zb), Vector3(x, y, zb)])
		led2.radius = led_radius
		led2.material = back_led_material
		_add_generated(led2)

	if light_energy > 0.0:
		var light := OmniLight3D.new()
		light.name = "NicheLight"
		light.position = Vector3(0.0, open_half.y - open_corner * 0.5, protrusion - 0.04)
		light.light_color = light_color
		light.light_energy = light_energy
		light.light_specular = light_specular
		light.omni_range = light_range
		light.omni_attenuation = light_attenuation
		light.shadow_enabled = false
		LedStrip.setup_light(light)
		_add_generated(light)

	if collision_enabled:
		var bodyc := StaticBody3D.new()
		bodyc.name = "NicheBody"
		var shape := BoxShape3D.new()
		shape.size = Vector3(outer_size.x, outer_size.y, protrusion + wall_embed)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(0.0, 0.0, (protrusion - wall_embed) * 0.5)
		bodyc.add_child(col)
		_add_generated(bodyc)


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


## Perfil del cuerpo en (u, h) respecto al contorno exterior (u hacia fuera, h = z):
## desde detrás de la pared sube por el lateral, dobla el canto, cruza el frente, dobla el
## labio y entra por las paredes interiores hasta el fondo.
func _body_profile() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var re := minf(edge_radius, minf(protrusion, frame_margin) * 0.9)
	var rl := minf(lip_radius, frame_margin * 0.4)
	var rb := inner_corner_radius
	var seg := 8
	pts.append(Vector2(0.0, -wall_embed))
	for k in seg + 1:
		var a := PI * 0.5 * float(k) / float(seg)
		pts.append(Vector2(-re + re * cos(a), protrusion - re + re * sin(a)))
	pts.append(Vector2(lerpf(-re, -frame_margin + rl, 0.5), protrusion))
	for k in seg + 1:
		var a := PI * 0.5 * float(k) / float(seg)
		pts.append(Vector2(-frame_margin + rl - rl * sin(a), protrusion - rl + rl * cos(a)))
	for k in seg + 1:
		var a := PI * 0.5 * float(k) / float(seg)
		pts.append(Vector2(-frame_margin - rb + rb * cos(a), back_offset + rb - rb * sin(a)))
	return pts


## Rectángulo de esquinas redondeadas centrado en el origen (plano XY), en sentido antihorario.
func _rounded_rect(half: Vector2, r: float) -> PackedVector3Array:
	r = minf(r, minf(half.x, half.y))
	var per_corner := maxi(contour_points / 4, 2)
	var pts := PackedVector3Array()
	var centers := [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r),
			Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	for c in 4:
		var ctr: Vector2 = centers[c]
		for k in per_corner + 1:
			var a := PI * 0.5 * (float(c) + float(k) / float(per_corner))
			pts.append(Vector3(ctr.x + r * cos(a), ctr.y + r * sin(a), 0.0))
		# Tramo recto hasta la siguiente esquina, con algún punto intermedio
		var nxt: Vector2 = centers[(c + 1) % 4]
		var a_end := PI * 0.5 * float(c + 1)
		var p0 := ctr + Vector2(cos(a_end), sin(a_end)) * r
		var p1 := nxt + Vector2(cos(a_end), sin(a_end)) * r
		var steps := maxi(int(p0.distance_to(p1) / 0.08), 1)
		for s in range(1, steps):
			var p := p0.lerp(p1, float(s) / float(steps))
			pts.append(Vector3(p.x, p.y, 0.0))
	return pts


## Tapa plana (abanico desde el centro) a la altura z, mirando a +Z.
func _fan(contour: PackedVector3Array, z: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	st.add_vertex(Vector3(0.0, 0.0, z))
	for p in contour:
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(p.x, p.y, z))
	var n := contour.size()
	for k in n:
		# Contorno antihorario visto desde +Z: en Godot la cara frontal va en sentido horario
		st.add_index(0)
		st.add_index(1 + (k + 1) % n)
		st.add_index(1 + k)
	return st.commit()
