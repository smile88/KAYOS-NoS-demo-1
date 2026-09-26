extends Node3D
class_name ColdOpenDirector
## Cold Open v2 — "The Same Night", 2000 AO (docs/Cold_Open_v2_Proposal.md). The whole playable night:
##
##   DESK     Talindir at his desk in the scriptorium, late. The letter on the desk. Free to wander.
##   DUTY     Archivist Maelis comes in: Sorrel has gone to the festival; the Record has no hand.
##   GATHER   Three things, any order — call the Record down (Hall of Records), fill the ink-horn
##            (scriptorium), take the Song-glass reading (Hall). Each shows the Song at work, and each
##            shows it going wrong: the lamps dip, the ink drifts toward the Tower, the glass reads low.
##   KEY      Maelis at the cloister gate, watching the procession. The key to the stair.
##   CLIMB    The stair tower, a hundred and eight steps, to the balcony.
##   BALCONY  The crowd, the Tower, the festival-goer and the one choice (COLDOPEN_HONEST); the Record
##            set on the lectern at the rail — and the ninth bell.
##   SILENCE  The cutscene (ColdOpenCutscene). Then the title, and Part One.
##
## Nothing here can cause or prevent the Silence. The quest gives Talindir a reason to climb; the
## night comes anyway.

signal stage_changed(stage: int)

enum Stage { DESK, DUTY, GATHER, KEY, CLIMB, BALCONY, SILENCE, DONE }

const L = preload("res://threed/coldopen/ColdOpenLayout.gd")
const S = preload("res://threed/coldopen/ColdOpenScript.gd")
const PLAYER_SCENE := preload("res://threed/Player3D.tscn")
const DIALOGUE_UI := preload("res://ui/DialogueUI.tscn")
signal demo_ended
var touch: TouchControls
var demo_over := false

## Seconds at the desk before Maelis comes in on her own (sooner if the player has looked at things).
const MAELIS_COMES_AT := 22.0
## Seconds on the balcony before the festival-goer comes over.
const FG_COMES_AT := 9.0
## The ninth bell does not wait for ever: this long on the balcony and the night begins anyway.
const NINTH_BELL_AT := 240.0

var world: ColdOpenWorld
var player: Player3D
var rig: CameraRig3D
var ui: ColdOpenUI
var dialogue_ui: Control
var maelis: NPC3D
var festival_goer: NPC3D
var crowd: Array[Wanderer3D] = []
## Revellers who are only there to be a crowd: no lines, no prompt — people at a rail.
var extras: Array[RiggedCharacter3D] = []
var celebrant: RiggedCharacter3D
var procession: Array[RiggedCharacter3D] = []
var stair_door: Node3D
var stair_door_body: StaticBody3D
var hip_seal: OmniLight3D
var carried_record: Node3D
var lectern_record: Node3D
var cutscene: ColdOpenCutscene

## Renders and tools set this before adding the scene: no black opening card.
var skip_opening := false

var stage: int = Stage.DESK
var got := {"record": false, "ink": false, "glass": false}
var letter_stage := 0
var examined := 0
var _t := 0.0
var _stage_t := 0.0
var _walks: Array = []           # [npc, target, speed, callback]
var _lift_down := false
var _fg_spoke := false
var _choice_made := false


class UseSpot extends Interactable3D:
	## An interactable whose use runs a director callback instead of a canned examine.
	var on_use: Callable

	func interact() -> void:
		if on_use.is_valid():
			on_use.call()
		else:
			super.interact()


class TalkNPC extends NPC3D:
	## An NPC whose conversation is the director's to choose (it depends on the night's stage).
	var on_use: Callable

	func interact() -> void:
		if on_use.is_valid():
			on_use.call()
		else:
			super.interact()


func _ready() -> void:
	GameState.current_protagonist = "talindir"
	_fit_ui()
	get_tree().root.size_changed.connect(_fit_ui)
	var t0 := Time.get_ticks_msec()
	world = ColdOpenWorld.new()
	world.name = "World"
	add_child(world)
	world.build_world()
	print("[demo] world built in %d ms" % (Time.get_ticks_msec() - t0))
	_spawn_player()
	_spawn_camera()
	ui = ColdOpenUI.new()
	ui.name = "ColdOpenUI"
	add_child(ui)
	if TouchControls.wanted():
		ui.use_touch_layout()
		touch = TouchControls.new()
		touch.name = "TouchControls"
		touch.director = self
		add_child(touch)
	dialogue_ui = DIALOGUE_UI.instantiate()
	add_child(dialogue_ui)
	var strain := dialogue_ui.get_node_or_null("Strain")
	if strain:
		strain.visible = false
	_place_examinables()
	_place_quest_spots()
	_spawn_people()
	_build_stair_door()
	cutscene = ColdOpenCutscene.new()
	cutscene.name = "Cutscene"
	add_child(cutscene)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	DialogueManager.dialogue_started.connect(func(_id): ui.hush())
	ColdOpenAudio.start(self)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		ColdOpenWorld.apply_light_budget(self)
		if touch:
			# phones: the moon's shadow pass redraws the whole city; the look survives without it
			var moon := find_child("Moon", true, false) as DirectionalLight3D
			if moon:
				moon.shadow_enabled = false
	if _want_fps():
		_add_fps_label()
	print("[demo] scene ready in %d ms" % (Time.get_ticks_msec() - t0))
	_opening()


