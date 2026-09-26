extends Node3D
class_name ColdOpenArchive
## The Astral Archive of Astra'Thalas, where Talindir has been a scribe for sixty years: the
## scriptorium (01_scriptorium.png), the Hall of Records, the cloister with its fountain and bell and
## the gate onto the festival street, the stair tower, and the high balcony over the city
## (02_balcony.png). Every room is walkable, with collision; the stairs are stepped masonry over hidden
## ramps (CLAUDE.md).
##
## Geometry per room goes through SolariKit into one mesh per room. The things the quest and the
## cutscene move — the letter's seal, the book-lift, the Record, the Song-glass, the orrery, the
## fountain's hanging water, the bell, the braziers' fire — are separate nodes, exposed as members.

const L = preload("res://threed/coldopen/ColdOpenLayout.gd")
const P = preload("res://threed/coldopen/ColdOpenProps.gd")

var mats: Dictionary
## Quest and cutscene handles.
var letter: Node3D
var letter_seal: MeshInstance3D
var letter_seal_mat: ShaderMaterial
var book_lift: SongHeld
var record_on_lift: Node3D
var song_glass_level: Node3D
var orrery_rings: Array[Node3D] = []
var bell: Node3D
var brazier_fires: Array[Node3D] = []
var ink_well: MeshInstance3D
var quill: SongHeld
var lamps: Array[SongHeld] = []
var balcony_lamps: Array[SongHeld] = []
var fallen_garland_spots: Array[Vector3] = []


func build(p_mats: Dictionary) -> void:
	mats = p_mats
	_scriptorium()
	_hall()
	_cloister()
	_street()
	_stair_tower()
	_balcony()


func _kit(seed_value: int) -> SolariKit:
	return SolariKit.new(mats, seed_value)


func _lamp(pos: Vector3, size := 0.26, energy := 2.2, rng_m := 8.0, rest := 0.0, shadows := false) -> SongHeld:
	var l := SongHeld.make_lamp(mats, size, energy, rng_m, shadows)
	l.position = pos
	l.rest_y = rest + size
	add_child(l)
	lamps.append(l)
	return l


## A strip of the Song's light set into a floor (along a line) or up a pilaster face.
func _floor_line(kit: SolariKit, a: Vector3, b: Vector3, w := 0.14, y := 0.012) -> void:
	var along := (b - a).normalized()
	var s := along.cross(Vector3.UP).normalized() * w * 0.5
	var up := Vector3.UP * y
	kit.quad("song_line", a - s + up, b - s + up, b + s + up, a + s + up, Vector3.UP)


