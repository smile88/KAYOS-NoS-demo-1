extends Node3D
class_name ColdOpenCity
## Astra'Thalas below the Archive, as the style frames show it: a golden bowl of marble terraces
## stepping down to the Tower of Celestial Harmony, every window lit, the Song's gold threads strung
## from the Tower to every lamp, hundreds of sky-lanterns held in the air — and on the far hills the
## small pale lights of the echo stones, which nobody in the city has ever noticed.
##
## All of it is built once, in code, on SolariKit (one mesh per terrace ring). The Silence needs no
## per-object scripting here: the world, thread and lantern shaders all read the ring's global radius.
## What the cutscene does drive by hand — the column of light, the echo stones, the ring's visible
## front — is exposed as members.

const L = preload("res://threed/coldopen/ColdOpenLayout.gd")
const LANTERN_SHADER := preload("res://threed/coldopen/shaders/lantern.gdshader")
const THREAD_SHADER := preload("res://threed/coldopen/shaders/thread.gdshader")
const COLUMN_SHADER := preload("res://threed/coldopen/shaders/light_column.gdshader")
const WALL_SHADER := preload("res://threed/coldopen/shaders/silence_wall.gdshader")

## Terraces: [inner radius, outer radius, deck height] measured from the Tower. The Archive stands on
## the ring at y 0; the plaza round the Tower's foot is L.PLAZA_Y.
const RINGS := [
	[0.0, 58.0, -34.0], [58.0, 96.0, -30.0], [96.0, 135.0, -24.0], [135.0, 174.0, -16.0],
	[174.0, 212.0, -8.0], [212.0, 290.0, -0.3], [290.0, 350.0, 8.0], [350.0, 420.0, 16.0],
	[420.0, 540.0, 24.0],
]
const AVENUES := 8                  # radial processional ways, the first pointing at the Archive
const AVENUE_HALF := 7.0
## Keep the city's random fabric off the Archive (its own builder) and the street by its gate.
const ARCHIVE_KEEP := Rect2(Vector2(-84.0, -22.0), Vector2(128.0, 80.0))

var mats: Dictionary
var rng := RandomNumberGenerator.new()
## Echo stones, farthest first — the order the cutscene puts them out in.
var echo_stones: Array = []
var column: MeshInstance3D
var column_glow: MeshInstance3D
var column_light: OmniLight3D
var silence_wall: MeshInstance3D
var tower_root: Node3D
var lanterns: MultiMeshInstance3D
var threads_mat: ShaderMaterial
var _lamp_tops: Array = []          # candidate thread ends: [position, ring index]


static func ground_y(d: float) -> float:
	for r in RINGS:
		if d < r[1]:
			return r[2]
	return RINGS[RINGS.size() - 1][2]


static func tower_d(p: Vector3) -> float:
	return Vector2(p.x - L.TOWER.x, p.z - L.TOWER.z).length()


func build(p_mats: Dictionary) -> void:
	mats = p_mats
	rng.seed = 20000
	mats["hill"] = ColdOpenPalette.mat(Color(0.13, 0.15, 0.24), 0.95, 0.0, 0.0, Color(0, 0, 0), 0.0, 1.0, 1.0)
	_terraces()
	_avenues()
	_buildings()
	_tower()
	_hills()
	_echo_stones()
	_threads()
	_lanterns()
	_column()
	_wall()


