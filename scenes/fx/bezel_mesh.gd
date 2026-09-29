class_name BezelMesh
extends RefCounted
## Marcos en bisel: barre un perfil 2D a lo largo de un contorno cerrado apoyado en una
## superficie (pared, pantalla). El perfil va en (u, h): u = distancia hacia fuera del
## contorno, en el plano tangente de la superficie; h = altura hacia la sala. Las
## normales del perfil salen de su propia forma, así que cantos redondeados y caras
## algo abombadas dan bandas de brillo y de sombra en el metal.


## Aro de cromo plano y estrecho. Desde fuera hacia dentro: pie metido `foot` en la
## pared, canto exterior redondeado, cara superior casi plana (baja un poco hacia el
## hueco y se abomba ligeramente) y canto interior redondeado que baja hasta `inner_floor`.
static func chrome_profile(u_inner: float, width: float, height: float, foot: float,
		inner_floor: float) -> PackedVector2Array:
	var u_outer := u_inner + width
	var rs := minf(width * 0.3, height * 0.95)     # radio horizontal del canto exterior
	var ri := minf(width * 0.1, height * 0.3)      # radio del canto interior
	var h_in := height * 0.78                     # altura del borde interior de la cara
	var bulge := height * 0.08
	var pts := PackedVector2Array()
	pts.append(Vector2(u_outer, -foot))
	var seg := 8
	for k in seg + 1:
		var a := PI * 0.5 * float(k) / float(seg)
		pts.append(Vector2(u_outer - rs + rs * cos(a), height * sin(a)))
	var top := 8
	for k in range(1, top):
		var t := float(k) / float(top)
		pts.append(Vector2(lerpf(u_outer - rs, u_inner + ri, t), lerpf(height, h_in, t) + bulge * sin(PI * t)))
	for k in seg + 1:
		var a := PI * 0.5 * float(k) / float(seg)
		pts.append(Vector2(u_inner + ri - ri * sin(a), h_in - ri + ri * cos(a)))
	pts.append(Vector2(u_inner, inner_floor))
	return pts


## Banda plana (acento de color): empieza escondida bajo el aro de cromo (`u_start`),
## llega hasta `u_end` a altura `height` y dobla hacia atrás en un labio corto.
static func flat_band_profile(u_start: float, u_end: float, height: float, lip: float) -> PackedVector2Array:
	var r := minf(lip * 0.5, 0.004)
	var pts := PackedVector2Array()
	pts.append(Vector2(u_start, height))
	pts.append(Vector2(lerpf(u_start, u_end + r, 0.5), height))
	pts.append(Vector2(u_end + r, height))
	var seg := 4
	for k in range(1, seg + 1):
		var a := PI * 0.5 * float(k) / float(seg)
		pts.append(Vector2(u_end + r - r * sin(a), height - r + r * cos(a)))
	pts.append(Vector2(u_end, height - lip))
	return pts


## Barre `profile` (ordenado de fuera hacia dentro) a lo largo del contorno cerrado
## `points` con las normales de la superficie `surface_normals`. La dirección "hacia
## fuera" se calcula en cada punto (tangente × normal) y se orienta respecto al centro.
static func sweep(points: PackedVector3Array, surface_normals: PackedVector3Array,
		profile: PackedVector2Array) -> ArrayMesh:
	var count := points.size()
	var pc := profile.size()
	if count < 3 or pc < 2:
		return ArrayMesh.new()
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= float(count)
	var prof_n := _profile_normals(profile)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for k in count:
		var p := points[k]
		var n := surface_normals[k]
		var tangent := (points[(k + 1) % count] - points[(k - 1 + count) % count]).normalized()
		var out := tangent.cross(n).normalized()
		if out.dot(p - center) < 0.0:
			out = -out
		for j in pc:
			verts.append(p + out * profile[j].x + n * profile[j].y)
			norms.append((out * prof_n[j].x + n * prof_n[j].y).normalized())
	var indices := PackedInt32Array()
	for k in count:
		var k2 := (k + 1) % count
		for j in pc - 1:
			_add_tri(verts, norms, indices, k * pc + j, k * pc + j + 1, k2 * pc + j + 1)
			_add_tri(verts, norms, indices, k * pc + j, k2 * pc + j + 1, k2 * pc + j)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Normales del perfil (u, h) por diferencias centradas, apuntando hacia la sala
## (el perfil se recorre de fuera hacia dentro).
static func _profile_normals(profile: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := profile.size()
	for j in n:
		var a := profile[maxi(j - 1, 0)]
		var b := profile[mini(j + 1, n - 1)]
		var t := b - a
		var nrm := Vector2(t.y, -t.x)
		out.append(nrm.normalized() if nrm.length_squared() > 1e-12 else Vector2(0.0, 1.0))
	return out


## Triángulo orientado según las normales (en Godot las caras frontales van en sentido horario).
static func _add_tri(verts: PackedVector3Array, norms: PackedVector3Array, indices: PackedInt32Array,
		a: int, b: int, c: int) -> void:
	var geo := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if geo.length_squared() < 1e-14:
		return
	indices.append(a)
	if geo.dot(norms[a] + norms[b] + norms[c]) > 0.0:
		indices.append(c)
		indices.append(b)
	else:
		indices.append(b)
		indices.append(c)