## Phones: keep the screen text at 1:1 pixels (the pixel font breaks up when scaled below 1). The
## layout is designed at 960x540; a landscape phone is only ~360-430 px tall, so there the canvas is
## simply the window.
func _fit_ui() -> void:
	var win := DisplayServer.window_get_size()
	var root := get_tree().root
	if win.y > 0 and win.y < 540:
		root.content_scale_size = win
	else:
		root.content_scale_size = Vector2i(960, 540)


## ?fps=1 on the web page (or KAYOS_FPS=1) puts a frame counter in the corner.
func _want_fps() -> bool:
	if OS.get_environment("KAYOS_FPS") == "1":
		return true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		return typeof(q) == TYPE_STRING and (q as String).contains("fps=1")
	return false


func _add_fps_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var l := Label.new()
	l.position = Vector2(8, 4)
	l.add_theme_font_size_override("font_size", 14)
	layer.add_child(l)
	add_child(layer)
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(func():
		l.text = "%d fps  ·  %d draws" % [Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		print("[demo] " + l.text))
	layer.add_child(t)


## Black, the place and the night, then up on Talindir at his desk.
func _opening() -> void:
	if skip_opening:
		ui.whisper(S.CONTROLS_TOUCH if touch else S.CONTROLS, 6.0)
		return
	ui.fade(true, 0.0)
	player.set_physics_process(false)
	await get_tree().create_timer(0.6).timeout
	await ui.narrate(S.PLACE_CARD, 2.8).finished
	await ui.fade(false, 2.4).finished
	player.set_physics_process(true)
	ui.whisper(S.CONTROLS_TOUCH if touch else S.CONTROLS, 6.0)
	get_tree().create_timer(6.5).timeout.connect(func(): if stage == Stage.DESK: ui.whisper(S.OPENING, 6.0))


# =================================================================================================
# setup
# =================================================================================================
func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player3D
	player.model_rig = ColdOpenCast.rig_path("CH-007_talindir_aged")
	player.gravity_enabled = true
	player.speed = 3.0
	player.run_multiplier = 1.6
	player.jump_velocity = 0.0
	player.fall_limit = -40.0
	player.position = L.SPAWN
	add_child(player)
	ColdOpenCast.dress(player.model)
	player.model.face_dir(Vector3(0, 0, -1))
	# the letter's seal, glowing faintly at his hip once it wakes
	hip_seal = OmniLight3D.new()
	hip_seal.light_color = ColdOpenPalette.SONG
	hip_seal.light_energy = 0.0
	hip_seal.omni_range = 1.4
	hip_seal.position = Vector3(0.28, 0.95, 0.05)
	player.model.add_child(hip_seal)


func _spawn_camera() -> void:
	rig = CameraRig3D.new()
	rig.name = "Camera3D"
	rig.distance = 5.2
	rig.min_distance = 2.2
	rig.max_distance = 12.0
	rig.pitch_deg = 20.0
	rig.height = 1.55
	rig.fov = 62.0
	add_child(rig)
	rig.target_path = rig.get_path_to(player)
	rig._target = player
	rig._place()
	rig.current = true


func _examine(name: String, pos: Vector3, flag := "") -> Interactable3D:
	var it := Interactable3D.new()
	it.name = "IX_" + name.replace(" ", "").replace("'", "").replace(",", "").replace("—", "")
	it.display_name = name
	it.examine_text = S.EXAMINE.get(name, "")
	if flag != "":
		it.flag_on_interact = flag
	it.position = pos
	add_child(it)
	return it


func _spot(name: String, pos: Vector3, cb: Callable) -> UseSpot:
	var it := UseSpot.new()
	it.name = "USE_" + name.replace(" ", "").replace("'", "").replace("-", "")
	it.display_name = name
	it.on_use = cb
	it.position = pos
	add_child(it)
	return it


func _place_examinables() -> void:
	var y := L.BAL_Y
	# the scriptorium
	_examine("Your Desk", L.DESK + Vector3(-0.6, 0, 0.3))
	_examine("A Cold Cup", L.DESK + Vector3(0.7, 0, 0.2))
	_examine("Wax and Matrix", L.DESK + Vector3(-0.9, 0, -0.4))
	_examine("Sorrel's Desk", Vector3(3.2, 0, L.DESK.z + 0.3))
	_examine("The Writing Quill", L.QUILL_DESK + Vector3(0, 0, 0.4))
	_examine("The Scriptorium Window", Vector3(0, 0, L.SCR_Z0 + 1.0))
	_examine("A Floating Lamp", Vector3(0, 0, 18.0))
	_examine("Volume the First", Vector3(0, 0, 25.4))
	_examine("The Newest Shelf", Vector3(-7.0, 0, 22.5))
	_examine("The Duty Roster", Vector3(2.4, 0, 27.4))
	# the Hall of Records
	_examine("The Stacks — Recent Years", Vector3(14.0, 0, 38.0))
	_examine("The Stacks — the Middle Ages", Vector3(-18.0, 0, 38.0))
	_examine("The Orrery", L.ORRERY + Vector3(0, 0, -2.2))
	_examine("The Survey of the Songlines", Vector3(-11.0, 0, 34.9))
	# the cloister
	_examine("The Fountain", L.FOUNTAIN + Vector3(0, 0, 3.6))
	_examine("The Street Gate", L.GATE + Vector3(1.6, 0, 0))
	_examine("A Citrus Tree", Vector3(-48.5, 0, 26.0))
	# the stair
	_examine("The Stair Window", Vector3(-22.5, 12.0, -8.0))
	# the balcony
	_examine("Festival Banner", Vector3(-8.8, y, L.STAIR_Z0 - 1.2), "COLDOPEN_SAW_BANNER")
	_examine("A Star-Lamp", Vector3(-4.0, y, -8.0))
	_examine("A Child's Sun-Mask", Vector3(-5.2, y, -1.5))
	_examine("Sun-Sigil Mosaic", L.MOSAIC + Vector3(0, 0, 2.6))
	_examine("Order of Ceremony", Vector3(6.2, y, -15.8))
	_examine("The Balustrade", Vector3(-3.5, y, L.BAL_Z0 + 1.0))
	_examine("Initials, Cut in the Rail", Vector3(4.2, y, L.BAL_Z0 + 1.0))
	_examine("Two Cups, Left Behind", Vector3(9.6, y, -15.8))
	_examine("A Brazier", Vector3(-7.2, y, -7.4))
	# small props for the balcony examinables
	var k := SolariKit.new(world.mats, 90)
	k.disc("cloth_gold", Vector3(-5.2, y + 0.02, -1.5), 0.22, 9)
	for i in 9:
		var a := TAU * i / 9.0
		k.tri("cloth_gold", Vector3(-5.2, y + 0.021, -1.5) + Vector3(sin(a - 0.12), 0, cos(a - 0.12)) * 0.2,
			Vector3(-5.2, y + 0.021, -1.5) + Vector3(sin(a), 0, cos(a)) * 0.36,
			Vector3(-5.2, y + 0.021, -1.5) + Vector3(sin(a + 0.12), 0, cos(a + 0.12)) * 0.2, Vector3.UP)
	for dx in [-0.12, 0.12]:
		k.prism("gold", Vector3(9.6 + dx, y + L.RAIL_H, L.BAL_Z0 + 0.3), 0.05, 0.11, 8, 0.06)
	k.box("paper", Vector3(6.2, y + L.RAIL_H + 0.01, L.BAL_Z0 + 0.3), Vector3(0.3, 0.01, 0.4), Basis(Vector3.UP, 0.3))
	k.commit(self, "BalconyBits")


func _place_quest_spots() -> void:
	_spot("Elorin's Letter", L.DESK + Vector3(0.5, 0, 0.3), _use_letter)
	_spot("The Star-Ink Font", L.INK_FONT + Vector3(-0.9, 0, 0), _use_ink)
	_spot("The Book-Lift", L.BOOK_LIFT + Vector3(0, 0, -2.0), _use_lift)
	_spot("The Song-Glass", L.SONG_GLASS + Vector3(0, 0, -1.2), _use_glass)
	_spot("The Resonance Bell", L.BELL + Vector3(0, 0, -1.2), _use_bell)
	_spot("The Stair Door", L.STAIR_DOOR + Vector3(-1.4, 0, 0), _use_stair_door)
	_spot("The Lectern", L.LECTERN + Vector3(0, 0, 1.0), _use_lectern)


func _npc(rig_file: String, name: String, pos: Vector3, text := "") -> NPC3D:
	var n := TalkNPC.new()
	n.rig_model = ColdOpenCast.rig_path(rig_file)
	n.display_name = name
	n.examine_text = text
	n.show_label = false
	n.show_prompt = false
	n.position = pos
	add_child(n)
	ColdOpenCast.dress(n.model)
	return n


func _spawn_people() -> void:
	# Maelis waits in the Hall, out of sight, until it is time to come in
	maelis = _npc("NPC-maelis_archivist", "Archivist Maelis", Vector3(0, 0, L.SCR_Z1 + 3.0))
	maelis.visible = false
	(maelis as TalkNPC).on_use = _talk_to_maelis
	# the balcony crowd
	var spots := [Vector3(-6.5, 0, -15.6), Vector3(-3.2, 0, -15.9), Vector3(2.0, 0, -15.8), Vector3(5.5, 0, -15.6),
		Vector3(-8.6, 0, -12.5), Vector3(8.4, 0, -12.0), Vector3(-1.0, 0, -15.9), Vector3(7.6, 0, -15.6)]
	for i in S.CROWD.size():
		var c: Array = S.CROWD[i]
		var w := Wanderer3D.new()
		w.rig_model = ColdOpenCast.rig_path(c[1])
		w.display_name = c[0]
		w.examine_text = c[2]
		w.show_label = false
		w.show_prompt = false
		var p: Vector3 = spots[i]
		w.position = Vector3(p.x, L.BAL_Y, p.z)
		w.roam_rect = Rect2(p.x - 1.2, p.z, 2.4, 1.2) if i % 3 != 2 else Rect2()
		w.speed = 0.6
		add_child(w)
		ColdOpenCast.dress(w.model)
		w.face(Vector3(0, 0, -1))
		crowd.append(w)
	var extra_rigs := ["NPC-sol-reveller2", "NPC-sol-reveller5", "NPC-sol-reveller8", "NPC-sol-reveller3",
		"NPC-sol-reveller6", "NPC-sol-reveller1", "NPC-sol-lantern2"]
	var extra_x := [-9.6, -5.0, -2.2, 0.9, 3.6, 6.6, 9.4]
	for i in extra_rigs.size():
		var r := RiggedCharacter3D.new()
		r.rig_path = ColdOpenCast.rig_path(extra_rigs[i])
		r.name = "Extra%d" % i
		add_child(r)
		r.position = Vector3(extra_x[i], L.BAL_Y, L.BAL_Z0 + 1.15 + (i % 2) * 0.35)
		r.face_dir(Vector3(randf_range(-0.2, 0.2), 0, -1))
		ColdOpenCast.dress(r)
		extras.append(r)
	festival_goer = _npc("NPC-festivalgoer", "Festival-Goer", Vector3(3.6, L.BAL_Y, -12.8))
	festival_goer.dialogue = ""
	festival_goer.examine_text = "She is watching the Tower with her whole body, the way children do."
	festival_goer.face(Vector3(0, 0, -1))
	# the celebrant on the Tower's apex
	celebrant = RiggedCharacter3D.new()
	celebrant.rig_path = ColdOpenCast.rig_path("CH-028_grand_archmage_sulvaine")
	celebrant.name = "Sulvaine"
	add_child(celebrant)
	celebrant.position = L.TOWER + Vector3(0, L.TOWER_H + 0.1, 0)
	celebrant.face_dir(Vector3(0, 0, 1))
	celebrant.scale = Vector3.ONE * 1.6      # regalia and crown: a figure that reads from a mile off
	ColdOpenCast.dress(celebrant)
	# the procession in the street outside the gate
	var bearers := ["NPC-sol-lantern1", "NPC-sol-lantern2", "NPC-sol-reveller1", "NPC-sol-lantern1",
		"NPC-sol-reveller8", "NPC-sol-lantern2", "NPC-sol-reveller3", "NPC-sol-lantern1", "NPC-sol-reveller6", "NPC-sol-lantern2"]
	for i in bearers.size():
		var r := RiggedCharacter3D.new()
		r.rig_path = ColdOpenCast.rig_path(bearers[i])
		add_child(r)
		r.position = Vector3(-64.5 + (i % 3) * 1.6, 0, 60.0 - i * 9.5)
		r.face_dir(Vector3(0, 0, -1))
		r.set_moving(true, 1.0)
		ColdOpenCast.dress(r)
		procession.append(r)


func _build_stair_door() -> void:
	stair_door = Node3D.new()
	stair_door.name = "StairDoor"
	stair_door.position = L.STAIR_DOOR + Vector3(-0.1, 0, 1.5)
	add_child(stair_door)
	var k := SolariKit.new(world.mats, 91)
	k.box("wood", Vector3(0, 2.2, -1.5), Vector3(0.14, 4.4, 3.0))
	for zz in [-2.6, -1.5, -0.4]:
		k.box("gold", Vector3(-0.08, 2.2, zz), Vector3(0.03, 4.2, 0.08))
	k.box("gold", Vector3(-0.1, 1.2, -2.7), Vector3(0.06, 0.2, 0.1))
	k.commit(stair_door, "Leaf")
	stair_door_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.4, 4.4, 3.0)
	cs.shape = bs
	cs.position = Vector3(0, 2.2, -1.5)
	stair_door_body.add_child(cs)
	stair_door.add_child(stair_door_body)


