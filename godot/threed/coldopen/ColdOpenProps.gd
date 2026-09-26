extends RefCounted
class_name ColdOpenProps
## Furniture and fittings for the Cold Open, drawn into a SolariKit: bookcases full of books, scribes'
## desks, balustrades, the sun mosaic, braziers, banners, garlands. Static helpers — the Archive
## builder calls them with a kit and a placement. Everything faces the way the frames show it.

const BOOK_COLOURS := [
	Color(0.55, 0.16, 0.14), Color(0.2, 0.26, 0.45), Color(0.22, 0.36, 0.24), Color(0.45, 0.3, 0.16),
	Color(0.84, 0.76, 0.58), Color(0.62, 0.46, 0.2), Color(0.36, 0.18, 0.3), Color(0.3, 0.2, 0.12),
]


## A bookcase standing against a wall. `pos` = floor point at the middle of its front edge; `face` =
## the way its front faces (horizontal unit); `w` wide, `h` tall, `d` deep. Shelves every 0.62 m,
## crammed with books of every colour, a few leaning, a few gaps.
static func bookcase(kit: SolariKit, pos: Vector3, face: Vector3, w: float, h: float, d := 0.7, solid := true) -> void:
	var side := face.cross(Vector3.UP).normalized()
	var b := Basis(side, Vector3.UP, face)
	var back := pos - face * d
	var ctr := pos - face * d * 0.5
	# carcass: two sides, a top, a back, a plinth
	kit.box("wood", ctr + side * (w * 0.5 - 0.06) + Vector3.UP * h * 0.5, Vector3(0.12, h, d), b)
	kit.box("wood", ctr - side * (w * 0.5 - 0.06) + Vector3.UP * h * 0.5, Vector3(0.12, h, d), b)
	kit.box("wood", ctr + Vector3.UP * (h - 0.08), Vector3(w + 0.2, 0.16, d + 0.1), b)
	kit.box("wood_dark", back + face * 0.03 + Vector3.UP * h * 0.5, Vector3(w, h, 0.06), b)
	kit.box("wood", ctr + Vector3.UP * 0.12, Vector3(w, 0.24, d), b)
	var shelf_h := 0.62
	var y := 0.24
	var inner := w - 0.24
	while y + shelf_h < h - 0.1:
		kit.box("wood", ctr + Vector3.UP * (y + 0.02), Vector3(w - 0.12, 0.04, d - 0.04), b)
		# books along this shelf
		var u := -inner * 0.5
		while u < inner * 0.5 - 0.05:
			var bw := kit.rng.randf_range(0.04, 0.11)
			if kit.rng.randf() < 0.06:
				u += kit.rng.randf_range(0.1, 0.3)     # a gap where books are out
				continue
			var bh := kit.rng.randf_range(0.34, 0.54)
			var bd := kit.rng.randf_range(0.26, d - 0.12)
			var col: Color = BOOK_COLOURS[kit.rng.randi() % BOOK_COLOURS.size()]
			col = col * kit.rng.randf_range(0.85, 1.15)
			var c := back + face * (bd * 0.5 + 0.06) + side * (u + bw * 0.5) + Vector3.UP * (y + 0.04 + bh * 0.5)
			kit.box("books", c, Vector3(bw, bh, bd), b, col)
			u += bw + 0.004
		y += shelf_h
	if solid:
		kit.solid(ctr + Vector3.UP * h * 0.5, Vector3(w, h, d), b)


## A scribe's writing desk. `pos` = floor under the middle of the desk; the scribe stands at
## pos + face * 0.9 looking along -face. Slanted top, a bank of drawers, a stool.
static func desk(kit: SolariKit, pos: Vector3, face: Vector3, w := 2.0, d := 0.95) -> void:
	var side := face.cross(Vector3.UP).normalized()
	var b := Basis(side, Vector3.UP, face)
	var top_y := 0.86
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kit.box("wood_dark", pos + side * (w * 0.5 - 0.1) * sx + face * (d * 0.5 - 0.1) * sz + Vector3.UP * top_y * 0.5,
				Vector3(0.1, top_y, 0.1), b)
	# the top, tilted a little toward the scribe
	var tilt := Basis(side, deg_to_rad(-8.0)) * b
	kit.box("wood", pos + Vector3.UP * (top_y + 0.04), Vector3(w, 0.08, d), tilt)
	# a drawer bank on the left
	kit.box("wood", pos - side * (w * 0.5 - 0.35) + Vector3.UP * top_y * 0.55, Vector3(0.6, top_y * 0.8, d - 0.1), b)
	kit.box("gold", pos - side * (w * 0.5 - 0.35) + face * (d * 0.5 - 0.02) + Vector3.UP * top_y * 0.6, Vector3(0.14, 0.04, 0.03), b)
	# a shelf at the back for pots and books
	kit.box("wood", pos - face * (d * 0.5 - 0.1) + Vector3.UP * (top_y + 0.22), Vector3(w, 0.05, 0.22), b)
	# stool
	var st := pos + face * (d * 0.5 + 0.55)
	kit.box("wood_dark", st + Vector3.UP * 0.3, Vector3(0.12, 0.6, 0.12), b)
	kit.prism("wood", st + Vector3.UP * 0.6, 0.28, 0.07, 8)
	kit.solid(pos + Vector3.UP * 0.5, Vector3(w, 1.0, d), b)