# --- terraces ---------------------------------------------------------------------------------
func _terraces() -> void:
	var kit := SolariKit.new(mats, 11)
	var segs := 128
	for i in RINGS.size():
		var r0: float = RINGS[i][0]
		var r1: float = RINGS[i][1]
		var y: float = RINGS[i][2]
		for s in segs:
			var a0 := TAU * s / segs
			var a1 := TAU * (s + 1) / segs
			var d0 := Vector3(sin(a0), 0, cos(a0))
			var d1 := Vector3(sin(a1), 0, cos(a1))
			var c := L.TOWER
			var top := func(d: Vector3, r: float) -> Vector3: return Vector3(c.x, y, c.z) + d * r
			if r0 <= 0.0:
				kit.tri("street", top.call(d0, 0.0), top.call(d0, r1), top.call(d1, r1), Vector3.UP)
			else:
				kit.quad("street", top.call(d0, r0), top.call(d0, r1), top.call(d1, r1), top.call(d1, r0), Vector3.UP)
				# the retaining wall up from the ring below, facing the Tower
				var yb: float = RINGS[i - 1][2]
				var lo0 := Vector3(c.x, yb, c.z) + d0 * r0
				var lo1 := Vector3(c.x, yb, c.z) + d1 * r0
				kit.quad("marble", lo1, lo0, top.call(d0, r0), top.call(d1, r0), -(d0 + d1).normalized())
				# a gold coping along the lip
				var cp0: Vector3 = top.call(d0, r0) + Vector3.UP * 0.5
				var cp1: Vector3 = top.call(d1, r0) + Vector3.UP * 0.5
				kit.quad("gold_dim", top.call(d0, r0), top.call(d1, r0), cp1, cp0, -(d0 + d1).normalized())
			if i == RINGS.size() - 1:
				# the outer rim wall, so the bowl has an edge against the hills
				kit.quad("marble", top.call(d1, r1), top.call(d0, r1), top.call(d0, r1) + Vector3.UP * 6.0,
					top.call(d1, r1) + Vector3.UP * 6.0, -(d0 + d1).normalized())
		# the plaza gets a great sun-disc inlay round the Tower's foot
		if i == 0:
			kit.disc("gold_dim", Vector3(c_x(), y + 0.05, L.TOWER.z), 40.0, 32, 36.0)
			kit.disc("marble_floor", Vector3(c_x(), y + 0.04, L.TOWER.z), 36.0, 32, 20.0)
	kit.commit(self, "Terraces")


func c_x() -> float:
	return L.TOWER.x


# --- avenues and lamps --------------------------------------------------------------------------
func _avenue_angle(k: int) -> float:
	return TAU * k / AVENUES


## True if the ground point sits on a radial avenue (kept clear of buildings).
func _on_avenue(p: Vector3, pad := 0.0) -> bool:
	var v := Vector2(p.x - L.TOWER.x, p.z - L.TOWER.z)
	var r := v.length()
	if r < 1.0:
		return true
	var a := atan2(v.x, v.y)
	for k in AVENUES:
		var da := wrapf(a - _avenue_angle(k), -PI, PI)
		if absf(da) * r < AVENUE_HALF + pad:
			return true
	return false


func _avenues() -> void:
	var kit := SolariKit.new(mats, 12)
	for k in AVENUES:
		var a := _avenue_angle(k)
		var dir := Vector3(sin(a), 0, cos(a))
		var side := dir.cross(Vector3.UP).normalized()
		var r := 70.0
		while r < 555.0:
			var y := ground_y(r)
			var p := L.TOWER + dir * r
			p.y = y
			if not ARCHIVE_KEEP.has_point(Vector2(p.x, p.z)):
				for sgn in [-1.0, 1.0]:
					var q: Vector3 = p + side * (AVENUE_HALF - 0.8) * sgn
					kit.box("bronze", q + Vector3.UP * 2.0, Vector3(0.18, 4.0, 0.18))
					kit.box("song_glow", q + Vector3.UP * 4.25, Vector3(0.5, 0.5, 0.5))
					_lamp_tops.append([q + Vector3.UP * 4.25, r])
			r += 18.0
		# the avenue's paving: a gold-edged processional strip, stepping with the terraces
		for i in range(1, RINGS.size()):
			var r0: float = RINGS[i][0]
			var r1: float = RINGS[i][1]
			var y2: float = RINGS[i][2] + 0.03
			var a0 := L.TOWER + dir * r0 + side * AVENUE_HALF
			var b0 := L.TOWER + dir * r0 - side * AVENUE_HALF
			var a1 := L.TOWER + dir * r1 + side * AVENUE_HALF
			var b1 := L.TOWER + dir * r1 - side * AVENUE_HALF
			for q in [a0, b0, a1, b1]:
				q.y = y2
			if ARCHIVE_KEEP.has_point(Vector2(a1.x, a1.z)) and ARCHIVE_KEEP.has_point(Vector2(b0.x, b0.z)):
				continue
			a0.y = y2; b0.y = y2; a1.y = y2; b1.y = y2
			kit.quad("marble_floor", b0, a0, a1, b1, Vector3.UP)
			# steps up the retaining wall so the avenue reads as continuous
			var yb: float = RINGS[i - 1][2]
			var foot := L.TOWER + dir * (r0 - 8.0)
			foot.y = yb
			kit.stairs("marble", foot, dir, RINGS[i][2] - yb, 8.0, AVENUE_HALF * 2.0 - 2.0, 0.35)
	kit.commit(self, "Avenues")