# =================================================================================================
# the night
# =================================================================================================
func _set_stage(s: int) -> void:
	stage = s
	_stage_t = 0.0
	_refresh_objectives()
	stage_changed.emit(s)


func _refresh_objectives() -> void:
	match stage:
		Stage.GATHER, Stage.KEY:
			var items := [[S.OBJ_RECORD, got.record], [S.OBJ_INK, got.ink], [S.OBJ_GLASS, got.glass]]
			if stage == Stage.KEY:
				items.append([S.OBJ_KEY, false])
			ui.set_objectives(S.QUEST_TITLE, items)
		Stage.CLIMB:
			ui.set_objectives(S.QUEST_TITLE, [[S.OBJ_KEY, true], [S.OBJ_CLIMB, false]])
		Stage.BALCONY:
			ui.set_objectives(S.QUEST_TITLE, [[S.OBJ_CLIMB, true], [S.OBJ_LECTERN, false]])
		_:
			ui.set_objectives("", [])


func _process(delta: float) -> void:
	_t += delta
	_stage_t += delta
	_run_walks(delta)
	_run_procession(delta)
	_song_glass(delta)
	if stage == Stage.SILENCE or stage == Stage.DONE:
		ui.set_prompt("")
		return
	_update_prompt()
	if DialogueManager.is_active():
		return
	match stage:
		Stage.DESK:
			if _stage_t > MAELIS_COMES_AT or (examined >= 2 and _stage_t > 8.0):
				_maelis_comes_in()
		Stage.CLIMB:
			if player.global_position.y > L.BAL_Y - 0.5 and player.global_position.x > L.STAIR_X1 - 0.5:
				_arrive_on_balcony()
			elif player.global_position.y > 8.0 and not GameState.get_flag("CO2_COUNTED", false):
				GameState.set_flag("CO2_COUNTED", true)
				ui.whisper(S.STAIR_COUNT, 4.0)
		Stage.BALCONY:
			if not _fg_spoke and _stage_t > FG_COMES_AT:
				_festival_goer_comes()
			if _stage_t > NINTH_BELL_AT:
				_begin_silence()


