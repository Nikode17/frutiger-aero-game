class_name AquariumJelly
extends Node2D
## Medusa translúcida genérica: campana que late y tentáculos ondulantes. Sube despacio
## a impulsos y deriva; al salir por arriba vuelve a aparecer por abajo.

var size: float = 40.0
var color: Color = Color(0.9, 0.8, 1.0, 0.45)
var bounds: Vector2 = Vector2(1024, 420)

var _time: float = 0.0
var _phase: float = 0.0
var _drift: float = 0.0


func setup(rng: RandomNumberGenerator, view_size: Vector2) -> void:
	bounds = view_size
	size = rng.randf_range(28.0, 46.0)
	_phase = rng.randf() * TAU
	_drift = rng.randf_range(-6.0, 6.0)
	position = Vector2(rng.randf_range(view_size.x * 0.1, view_size.x * 0.9), rng.randf_range(view_size.y * 0.2, view_size.y * 0.7))


func _process(delta: float) -> void:
	_time += delta
	# Impulso al contraerse la campana
	var pulse := maxf(sin(_time * 1.6 + _phase), 0.0)
	position.y -= (4.0 + pulse * 18.0) * delta
	position.x += _drift * delta
	if position.y < -size * 3.0:
		position.y = bounds.y + size
	position.x = wrapf(position.x, -size * 2.0, bounds.x + size * 2.0)
	queue_redraw()


func _draw() -> void:
	var squeeze := 0.5 + 0.5 * sin(_time * 1.6 + _phase)
	var w := size * (1.0 - 0.18 * squeeze)
	var h := size * (0.7 + 0.12 * squeeze)
	# Tentáculos
	for k in 6:
		var x0 := lerpf(-w * 0.75, w * 0.75, float(k) / 5.0)
		var pts := PackedVector2Array()
		for s in 10:
			var t := float(s) / 9.0
			pts.append(Vector2(x0 + sin(_time * 2.2 + t * 4.0 + float(k)) * size * 0.12 * t, t * size * 1.6))
		draw_polyline(pts, Color(color.r, color.g, color.b, color.a * 0.7), 1.5, true)
	# Campana
	var bell := PackedVector2Array()
	for k in 21:
		var a := PI + PI * float(k) / 20.0
		bell.append(Vector2(cos(a) * w, sin(a) * h))
	for k in 7:
		var t := float(k) / 6.0
		bell.append(Vector2(lerpf(w, -w, t), sin(t * PI * 3.0) * h * 0.08))
	draw_colored_polygon(bell, color)
	# Brillo interior
	draw_circle(Vector2(-w * 0.3, -h * 0.55), size * 0.12, Color(1, 1, 1, 0.35))