# =================================================================================================
# THE SCRIPTORIUM — a long vaulted hall of desks and shelves; its great window looks at the Tower.
# =================================================================================================
func _scriptorium() -> void:
	var kit := _kit(1)
	var X := L.SCR_X
	var z0 := L.SCR_Z0
	var z1 := L.SCR_Z1
	var sp := L.SCR_SPRING
	# floor
	kit.block("marble_floor", Vector3(0, -0.25, (z0 + z1) * 0.5), Vector3(2 * X + 2, 0.5, z1 - z0 + 2))
	_floor_line(kit, Vector3(-2.0, 0, z0 + 0.5), Vector3(-2.0, 0, z1 - 0.5))
	_floor_line(kit, Vector3(2.0, 0, z0 + 0.5), Vector3(2.0, 0, z1 - 0.5))
	kit.box("marble_blue", Vector3(0, 0.006, (z0 + z1) * 0.5), Vector3(3.2, 0.01, z1 - z0 - 1.0))
	# side walls
	kit.wall("marble", Vector3(-X, 0, z0 - 1), Vector3(0, 0, 1), Vector3(1, 0, 0), z1 - z0 + 2, sp, 1.0)
	kit.wall("marble", Vector3(X, 0, z0 - 1), Vector3(0, 0, 1), Vector3(-1, 0, 0), z1 - z0 + 2, sp, 1.0)
	# the window end, and the door end
	kit.wall("marble", Vector3(-X, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, 1), 2 * X, L.BAL_Y, 1.0,
		[{"u": X - 2.5, "w": 5.0, "sill": 1.4, "spring": 9.0, "rise": 2.5}], 10, "marble_warm")
	kit.wall("marble", Vector3(-X, 0, z1), Vector3(1, 0, 0), Vector3(0, 0, -1), 2 * X, 15.0, 1.0,
		[{"u": X - 1.5, "w": 3.0, "sill": 0.0, "spring": 3.6, "rise": 1.5}], 8, "marble_warm")
	# the window: mullions, a transom, and tracery bars in the arch
	for x in [-0.85, 0.85]:
		kit.box("marble_warm", Vector3(x, 6.3, z0 - 0.5), Vector3(0.16, 9.8, 0.2))
	kit.box("marble_warm", Vector3(0, 7.0, z0 - 0.5), Vector3(5.0, 0.16, 0.2))
	for i in 5:
		var a := PI * (i + 0.5) / 5.0
		var p := Vector3(cos(a) * 1.3, 9.0 + sin(a) * 1.3, z0 - 0.5)
		kit.box("marble_warm", p, Vector3(0.14, 2.4, 0.2), Basis(Vector3(0, 0, 1), a - PI * 0.5))
	kit.box("marble_warm", Vector3(0, 1.35, z0 - 0.2), Vector3(5.4, 0.15, 0.9))
	# the vault: faceted segmental barrel with ribs
	var R := (X * X + L.SCR_RISE * L.SCR_RISE) / (2.0 * L.SCR_RISE)
	var cy := sp + L.SCR_RISE - R
	var prof := []
	var n := 10
	for i in n + 1:
		var x := -X + 2.0 * X * i / n
		prof.append(Vector3(x, cy + sqrt(R * R - x * x), 0))
	for i in n:
		var a: Vector3 = prof[i]
		var b: Vector3 = prof[i + 1]
		var mid := (a + b) * 0.5
		var nrm := Vector3(-mid.x, -(mid.y - cy), 0).normalized()
		kit.quad("marble", a + Vector3(0, 0, z0), b + Vector3(0, 0, z0), b + Vector3(0, 0, z1), a + Vector3(0, 0, z1), nrm)
	for rz in [0.5, 5.5, 10.5, 15.5, 20.5, 25.5]:
		for i in n:
			var a: Vector3 = prof[i]
			var b: Vector3 = prof[i + 1]
			var mid := (a + b) * 0.5
			var dirv := (b - a).normalized()
			var nrm := Vector3(-mid.x, -(mid.y - cy), 0).normalized()
			kit.box("marble_warm", mid + Vector3(0, 0, rz) + nrm * 0.18, Vector3(a.distance_to(b) + 0.06, 0.36, 0.7),
				Basis(dirv, nrm, Vector3(0, 0, 1)))
			kit.box("gold", mid + Vector3(0, 0, rz) + nrm * 0.37, Vector3(a.distance_to(b) + 0.06, 0.03, 0.18),
				Basis(dirv, nrm, Vector3(0, 0, 1)))
	# the exterior roof over the vault: a gold-tiled gable
	var eave := 9.6
	var ridge := 16.8
	kit.quad("city_roof", Vector3(-X - 1.5, eave, z0 - 0.9), Vector3(-X - 1.5, eave, z1 + 1.2), Vector3(0, ridge, z1 + 1.2), Vector3(0, ridge, z0 - 0.9))
	kit.quad("city_roof", Vector3(X + 1.5, eave, z1 + 1.2), Vector3(X + 1.5, eave, z0 - 0.9), Vector3(0, ridge, z0 - 0.9), Vector3(0, ridge, z1 + 1.2))
	kit.tri("marble", Vector3(-X - 1, eave, z1 + 1), Vector3(X + 1, eave, z1 + 1), Vector3(0, ridge - 0.4, z1 + 1), Vector3(0, 0, 1))
	kit.box("marble", Vector3(-X - 0.5, sp + 0.3, (z0 + z1) * 0.5), Vector3(1.0, 0.6, z1 - z0 + 2))
	kit.box("marble", Vector3(X + 0.5, sp + 0.3, (z0 + z1) * 0.5), Vector3(1.0, 0.6, z1 - z0 + 2))
	# pilasters with the Song's light running up them, and bookcases in the bays between
	var bays := [[1.0, 5.0], [6.0, 10.0], [11.0, 15.0], [16.0, 20.0], [21.0, 25.0]]
	for sx in [-1.0, 1.0]:
		var face := Vector3(-sx, 0, 0)
		for pz in [0.5, 5.5, 10.5, 15.5, 20.5, 25.5]:
			var px: float = sx * (X - 0.35)
			kit.box("marble_warm", Vector3(px, sp * 0.5, pz), Vector3(0.7, sp, 1.0))
			kit.box("gold", Vector3(px - sx * 0.02, sp - 0.3, pz), Vector3(0.9, 0.3, 1.2))
			kit.box("marble_warm", Vector3(px, 0.3, pz), Vector3(0.9, 0.6, 1.2))
			var lx: float = px - sx * 0.36
			kit.quad("song_line", Vector3(lx, 0.7, pz - 0.07), Vector3(lx, 0.7, pz + 0.07), Vector3(lx, sp - 0.5, pz + 0.07),
				Vector3(lx, sp - 0.5, pz - 0.07), face)
			kit.solid(Vector3(px, sp * 0.5, pz), Vector3(0.9, sp, 1.2))
		for bay in bays:
			var zc: float = (bay[0] + bay[1]) * 0.5
			if sx > 0.0 and absf(zc - L.INK_FONT.z) < 1.0:
				continue
			P.bookcase(kit, Vector3(sx * (X - 0.72), 0, zc), face, bay[1] - bay[0] - 0.1, 6.4, 0.7)
	# the ink font in its bay: a marble basin of star-ink
	var f := L.INK_FONT
	kit.prism("marble_warm", f, 0.35, 0.9, 8, 0.25)
	kit.prism("marble_warm", f + Vector3.UP * 0.9, 0.62, 0.22, 10, 0.7)
	kit.prism("gold", f + Vector3.UP * 1.12, 0.72, 0.05, 10)
	kit.solid(f + Vector3.UP * 0.6, Vector3(1.4, 1.2, 1.4))
	ink_well = MeshInstance3D.new()
	var ik := SolariKit.new({"ink": ColdOpenPalette.mat(Color(0.05, 0.07, 0.2), 0.1, 0.0, 0.0, Color(0.4, 0.5, 1.0), 1.4)}, 3)
	ik.disc("ink", Vector3.ZERO, 0.62, 10)
	ink_well = ik.commit(self, "StarInk")
	ink_well.position = f + Vector3.UP * 1.1
	# a gilded star over the ink font
	kit.box("gold", Vector3(X - 0.08, 4.2, f.z), Vector3(0.06, 0.5, 0.5), Basis(Vector3(1, 0, 0), PI * 0.25))
	# desks: two rows either side of the aisle, all facing the window
	for z in [3.8, 9.5, 14.6, 19.4]:
		for x in [-3.2, 3.2]:
			P.desk(kit, Vector3(x, 0, z), Vector3(0, 0, 1))
			if not (x < 0.0 and absf(z - L.DESK.z) < 0.1):
				P.clutter(kit, Vector3(x, 0, z), Vector3(0, 0, 1), kit.rng.randf() < 0.5)
	_talindirs_desk(kit)
	# a long reading table at the door end
	kit.box("wood", Vector3(0, 0.84, 25.4), Vector3(1.4, 0.1, 3.6))
	for dz in [-1.5, 1.5]:
		for dx in [-0.55, 0.55]:
			kit.box("wood_dark", Vector3(dx, 0.4, 25.4 + dz), Vector3(0.1, 0.8, 0.1))
	kit.solid(Vector3(0, 0.5, 25.4), Vector3(1.4, 1.0, 3.6))
	kit.commit(self, "Scriptorium")
	# floating lamps down the aisle, and one by every pilaster
	for z in [1.5, 7.0, 12.5, 18.0, 23.5]:
		_lamp(Vector3(0, 5.2, z), 0.3, 2.6, 11.0, 0.0, z > 15.0)
	for sx in [-1.0, 1.0]:
		for pz in [3.0, 8.0, 13.0, 18.0, 23.0]:
			_lamp(Vector3(sx * (X - 1.6), 6.8, pz), 0.2, 1.4, 6.0)
	# the self-writing quill at the desk across the aisle
	quill = SongHeld.new()
	quill.name = "Quill"
	quill.bob = 0.03
	quill.bob_speed = 6.0
	quill.tumble = 4.0
	var qk := SolariKit.new(mats, 9)
	qk.facet_jitter = 0.0
	qk.prism("paper", Vector3.ZERO, 0.035, 0.42, 4, 0.004, true, 0.0)
	qk.box("paper", Vector3(0.03, 0.26, 0), Vector3(0.06, 0.3, 0.012))
	qk.prism("gold", Vector3.ZERO - Vector3.UP * 0.06, 0.012, 0.07, 4, 0.002)
	qk.commit(quill, "Feather")
	quill.position = L.QUILL_DESK + Vector3(0.2, 1.02, 0.1)
	quill.rotation_degrees = Vector3(-25, 20, 18)
	quill.rest_y = 0.94
	var ql := OmniLight3D.new()
	ql.light_color = ColdOpenPalette.SONG
	ql.light_energy = 0.8
	ql.omni_range = 1.6
	ql.position = Vector3(0, -0.05, 0)
	quill.add_child(ql)
	quill.register_light(ql)
	add_child(quill)


