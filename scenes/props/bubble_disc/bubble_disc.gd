@tool
class_name BubbleDisc
extends Node3D
## Disco de burbuja para pared: fondo retroiluminado (backlit_disc) bajo una lente de
## cristal abombada, aro de cromo fino alrededor y un halo suave de su color sobre la
## pared. Sin luces reales: todo es emisivo. Origen en la pared, en el centro del disco;
## +Z sale hacia la sala.

@export_tool_button("Reconstruir disco") var rebuild_action: Callable = build

@export_group("Forma")
@export var radius: float = 0.12            # radio exterior del aro (m)
@export var rim_width: float = 0.018        # ancho del aro de cromo
@export var rim_height: float = 0.012       # cuánto sale el aro de la pared
@export var lens_height: float = 0.25       # abombado de la lente, en fracción del radio
@export var wall_embed: float = 0.015       # cuánto se mete en la pared (pared curva)
@export_range(16, 128) var segments: int = 48

@export_group("Luz")
@export var color: Color = Color(0.25, 0.8, 1.0)
@export var energy: float = 1.0
## Semilla de las burbujas del fondo (para que cada disco sea distinto)
@export var seed_value: float = 0.0
## Halo en la pared: tamaño (múltiplo del radio) e intensidad (0 = sin halo)
@export var halo_scale: float = 1.9
@export var halo_energy: float = 0.3

@export_group("Materiales")
@export var rim_material: Material = preload("res://assets/materials/chrome_bezel.tres")
@export var lens_material: Material = preload("res://assets/materials/glass_clear.tres")
@export var backplate_material: Material = preload("res://assets/materials/backlit_disc.tres")
@export var halo_material: Material = preload("res://assets/materials/glow_halo.tres")

const META_GENERATED := &"bubble_disc_generated"


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var inner := radius - rim_width
	# Aro de cromo: perfil de bisel barrido sobre un círculo
	var ring := PackedVector3Array()
	var normals := PackedVector3Array()
	for k in segments:
		var a := TAU * float(k) / float(segments)
		ring.append(Vector3(cos(a), sin(a), 0.0) * inner)
		normals.append(Vector3.BACK)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = BezelMesh.sweep(ring, normals, BezelMesh.chrome_profile(
			-0.003, rim_width + 0.003, rim_height, wall_embed, 0.0))
	rim.material_override = rim_material
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(rim)

	# Fondo luminoso, apenas por delante de la pared
	var plate := MeshInstance3D.new()
	plate.name = "Backplate"
	plate.mesh = _disc(inner, 0.003)
	plate.material_override = backplate_material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.set_instance_shader_parameter("disc_color", color)
	plate.set_instance_shader_parameter("disc_energy", energy)
	plate.set_instance_shader_parameter("disc_seed", seed_value)
	_add_generated(plate)

	# Lente: casquete esférico que arranca bajo el borde interior del aro
	var lens := MeshInstance3D.new()
	lens.name = "Lens"
	lens.mesh = _cap(inner, inner * lens_height, 0.004)
	lens.material_override = lens_material
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(lens)

	if halo_material and halo_energy > 0.0 and halo_scale > 1.0:
		var halo := MeshInstance3D.new()
		halo.name = "Halo"
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * radius * halo_scale * 2.0
		halo.mesh = quad
		halo.position = Vector3(0.0, 0.0, 0.002)
		halo.material_override = halo_material
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.set_instance_shader_parameter("halo_color", color)
		halo.set_instance_shader_parameter("halo_energy", halo_energy)
		halo.set_instance_shader_parameter("inner_radius", radius / (radius * halo_scale))
		_add_generated(halo)


func _add_generated(node: Node) -> void:
	node.set_meta(META_GENERATED, true)
	add_child(node)


## Disco plano de radio r a la altura z, mirando a +Z, con UV de 0 a 1.
func _disc(r: float, z: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(Vector3(0.0, 0.0, z))
	for k in segments:
		var a := TAU * float(k) / float(segments)
		st.set_normal(Vector3.BACK)
		st.set_uv(Vector2(0.5 + 0.5 * cos(a), 0.5 - 0.5 * sin(a)))
		st.add_vertex(Vector3(cos(a) * r, sin(a) * r, z))
	for k in segments:
		# Antihorario visto desde +Z: se indexa al revés para que sea la cara frontal
		st.add_index(0)
		st.add_index(1 + (k + 1) % segments)
		st.add_index(1 + k)
	return st.commit()


## Casquete esférico de base r y altura h, con la base en z = z0, abombado hacia +Z.
func _cap(r: float, h: float, z0: float) -> ArrayMesh:
	var sphere_r := (r * r + h * h) / (2.0 * h)
	var half_angle := asin(clampf(r / sphere_r, 0.0, 1.0))
	var cz := z0 + h - sphere_r    # centro de la esfera
	var rings := 10
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings + 1:
		var phi := half_angle * float(j) / float(rings)   # 0 en el polo, half_angle en la base
		for k in segments + 1:
			var a := TAU * float(k) / float(segments)
			var n := Vector3(sin(phi) * cos(a), sin(phi) * sin(a), cos(phi))
			st.set_normal(n)
			st.add_vertex(Vector3(0.0, 0.0, cz) + n * sphere_r)
	var row := segments + 1
	for j in rings:
		for k in segments:
			var i0 := j * row + k
			var i1 := i0 + 1
			var i2 := i0 + row
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)
	return st.commit()