func _update_prompt() -> void:
	if DialogueManager.is_active():
		ui.set_prompt("")
		return
	var best: Interactable3D = null
	var bd := player.interact_reach
	var here := player.global_position
	for n in get_tree().get_nodes_in_group("interactable3d"):
		var it := n as Interactable3D
		if it == null or not it.is_visible_in_tree():
			continue
		if absf(it.global_position.y - here.y) > player.interact_height:
			continue
		var d := Vector2(it.global_position.x - here.x, it.global_position.z - here.z).length()
		if d <= bd:
			bd = d
			best = it
	ui.set_prompt(best.display_name if best else "")


## Walk an NPC in a straight line (the Archive's rooms are open enough for it).
func _walk(npc: NPC3D, to: Vector3, speed: float, then: Callable = Callable()) -> void:
	_walks.append([npc, to, speed, then])


func _run_walks(delta: float) -> void:
	var busy := {}
	for w in _walks.duplicate():
		# one leg at a time per walker: later legs wait for earlier ones
		if busy.has(w[0]):
			continue
		busy[w[0]] = true
		var npc: NPC3D = w[0]
		var to: Vector3 = w[1]
		var v := to - npc.global_position
		v.y = 0.0
		if v.length() < 0.12:
			npc.stop_walking()
			_walks.erase(w)
			var cb: Callable = w[3]
			if cb.is_valid():
				cb.call()
			continue
		var step := minf(v.length(), float(w[2]) * delta)
		npc.walk_toward(v.normalized(), w[2])
		npc.global_position += v.normalized() * step