## Talindir's own desk: an open ledger, ink, cold tea, loose pages, and the letter.
func _talindirs_desk(kit: SolariKit) -> void:
	var d := L.DESK
	var top := d + Vector3.UP * 0.94
	# the open ledger: two pages angled up from the spine
	var sp := top + Vector3(-0.1, 0.02, 0.05)
	kit.box("leather", sp, Vector3(0.9, 0.04, 0.62))
	kit.quad("paper", sp + Vector3(-0.44, 0.04, -0.29), sp + Vector3(0, 0.07, -0.29), sp + Vector3(0, 0.07, 0.29), sp + Vector3(-0.44, 0.04, 0.29), Vector3.UP)
	kit.quad("paper", sp + Vector3(0, 0.07, -0.29), sp + Vector3(0.44, 0.04, -0.29), sp + Vector3(0.44, 0.04, 0.29), sp + Vector3(0, 0.07, 0.29), Vector3.UP)
	for i in 6:
		var y := 0.075
		var zz := -0.2 + i * 0.075
		kit.box("ink", sp + Vector3(-0.22, y - 0.02, zz), Vector3(0.32, 0.004, 0.012))
		kit.box("ink", sp + Vector3(0.22, y - 0.02, zz), Vector3(0.3 - (0.12 if i == 5 else 0.0), 0.004, 0.012))
	# ink pots, a quill in its stand, a cup of tea long gone cold
	kit.prism("ink", top + Vector3(0.62, 0, -0.28), 0.07, 0.11, 6)
	kit.prism("glass_dark", top + Vector3(0.78, 0, -0.26), 0.05, 0.09, 6)
	kit.prism("paper", top + Vector3(0.62, 0.11, -0.28), 0.01, 0.34, 4, 0.002)
	kit.prism("ivory", top + Vector3(0.7, 0, 0.18), 0.075, 0.1, 8, 0.09)
	kit.disc("wood_dark", top + Vector3(0.7, 0.09, 0.18), 0.07, 8)
	# loose pages
	for i in 3:
		kit.box("paper", top + Vector3(-0.72 + i * 0.05, 0.004 + i * 0.003, 0.2 - i * 0.04), Vector3(0.3, 0.004, 0.42),
			Basis(Vector3.UP, 0.25 * i - 0.2))
	# the letter: folded vellum, and the seal, which is its own node — it glows as the night comes on
	var lp := top + Vector3(0.52, 0.01, 0.3)
	letter = Node3D.new()
	letter.name = "Letter"
	letter.position = lp
	letter.rotation.y = -0.3
	add_child(letter)
	letter_seal_mat = ColdOpenPalette.mat(Color(0.2, 0.16, 0.42), 0.4, 0.0, 0.0, ColdOpenPalette.SONG, 0.0, 0.0)
	var sk := SolariKit.new({"seal": letter_seal_mat, "paper": mats["paper"]}, 2)
	sk.facet_jitter = 0.0
	sk.box("paper", Vector3.ZERO, Vector3(0.34, 0.02, 0.22))
	sk.prism("seal", Vector3(0, 0.01, 0), 0.05, 0.018, 10)
	letter_seal = sk.commit(letter, "LetterMesh")
	# the satchel hangs on the stool
	kit.box("leather", d + Vector3(0.45, 0.45, 0.95), Vector3(0.36, 0.3, 0.14))


