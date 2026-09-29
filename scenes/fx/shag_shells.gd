class_name ShagShells
extends Node
## Pelo largo con capas "shell" para una alfombra con shag_rug.gdshader. Solo en calidad
## Alta: añade a la malla de la alfombra una copia que dibuja varias capas desplazadas
## hacia arriba (cadena de next_pass, una capa por material). En Media y Baja se oculta y
## queda la versión plana del material. No proyecta sombras ni sale en el reflejo planar.
## Bajo los muebles de flatten_nodes el pelo se aplasta para que sus bases no se hundan.

## Nodo con la alfombra: un MeshInstance3D o una escena importada que lo contenga
@export var target_path: NodePath = ^".."
## Material base; si está vacío se usa el de la propia malla
@export var base_material: ShaderMaterial
## Número de capas shell (la primera es la raíz)
@export_range(2, 16) var layer_count: int = 10
@export var pile_height: float = 0.032

@export_group("Muebles encima")
## Muebles apoyados en la alfombra (hasta 4): bajo cada uno se aplasta el pelo
@export var flatten_nodes: Array[NodePath] = []
## Radio de la base de cada mueble (m), en el mismo orden; si falta se usa 0.35
@export var flatten_radii: PackedFloat32Array = PackedFloat32Array()
## Anchura de la transición entre pelo aplastado y completo (m)
@export var flatten_fade: float = 0.06

var _shells: MeshInstance3D


func _ready() -> void:
	var gq := get_node_or_null(^"/root/GraphicsQuality")
	if gq:
		gq.level_changed.connect(_on_level_changed)
		_on_level_changed(gq.level)
	else:
		_set_enabled(true)


func _on_level_changed(level: int) -> void:
	# Solo en Alta (2)
	_set_enabled(level == 2)


func _set_enabled(value: bool) -> void:
	if value and _shells == null:
		_build()
	if _shells:
		_shells.visible = value


func _build() -> void:
	var target := get_node_or_null(target_path)
	var source := _find_mesh(target) if target else null
	if source == null:
		push_warning("ShagShells: no se encontró la malla de la alfombra en '%s'." % target_path)
		return
	var base := base_material
	if base == null:
		base = source.get_active_material(0) as ShaderMaterial
	if base == null:
		push_warning("ShagShells: la alfombra no usa un ShaderMaterial de pelo.")
		return
	var areas := _flatten_areas(source)
	# Cadena de capas: la primera es la raíz (completa y oscura), las demás los mechones
	var first: ShaderMaterial = null
	var prev: ShaderMaterial = null
	for k in layer_count:
		var mat := base.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shell_mode", true)
		mat.set_shader_parameter("shell_layer", float(k) / float(layer_count - 1))
		mat.set_shader_parameter("pile_height", pile_height)
		mat.set_shader_parameter("flatten_areas", areas)
		mat.set_shader_parameter("flatten_count", areas.size())
		if prev:
			prev.next_pass = mat
		else:
			first = mat
		prev = mat
	_shells = MeshInstance3D.new()
	_shells.name = "ShagShells"
	_shells.mesh = source.mesh
	_shells.material_override = first
	_shells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shells.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_shells.layers = 1 << PlanarReflection.HIDDEN_LAYER_BIT
	source.add_child(_shells)


## Zonas aplastadas en el espacio local de la malla: (x, z, radio, transición).
func _flatten_areas(source: MeshInstance3D) -> PackedVector4Array:
	var areas := PackedVector4Array()
	var to_local := source.global_transform.affine_inverse()
	for i in mini(flatten_nodes.size(), 4):
		var node := get_node_or_null(flatten_nodes[i]) as Node3D
		if node == null:
			push_warning("ShagShells: no se encontró el mueble '%s'." % flatten_nodes[i])
			continue
		var p := to_local * node.global_position
		var r := flatten_radii[i] if i < flatten_radii.size() else 0.35
		areas.append(Vector4(p.x, p.z, r, flatten_fade))
	return areas


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null