func _run_procession(delta: float) -> void:
	for r in procession:
		r.position.z -= 1.0 * delta
		if r.position.z < -40.0:
			r.position.z += 100.0


func _song_glass(delta: float) -> void:
	var lvl := world.archive.song_glass_level
	if lvl == null or SilenceState.radius >= 0.0:
		return
	# the reading: low, and breathing — it dips, and recovers, and dips
	var base := 1.05 - clampf(_t / 600.0, 0.0, 0.25)
	lvl.scale.y = base + sin(_t * 0.9) * 0.18 + sin(_t * 2.3) * 0.05


# --- DESK -> DUTY ------------------------------------------------------------------------------
func _maelis_comes_in() -> void:
	_set_stage(Stage.DUTY)
	maelis.visible = true
	maelis.global_position = Vector3(1.2, 0, L.SCR_Z1 + 0.5)
	var to := player.global_position + Vector3(0.9, 0, 1.4)
	# round the reading table by the door, then down the aisle to him
	_walk(maelis, Vector3(1.2, 0, 23.2), 1.3)
	_walk(maelis, to, 1.3, func():
		maelis.face(player.global_position - maelis.global_position)
		player.model.face_dir(maelis.global_position - player.global_position)
		DialogueManager.start(S.maelis_duty())
		(maelis.model as RiggedCharacter3D).set_talking(true))