## A little still-life of desk clutter on a desk top: a book or two, papers, an ink pot.
static func clutter(kit: SolariKit, pos: Vector3, face: Vector3, rich := false) -> void:
	var side := face.cross(Vector3.UP).normalized()
	var b := Basis(side, Vector3.UP, face)
	var top := pos + Vector3.UP * 0.93
	var n := 3 if rich else 2
	for i in n:
		var col: Color = BOOK_COLOURS[kit.rng.randi() % BOOK_COLOURS.size()]
		var p := top - face * 0.25 + side * kit.rng.randf_range(0.3, 0.8) + Vector3.UP * (0.035 + i * 0.07)
		kit.box("books", p, Vector3(0.36, 0.07, 0.26), Basis(Vector3.UP, kit.rng.randf_range(-0.3, 0.3)) * b, col)
	kit.box("paper", top + side * -0.1 + face * 0.1, Vector3(0.34, 0.01, 0.46), Basis(Vector3.UP, 0.12) * b)
	kit.prism("ink", top - face * 0.32 - side * 0.55 + Vector3.UP * 0.2, 0.06, 0.1, 6)


## A balustrade from `a` to `b` (floor points, same height): plinth, turned balusters, a broad rail,
## solid to the player at rail height.
static func balustrade(kit: SolariKit, a: Vector3, b: Vector3, h := 1.1, spacing := 0.42, key := "marble") -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var face := Vector3.UP.cross(along).normalized()
	var bs := Basis(along, Vector3.UP, face)
	var mid := (a + b) * 0.5
	kit.box(key, mid + Vector3.UP * 0.12, Vector3(length, 0.24, 0.55), bs)
	kit.box(key, mid + Vector3.UP * (h - 0.1), Vector3(length + 0.1, 0.2, 0.6), bs)
	kit.box("gold", mid + Vector3.UP * (h - 0.21), Vector3(length + 0.12, 0.04, 0.62), bs)
	var n := int(length / spacing)
	for i in n:
		var p := a + along * (spacing * (i + 0.5) + (length - spacing * n) * 0.5)
		kit.prism(key, p + Vector3.UP * 0.24, 0.08, 0.14, 6, 0.13)
		kit.prism(key, p + Vector3.UP * 0.38, 0.13, 0.26, 6, 0.07)
		kit.prism(key, p + Vector3.UP * 0.64, 0.07, 0.18, 6, 0.1)
		kit.prism(key, p + Vector3.UP * 0.82, 0.1, h - 1.02, 6, 0.1)
	# posts every few metres
	var posts := maxi(1, int(length / 3.0))
	for i in posts + 1:
		var p := a + along * (length * i / posts)
		kit.box(key, p + Vector3.UP * h * 0.52, Vector3(0.38, h * 1.04, 0.62), bs)
	kit.solid(mid + Vector3.UP * (h * 0.5 + 0.4), Vector3(length, h + 0.8, 0.6), bs)


## The sun mosaic set into the balcony floor: an eight-pointed gold star inside rings of ivory and
## gold tesserae (02_balcony.png).
static func sun_mosaic(kit: SolariKit, c: Vector3, r: float) -> void:
	var y := Vector3.UP * 0.012
	kit.disc("gold", c + y, r, 48, r - 0.28)
	kit.disc("marble_blue", c + y, r - 0.28, 48, r - 0.36)
	# a band of alternating tesserae
	var n := 48
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var key := "gold" if i % 2 == 0 else "ivory"
		kit.quad(key, c + y + d0 * (r * 0.62), c + y + d0 * (r - 0.36), c + y + d1 * (r - 0.36), c + y + d1 * (r * 0.62), Vector3.UP)
	kit.disc("ivory", c + y * 0.9, r * 0.62, 32)
	# the star: 16 rays, long and short
	var rays := 16
	for i in rays:
		var a := TAU * i / rays
		var tip := (r * 0.98) if i % 2 == 0 else (r * 0.66)
		var w := 0.2
		var d := Vector3(sin(a), 0, cos(a))
		var dl := Vector3(sin(a - w), 0, cos(a - w))
		var dr := Vector3(sin(a + w), 0, cos(a + w))
		var y2 := y * 1.6
		kit.tri("gold" if i % 2 == 0 else "gold_dim", c + y2 + dl * r * 0.22, c + y2 + d * tip, c + y2 + dr * r * 0.22, Vector3.UP)
	kit.disc("gold", c + y * 2.0, r * 0.24, 16)
	kit.disc("ivory", c + y * 2.2, r * 0.12, 12)