# --- the city fabric ----------------------------------------------------------------------------
func _buildings() -> void:
	for i in range(1, RINGS.size()):
		var kit := SolariKit.new(mats, 100 + i)
		kit.facet_jitter = 0.07
		var r0: float = RINGS[i][0]
		var r1: float = RINGS[i][1]
		var y: float = RINGS[i][2]
		var width := r1 - r0
		var rows := 2 if width < 60.0 else 3
		for row in rows:
			var rr := r0 + width * (row + 0.5) / rows
			var a := rng.randf() * 0.1
			while a < TAU:
				var w := rng.randf_range(8.0, 16.0)
				var aw := w / rr
				var center := L.TOWER + Vector3(sin(a + aw * 0.5), 0, cos(a + aw * 0.5)) * rr
				center.y = y
				var keep := ARCHIVE_KEEP.grow(4.0).has_point(Vector2(center.x, center.z))
				if not keep and not _on_avenue(center, w * 0.5 + 2.0):
					var depth := minf(rng.randf_range(8.0, 14.0), width / rows - 3.0)
					_building(kit, center, a + aw * 0.5, w, depth, i)
				a += aw + rng.randf_range(2.0, 6.0) / rr
		kit.commit(self, "City%d" % i)


## One Solari house, facing the Tower: ivory walls, a gold roof, and warm windows in rows.
func _building(kit: SolariKit, base: Vector3, ang: float, w: float, d: float, ring: int) -> void:
	var out := Vector3(sin(ang), 0, cos(ang))       # away from the Tower
	var side := out.cross(Vector3.UP).normalized()
	var b := Basis(side, Vector3.UP, out)
	var tall := rng.randf() < 0.06
	var h := rng.randf_range(24.0, 34.0) if tall else rng.randf_range(7.0, 17.0)
	if tall:
		w = minf(w, 9.0)
		d = minf(d, 9.0)
	var wall := "city_wall" if rng.randf() < 0.6 else "city_wall_b"
	kit.box(wall, base + Vector3.UP * h * 0.5, Vector3(w, h, d), b)
	# a plinth course
	kit.box("stone_base", base + Vector3.UP * 0.6, Vector3(w + 0.4, 1.2, d + 0.4), b)
	# windows: storeys every 3.4 m, on the face toward the Tower and the face away from it
	var storeys := int((h - 2.0) / 3.4)
	var cols := maxi(1, int(w / 3.0))
	for f: float in [-1.0, 1.0]:
		var n := out * f
		for s in storeys:
			for c in cols:
				if rng.randf() > 0.72:
					continue
				var u := (c + 0.5) / cols - 0.5
				var p := base + side * (u * w) + Vector3.UP * (2.2 + s * 3.4) + n * (d * 0.5 + 0.03)
				var hw := side * 0.55
				var hh := Vector3.UP * 0.85
				var key := "window_lit" if rng.randf() < 0.85 else "glass_dark"
				kit.quad(key, p - hw - hh, p + hw - hh, p + hw + hh, p - hw + hh, n)
	# roofs
	var top := base + Vector3.UP * h
	var roll := rng.randf()
	var roof := "city_roof" if rng.randf() < 0.75 else "city_roof_b"
	if tall or roll < 0.12:
		# a drum and a gold dome
		var r := minf(w, d) * 0.42
		kit.prism(wall, top, r, 2.5, 10)
		kit.dome("city_roof", top + Vector3.UP * 2.5, r * 1.02, r * 1.1, 10, 3)
		kit.prism("gold", top + Vector3.UP * (2.5 + r * 1.1), 0.25, 3.0, 4, 0.02)
	elif roll < 0.72:
		# a hipped roof
		var e := 0.4
		var rh := minf(w, d) * rng.randf_range(0.28, 0.45)
		var c0 := top + (-side * (w * 0.5 + e) - out * (d * 0.5 + e))
		var c1 := top + (side * (w * 0.5 + e) - out * (d * 0.5 + e))
		var c2 := top + (side * (w * 0.5 + e) + out * (d * 0.5 + e))
		var c3 := top + (-side * (w * 0.5 + e) + out * (d * 0.5 + e))
		var ridge := maxf(0.0, (w - d) * 0.5)
		var r0 := top + Vector3.UP * rh - side * ridge
		var r1 := top + Vector3.UP * rh + side * ridge
		kit.quad(roof, c0, c1, r1, r0)
		kit.quad(roof, c2, c3, r0, r1)
		kit.tri(roof, c1, c2, r1)
		kit.tri(roof, c3, c0, r0)
	else:
		# a flat roof behind a parapet, with a little gilded pavilion
		kit.box(wall, top + Vector3.UP * 0.5 + out * (d * 0.5 - 0.2), Vector3(w, 1.0, 0.4), b)
		kit.box(wall, top + Vector3.UP * 0.5 - out * (d * 0.5 - 0.2), Vector3(w, 1.0, 0.4), b)
		kit.box(wall, top + Vector3.UP * 0.5 + side * (w * 0.5 - 0.2), Vector3(0.4, 1.0, d), b)
		kit.box(wall, top + Vector3.UP * 0.5 - side * (w * 0.5 - 0.2), Vector3(0.4, 1.0, d), b)
		if rng.randf() < 0.5:
			kit.prism("city_roof", top, 1.6, 2.2, 6, 0.1)