func _on_dialogue_finished(id: String) -> void:
	match id:
		"co2_maelis_duty":
			(maelis.model as RiggedCharacter3D).set_talking(false)
			_walk(maelis, Vector3(1.2, 0, 23.2), 1.4)
			_walk(maelis, Vector3(1.2, 0, L.SCR_Z1 + 1.2), 1.4, func():
				maelis.global_position = L.ARCHIVIST
				maelis.face(Vector3(-1, 0, 0))
				maelis.examine_text = "Watching the street through the bars, in the way of a woman who has decided to enjoy herself and is working at it.")
			if not GameState.get_flag("CO2_LETTER_TAKEN", false):
				_take_letter(true)
			GameState.start_quest("co2_record", S.QUEST_TITLE, "Sorrel has gone to the festival. Record the two-thousandth Luminarae from the balcony.", "main")
			_set_stage(Stage.GATHER)
			ColdOpenAudio.bell(self, 7, false)
			get_tree().create_timer(1.0).timeout.connect(func(): ui.whisper(S.AFTER_DUTY, 5.0))
		"co2_maelis_key":
			(maelis.model as RiggedCharacter3D).set_talking(false)
			if GameState.get_flag("CO2_HAS_KEY", false):
				_open_stair_door()
				_set_stage(Stage.CLIMB)
				ColdOpenAudio.bell(self, 8, false)
		"coldopen_festivalgoer":
			_fg_spoke = true
			_choice_made = true
			var honest: bool = GameState.get_flag("COLDOPEN_HONEST", false)
			_walk(festival_goer, Vector3(4.2 if honest else 3.0, L.BAL_Y, -15.4), 1.2, func():
				festival_goer.face(Vector3(0, 0, -1)))
			festival_goer.dialogue = ""
			festival_goer.examine_text = (
				"She is standing with her friends again. She is not laughing, and every little while she looks up at the sky, and then at you."
				if honest else
				"She is dancing again, and has already forgotten you entirely, which is precisely what you asked her to do.")
			ui.set_objectives(S.QUEST_TITLE, [[S.OBJ_CLIMB, true], [S.OBJ_LECTERN, false]])
		"co2_lectern":
			if GameState.get_flag("CO2_RECORD_OPEN", false):
				_begin_silence()


# --- the letter --------------------------------------------------------------------------------
func _use_letter() -> void:
	if GameState.get_flag("CO2_LETTER_TAKEN", false):
		_say_examine("Elorin's Letter", S.letter_text(letter_stage))
		return
	examined += 1
	_say_examine("Elorin's Letter", S.letter_text(0) + " You put it in your satchel, where it has always lived.")
	_take_letter(false)


func _take_letter(quietly: bool) -> void:
	GameState.set_flag("CO2_LETTER_TAKEN", true)
	GameState.set_flag("COLDOPEN_SAW_LETTER", true)
	world.archive.letter.visible = false
	var spot := get_node_or_null("USE_ElorinsLetter") as UseSpot
	if spot:
		spot.position = Vector3(0, -100, 0)     # it is in the satchel now; examine it there
	if quietly:
		ui.whisper(S.LETTER_POCKETED, 4.0)


func _wake_seal(stage_to: int) -> void:
	if stage_to <= letter_stage:
		return
	letter_stage = stage_to
	var tw := create_tween()
	tw.tween_property(hip_seal, "light_energy", 0.5 * stage_to, 3.0)