# =================================================================================================
# THE HALL OF RECORDS — shelves to the ceiling, the book-lift, the orrery, the Song-glass.
# =================================================================================================
func _hall() -> void:
	var kit := _kit(2)
	var x0 := L.HALL_X0
	var x1 := L.HALL_X1
	var z0 := L.HALL_Z0
	var z1 := L.HALL_Z1
	var h := L.HALL_H
	kit.block("marble_floor", Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1 + 1) * 0.5), Vector3(x1 - x0 + 2, 0.5, z1 - z0 + 1))
	_floor_line(kit, Vector3(x0 + 1, 0, 32.2), Vector3(x1 - 1, 0, 32.2))
	_floor_line(kit, Vector3(x0 + 1, 0, 35.8), Vector3(x1 - 1, 0, 35.8))
	# south wall either side of the scriptorium's door-end wall
	kit.wall("marble", Vector3(x0 - 1, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, 1), -L.SCR_X - 1 - x0 + 1, h, 1.0)
	kit.wall("marble", Vector3(L.SCR_X + 1, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, 1), x1 + 1 - L.SCR_X - 1, h, 1.0)
	kit.wall("marble", Vector3(x0 - 1, 0, z1), Vector3(1, 0, 0), Vector3(0, 0, -1), x1 - x0 + 2, h, 1.0)
	kit.wall("marble", Vector3(x1, 0, z0 - 1), Vector3(0, 0, 1), Vector3(-1, 0, 0), z1 - z0 + 2, h, 1.0,
		[{"u": 4.0, "w": 3.0, "sill": 4.0, "spring": 8.0, "rise": 1.5}], 8, "marble_warm")
	# ceiling, coffered in gold
	kit.box("marble", Vector3((x0 + x1) * 0.5, h + 0.3, (z0 + z1) * 0.5), Vector3(x1 - x0 + 2, 0.6, z1 - z0 + 2))
	var x := x0 + 3.0
	while x < x1:
		kit.box("gold_dim", Vector3(x, h - 0.2, (z0 + z1) * 0.5), Vector3(0.3, 0.4, z1 - z0))
		x += 6.0
	kit.box("gold_dim", Vector3((x0 + x1) * 0.5, h - 0.2, z0 + 3.3), Vector3(x1 - x0, 0.4, 0.3))
	kit.box("gold_dim", Vector3((x0 + x1) * 0.5, h - 0.2, z1 - 3.3), Vector3(x1 - x0, 0.4, 0.3))
	# the stacks: floor to ceiling along the north wall, with ladders
	var bx := x0 + 0.5
	while bx + 4.0 <= x1 - 0.5:
		P.bookcase(kit, Vector3(bx + 2.0, 0, z1 - 0.72), Vector3(0, 0, -1), 3.9, h - 1.4, 0.72)
		bx += 4.0
	for lx in [-21.0, 3.0]:
		kit.box("wood_dark", Vector3(lx - 0.25, 4.2, z1 - 1.3), Vector3(0.08, 8.4, 0.08), Basis(Vector3(1, 0, 0), 0.12))
		kit.box("wood_dark", Vector3(lx + 0.25, 4.2, z1 - 1.3), Vector3(0.08, 8.4, 0.08), Basis(Vector3(1, 0, 0), 0.12))
		for r in 14:
			kit.box("wood_dark", Vector3(lx, 0.4 + r * 0.58, z1 - 1.3 - (0.4 + r * 0.58) * 0.12 + 0.5), Vector3(0.5, 0.05, 0.05))
	# low cases along the south wall between the doors
	for cx in [-24.0, -18.0, -12.0, 12.5, 18.5]:
		P.bookcase(kit, Vector3(cx, 0, z0 + 0.62), Vector3(0, 0, 1), 3.9, 2.4, 0.6)
	# reading tables down the middle
	for tx in [-20.0, -11.0, 4.5]:
		kit.box("wood", Vector3(tx, 0.84, 34.0), Vector3(5.0, 0.1, 1.4))
		for ex in [-2.2, 2.2]:
			kit.box("wood_dark", Vector3(tx + ex, 0.4, 34.0), Vector3(0.12, 0.8, 1.1))
		kit.solid(Vector3(tx, 0.5, 34.0), Vector3(5.0, 1.0, 1.4))
		P.clutter(kit, Vector3(tx - 1.0, 0, 34.0), Vector3(0, 0, 1), true)
		P.clutter(kit, Vector3(tx + 1.4, 0, 34.0), Vector3(0, 0, -1), false)
	# the book-lift's call-post
	var cp := L.BOOK_LIFT + Vector3(0, 0, -1.8)
	kit.prism("bronze", cp, 0.16, 1.1, 6, 0.1)
	kit.prism("gold", cp + Vector3.UP * 1.1, 0.14, 0.12, 6)
	kit.solid(cp + Vector3.UP * 0.6, Vector3(0.4, 1.2, 0.4))
	# the orrery's plinth
	var o := L.ORRERY
	kit.prism("marble_warm", o, 1.9, 0.5, 12)
	kit.prism("marble", o + Vector3.UP * 0.5, 1.4, 0.9, 12, 1.2)
	kit.prism("gold", o + Vector3.UP * 1.4, 0.2, 1.4, 6, 0.08)
	kit.solid(o + Vector3.UP * 0.9, Vector3(3.6, 1.8, 3.6))
	# the Song-glass: a tall glass tube on a gilded stand
	var g := L.SONG_GLASS
	kit.prism("marble_warm", g, 0.5, 0.9, 8, 0.4)
	kit.prism("gold", g + Vector3.UP * 0.9, 0.3, 0.12, 8)
	kit.prism("gold", g + Vector3.UP * 3.0, 0.3, 0.12, 8)
	for k in 4:
		var a := TAU * k / 4.0
		kit.box("gold", g + Vector3(sin(a), 0, cos(a)) * 0.24 + Vector3.UP * 1.96, Vector3(0.04, 2.0, 0.04))
	kit.prism("glass_dark", g + Vector3.UP * 1.02, 0.13, 1.98, 8)
	# graduations beside it
	for i in 8:
		kit.box("gold", g + Vector3(0.3, 1.1 + i * 0.24, 0), Vector3(0.12, 0.02, 0.02))
	kit.solid(g + Vector3.UP * 1.5, Vector3(0.8, 3.0, 0.8))
	kit.commit(self, "HallOfRecords")
	# the Song-glass's level: a column of gold light inside the glass
	var lvk := SolariKit.new({"lvl": ColdOpenPalette.mat(Color(1, 0.9, 0.6), 0.3, 0.0, 0.0, ColdOpenPalette.SONG, 5.0)}, 4)
	lvk.facet_jitter = 0.0
	lvk.prism("lvl", Vector3.ZERO, 0.09, 1.0, 8)
	song_glass_level = Node3D.new()
	song_glass_level.name = "SongGlassLevel"
	add_child(song_glass_level)
	lvk.commit(song_glass_level, "Level")
	song_glass_level.position = g + Vector3.UP * 1.04
	song_glass_level.scale = Vector3(1, 1.7, 1)
	# the orrery: a gold sun and ringed planets turning on the Song
	var sun := SongHeld.make_lamp(mats, 0.45, 3.0, 9.0)
	sun.position = o + Vector3.UP * 3.0
	sun.rest_y = o.y + 1.9
	sun.bob = 0.0
	add_child(sun)
	var ring_specs := [[1.3, 0.0, 0.6], [2.0, 0.35, 0.4], [2.7, -0.25, 0.28], [3.4, 0.15, 0.18]]
	for spec in ring_specs:
		var pivot := Node3D.new()
		pivot.position = o + Vector3.UP * 3.0
		pivot.rotation = Vector3(spec[1], 0, spec[1] * 0.6)
		add_child(pivot)
		var spinner := Node3D.new()
		spinner.set_meta("speed", spec[2])
		pivot.add_child(spinner)
		var rk := SolariKit.new(mats, 20)
		var rr: float = spec[0]
		var segs := 28
		for s in segs:
			var a0 := TAU * s / segs
			var a1 := TAU * (s + 1) / segs
			var p0 := Vector3(sin(a0), 0, cos(a0)) * rr
			var p1 := Vector3(sin(a1), 0, cos(a1)) * rr
			var dirv := (p1 - p0).normalized()
			rk.box("gold", (p0 + p1) * 0.5, Vector3(0.05, 0.05, p0.distance_to(p1)), Basis(dirv.cross(Vector3.UP).normalized(), Vector3.UP, dirv))
		rk.dome("marble_blue" if rr > 2.0 else "bronze", Vector3(rr, -0.15, 0), 0.16, 0.16, 8, 2)
		rk.dome("marble_blue" if rr > 2.0 else "bronze", Vector3(rr, -0.15, 0), 0.16, -0.16, 8, 2)
		rk.commit(spinner, "Ring")
		orrery_rings.append(spinner)
	# the book-lift, hovering high against the stacks with the Luminarae Record on it
	book_lift = SongHeld.new()
	book_lift.name = "BookLift"
	book_lift.bob = 0.06
	var bk := SolariKit.new(mats, 21)
	bk.box("wood", Vector3.ZERO, Vector3(1.5, 0.12, 1.1))
	for sx in [-0.7, 0.7]:
		for sz in [-0.5, 0.5]:
			bk.prism("gold", Vector3(sx, 0.06, sz), 0.04, 0.35, 4)
	bk.prism("gold", Vector3(0, -0.06, 0), 0.3, 0.2, 8, 0.05)
	bk.commit(book_lift, "Platform")
	record_on_lift = make_record()
	record_on_lift.position = Vector3(0, 0.16, 0)
	book_lift.add_child(record_on_lift)
	var bl := OmniLight3D.new()
	bl.light_color = ColdOpenPalette.SONG
	bl.light_energy = 1.2
	bl.omni_range = 4.0
	bl.position = Vector3(0, -0.4, 0)
	book_lift.add_child(bl)
	book_lift.register_light(bl)
	book_lift.position = L.BOOK_LIFT + Vector3(0, 8.6, 0)
	book_lift.rest_y = 0.06
	add_child(book_lift)
	# lamps floating down the hall
	var lx := x0 + 4.0
	while lx < x1:
		_lamp(Vector3(lx, 5.6, 34.0), 0.28, 2.4, 10.0)
		lx += 7.0


## The Luminarae Record: the Archive's oldest unbroken book — two thousand festivals, one page each.
func make_record() -> Node3D:
	var root := Node3D.new()
	root.name = "Record"
	var k := SolariKit.new(mats, 22)
	k.box("leather", Vector3(0, 0.09, 0), Vector3(0.8, 0.18, 0.58))
	k.box("paper", Vector3(0.02, 0.09, 0), Vector3(0.74, 0.14, 0.56))
	k.box("gold", Vector3(0, 0.185, 0), Vector3(0.28, 0.01, 0.28))
	k.disc("gold", Vector3(0, 0.19, 0), 0.1, 12)
	for sz in [-0.18, 0.18]:
		k.box("gold", Vector3(0.4, 0.09, sz), Vector3(0.06, 0.12, 0.06))
	k.commit(root, "Book")
	return root


