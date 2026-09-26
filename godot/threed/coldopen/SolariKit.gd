extends RefCounted
class_name SolariKit
## The Solari architecture kit for Cold Open v2 — stylised low-poly, per art/style_frames/cold_open/.
##
## A kit instance ACCUMULATES geometry, one SurfaceTool per material key, and `commit()` turns the lot
## into ONE MeshInstance3D with one surface per material (the Starfall rule: a building is one mesh,
## not a pile of boxes). Every face is flat-shaded with its own normal, and carries a small random
## tone in its vertex colour — that per-facet variation is most of the "faceted" read in the frames.
##
## Winding: every primitive states the outward normal it wants and `_tri` orders the vertices so the
## face points that way in Godot (front faces are CLOCKWISE — see CLAUDE.md). Nothing here can come
## out inside-out by accident.
##
## Collision is separate and simple: `solid()` adds a box shape to the kit's StaticBody3D, `ramp()`
## an invisible sloped box whose TOP face is the walking line (CLAUDE.md: stairs need a hidden ramp).

var materials: Dictionary = {}          # key -> Material
var _surfs: Dictionary = {}             # key -> SurfaceTool
var _order: Array = []
var body: StaticBody3D
var rng := RandomNumberGenerator.new()
## How strong the per-facet tone jitter is (0 = none).
var facet_jitter := 0.05


func _init(mats: Dictionary, seed_value := 1) -> void:
	materials = mats
	rng.seed = seed_value
	body = StaticBody3D.new()
	body.name = "Solid"


func _st(key: String) -> SurfaceTool:
	if not _surfs.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfs[key] = st
		_order.append(key)
	return _surfs[key]


func _tone() -> Color:
	var j := rng.randf_range(-facet_jitter, facet_jitter)
	return Color(1.0 + j, 1.0 + j, 1.0 + j * 0.8)


## One flat triangle facing `n`.
func _tri(key: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var st := _st(key)
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-12:
		return
	# counter-clockwise about n -> reverse for Godot's clockwise front faces
	var verts := [a, c, b] if face.dot(n) > 0.0 else [a, b, c]
	var nn := n.normalized()
	for v in verts:
		st.set_color(col)
		st.set_normal(nn)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


## A flat quad a-b-c-d (in order round its edge) facing `n`, one tone for the whole facet.
func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n := Vector3.ZERO, col := Color(-1, 0, 0)) -> void:
	if n == Vector3.ZERO:
		n = (b - a).cross(c - a).normalized()
	var t := _tone() if col.r < 0.0 else col
	_tri(key, a, b, c, n, t)
	_tri(key, a, c, d, n, t)


func tri(key: String, a: Vector3, b: Vector3, c: Vector3, n := Vector3.ZERO, col := Color(-1, 0, 0)) -> void:
	if n == Vector3.ZERO:
		n = (b - a).cross(c - a).normalized()
	_tri(key, a, b, c, n, _tone() if col.r < 0.0 else col)


## An oriented box. `xf` places a unit-centred box: basis columns scaled by size/2.
func box(key: String, center: Vector3, size: Vector3, basis := Basis(), col := Color(-1, 0, 0)) -> void:
	var hx := basis.x * size.x * 0.5
	var hy := basis.y * size.y * 0.5
	var hz := basis.z * size.z * 0.5
	var c := center
	var p := func(sx: float, sy: float, sz: float) -> Vector3: return c + hx * sx + hy * sy + hz * sz
	var faces := [
		[basis.x, p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(1, -1, 1)],
		[-basis.x, p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), p.call(-1, -1, -1)],
		[basis.y, p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1)],
		[-basis.y, p.call(-1, -1, 1), p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1)],
		[basis.z, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1)],
		[-basis.z, p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1)],
	]
	for f in faces:
		quad(key, f[1], f[2], f[3], f[4], f[0], col)


## An axis-aligned box that is also solid.
func block(key: String, center: Vector3, size: Vector3, solid_too := true) -> void:
	box(key, center, size)
	if solid_too:
		solid(center, size)


## An n-sided prism (column, drum, tower) from `base` up `height`, radius tapering to `top_r`.
## `yaw` turns the facets. Caps optional.
func prism(key: String, base: Vector3, r: float, height: float, sides := 8, top_r := -1.0,
		caps := true, yaw := 0.0) -> void:
	if top_r < 0.0:
		top_r = r
	var top := base + Vector3.UP * height
	for i in sides:
		var a0 := yaw + TAU * i / sides
		var a1 := yaw + TAU * (i + 1) / sides
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var mid := (d0 + d1).normalized()
		var slope := (r - top_r) / maxf(height, 0.001)
		var n := (mid + Vector3.UP * slope).normalized()
		quad(key, base + d0 * r, base + d1 * r, top + d1 * top_r, top + d0 * top_r, n)
		if caps:
			if top_r > 0.001:
				tri(key, top, top + d0 * top_r, top + d1 * top_r, Vector3.UP)
			tri(key, base, base + d1 * r, base + d0 * r, Vector3.DOWN)


