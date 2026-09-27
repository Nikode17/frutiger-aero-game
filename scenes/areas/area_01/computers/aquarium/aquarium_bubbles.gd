class_name AquariumBubbles
extends Node2D
## Burbujas que suben con un leve bamboleo: sistema de partículas dibujado a mano para
## poder pintar borde y brillo de cada burbuja. Salen de unos cuantos puntos del fondo.

@export var bubble_count: int = 45
@export var stream_count: int = 5

var bounds: Vector2 = Vector2(1024, 420)
var _rng := RandomNumberGenerator.new()
var _bubbles: Array = []   # [pos, radio, velocidad, fase]
var _streams: PackedFloat32Array = PackedFloat32Array()


func setup(rng: RandomNumberGenerator, view_size: Vector2) -> void:
	bounds = view_size
	_rng.seed = rng.randi()
	_streams.clear()
	for k in stream_count:
		_streams.append(_rng.randf_range(view_size.x * 0.05, view_size.x * 0.95))
	_bubbles.clear()
	for k in bubble_count:
		var b := _new_bubble()
		b[0].y = _rng.randf_range(0.0, view_size.y)   # repartidas al empezar
		_bubbles.append(b)


func _new_bubble() -> Array:
	var x := _streams[_rng.randi() % _streams.size()] + _rng.randf_range(-12.0, 12.0)
	if _rng.randf() < 0.3:
		x = _rng.randf_range(0.0, bounds.x)
	return [Vector2(x, bounds.y + 10.0), _rng.randf_range(2.0, 7.0), _rng.randf_range(35.0, 75.0), _rng.randf() * TAU]


func _process(delta: float) -> void:
	for k in _bubbles.size():
		var b: Array = _bubbles[k]
		var pos: Vector2 = b[0]
		pos.y -= b[2] * delta
		pos.x += sin(pos.y * 0.05 + b[3]) * 12.0 * delta
		b[0] = pos
		if pos.y < -10.0:
			_bubbles[k] = _new_bubble()
	queue_redraw()


func _draw() -> void:
	for b in _bubbles:
		var p: Vector2 = b[0]
		var r: float = b[1]
		draw_circle(p, r, Color(0.9, 0.97, 1.0, 0.12))
		draw_arc(p, r, 0.0, TAU, 16, Color(0.95, 1.0, 1.0, 0.65), 1.2, true)
		draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.8))