# =================================================================================================
# THE CLOISTER — an arcaded garth open to the sky, the fountain, the bell, and the gate to the street.
# =================================================================================================
func _cloister() -> void:
	var kit := _kit(3)
	var x0 := L.CLO_X0
	var x1 := L.CLO_X1
	var z0 := L.CLO_Z0
	var z1 := L.CLO_Z1
	var wh := 8.0
	kit.block("marble_floor", Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1) * 0.5), Vector3(x1 - x0 + 2, 0.5, z1 - z0 + 2))
	# the east wall, shared with the stair tower (24 m) and the Hall (12 m)
	kit.wall("marble", Vector3(x1, 0, z0 - 1), Vector3(0, 0, 1), Vector3(-1, 0, 0), L.STAIR_Z1 - z0 + 2, 26.0, 1.0,
		[{"u": 2.5, "w": 3.0, "sill": 0.0, "spring": 3.2, "rise": 1.5}], 8, "marble_warm")
	kit.wall("marble", Vector3(x1, 0, L.STAIR_Z1 + 1), Vector3(0, 0, 1), Vector3(-1, 0, 0), L.HALL_Z0 - L.STAIR_Z1 - 2, wh, 1.0)
	kit.wall("marble", Vector3(x1, 0, L.HALL_Z0 - 1), Vector3(0, 0, 1), Vector3(-1, 0, 0), z1 - L.HALL_Z0 + 2, L.HALL_H, 1.0,
		[{"u": 4.0, "w": 3.5, "sill": 0.0, "spring": 3.4, "rise": 1.75}], 8, "marble_warm")
	# west wall with the gate
	kit.wall("marble", Vector3(x0, 0, z0 - 1), Vector3(0, 0, 1), Vector3(1, 0, 0), z1 - z0 + 2, wh, 1.0,
		[{"u": L.GATE.z - (z0 - 1) - 2.0, "w": 4.0, "sill": 0.0, "spring": 4.2, "rise": 2.0}], 10, "marble_warm")
	kit.wall("marble", Vector3(x0 - 1, 0, z1), Vector3(1, 0, 0), Vector3(0, 0, -1), x1 - x0 + 1, wh, 1.0)
	kit.wall("marble", Vector3(x0 - 1, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, 1), x1 - x0 + 1, wh, 1.0)
	# the gate: iron bars across the arch, and gilded finials
	var g := L.GATE
	for i in 13:
		var zz := g.z - 1.9 + i * 0.316
		kit.box("iron", Vector3(g.x + 0.5, 2.6, zz), Vector3(0.06, 5.2, 0.06))
		kit.prism("gold", Vector3(g.x + 0.5, 5.2, zz), 0.05, 0.18, 4, 0.0)
	for y in [0.6, 2.4, 4.3]:
		kit.box("iron", Vector3(g.x + 0.5, y, g.z), Vector3(0.08, 0.08, 4.0))
	kit.solid(Vector3(g.x + 0.5, 3.0, g.z), Vector3(0.4, 6.0, 4.2))
	# the arcade round the garth
	var gx0 := x0 + L.CLO_ARCADE
	var gx1 := x1 - L.CLO_ARCADE
	var gz0 := z0 + L.CLO_ARCADE
	var gz1 := z1 - L.CLO_ARCADE
	var ah := 5.6
	var runs := [
		[Vector3(gx0, 0, gz0), Vector3(1, 0, 0), Vector3(0, 0, 1), gx1 - gx0],
		[Vector3(gx0, 0, gz1), Vector3(1, 0, 0), Vector3(0, 0, -1), gx1 - gx0],
		[Vector3(gx0, 0, gz0), Vector3(0, 0, 1), Vector3(1, 0, 0), gz1 - gz0],
		[Vector3(gx1, 0, gz0), Vector3(0, 0, 1), Vector3(-1, 0, 0), gz1 - gz0],
	]
	for r in runs:
		var length: float = r[3]
		var n := int(round(length / 4.4))
		var pitch := length / n
		var ops := []
		for i in n:
			ops.append({"u": i * pitch + 0.55, "w": pitch - 1.1, "sill": 0.0, "spring": 3.4, "rise": (pitch - 1.1) * 0.5})
		var o: Vector3 = r[0] + (r[2] as Vector3) * 0.4
		kit.wall("marble_warm", o, r[1], r[2], length, ah, 0.8, ops, 8, "marble")
		kit.box("gold", o + (r[1] as Vector3) * length * 0.5 + Vector3.UP * (ah + 0.08) - (r[2] as Vector3) * 0.4,
			Vector3.ONE * 0.16 + (r[1] as Vector3).abs() * length)
	# the arcade roofs (the walk between the outer walls and the arcade)
	kit.box("marble", Vector3((x0 + x1) * 0.5, ah + 0.25, z0 + L.CLO_ARCADE * 0.5), Vector3(x1 - x0, 0.5, L.CLO_ARCADE + 0.8))
	kit.box("marble", Vector3((x0 + x1) * 0.5, ah + 0.25, z1 - L.CLO_ARCADE * 0.5), Vector3(x1 - x0, 0.5, L.CLO_ARCADE + 0.8))
	kit.box("marble", Vector3(x0 + L.CLO_ARCADE * 0.5, ah + 0.25, (z0 + z1) * 0.5), Vector3(L.CLO_ARCADE + 0.8, 0.5, z1 - z0))
	kit.box("marble", Vector3(x1 - L.CLO_ARCADE * 0.5, ah + 0.25, (z0 + z1) * 0.5), Vector3(L.CLO_ARCADE + 0.8, 0.5, z1 - z0))
	# the garth: paths in a cross, beds of green, four small citrus trees in gilded tubs
	var cx := (gx0 + gx1) * 0.5
	var cz := (gz0 + gz1) * 0.5
	_floor_line(kit, Vector3(cx, 0, gz0 + 0.8), Vector3(cx, 0, gz1 - 0.8))
	_floor_line(kit, Vector3(gx0 + 0.8, 0, cz), Vector3(gx1 - 0.8, 0, cz))
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var bc := Vector3(cx + qx * (gx1 - gx0) * 0.27, 0, cz + qz * (gz1 - gz0) * 0.3)
			kit.box("marble_warm", bc + Vector3.UP * 0.2, Vector3(5.5, 0.4, 12.0))
			kit.box("garland", bc + Vector3.UP * 0.45, Vector3(5.1, 0.12, 11.6))
			kit.solid(bc + Vector3.UP * 0.3, Vector3(5.5, 0.6, 12.0))
			var tp := bc + Vector3(0, 0.4, qz * -3.5)
			kit.prism("gold_dim", tp, 0.45, 0.6, 8, 0.55)
			kit.prism("wood_dark", tp + Vector3.UP * 0.6, 0.08, 1.4, 5, 0.06)
			kit.dome("garland", tp + Vector3.UP * 1.7, 1.1, 1.3, 7, 3)
			kit.dome("garland", tp + Vector3.UP * 1.7, 1.1, -0.5, 7, 2)
			for fr in 5:
				var a := fr * 1.3
				kit.box("cloth_gold", tp + Vector3.UP * (1.8 + fr * 0.12) + Vector3(sin(a), 0, cos(a)) * 0.95, Vector3.ONE * 0.13)
	# the fountain
	var f := L.FOUNTAIN
	kit.prism("marble_warm", f, 3.4, 0.7, 14)
	kit.prism("marble_blue", f + Vector3.UP * 0.7, 3.0, 0.02, 14)
	kit.prism("gold", f + Vector3.UP * 0.68, 3.45, 0.08, 14)
	kit.prism("marble_warm", f + Vector3.UP * 0.7, 0.4, 1.6, 8, 0.3)
	kit.prism("gold", f + Vector3.UP * 2.3, 0.3, 0.2, 10, 0.9)
	kit.solid(f + Vector3.UP * 0.5, Vector3(6.4, 1.0, 6.4))
	# the resonance bell, in a marble frame
	var b := L.BELL
	for sx in [-1.3, 1.3]:
		kit.box("marble_warm", b + Vector3(sx, 1.9, 0), Vector3(0.45, 3.8, 0.45))
	kit.box("gold", b + Vector3(0, 3.9, 0), Vector3(3.2, 0.3, 0.5))
	kit.solid(b + Vector3.UP * 1.9, Vector3(3.1, 3.8, 0.6))
	kit.commit(self, "Cloister")
	bell = Node3D.new()
	bell.name = "Bell"
	bell.position = b + Vector3.UP * 3.75
	var bk := SolariKit.new(mats, 30)
	bk.dome("bronze", Vector3(0, -1.2, 0), 0.72, 1.05, 12, 4)
	bk.prism("bronze", Vector3(0, -1.28, 0), 0.8, 0.1, 12, 0.72)
	bk.prism("gold", Vector3(0, -0.15, 0), 0.06, 0.15, 6)
	bk.prism("iron", Vector3(0, -1.1, 0), 0.03, 0.9, 4)
	bk.commit(bell, "BellMesh")
	add_child(bell)
	# the fountain's water: bright drops held in arcs in the air, not falling
	var water := ColdOpenPalette.mat(Color(0.7, 0.82, 0.95), 0.1, 0.0, 0.0, Color(0.75, 0.88, 1.0), 0.9)
	for arc in 6:
		var a := TAU * arc / 6.0
		var dirv := Vector3(sin(a), 0, cos(a))
		for i in 7:
			var t := (i + 1) / 8.0
			var p := f + Vector3.UP * 2.45 + dirv * (t * 2.3) + Vector3.UP * (sin(t * PI) * 1.1 - t * 1.5)
			var drop := SongHeld.new()
			drop.bob = 0.05
			drop.bob_speed = 1.3
			drop.tumble = 0.0
			var dk := SolariKit.new({"w": water}, arc * 10 + i)
			dk.facet_jitter = 0.0
			dk.dome("w", Vector3.ZERO, 0.05, 0.07, 6, 2)
			dk.dome("w", Vector3.ZERO, 0.05, -0.07, 6, 2)
			dk.commit(drop, "Drop")
			drop.position = p
			drop.rest_y = f.y + 0.72
			add_child(drop)
	# lamps: under the arcade, and over the garth
	for z in [-5.0, 5.0, 15.0, 25.0, 35.0]:
		_lamp(Vector3(x0 + 2.0, 4.4, z), 0.2, 1.4, 6.0)
		_lamp(Vector3(x1 - 2.0, 4.4, z), 0.2, 1.4, 6.0)
	for p in [Vector3(cx, 6.5, cz - 12.0), Vector3(cx, 7.5, cz + 12.0), Vector3(cx - 5.0, 5.5, cz), Vector3(cx + 5.0, 6.0, cz)]:
		_lamp(p, 0.34, 3.0, 14.0)


