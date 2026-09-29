@tool
class_name GlassOrb
extends Node3D
## Esfera de cristal decorativa apoyada por su base (el origen queda en el punto de apoyo).
## El cristal de la biblioteca lee la pantalla, así que la esfera se ordena algo por
## delante (sorting_offset) para que no la tape otro cristal sobre el que se apoya
## (tapa de mesa, balda).

@export_tool_button("Reconstruir esfera") var rebuild_action: Callable = build

@export var radius: float = 0.07:
	set(value):
		radius = value
		build()
@export var material: Material = preload("res://assets/materials/glass_cyan.tres"):
	set(value):
		material = value
		build()
@export_range(8, 64) var segments: int = 32
## Adelanta la esfera al ordenar transparentes (m)
@export var sorting_offset: float = 0.5
## Fuera del reflejo planar del suelo (objeto pequeño)
@export var hide_in_floor_reflection: bool = true

const META_GENERATED := &"glass_orb_generated"


func _ready() -> void:
	build()


func build() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(META_GENERATED):
			remove_child(child)
			child.queue_free()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments
	sphere.rings = segments / 2
	var mi := MeshInstance3D.new()
	mi.name = "Orb"
	mi.mesh = sphere
	mi.position = Vector3(0.0, radius, 0.0)
	mi.material_override = material
	mi.sorting_offset = sorting_offset
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(META_GENERATED, true)
	add_child(mi)
	if hide_in_floor_reflection and not Engine.is_editor_hint():
		add_to_group(&"no_planar_reflection")