# --- the Tower of Celestial Harmony -------------------------------------------------------------
func _tower() -> void:
	tower_root = Node3D.new()
	tower_root.name = "Tower"
	add_child(tower_root)
	var kit := SolariKit.new(mats, 77)
	var c := L.TOWER
	# tiers: [bottom y, height, radius, top radius, sides]
	var tiers := [
		[0.0, 28.0, 24.0, 22.0, 16],
		[28.0, 24.0, 20.0, 18.5, 16],
		[52.0, 22.0, 17.0, 15.5, 16],
		[74.0, 22.0, 14.0, 12.8, 16],
		[96.0, 20.0, 11.5, 10.2, 12],
		[116.0, 20.0, 9.0, 7.6, 12],
		[136.0, 28.0, 7.0, 5.0, 12],
		[164.0, 20.0, 5.0, 5.0, 12],
	]
	for t in tiers:
		var b := c + Vector3.UP * float(t[0])
		kit.prism("marble", b, t[2], t[1], t[4], t[3], true)
		# a gold band and a gallery ledge at the top of each tier
		var top := b + Vector3.UP * float(t[1])
		kit.prism("gold", top - Vector3.UP * 0.8, float(t[3]) + 0.3, 0.8, t[4])
		kit.prism("marble_warm", top, float(t[3]) + 1.6, 0.5, t[4])
		# gallery posts
		var n: int = t[4] * 2
		for k in n:
			var a := TAU * k / n
			var p := top + Vector3(sin(a), 0, cos(a)) * (float(t[3]) + 1.3)
			kit.box("gold", p + Vector3.UP * 0.6, Vector3(0.2, 1.2, 0.2))
		# tall slit windows of Song-light up each tier
		var slits := 8 if t[4] >= 16 else 6
		for k in slits:
			var a := TAU * (k + 0.5) / slits
			var dirv := Vector3(sin(a), 0, cos(a))
			var r := lerpf(float(t[2]), float(t[3]), 0.5) + 0.06
			var p := b + dirv * r + Vector3.UP * float(t[1]) * 0.5
			var side := dirv.cross(Vector3.UP).normalized()
			var hw := side * 0.5
			var hh := Vector3.UP * float(t[1]) * 0.3
			kit.quad("song_line", p - hw - hh, p + hw - hh, p + hw + hh, p - hw + hh, dirv)
	# the great base: a stepped podium out of the plaza
	for s in 4:
		kit.prism("marble_floor", c + Vector3.UP * (s * 0.8), 38.0 - s * 2.6, 0.8, 16)
	# the apex: an open crown of gold ribs round the platform the celebrant stands on
	var apex := c + Vector3.UP * L.TOWER_H
	for k in 8:
		var a := TAU * k / 8.0
		var p := apex + Vector3(sin(a), 0, cos(a)) * 4.6
		kit.box("gold", p + Vector3.UP * 3.0, Vector3(0.45, 6.0, 0.45))
	kit.disc("gold", apex + Vector3.UP * 0.05, 4.4, 16, 3.6)
	kit.prism("gold", apex + Vector3.UP * 6.0, 5.1, 0.6, 12, 5.1)
	kit.commit(tower_root, "TowerMesh")
	var halo := OmniLight3D.new()
	halo.position = apex + Vector3.UP * 3.0
	halo.light_color = ColdOpenPalette.SONG
	halo.light_energy = 6.0
	halo.omni_range = 60.0
	halo.shadow_enabled = false
	halo.add_to_group("song_light")
	tower_root.add_child(halo)
	column_light = halo
	# uplighters round the podium: the Tower stands white-gold against the night
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var sp := SpotLight3D.new()
		sp.position = c + Vector3(sin(a), 0, cos(a)) * 46.0 + Vector3.UP * 3.0
		sp.light_color = Color(1.0, 0.8, 0.5)
		sp.light_energy = 14.0
		sp.spot_range = 220.0
		sp.spot_angle = 20.0
		sp.spot_attenuation = 0.4
		sp.shadow_enabled = false
		sp.add_to_group("song_light")
		tower_root.add_child(sp)
		sp.look_at_from_position(sp.position, c + Vector3.UP * 90.0, Vector3.UP)