## Outside the gate: the festival street. Seen only through the bars — houses hung with garlands,
## every window lit, and the procession passing (the director walks people along it).
func _street() -> void:
	var kit := _kit(4)
	var sx0 := L.CLO_X0 - 17.0
	kit.box("street", Vector3((sx0 + L.CLO_X0 - 1.0) * 0.5, -0.2, 15.0), Vector3(L.CLO_X0 - 1.0 - sx0, 0.4, 110.0))
	var z := -38.0
	while z < 68.0:
		var w := kit.rng.randf_range(7.0, 11.0)
		var h := kit.rng.randf_range(9.0, 15.0)
		var c := Vector3(sx0 - 4.0, 0, z + w * 0.5)
		kit.box("city_wall" if kit.rng.randf() < 0.5 else "city_wall_b", c + Vector3.UP * h * 0.5, Vector3(8.0, h, w - 0.3))
		for s in int((h - 2.0) / 3.4):
			for k in int(w / 2.6):
				if kit.rng.randf() < 0.8:
					var p := Vector3(sx0 + 0.02, 2.4 + s * 3.4, z + 1.4 + k * 2.6)
					kit.quad("window_lit", p + Vector3(0, -0.8, -0.5), p + Vector3(0, -0.8, 0.5), p + Vector3(0, 0.8, 0.5), p + Vector3(0, 0.8, -0.5), Vector3(1, 0, 0))
		kit.quad("city_roof", c + Vector3(4.2, h, -w * 0.5), c + Vector3(4.2, h, w * 0.5), c + Vector3(0, h + 3.0, w * 0.5), c + Vector3(0, h + 3.0, -w * 0.5))
		P.garland(kit, Vector3(sx0 + 0.3, 6.0, z + 0.5), Vector3(sx0 + 0.3, 6.0, z + w - 0.5), 0.6)
		z += w
	# strings of festival lights across the street
	for zz in [-20.0, -4.0, 12.0, 28.0, 44.0]:
		P.garland(kit, Vector3(sx0 + 0.5, 7.0, zz), Vector3(L.CLO_X0 - 1.0, 7.0, zz + 3.0), 1.2)
	kit.commit(self, "Street")
	for zz in [-10.0, 6.0, 22.0, 38.0]:
		_lamp(Vector3(sx0 + 6.0, 6.0, zz), 0.3, 2.4, 10.0, 0.0)


