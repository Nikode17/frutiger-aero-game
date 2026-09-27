extends SceneTree
## Herramienta: renderiza el árbol destacado del exterior desde varios ángulos, con sus
## materiales finales y fondo transparente, y guarda un atlas para los árboles lejanos
## (impostores). Se ejecuta con ventana (headless no renderiza):
##   godot --path . --resolution 1024x1024 -s res://scripts/tools/bake_tree_impostors.gd
## Imprime el tamaño del encuadre, que debe coincidir con impostor_size en la vegetación.

const TREE_PATH := "res://assets/models/exterior/tree_hero.glb"
const OUT_PATH := "res://assets/textures/exterior/tree_hero_impostor.png"
const CELL := 1024
const GRID := Vector2i(2, 2)
const EXPOSURE := 0.5   # el shader del impostor multiplica por 1 / EXPOSURE


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	# Luz parecida a la del área: sol cálido desde arriba y ambiente azul claro
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.85, 1.0)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = EXPOSURE
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	vp.add_child(sun)

	var tree: Node3D = load(TREE_PATH).instantiate()
	vp.add_child(tree)
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
		var box := mi.global_transform * mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	# Encuadre cuadrado centrado en el eje del tronco: radio real de la copa para que al
	# girar el árbol no se salga del marco
	var half_w := 0.0
	for mi: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := mi.global_transform * v
				half_w = maxf(half_w, Vector2(p.x, p.z).length())
	var frame := maxf(half_w * 2.0, aabb.size.y) * 1.02
	var bottom := aabb.position.y
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = frame
	cam.near = 0.1
	cam.far = 200.0
	cam.position = Vector3(0.0, bottom + frame * 0.5, 40.0)
	vp.add_child(cam)
	cam.current = true

	var atlas := Image.create(CELL * GRID.x, CELL * GRID.y, false, Image.FORMAT_RGBA8)
	var views := GRID.x * GRID.y
	for k in views:
		tree.rotation.y = TAU * float(k) / float(views)
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(k % GRID.x, k / GRID.x) * CELL)
	atlas.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("IMPOSTOR guardado en %s: encuadre %.2f m (ancho = alto), base del encuadre y = %.2f m" % [OUT_PATH, frame, bottom])
	quit()