## A brazier: three honey-wood legs, a bronze bowl, a heap of logs. The flames are a separate node
## (Brazier fire, ColdOpenArchive) so they can move. Returns the point the fire sits on.
static func brazier(kit: SolariKit, pos: Vector3) -> Vector3:
	for i in 3:
		var a := TAU * i / 3.0
		var foot := pos + Vector3(sin(a), 0, cos(a)) * 0.55
		var top := pos + Vector3.UP * 0.95 + Vector3(sin(a), 0, cos(a)) * 0.25
		var mid := (foot + top) * 0.5
		var dir := (top - foot).normalized()
		var s := dir.cross(Vector3(cos(a), 0, -sin(a))).normalized()
		kit.box("wood_dark", mid, Vector3(0.09, foot.distance_to(top), 0.09), Basis(s.cross(dir).normalized(), dir, s))
	kit.prism("bronze", pos + Vector3.UP * 0.9, 0.32, 0.32, 8, 0.62)
	kit.prism("gold", pos + Vector3.UP * 1.2, 0.64, 0.06, 8, 0.64)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var d := Vector3(sin(a), 0, cos(a))
		kit.box("wood_dark", pos + Vector3.UP * 1.24 + d * 0.12, Vector3(0.12, 0.12, 0.62), Basis(Vector3.UP, a))
	kit.solid(pos + Vector3.UP * 0.6, Vector3(1.1, 1.2, 1.1))
	return pos + Vector3.UP * 1.26


## A festival banner on a gilded pole: ivory cloth, a gold sun, a gold swallowtail hem.
static func banner(kit: SolariKit, foot: Vector3, face: Vector3, height := 7.0, bw := 1.7, bh := 4.2) -> void:
	var side := face.cross(Vector3.UP).normalized()
	kit.prism("gold", foot, 0.1, height, 6, 0.08)
	kit.prism("gold", foot + Vector3.UP * height, 0.16, 0.3, 6, 0.0)
	var bar := foot + Vector3.UP * (height - 0.35) + face * 0.12
	kit.box("gold", bar + side * (bw * 0.5 - 0.1), Vector3(bw + 0.2, 0.08, 0.08), Basis(side, Vector3.UP, face))
	var top_l := bar + face * 0.02
	var top_r := bar + side * bw + face * 0.02
	var bot_l := top_l - Vector3.UP * bh
	var bot_r := top_r - Vector3.UP * bh
	kit.quad("ivory", bot_l, bot_r, top_r, top_l, face)
	kit.quad("ivory", top_l, top_r, bot_r, bot_l, -face)
	# swallowtail
	var tail := bot_l + side * bw * 0.5 - Vector3.UP * 0.35
	kit.tri("cloth_gold", bot_l, bot_l + side * bw * 0.5 + Vector3.UP * 0.45, bot_l - Vector3.UP * 0.5, face)
	kit.tri("cloth_gold", bot_r, bot_r - Vector3.UP * 0.5, bot_l + side * bw * 0.5 + Vector3.UP * 0.45, face)
	kit.quad("cloth_gold", bot_l, bot_r, bot_r + Vector3.UP * 0.35, bot_l + Vector3.UP * 0.35, face)
	kit.quad("cloth_gold", bot_l + Vector3.UP * 0.35, bot_r + Vector3.UP * 0.35, bot_r, bot_l, -face)
	var _t := tail
	# the sun: a disc with rays, on both faces
	var sc := top_l + side * bw * 0.5 - Vector3.UP * bh * 0.38
	for f in [face, -face]:
		var off: Vector3 = f * 0.02
		var n := 12
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var d0 := side * sin(a0) + Vector3.UP * cos(a0)
			var d1 := side * sin(a1) + Vector3.UP * cos(a1)
			kit.tri("cloth_gold", sc + off, sc + off + d0 * 0.34, sc + off + d1 * 0.34, f)
			var dm := (d0 + d1).normalized()
			kit.tri("cloth_gold", sc + off + d0 * 0.4, sc + off + dm * 0.7, sc + off + d1 * 0.4, f)


## A swag of greenery and white flowers between two points, drooping.
static func garland(kit: SolariKit, a: Vector3, b: Vector3, sag := 0.35, flowers := true, key := "garland") -> void:
	var segs := 8
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		var mid := (prev + p) * 0.5
		var dir := (p - prev)
		var len := dir.length()
		dir = dir.normalized()
		var s := dir.cross(Vector3.UP).normalized()
		if s.length() < 0.1:
			s = Vector3.RIGHT
		kit.box(key, mid, Vector3(0.16, 0.16, len + 0.04), Basis(s, dir.cross(s).normalized(), dir))
		if flowers and i % 2 == 0:
			kit.box("flower", mid + Vector3.UP * 0.08, Vector3(0.12, 0.08, 0.12), Basis(Vector3.UP, t * 3.0))
		prev = p
