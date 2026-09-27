extends Node2D
## Escena 2D del salvapantallas de acuario que se ve en la pantalla grande del entrante.
## Se renderiza en un SubViewport; todo se genera aquí por código (sin imágenes).
## Capas, de atrás a delante: fondo (shader), algas lejanas, medusas, peces, algas
## cercanas y burbujas.

@export var random_seed: int = 2003
@export_range(0, 30) var fish_count: int = 10
@export_range(0, 6) var jelly_count: int = 2
@export var fish_colors: Array[Color] = [Color(1.0, 0.55, 0.15), Color(1.0, 0.83, 0.2), Color(1.0, 0.68, 0.1), Color(0.98, 0.45, 0.2)]
@export var background_shader: Shader = preload("res://assets/shaders/aquarium_bg.gdshader")

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed
	var view_size := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.size = view_size
	var mat := ShaderMaterial.new()
	mat.shader = background_shader
	mat.set_shader_parameter("aspect", view_size.x / view_size.y)
	bg.material = mat
	bg.z_index = -20
	add_child(bg)

	var back_weeds := AquariumWeeds.new()
	back_weeds.colors = [Color(0.2, 0.5, 0.45), Color(0.28, 0.58, 0.5)]
	back_weeds.height_range = Vector2(50.0, 110.0)
	back_weeds.base_y = view_size.y * 0.93
	back_weeds.z_index = -10
	back_weeds.setup(_rng, view_size, 14)
	add_child(back_weeds)

	for k in jelly_count:
		var jelly := AquariumJelly.new()
		jelly.setup(_rng, view_size)
		jelly.z_index = -5
		add_child(jelly)

	for k in fish_count:
		var fish := AquariumFish.new()
		fish.body_color = fish_colors[k % fish_colors.size()]
		fish.striped = k % 2 == 0
		fish.setup(_rng, view_size, _rng.randf())
		add_child(fish)

	var front_weeds := AquariumWeeds.new()
	front_weeds.height_range = Vector2(70.0, 170.0)
	front_weeds.base_y = view_size.y + 4.0
	front_weeds.z_index = 20
	front_weeds.setup(_rng, view_size, 9)
	add_child(front_weeds)

	var bubbles := AquariumBubbles.new()
	bubbles.z_index = 25
	bubbles.setup(_rng, view_size)
	add_child(bubbles)