## Talindir's interior line, once whoever is speaking has finished.
func _whisper_after_talk(text: String, hold: float) -> void:
	while DialogueManager.is_active():
		await DialogueManager.dialogue_finished
	await get_tree().create_timer(0.4).timeout
	ui.whisper(text, hold)


func _say_examine(title: String, text: String) -> void:
	DialogueManager.start({"id": "examine", "start": "n", "nodes": {"n": {"speaker": title, "text": text}}})


# --- GATHER ------------------------------------------------------------------------------------
func _gather_open() -> bool:
	if stage < Stage.GATHER:
		ui.whisper("Not now — later. Tonight the Archive is quiet, and you had meant to sit.", 3.5)
		return false
	return true


func _use_lift() -> void:
	if got.record:
		_say_examine("The Book-Lift", "Empty now, hanging at your shoulder in the air, waiting to be sent up again.")
		return
	if not _gather_open():
		return
	if not _lift_down:
		_lift_down = true
		ui.whisper("You lay your palm on the call-post. High on the stacks, the lift answers.", 3.0)
		var tw := world.archive.book_lift.glide_to(1.25, 4.0)
		tw.finished.connect(func():
			_lamp_dip(world.archive.lamps.filter(func(l): return l.global_position.z > L.HALL_Z0))
			ui.whisper(S.LIFT_FLICKER, 5.5)
			_wake_seal(1))
		return
	# it is down: take the Record
	got.record = true
	world.archive.record_on_lift.visible = false
	_carry_record()
	_refresh_objectives()
	ui.whisper("The Luminarae Record: two thousand festivals, one page each. It is heavier than it looks, and it looks heavy.", 4.5)
	_check_gathered()


## Every lamp in `lamps` dips at once and comes back.
func _lamp_dip(lamps: Array) -> void:
	for l in lamps:
		var sh := l as SongHeld
		for light in sh.lights:
			var e: float = light.light_energy
			var tw := create_tween()
			tw.tween_property(light, "light_energy", e * 0.08, 0.35)
			tw.tween_interval(0.6)
			tw.tween_property(light, "light_energy", e, 0.9)


func _carry_record() -> void:
	carried_record = world.archive.make_record()
	# held against his right side, under the arm, covers facing out
	player.model.add_child(carried_record)
	carried_record.position = Vector3(-0.3, 1.06, 0.04)
	carried_record.rotation = Vector3(0, 0, PI * 0.5)
	carried_record.scale = Vector3.ONE * 0.6


func _use_ink() -> void:
	if got.ink:
		_say_examine("The Star-Ink Font", "Ink the colour of the sky past midnight, with the stars still in it. They are still drifting south.")
		return
	if not _gather_open():
		_say_examine("The Star-Ink Font", "Ink the colour of the sky past midnight, with small stars moving in it. The Record takes no other.")
		return
	got.ink = true
	_refresh_objectives()
	_say_examine("The Star-Ink Font", "You dip the horn and it comes up full of night. The small stars in the ink turn in it as they always do — and then, as you watch, they settle into one direction and begin, very slowly, to drift.")
	_whisper_after_talk(S.INK_DRIFT, 5.0)
	_wake_seal(1)
	_check_gathered()


func _use_glass() -> void:
	if not _gather_open():
		_say_examine("The Song-Glass", "A column of gold light in a glass tube, as tall as a man: the Archive's measure of the Song. Tonight it stands lower than you like.")
		return
	if got.glass:
		_say_examine("The Song-Glass", S.GLASS_LOW)
		return
	got.glass = true
	_refresh_objectives()
	DialogueManager.start({"id": "co2_glass", "start": "a", "nodes": {
		"a": {"speaker": "The Song-Glass", "text": "You read it the way you have read it every Luminarae for sixty years, and write the figure in the margin of your hand. " + S.GLASS_LOW, "choices": [{"text": "(look closer)", "goto": "b"}]},
		"b": {"speaker": "", "text": S.GLASS_KNOWN}}})
	_wake_seal(2)
	_whisper_after_talk(S.SEAL_WAKES, 5.0)
	_check_gathered()


func _check_gathered() -> void:
	if got.record and got.ink and got.glass and stage == Stage.GATHER:
		_set_stage(Stage.KEY)
		maelis.dialogue = ""


func _use_bell() -> void:
	ColdOpenAudio.bell_wrong(self)
	if GameState.get_flag("CO2_RANG_BELL", false):
		_say_examine("The Resonance Bell", "You leave it be. Once was enough.")
		return
	GameState.set_flag("CO2_RANG_BELL", true)
	_say_examine("The Resonance Bell", "The bell the Archive rings to call the scribes to table, cast to the Song's own note. You strike it with the flat of your hand — and the note is wrong. Not cracked; wrong, as if the air it rings in had been tuned a hair's breadth flat. Across the garth, Maelis turns her head.")