# =================================================================================================
# THE STAIR TOWER — three long flights up to the balcony, round a solid core.
# =================================================================================================
func _stair_tower() -> void:
	var kit := _kit(5)
	var x0 := L.STAIR_X0
	var x1 := L.STAIR_X1
	var z0 := L.STAIR_Z0
	var z1 := L.STAIR_Z1
	var top := 26.0
	kit.block("marble_floor", Vector3((x0 + x1) * 0.5, -0.25, (z0 + z1) * 0.5), Vector3(x1 - x0 + 1, 0.5, z1 - z0 + 2))
	# north and south walls, windows at each flight's middle
	var win := []
	for y in [3.5, 9.5, 15.5]:
		win.append({"u": 8.5, "w": 1.2, "sill": y, "spring": y + 1.8, "rise": 0.6})
	kit.wall("marble", Vector3(x0 - 1, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, 1), x1 - x0 + 2, top, 1.0, win, 6, "marble_warm")
	kit.wall("marble", Vector3(x0 - 1, 0, z1), Vector3(1, 0, 0), Vector3(0, 0, -1), x1 - x0 + 2, top, 1.0, [], 6)
	# the east wall, with the door out onto the balcony at the top
	kit.wall("marble", Vector3(x1, 0, z0 - 1), Vector3(0, 0, 1), Vector3(-1, 0, 0), z1 - z0 + 2, top, 1.0,
		[{"u": (L.BAL_DOOR.z - 1.5) - (z0 - 1), "w": 3.0, "sill": L.BAL_Y, "spring": L.BAL_Y + 3.2, "rise": 1.5}], 8, "marble_warm")
	kit.box("marble", Vector3((x0 + x1) * 0.5, top + 0.3, (z0 + z1) * 0.5), Vector3(x1 - x0 + 2, 0.6, z1 - z0 + 2))
	# a gold pyramid roof
	var c := Vector3((x0 + x1) * 0.5, top + 0.6, (z0 + z1) * 0.5)
	var hx := (x1 - x0) * 0.5 + 1.3
	var hz := (z1 - z0) * 0.5 + 1.3
	var apex := c + Vector3.UP * 7.0
	kit.tri("city_roof", c + Vector3(-hx, 0, -hz), c + Vector3(hx, 0, -hz), apex)
	kit.tri("city_roof", c + Vector3(hx, 0, hz), c + Vector3(-hx, 0, hz), apex)
	kit.tri("city_roof", c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), apex)
	kit.tri("city_roof", c + Vector3(-hx, 0, hz), c + Vector3(-hx, 0, -hz), apex)
	kit.prism("gold", apex, 0.25, 3.0, 4, 0.02)
	# the core wall between the two lanes, and the solid vault under flight two
	# two lanes, each running wall to core with no gap to slip into
	var spine_z := (z0 + z1) * 0.5
	var lane_w := (z1 - z0) * 0.5 - 0.2
	var lane_s := z0 + lane_w * 0.5
	var lane_n := z1 - lane_w * 0.5
	kit.block("marble_warm", Vector3((L.STAIR_FOOT_X + L.STAIR_HEAD_X) * 0.5, 9.8, spine_z), Vector3(L.STAIR_HEAD_X - L.STAIR_FOOT_X, 19.6, 0.4))
	kit.block("marble", Vector3((L.STAIR_FOOT_X + L.STAIR_HEAD_X) * 0.5, 3.0, (spine_z + 0.2 + z1) * 0.5), Vector3(L.STAIR_HEAD_X - L.STAIR_FOOT_X, 6.0, z1 - spine_z - 0.2))
	# flights
	var r := L.FLIGHT_RISE
	kit.stairs("marble_warm", Vector3(L.STAIR_FOOT_X, 0, lane_s), Vector3(1, 0, 0), r, L.FLIGHT_RUN, lane_w)
	kit.stairs("marble_warm", Vector3(L.STAIR_HEAD_X, r, lane_n), Vector3(-1, 0, 0), r, L.FLIGHT_RUN, lane_w)
	kit.stairs("marble_warm", Vector3(L.STAIR_FOOT_X, 2 * r, lane_s), Vector3(1, 0, 0), r, L.FLIGHT_RUN, lane_w)
	# landings (top faces flush with the flights' heads)
	for spec in [[L.STAIR_HEAD_X, x1, r], [x0, L.STAIR_FOOT_X, 2 * r], [L.STAIR_HEAD_X, x1, 3 * r]]:
		var a: float = spec[0]
		var bb: float = spec[1]
		var y: float = spec[2]
		kit.block("marble_floor", Vector3((a + bb) * 0.5, y - 0.2, (z0 + z1) * 0.5), Vector3(bb - a, 0.4, z1 - z0))
		kit.box("gold", Vector3((a + bb) * 0.5, y - 0.42, z0 + 0.1), Vector3(bb - a, 0.06, 0.2))
	# the threshold out to the balcony
	kit.block("marble_floor", Vector3(x1 + 0.5, L.BAL_Y - 0.2, L.BAL_DOOR.z), Vector3(1.4, 0.4, 3.0))
	# the top landing looks down twelve metres onto flight two: a balustrade on that edge
	P.balustrade(kit, Vector3(L.STAIR_HEAD_X, 3 * r, z1 - 0.1), Vector3(L.STAIR_HEAD_X, 3 * r, spine_z + 0.25), 1.0)
	kit.commit(self, "StairTower")
	# a lamp over each landing and each flight
	_lamp(Vector3(x0 + 1.5, 3.5, (z0 + z1) * 0.5), 0.24, 2.0, 9.0)
	_lamp(Vector3(x1 - 2.0, r + 3.0, (z0 + z1) * 0.5), 0.24, 2.0, 9.0)
	_lamp(Vector3(x0 + 1.5, 2 * r + 3.0, (z0 + z1) * 0.5), 0.24, 2.0, 9.0, 2 * r)
	_lamp(Vector3(x1 - 2.0, 3 * r + 3.0, (z0 + z1) * 0.5), 0.24, 2.0, 9.0, 3 * r)
	_lamp(Vector3(-21.8, 4.5, lane_s), 0.18, 1.2, 6.0)
	_lamp(Vector3(-21.8, 10.5, lane_n), 0.18, 1.2, 6.0, r)
	_lamp(Vector3(-21.8, 16.5, lane_s), 0.18, 1.2, 6.0, 2 * r)