## A faceted dome (hemisphere or less) sitting on `base`.
## A negative `rise` hangs the dome downward (bowls, bells turned over, the lower half of an orb).
func dome(key: String, base: Vector3, r: float, rise := 0.0, sides := 12, rings := 4) -> void:
	if rise == 0.0:
		rise = r
	for j in rings:
		var t0 := float(j) / rings * PI * 0.5
		var t1 := float(j + 1) / rings * PI * 0.5
		var r0 := cos(t0) * r
		var r1 := cos(t1) * r
		var y0 := sin(t0) * rise
		var y1 := sin(t1) * rise
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var d0 := Vector3(sin(a0), 0, cos(a0))
			var d1 := Vector3(sin(a1), 0, cos(a1))
			var p00 := base + d0 * r0 + Vector3.UP * y0
			var p01 := base + d1 * r0 + Vector3.UP * y0
			var p10 := base + d0 * r1 + Vector3.UP * y1
			var p11 := base + d1 * r1 + Vector3.UP * y1
			var n := ((p00 + p01 + p10 + p11) * 0.25 - base).normalized()
			if j == rings - 1:
				tri(key, p00, p01, p10, n)
			else:
				quad(key, p00, p01, p11, p10, n)


## A flat n-gon disc (sun mosaics, plinths) facing `n` (default up).
func disc(key: String, center: Vector3, r: float, sides := 16, r_in := 0.0, yaw := 0.0,
		col := Color(-1, 0, 0)) -> void:
	for i in sides:
		var a0 := yaw + TAU * i / sides
		var a1 := yaw + TAU * (i + 1) / sides
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		if r_in <= 0.0:
			tri(key, center, center + d0 * r, center + d1 * r, Vector3.UP, col)
		else:
			quad(key, center + d0 * r_in, center + d0 * r, center + d1 * r, center + d1 * r_in, Vector3.UP, col)


## A wall slab in the plane spanned by `along` (unit, horizontal) and UP, front facing `normal`,
## `length` long from `origin` (its bottom-left, front face), `height` tall, `thick` deep (going
## -normal). `openings`: [{u, w, sill, spring, rise}] — u = distance of the opening's left edge from
## origin along the wall; sill = bottom height (0 = a doorway); spring = where the arch starts; rise
## = arch height (0 = square head). The arch is polygonal (low-poly) with `seg` segments.
func wall(key: String, origin: Vector3, along: Vector3, normal: Vector3, length: float, height: float,
		thick: float, openings := [], seg := 8, reveal_key := "") -> void:
	if reveal_key == "":
		reveal_key = key
	var back := -normal * thick
	var P := func(u: float, v: float) -> Vector3: return origin + along * u + Vector3.UP * v
	# Sort openings, then march along the wall in strips.
	var ops := openings.duplicate()
	ops.sort_custom(func(a, b): return a["u"] < b["u"])
	var u := 0.0
	for op in ops:
		var u0: float = op["u"]
		var w: float = op["w"]
		var sill: float = op.get("sill", 0.0)
		var spring: float = op.get("spring", height * 0.6)
		var rise: float = op.get("rise", w * 0.5)
		if u0 > u:
			_wall_rect(key, P, u, u0, 0.0, height, normal, back)
		# columns of the opening
		var steps := seg if rise > 0.0 else 1
		for s in steps:
			var ua := u0 + w * s / steps
			var ub := u0 + w * (s + 1) / steps
			var ya := _arch_y(ua - u0, w, spring, rise)
			var yb := _arch_y(ub - u0, w, spring, rise)
			# above the head
			var fa: Vector3 = P.call(ua, ya)
			var fb: Vector3 = P.call(ub, yb)
			quad(key, fa, fb, P.call(ub, height), P.call(ua, height), normal)
			quad(key, P.call(ub, height) + back, fb + back, fa + back, P.call(ua, height) + back, -normal)
			# intrados (the underside of the head, inside the reveal)
			var dn := (fb - fa).cross(back).normalized()
			if dn.y > 0.0:
				dn = -dn
			quad(reveal_key, fa, fa + back, fb + back, fb, dn)
			# below the sill
			if sill > 0.0:
				quad(key, P.call(ua, 0.0), P.call(ub, 0.0), P.call(ub, sill), P.call(ua, sill), normal)
				quad(key, P.call(ub, sill) + back, P.call(ub, 0.0) + back, P.call(ua, 0.0) + back, P.call(ua, sill) + back, -normal)
				quad(reveal_key, P.call(ua, sill), P.call(ub, sill), P.call(ub, sill) + back, P.call(ua, sill) + back, Vector3.UP)
		# jambs
		var ys := _arch_y(0.0, w, spring, rise)
		quad(reveal_key, P.call(u0, sill), P.call(u0, sill) + back, P.call(u0, ys) + back, P.call(u0, ys), along)
		quad(reveal_key, P.call(u0 + w, ys), P.call(u0 + w, ys) + back, P.call(u0 + w, sill) + back, P.call(u0 + w, sill), -along)
		u = u0 + w
	if u < length:
		_wall_rect(key, P, u, length, 0.0, height, normal, back)
	# top and ends
	quad(key, P.call(0.0, height), P.call(length, height), P.call(length, height) + back, P.call(0.0, height) + back, Vector3.UP)
	quad(key, P.call(0.0, 0.0), P.call(0.0, height), P.call(0.0, height) + back, P.call(0.0, 0.0) + back, -along)
	quad(key, P.call(length, height), P.call(length, 0.0), P.call(length, 0.0) + back, P.call(length, height) + back, along)
	# collision: solid spans between openings, plus the head over each opening
	u = 0.0
	for op in ops:
		var u0: float = op["u"]
		if u0 > u:
			_wall_solid(origin, along, normal, u, u0, 0.0, height, thick)
		var sill2: float = op.get("sill", 0.0)
		if sill2 > 0.0:
			_wall_solid(origin, along, normal, u0, u0 + op["w"], 0.0, sill2, thick)
		u = u0 + op["w"]
	if u < length:
		_wall_solid(origin, along, normal, u, length, 0.0, height, thick)


