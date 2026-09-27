class_name AquariumFish
extends Node2D
## Pez tropical genérico dibujado con formas simples. Nada de un lado a otro de la pantalla,
## con un ligero vaivén vertical y la cola moviéndose. Al salir por un lado vuelve a entrar.

var length: float = 60.0
var body_color: Color = Color(1.0, 0.55, 0.15)
var stripe_color: Color = Color(1.0, 0.97, 0.9)
var striped: bool = true
var speed: float = 40.0          # px/s
var direction: float = 1.0       # 1 = hacia la derecha, -1 = hacia la izquierda
var bob_amplitude: float = 8.0
var bounds: Vector2 = Vector2(1024, 420)

var _base_y: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0


func setup(rng: RandomNumberGenerator, view_size: Vector2, depth: float) -> void:
	bounds = view_size
	length = lerpf(34.0, 78.0, depth)
	speed = lerpf(22.0, 55.0, rng.randf()) * lerpf(0.7, 1.1, depth)
	direction = 1.0 if rng.randf() < 0.5 else -1.0
	bob_amplitude = rng.randf_range(4.0, 12.0)
	_phase = rng.randf() * TAU
	_base_y = rng.randf_range(view_size.y * 0.12, view_size.y * 0.72)
	position = Vector2(rng.randf_range(0.0, view_size.x), _base_y)
	# Los peces lejanos se tiñen del color del agua
	modulate = Color(1, 1, 1).lerp(Color(0.6, 0.8, 1.0), 1.0 - depth)
	z_index = int(depth * 10.0)


func _process(delta: float) -> void:
	_time += delta
	position.x += speed * direction * delta
	position.y = _base_y + sin(_time * 0.9 + _phase) * bob_amplitude
	var margin := length * 1.5
	if direction > 0.0 and position.x > bounds.x + margin:
		position.x = -margin
	elif direction < 0.0 and position.x < -margin:
		position.x = bounds.x + margin
	scale.x = direction
	queue_redraw()


func _draw() -> void:
	var rx := length * 0.5
	var ry := length * 0.3
	var outline := body_color.darkened(0.35)
	# Cola que se mueve
	var wag := sin(_time * 9.0 + _phase) * ry * 0.45
	var tail := PackedVector2Array([
		Vector2(-rx * 0.8, 0.0),
		Vector2(-rx * 1.45, -ry * 0.85 + wag),
		Vector2(-rx * 1.3, wag * 0.5),
		Vector2(-rx * 1.45, ry * 0.85 + wag),
	])
	draw_colored_polygon(tail, body_color.darkened(0.1))
	# Aleta dorsal
	draw_colored_polygon(PackedVector2Array([Vector2(-rx * 0.35, -ry * 0.8), Vector2(rx * 0.15, -ry * 1.35), Vector2(rx * 0.35, -ry * 0.85)]), body_color.darkened(0.12))
	# Cuerpo
	var body := PackedVector2Array()
	for k in 24:
		var a := TAU * float(k) / 24.0
		body.append(Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(body, body_color)
	# Rayas claras que siguen la altura del cuerpo
	if striped:
		for sx in [rx * 0.25, -rx * 0.25]:
			var h: float = ry * sqrt(maxf(1.0 - pow(sx / rx, 2.0), 0.0))
			var band := PackedVector2Array()
			for k in 12:
				var a := TAU * float(k) / 12.0
				band.append(Vector2(sx + cos(a) * rx * 0.09, sin(a) * h * 0.97))
			draw_colored_polygon(band, stripe_color)
	body.append(body[0])
	draw_polyline(body, outline, 1.5, true)
	# Ojo
	draw_circle(Vector2(rx * 0.58, -ry * 0.2), ry * 0.2, Color(1, 1, 1))
	draw_circle(Vector2(rx * 0.62, -ry * 0.2), ry * 0.11, Color(0.05, 0.08, 0.12))