# =================================================================================================
# THE BALCONY — the rail, the sun mosaic, the braziers, the banners, the flanking towers, the city.
# =================================================================================================
func _balcony() -> void:
	var kit := _kit(6)
	var y := L.BAL_Y
	var X := L.BAL_X
	var z0 := L.BAL_Z0
	var z1 := L.BAL_Z1
	kit.block("marble_floor", Vector3(0, y - 0.5, (z0 + z1) * 0.5), Vector3(2 * X, 1.0, z1 - z0))
	P.sun_mosaic(kit, L.MOSAIC, L.MOSAIC_R)
	_floor_line(kit, Vector3(-5.5, y, z1 - 0.5), Vector3(-5.5, y, z0 + 1.2))
	_floor_line(kit, Vector3(5.5, y, z1 - 0.5), Vector3(5.5, y, z0 + 1.2))
	# the rail, and the side rails out past the towers
	P.balustrade(kit, Vector3(-X, y, z0 + 0.3), Vector3(X, y, z0 + 0.3), L.RAIL_H)
	P.balustrade(kit, Vector3(-X + 0.3, y, L.STAIR_Z0 - 1.0), Vector3(-X + 0.3, y, z0 + 0.3), L.RAIL_H)
	P.balustrade(kit, Vector3(X - 0.3, y, z0 + 0.3), Vector3(X - 0.3, y, L.STAIR_Z0 - 1.0), L.RAIL_H)
	# behind the towers the terrace runs back over the scriptorium roof: rails there too
	P.balustrade(kit, Vector3(-X + 0.3, y, L.STAIR_Z1 + 1.0), Vector3(-X + 0.3, y, z1 - 0.3), L.RAIL_H)
	P.balustrade(kit, Vector3(X - 0.3, y, z1 - 0.3), Vector3(X - 0.3, y, L.STAIR_Z1 + 1.0), L.RAIL_H)
	# garlands along the rail
	var gx := -X + 0.4
	while gx < X - 1.0:
		P.garland(kit, Vector3(gx, y + L.RAIL_H - 0.05, z0 + 0.05), Vector3(gx + 2.2, y + L.RAIL_H - 0.05, z0 + 0.05), 0.3)
		gx += 2.2
	# the substructure: a great arch under the rail, arches along the sides
	kit.wall("marble", Vector3(-X, -8.0, z0), Vector3(1, 0, 0), Vector3(0, 0, -1), 2 * X, y - 1.0 + 8.0, 1.2,
		[{"u": 3.0, "w": 2 * X - 6.0, "sill": 0.0, "spring": 14.5, "rise": 7.0}], 12, "marble_warm")
	for sx in [-1.0, 1.0]:
		kit.wall("marble", Vector3(sx * X, -8.0, z0), Vector3(0, 0, 1), Vector3(sx, 0, 0), L.STAIR_Z0 - 1.0 - z0, y - 1.0 + 8.0, 1.2,
			[{"u": 1.2, "w": 4.4, "sill": 0.0, "spring": 11.0, "rise": 2.2}], 8, "marble_warm")
	kit.box("gold", Vector3(0, y - 1.1, z0 - 0.62), Vector3(2 * X + 0.4, 0.2, 0.1))
	# the back wall: the Archive's upper façade, three blind arches and a gilded cornice
	var bw := 8.0
	kit.wall("marble", Vector3(-X, y, z1), Vector3(1, 0, 0), Vector3(0, 0, -1), 2 * X, bw, 1.0,
		[{"u": 2.5, "w": 3.0, "sill": 0.0, "spring": 4.4, "rise": 1.5},
		 {"u": X - 1.5, "w": 3.0, "sill": 0.0, "spring": 4.4, "rise": 1.5},
		 {"u": 2 * X - 5.5, "w": 3.0, "sill": 0.0, "spring": 4.4, "rise": 1.5}], 8, "marble_warm")
	for ax in [-X + 4.0, 0.0, X - 4.0]:
		kit.box("marble_dark", Vector3(ax, y + 3.0, z1 + 0.85), Vector3(3.0, 6.0, 0.2))
		kit.solid(Vector3(ax, y + 3.0, z1 + 0.5), Vector3(3.0, 6.0, 0.8))
	kit.box("gold", Vector3(0, y + bw + 0.15, z1 - 0.1), Vector3(2 * X + 0.6, 0.3, 1.3))
	# the right flanking tower (the left one is the stair tower)
	var t0 := Vector3(X + 3.0, 0, (L.STAIR_Z0 + L.STAIR_Z1) * 0.5)
	var tw := 6.0
	var td := L.STAIR_Z1 - L.STAIR_Z0 + 2.0
	kit.block("marble", t0 + Vector3.UP * 13.0, Vector3(tw, 26.0, td))
	for wy in [21.0, 24.0]:
		for wz in [-1.5, 1.5]:
			var p := t0 + Vector3(-tw * 0.5 - 0.02, wy, wz)
			kit.quad("window_lit", p + Vector3(0, -0.8, -0.45), p + Vector3(0, 0.8, -0.45), p + Vector3(0, 0.8, 0.45), p + Vector3(0, -0.8, 0.45), Vector3(-1, 0, 0))
			var q := t0 + Vector3(wz * 1.2, wy, -td * 0.5 - 0.02)
			kit.quad("window_lit", q + Vector3(-0.45, -0.8, 0), q + Vector3(0.45, -0.8, 0), q + Vector3(0.45, 0.8, 0), q + Vector3(-0.45, 0.8, 0), Vector3(0, 0, -1))
	var rc := t0 + Vector3.UP * 26.0
	var rap := rc + Vector3.UP * 7.0
	kit.tri("city_roof", rc + Vector3(-tw * 0.5 - 0.8, 0, -td * 0.5 - 0.8), rc + Vector3(tw * 0.5 + 0.8, 0, -td * 0.5 - 0.8), rap)
	kit.tri("city_roof", rc + Vector3(tw * 0.5 + 0.8, 0, td * 0.5 + 0.8), rc + Vector3(-tw * 0.5 - 0.8, 0, td * 0.5 + 0.8), rap)
	kit.tri("city_roof", rc + Vector3(tw * 0.5 + 0.8, 0, -td * 0.5 - 0.8), rc + Vector3(tw * 0.5 + 0.8, 0, td * 0.5 + 0.8), rap)
	kit.tri("city_roof", rc + Vector3(-tw * 0.5 - 0.8, 0, td * 0.5 + 0.8), rc + Vector3(-tw * 0.5 - 0.8, 0, -td * 0.5 - 0.8), rap)
	kit.prism("gold", rap, 0.25, 3.0, 4, 0.02)
	kit.box("gold", t0 + Vector3.UP * 26.1, Vector3(tw + 0.4, 0.3, td + 0.4))
	# lit windows on the stair tower's balcony face too
	for wy in [21.0, 24.0]:
		for wz in [-1.5, 1.5]:
			var p := Vector3(L.STAIR_X1 + 1.02, wy, (L.STAIR_Z0 + L.STAIR_Z1) * 0.5 + wz)
			kit.quad("window_lit", p + Vector3(0, -0.8, 0.45), p + Vector3(0, 0.8, 0.45), p + Vector3(0, 0.8, -0.45), p + Vector3(0, -0.8, -0.45), Vector3(1, 0, 0))
	# braziers, banners, the lectern at the rail
	for sx in [-1.0, 1.0]:
		var fire_at := P.brazier(kit, Vector3(sx * 7.2, y, -8.6))
		_brazier_fire(fire_at)
		# the cloth hangs off the pole toward -x, so the left pole stands further in
		P.banner(kit, Vector3(-8.0 if sx < 0 else X - 1.2, y, L.STAIR_Z0 - 1.6), Vector3(0, 0, 1))
	var lc := L.LECTERN
	kit.prism("marble_warm", lc, 0.32, 1.0, 8, 0.2)
	kit.box("gold", lc + Vector3(0, 1.08, 0.05), Vector3(0.8, 0.06, 0.55), Basis(Vector3(1, 0, 0), deg_to_rad(18)))
	kit.solid(lc + Vector3.UP * 0.6, Vector3(0.8, 1.2, 0.6))
	kit.commit(self, "Balcony")
	# lamps over the balcony
	for p in [Vector3(-4.0, y + 3.8, -8.0), Vector3(4.0, y + 4.2, -12.0), Vector3(0.0, y + 4.6, -5.0), Vector3(-7.0, y + 4.0, -14.0), Vector3(7.5, y + 3.6, -9.0)]:
		var l := _lamp(p, 0.3, 2.6, 11.0, y)
		balcony_lamps.append(l)
	# where the garlands will lie after the crowd rushes the rail
	for i in 7:
		fallen_garland_spots.append(Vector3(-5.0 + i * 1.6, y, -9.0 + (i % 3) * 1.4))


func _brazier_fire(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "BrazierFire"
	root.position = at
	var fk := SolariKit.new(mats, 40)
	fk.facet_jitter = 0.0
	for i in 5:
		var a := TAU * i / 5.0
		var off := Vector3(sin(a), 0, cos(a)) * (0.18 if i > 0 else 0.0)
		fk.prism("fire", off, 0.2 - i * 0.01, 0.75 + (0.35 if i == 0 else 0.0), 4, 0.0, false, a)
	fk.commit(root, "Flames")
	var l := OmniLight3D.new()
	l.light_color = ColdOpenPalette.FIRE
	l.light_energy = 3.2
	l.omni_range = 10.0
	l.position = Vector3.UP * 0.6
	l.shadow_enabled = true
	root.add_child(l)
	add_child(root)
	brazier_fires.append(root)


func _process(_delta: float) -> void:
	# fire flickers; the orrery turns while the Song holds it
	var t := Time.get_ticks_msec() / 1000.0
	for f in brazier_fires:
		var fl := f.get_node("Flames") as Node3D
		fl.scale = Vector3(1.0 + sin(t * 13.0 + f.position.x) * 0.06, 1.0 + sin(t * 9.0) * 0.12 + sin(t * 23.0) * 0.05, 1.0)
		fl.rotation.y = t * 0.8
		var l := f.get_child(1) as OmniLight3D
		l.light_energy = 3.0 + sin(t * 17.0) * 0.3 + sin(t * 7.3) * 0.2
	var silenced := SilenceState.reached(L.ORRERY)
	for ring in orrery_rings:
		var s: float = ring.get_meta("speed")
		if silenced:
			s = 0.0
		ring.rotation.y += s * _delta