# --- the land beyond the city -------------------------------------------------------------------
func _hills() -> void:
	var kit := SolariKit.new(mats, 5)
	kit.facet_jitter = 0.12
	var n := 46
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.08
		var d := rng.randf_range(1500.0, 2600.0)
		var p := L.TOWER + Vector3(sin(a), 0, cos(a)) * d
		p.y = -60.0
		var r := rng.randf_range(260.0, 520.0)
		var h := rng.randf_range(90.0, 260.0)
		kit.prism("hill", p, r, h, rng.randi_range(5, 7), rng.randf_range(20.0, 80.0), false, rng.randf() * TAU)
	# the plain under everything, out to the hills
	kit.disc("hill", L.TOWER + Vector3.UP * -58.0, 3200.0, 24, 560.0)
	kit.commit(self, "Hills")


## The echo stones: small pale lights far off on the hills in every direction. Canon: the Night is a
## network activation, not one stone in a vault — so they go out first, farthest first, closing in.
func _echo_stones() -> void:
	var n := 14
	var list := []
	for i in n:
		var a := TAU * (i + rng.randf() * 0.6) / n
		var d := rng.randf_range(950.0, 1650.0)
		var p := L.TOWER + Vector3(sin(a), 0, cos(a)) * d
		p.y = rng.randf_range(30.0, 110.0)
		var root := Node3D.new()
		root.name = "EchoStone%d" % i
		root.position = p
		var kit := SolariKit.new(mats, 300 + i)
		kit.prism("marble_dark", Vector3(0, -40, 0), 7.0, 58.0, 4, 0.6)
		kit.commit(root, "Obelisk")
		# a pale beacon: a glow at the tip and a thin beam straight up, so that from the city it reads
		# as one small cold light on the hill — and so its going out can be seen from the balcony
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.8, 0.88, 1.0) * 4.0
		m.disable_fog = true
		var glow := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 14.0
		sm.height = 28.0
		sm.radial_segments = 8
		sm.rings = 4
		glow.mesh = sm
		glow.material_override = m
		glow.position = Vector3(0, 20.0, 0)
		root.add_child(glow)
		var beam := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 1.2
		bm.bottom_radius = 4.0
		bm.height = 380.0
		bm.radial_segments = 6
		beam.mesh = bm
		var bmat := m.duplicate() as StandardMaterial3D
		bmat.albedo_color = Color(0.55, 0.65, 0.95) * 1.1
		beam.material_override = bmat
		beam.position = Vector3(0, 210.0, 0)
		beam.name = "Beam"
		root.add_child(beam)
		add_child(root)
		list.append([d, root])
	list.sort_custom(func(x, y): return x[0] > y[0])
	for e in list:
		echo_stones.append(e[1])


