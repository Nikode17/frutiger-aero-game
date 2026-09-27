class_name AquariumWeeds
extends Node2D
## Fila de algas que se mecen, dibujadas como tiras que se estrechan hacia la punta.

var bounds: Vector2 = Vector2(1024, 420)
var base_y: float = 400.0
var colors: Array[Color] = [Color(0.25, 0.72, 0.35), Color(0.55, 0.85, 0.3)]
var height_range: Vector2 = Vector2(60.0, 140.0)

var _fronds: Array = []   # [x, altura, anchura, fase, color]
var _time: float = 0.0


func setup(rng: RandomNumberGenerator, view_size: Vector2, count: int) -> void:
	bounds = view_size
	_fronds.clear()
	for k in count:
		var x := (float(k) + rng.randf_range(0.1, 0.9)) / float(count) * view_size.x
		_fronds.append([x, rng.randf_range(height_range.x, height_range.y), rng.randf_range(7.0, 13.0), rng.randf() * TAU, colors[rng.randi() % colors.size()]])


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for f in _fronds:
		var x: float = f[0]
		var h: float = f[1]
		var w: float = f[2]
		var ph: float = f[3]
		var col: Color = f[4]
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var segs := 12
		for s in segs + 1:
			var t := float(s) / float(segs)
			var sway := sin(_time * 1.1 + ph + t * 2.5) * 18.0 * t * t
			var cx := x + sway
			var y := base_y - t * h
			var half := w * 0.5 * (1.0 - t * 0.85)
			left.append(Vector2(cx - half, y))
			right.append(Vector2(cx + half, y))
		right.reverse()
		left.append_array(right)
		draw_colored_polygon(left, col)