# --- KEY -> CLIMB ------------------------------------------------------------------------------
func _talk_to_maelis() -> void:
	if stage == Stage.KEY:
		maelis.face(player.global_position - maelis.global_position)
		(maelis.model as RiggedCharacter3D).set_talking(true)
		DialogueManager.start(S.maelis_key())
	elif stage == Stage.GATHER:
		maelis.face(player.global_position - maelis.global_position)
		var missing := []
		if not got.record: missing.append("the Record")
		if not got.ink: missing.append("the ink")
		if not got.glass: missing.append("the reading")
		_say_examine("Archivist Maelis", "\"Not without %s, Talindir. I know you.\" She goes back to the street." % " and ".join(missing))
	else:
		_say_examine("Archivist Maelis", maelis.examine_text)


func _use_stair_door() -> void:
	if GameState.get_flag("CO2_HAS_KEY", false):
		return
	_say_examine("The Stair Door", S.STAIR_LOCKED)


func _open_stair_door() -> void:
	stair_door_body.collision_layer = 0
	var tw := create_tween()
	tw.tween_property(stair_door, "rotation:y", deg_to_rad(-100.0), 1.6).set_trans(Tween.TRANS_SINE)
	var spot := get_node_or_null("USE_TheStairDoor")
	if spot:
		spot.position.y = -100.0


# --- BALCONY -----------------------------------------------------------------------------------
func _arrive_on_balcony() -> void:
	_set_stage(Stage.BALCONY)
	rig.distance = 6.4
	ui.whisper(S.BALCONY_ARRIVE, 4.5)
	ColdOpenAudio.on_balcony(self)


func _festival_goer_comes() -> void:
	_fg_spoke = true
	var to := player.global_position + (Vector3(1.2, 0, -1.0))
	to.y = L.BAL_Y
	_walk(festival_goer, to, 1.3, func():
		festival_goer.face(player.global_position - festival_goer.global_position)
		player.model.face_dir(festival_goer.global_position - player.global_position)
		DialogueManager.start(S.festival_goer())
		(festival_goer.model as RiggedCharacter3D).set_talking(true)
		DialogueManager.dialogue_finished.connect(func(_i): (festival_goer.model as RiggedCharacter3D).set_talking(false), CONNECT_ONE_SHOT))


func _use_lectern() -> void:
	if stage != Stage.BALCONY:
		return
	if not _choice_made:
		# she has not reached him yet — she comes now
		ui.whisper(S.LECTERN_WAIT, 3.5)
		if not _fg_spoke:
			_festival_goer_comes()
		return
	DialogueManager.start(S.lectern_begin())


func _begin_silence() -> void:
	if stage == Stage.SILENCE:
		return
	_set_stage(Stage.SILENCE)
	ui.set_prompt("")
	if carried_record:
		carried_record.visible = false
	lectern_record = world.archive.make_record()
	lectern_record.position = L.LECTERN + Vector3(0, 1.12, 0.05)
	lectern_record.rotation.x = deg_to_rad(18)
	add_child(lectern_record)
	GameState.complete_quest("co2_record")
	await cutscene.play(self)
	_hand_off()


func _hand_off() -> void:
	_set_stage(Stage.DONE)
	GameState.set_flag("COLDOPEN_DONE", true)
	GameState.save_game()
	# Demo 1 ends here: Part One is not in this build. Hold the end card; a tap starts the night again.
	ui.title_card(S.DEMO_END_TITLE, S.DEMO_END_SUB)
	demo_over = true
	demo_ended.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not demo_over:
		return
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if tapped:
		demo_over = false
		get_viewport().set_input_as_handled()
		world.reset_silence()
		GameState.reset()
		get_tree().reload_current_scene()


# --- test and render hooks ---------------------------------------------------------------------
## Jump the night straight to `s` (tests, and ShotColdOpenV2's gameplay shots).
func skip_to(s: int) -> void:
	if s >= Stage.GATHER:
		GameState.set_flag("CO2_DUTY_GIVEN", true)
		maelis.visible = true
		maelis.global_position = L.ARCHIVIST
		_take_letter(true)
	if s >= Stage.KEY:
		got.record = true
		got.ink = true
		got.glass = true
		world.archive.record_on_lift.visible = false
		_carry_record()
	if s >= Stage.CLIMB:
		GameState.set_flag("CO2_HAS_KEY", true)
		_open_stair_door()
	if s >= Stage.BALCONY:
		player.global_position = L.BAL_SPAWN + Vector3(9.0, 0, -2.0)
		_arrive_on_balcony()
	else:
		_set_stage(s)