# --- the threads --------------------------------------------------------------------------------
func _threads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hub := L.TOWER + Vector3.UP * (L.THREAD_HUB_Y - L.PLAZA_Y)
	var targets: Array = []
	# a wide spread of street lamps across the city
	_lamp_tops.shuffle()
	for e in _lamp_tops:
		if targets.size() >= 34:
			break
		var q: Vector3 = e[0]
		if Vector2(q.x, q.z - L.BAL_Z0).length() < 150.0:
			continue     # none plunging past the balcony into the street right below it
		targets.append(q)
	# and the great fan the balcony sees: out to the Archive's flanking towers and the roofs beside it
	for x in [-17.0, 17.0, -48.0, 48.0, -80.0, 80.0]:
		targets.append(Vector3(x, L.BAL_Y + 14.0 + absf(x) * 0.08, -8.0 + absf(x) * 0.05))
	for tgt in targets:
		var dirh := Vector3(tgt.x - hub.x, 0, tgt.z - hub.z).normalized()
		var a: Vector3 = hub + dirh * 13.0
		_thread(st, a, tgt, 0.22)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Threads"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = THREAD_SHADER
	mi.material_override = m
	threads_mat = m
	add_child(mi)


## One sagging thread from a to b as a string of thin crossed ribbons (reads from any angle).
func _thread(st: SurfaceTool, a: Vector3, b: Vector3, thick: float) -> void:
	var segs := 14
	var span := a.distance_to(b)
	var sag := span * 0.06
	var pts := []
	for i in segs + 1:
		var t := float(i) / segs
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		pts.append(p)
	for i in segs:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var dir := (p1 - p0).normalized()
		var s1 := dir.cross(Vector3.UP).normalized() * thick * 0.5
		var s2 := dir.cross(s1).normalized() * thick * 0.5
		for s in [s1, s2]:
			st.add_vertex(p0 - s)
			st.add_vertex(p1 - s)
			st.add_vertex(p1 + s)
			st.add_vertex(p0 - s)
			st.add_vertex(p1 + s)
			st.add_vertex(p0 + s)