func _arch_y(x: float, w: float, spring: float, rise: float) -> float:
	if rise <= 0.0:
		return spring
	var t := clampf((x - w * 0.5) / (w * 0.5), -1.0, 1.0)
	return spring + rise * sqrt(maxf(0.0, 1.0 - t * t))


func _wall_rect(key: String, P: Callable, u0: float, u1: float, v0: float, v1: float, normal: Vector3, back: Vector3) -> void:
	quad(key, P.call(u0, v0), P.call(u1, v0), P.call(u1, v1), P.call(u0, v1), normal)
	quad(key, P.call(u1, v0) + back, P.call(u0, v0) + back, P.call(u0, v1) + back, P.call(u1, v1) + back, -normal)


func _wall_solid(origin: Vector3, along: Vector3, normal: Vector3, u0: float, u1: float, v0: float, v1: float, thick: float) -> void:
	var c := origin + along * (u0 + u1) * 0.5 + Vector3.UP * (v0 + v1) * 0.5 - normal * thick * 0.5
	var b := Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
	solid(c, Vector3(u1 - u0, v1 - v0, thick), b)


## A flight of visible steps from `foot` (front edge of the lowest tread, centre) climbing along
## `dir` (horizontal unit), `rise` total, `run` total, `width` wide — over an invisible ramp collider
## whose top face runs exactly along the nosings (the walking line).
func stairs(key: String, foot: Vector3, dir: Vector3, rise: float, run: float, width: float, step_h := 0.18) -> void:
	var n := maxi(1, int(round(rise / step_h)))
	var sh := rise / n
	var sd := run / n
	var side := dir.cross(Vector3.UP).normalized()
	for i in n:
		var c := foot + dir * (sd * (i + 0.5)) + Vector3.UP * (sh * (i + 0.5))
		# each step reaches down to the ground so the flight reads as solid masonry from the side
		var h := sh * (i + 1)
		var cc := Vector3(c.x, foot.y + h * 0.5, c.z)
		box(key, cc, Vector3(width, h, sd), Basis(side, Vector3.UP, dir))
	ramp(foot, foot + dir * run + Vector3.UP * rise, width)


## Invisible ramp collider from `lo` to `hi` (points on the walking line), `width` wide. The box is
## offset down by half its thickness so its TOP face is the walking line, and runs 0.4 m past each end
## (buried into the lower deck, flush at the upper).
func ramp(lo: Vector3, hi: Vector3, width: float) -> void:
	var d := hi - lo
	var dir := d.normalized()
	var ext := 0.4
	var a := lo - dir * ext
	var b := hi + Vector3(dir.x, 0, dir.z).normalized() * 0.01
	var mid := (a + b) * 0.5
	var length := (b - a).length()
	var thick := 0.6
	var fwd := (b - a).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var up := side.cross(fwd).normalized()
	solid(mid - up * thick * 0.5, Vector3(width, thick, length), Basis(side, up, -fwd).orthonormalized())


## A collision box (no mesh).
func solid(center: Vector3, size: Vector3, basis := Basis()) -> void:
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = size.abs()
	cs.shape = shp
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)


## Build the accumulated geometry into one MeshInstance3D (plus the collision body) under `parent`.
func commit(parent: Node, name := "Kit") -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var idx := 0
	for key in _order:
		var st: SurfaceTool = _surfs[key]
		st.index()
		st.commit(mesh)
		if materials.has(key):
			mesh.surface_set_material(idx, materials[key])
		else:
			push_warning("SolariKit: no material for key '%s'" % key)
		idx += 1
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	parent.add_child(mi)
	if body.get_child_count() > 0:
		body.name = name + "Solid"
		parent.add_child(body)
		body = StaticBody3D.new()
	_surfs.clear()
	_order.clear()
	return mi