# --- the sky-lanterns ---------------------------------------------------------------------------
func _lanterns() -> void:
	var mesh := _lantern_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var pts := []
	for i in 900:
		var near := i < 140
		var p: Vector3
		if near:
			# a drift of them close in front of the balcony, at and just above eye level
			p = Vector3(rng.randf_range(-70.0, 70.0), L.BAL_Y + rng.randf_range(-2.0, 40.0), rng.randf_range(-35.0, -150.0))
		else:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 470.0 + 25.0
			p = L.TOWER + Vector3(sin(a), 0, cos(a)) * d
			p.y = ground_y(d) + rng.randf_range(24.0, 150.0)
		if tower_d(p) < 34.0:
			continue
		pts.append(p)
	mm.instance_count = pts.size()
	for i in pts.size():
		var p: Vector3 = pts[i]
		var s := rng.randf_range(0.9, 1.5)
		var xf := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p)
		mm.set_instance_transform(i, xf)
		var floor_y := ground_y(tower_d(p))
		if ARCHIVE_KEEP.has_point(Vector2(p.x, p.z)):
			floor_y = maxf(floor_y, 0.0)
		mm.set_instance_custom_data(i, Color(rng.randf(), p.y - floor_y - 0.6, rng.randf() * 0.8, 0))
	lanterns = MultiMeshInstance3D.new()
	lanterns.name = "SkyLanterns"
	lanterns.multimesh = mm
	lanterns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = LANTERN_SHADER
	lanterns.material_override = m
	# the lanterns fall a long way: keep them from being culled as they drop
	lanterns.custom_aabb = AABB(Vector3(-800, -120, -1100), Vector3(1600, 400, 1600))
	add_child(lanterns)


func _lantern_mesh() -> ArrayMesh:
	# a six-sided paper lantern, wider at the top, open at the bottom
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var rb := 0.38
	var rt := 0.5
	var h := 1.0
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var n := (d0 + d1).normalized()
		var v := [d0 * rb, d1 * rb, d1 * rt + Vector3.UP * h, d0 * rt + Vector3.UP * h]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.add_vertex(v[k])
		# lid
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(Vector3.UP * (h + 0.12))
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(d1 * rt + Vector3.UP * h)
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(d0 * rt + Vector3.UP * h)
	return st.commit()


# --- the column of light and the visible front of the Silence -----------------------------------
func _column() -> void:
	var apex := L.TOWER + Vector3.UP * L.TOWER_H
	for spec in [["Column", 2.4, 1.0], ["ColumnGlow", 7.0, 0.35]]:
		var cm := CylinderMesh.new()
		cm.top_radius = spec[1]
		cm.bottom_radius = spec[1]
		cm.height = 700.0
		cm.radial_segments = 16
		cm.cap_top = false
		cm.cap_bottom = false
		var mi := MeshInstance3D.new()
		mi.name = spec[0]
		mi.mesh = cm
		mi.position = apex + Vector3.UP * 356.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = COLUMN_SHADER
		m.set_shader_parameter("strength", spec[2])
		mi.material_override = m
		add_child(mi)
		if spec[0] == "Column":
			column = mi
		else:
			column_glow = mi


func _wall() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 160.0
	cm.radial_segments = 96
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	silence_wall = MeshInstance3D.new()
	silence_wall.name = "SilenceFront"
	silence_wall.mesh = cm
	silence_wall.position = L.TOWER + Vector3.UP * 70.0
	silence_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = WALL_SHADER
	silence_wall.material_override = m
	silence_wall.visible = false
	add_child(silence_wall)


## Set the front's radius (the cutscene calls this every frame while the ring runs).
func set_front(radius: float, strength := 1.0) -> void:
	silence_wall.visible = radius > 0.0 and strength > 0.0
	silence_wall.scale = Vector3(maxf(radius, 0.01), 1.0, maxf(radius, 0.01))
	(silence_wall.material_override as ShaderMaterial).set_shader_parameter("strength", strength)


func set_column(strength: float, flicker := 0.0) -> void:
	for mi in [column, column_glow]:
		var m := (mi as MeshInstance3D).material_override as ShaderMaterial
		m.set_shader_parameter("strength", strength * (1.0 if mi == column else 0.35))
		m.set_shader_parameter("flicker", flicker)
	column_light.light_energy = 6.0 * strength
