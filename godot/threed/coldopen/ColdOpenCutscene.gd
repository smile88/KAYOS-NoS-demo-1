extends Node
class_name ColdOpenCutscene
## The Night of Silence, as a cutscene (docs/Cold_Open_v2_Proposal.md, Act 3). Its order of failures
## is the canon one for all four tellings of the night (Narrative_Outline.md §6, Crossing Point III):
##
##   1  the ninth bell; the Record open at the rail
##   2  the Invocation: the column of gold swells out of the Tower, the choir rises, the crowd cheers
##   3  the Grand Archmage at the apex, arms raised
##   4  wrongness: a sour note; on the far hills the echo stones go dark, farthest first, closing in
##   5  on the balcony: "what was that?" — and Talindir closes his eyes
##   6  the column falters; the choir's voice sags and breaks
##   7  the column goes out; Sulvaine falls from the apex
##   8  the ring: out of the Tower's foot, across the city — colour gone behind it, threads black and
##      snapping, lanterns falling like burning rain, windows dying district by district — and over
##      the balcony, where every sound stops
##   9  silence: the crowd's last moment left standing at the rail in gold; the people themselves
##      grey, folding down, grown suddenly old ("the falling and the aging")
##  10  Talindir sits among the fallen garlands; the narration; the letter — its first line
##  11  the title
##
## Everything in the world does its own part of the draining (the shaders read the ring's global
## radius; SongHeld things let go when it reaches them). This script moves the camera, the ring, the
## people and the sound.

const L = preload("res://threed/coldopen/ColdOpenLayout.gd")
const S = preload("res://threed/coldopen/ColdOpenScript.gd")

## Ring speed (m/s): it has to reach the balcony's camera exactly as wave.wav cuts to silence.
const WAVE_LEN := 12.0

var d: ColdOpenDirector
var cam: Camera3D
var ui: ColdOpenUI
var audio: ColdOpenAudio
var _ghosted: Dictionary = {}
var _ring_running := false
var _ring_r := -1.0
var _ring_speed := 20.0
var _silenced_audio := false
var _shake := 0.0
var _silence_at := 0.0         # tower distance of the listener (the camera) when the ring runs
var finished := false
## Which beat (1–11) the cutscene has reached — for tests and debugging.
var step := 0


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Wait for a tween started earlier — returning at once if it has already finished (awaiting a
## signal that has already fired never returns).
func _done(tw: Tween) -> void:
	if tw and tw.is_valid() and tw.is_running():
		await tw.finished


func _shot(from: Vector3, look: Vector3, fov := 60.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(look, Vector3.UP)


func _move(a: Vector3, la: Vector3, b: Vector3, lb: Vector3, over: float, fov_a := 60.0, fov_b := -1.0) -> Tween:
	if fov_b < 0.0:
		fov_b = fov_a
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var e := k * k * (3.0 - 2.0 * k)
		cam.fov = lerpf(fov_a, fov_b, e)
		cam.global_position = a.lerp(b, e)
		cam.look_at(la.lerp(lb, e), Vector3.UP), 0.0, 1.0, over)
	return tw


func play(director: ColdOpenDirector) -> void:
	d = director
	ui = d.ui
	audio = ColdOpenAudio.of(d)
	cam = Camera3D.new()
	cam.name = "Cine"
	d.add_child(cam)
	cam.current = true
	d.player.set_physics_process(false)
	d.player.set_process_unhandled_input(false)
	for w in d.crowd:
		w.freeze()
	ui.hide_hud(true)
	ui.letterbox(true, 1.6)
	var tal := d.player.model as RiggedCharacter3D

	step = 1
	# --- 1. the ninth bell --------------------------------------------------------------------
	d.player.global_position = L.LECTERN + Vector3(-0.9, 0, 0.7)
	tal.face_dir(Vector3(0.3, 0, -1))
	var honest: bool = GameState.get_flag("COLDOPEN_HONEST", false)
	if honest:
		# she told him it wasn't a kind thing to say; she came and stood by him anyway
		d.festival_goer.global_position = L.LECTERN + Vector3(-2.1, 0, 0.5)
		d.festival_goer.face(Vector3(0.2, 0, -1))
	tal.play_action("Interact")
	if audio:
		audio.shot("bell.wav", -2.0)
	ui.subtitle(S.CUT_NINTH, 3.0)
	await _move(Vector3(0.8, 19.6, -13.4), L.LECTERN + Vector3(0, 1.1, 0), Vector3(0.6, 20.0, -12.2), Vector3(0, 70, -225), 7.0, 50.0, 58.0).finished

	step = 2
	# --- 2. the Invocation --------------------------------------------------------------------
	if audio:
		audio.shot("invocation.wav", -3.0)
		audio.set_master(0.55)
	_cheer_loop(d.celebrant)
	var col := create_tween()
	col.tween_method(func(v: float): d.world.city.set_column(v), 1.0, 2.6, 22.0)
	# the threads draw the Song up with it: brighter and brighter
	var th := create_tween()
	th.tween_method(func(v: float): d.world.city.threads_mat.set_shader_parameter("energy", v), 3.0, 7.0, 22.0)
	for i in d.crowd.size():
		if i % 2 == 0:
			(d.crowd[i].model as RiggedCharacter3D).play_action("Cheer")
	for e in d.extras:
		e.play_action("Cheer")
	await _move(Vector3(-2.6, 21.4, -2.0), Vector3(0, 80, -225), Vector3(-1.8, 21.0, -8.8), Vector3(0, 95, -225), 10.0, 62.0).finished

	step = 3
	# --- 3. the Grand Archmage ----------------------------------------------------------------
	var apex := L.TOWER + Vector3(0, L.TOWER_H + 2.2, 0)
	var high := L.TOWER + Vector3(24.0, L.TOWER_H + 9.0, 36.0)
	await _move(high, apex, high + Vector3(-5.0, 1.5, -4.0), apex + Vector3(0, 1.5, 0), 7.0, 30.0, 22.0).finished

	step = 4
	# --- 4. the echo stones -------------------------------------------------------------------
	if audio:
		audio.shot("dissonance.wav", -5.0)
	_shot(Vector3(0, 64, 30), Vector3(0, 30, -1400), 58.0)
	var drift := _move(Vector3(0, 64, 30), Vector3(0, 30, -1400), Vector3(0, 70, 18), Vector3(0, 40, -1400), 14.0, 58.0, 70.0)
	var stones: Array = d.world.city.echo_stones
	for i in stones.size():
		_put_out(stones[i])
		if i == 6:
			ui.subtitle(S.CUT_WHAT, 3.5)
		await _wait(0.95)
	await _done(drift)

	step = 5
	# --- 5. Talindir knows ----------------------------------------------------------------------
	tal.face_dir(Vector3(0, 0, -1))
	var face := d.player.global_position + Vector3(0, 1.85, 0)
	await _move(face + Vector3(0.9, 0.05, -1.6), face, face + Vector3(0.7, 0.02, -1.25), face, 5.0, 38.0, 34.0).finished

	step = 6
	# --- 6. the falter --------------------------------------------------------------------------
	if audio:
		audio.shot("falter.wav", -3.0)
	col.kill()
	var fl := create_tween()
	fl.tween_method(func(v: float): d.world.city.set_column(v, 0.6), 2.6, 0.9, 6.0)
	await _move(Vector3(-24, 26, -28), Vector3(0, 95, -225), Vector3(-20, 27, -32), Vector3(0, 100, -225), 6.0, 32.0, 28.0).finished

	step = 7
	# --- 7. the column goes out; Sulvaine falls --------------------------------------------------
	fl.kill()
	var out := create_tween()
	out.tween_method(func(v: float): d.world.city.set_column(v, 0.9), 0.9, 0.0, 1.0)
	_shot(high + Vector3(-5.0, 1.5, -4.0), apex, 24.0)
	await _wait(1.1)
	_fall(d.celebrant)
	var track := create_tween()
	track.tween_method(func(k: float):
		cam.look_at(d.celebrant.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		cam.fov = lerpf(24.0, 40.0, k), 0.0, 1.0, 2.6)
	await track.finished
	await _wait(0.4)

	step = 8
	# --- 8. the ring ------------------------------------------------------------------------------
	var listener := Vector3(0.5, 22.5, 2.0)
	_silence_at = ColdOpenCity.tower_d(listener)
	_ring_speed = _silence_at / (WAVE_LEN - 0.25)
	var over_city := L.TOWER + Vector3(85.0, 120.0, 125.0)
	_shake = 0.0
	_move(over_city, L.TOWER + Vector3(0, -20, 0), over_city + Vector3(-10, -12, 16), L.TOWER + Vector3(0, -24, 30), 6.0, 60.0, 64.0)
	if audio:
		audio.set_master(1.0)
		audio.shot("wave.wav", 0.0)
	_flash()
	_ring_running = true
	_ring_r = 0.0
	# over the crowd's shoulders at the rail, as it comes
	await _wait(5.8)
	_shake = 0.04
	_move(Vector3(-3.6, 20.1, -12.2), Vector3(-2.0, 12.0, -160.0), Vector3(-3.2, 20.0, -11.4), Vector3(-2.0, 16.0, -160.0), 6.0, 66.0)
	await _wait(2.0)
	for w in d.crowd:
		(w.model as RiggedCharacter3D).play_action("Cheer")
	for e in d.extras:
		e.play_action("Cheer")
	while _ring_r < _silence_at + 40.0:
		await get_tree().process_frame

	step = 9
	_shake = 0.0
	# --- 9. silence ---------------------------------------------------------------------------------
	var fade := create_tween()
	fade.tween_method(func(v: float): d.world.set_fade(v), 0.0, 1.0, 7.0)
	await _wait(1.6)
	if audio:
		audio.shot("tinnitus.wav", -34.0)   # barely there: the ringing that silence makes
	# close on the crowd: their gold, and underneath it, the people
	var who := d.crowd[4] if d.crowd.size() > 4 else d.crowd[0]
	var wp := who.global_position + Vector3(0, 1.5, 0)
	_move(wp + Vector3(2.2, 0.2, 2.6), wp + Vector3(0, -0.4, 0), wp + Vector3(1.6, -0.1, 2.0), wp + Vector3(0, -0.7, 0), 6.0, 45.0)
	await _wait(1.0)
	ui.subtitle(S.CUT_CANT_HEAR, 3.2)
	await _wait(5.2)

	step = 10
	# --- 10. Talindir sits; the narration; the letter ----------------------------------------------
	d.player.global_position = L.MOSAIC + Vector3(0, 0, 0.6)
	tal.face_dir(Vector3(0, 0, 1))
	tal.play_action("Sit_Floor_Down", "Sit_Floor_Idle")
	if honest:
		var fg := d.festival_goer
		fg.global_position = L.MOSAIC + Vector3(1.05, 0, 0.9)
		fg.face(Vector3(-0.4, 0, 1))
		(fg.model as RiggedCharacter3D).play_action("Sit_Floor_Down", "Sit_Floor_Idle")
	_scatter_garlands()
	var wide := _move(Vector3(0.0, 19.9, -3.6), Vector3(0.0, 19.0, -14.0), Vector3(0.0, 19.4, -6.0), Vector3(0.0, 18.9, -14.0), 22.0, 60.0, 56.0)
	await _wait(1.5)
	ui.subtitle(S.CUT_SIT, 5.0)
	await _wait(6.5)
	if honest:
		ui.subtitle(S.CUT_SHE_STAYS, 3.6)
		await _wait(4.6)
	ui.narration_backdrop(true)
	for line in S.CUT_NARRATION:
		await ui.narrate(line, 2.6).finished
	ui.narration_backdrop(false)
	await _done(wide)
	var lap := d.player.global_position + Vector3(0, 0.7, 0.3)
	_move(lap + Vector3(0.9, 1.1, 1.6), lap, lap + Vector3(0.6, 0.9, 1.2), lap, 7.0, 40.0)
	d.hip_seal.light_energy = 3.0
	await _wait(1.2)
	if audio:
		audio.shot("seal.wav", -4.0)
	d.hip_seal.light_energy = 0.0
	await _wait(0.6)
	await ui.show_letter("%s\n\n                         — %s" % [S.LETTER_FIRST_LINE, S.LETTER_SIGNED]).finished
	await _wait(5.5)

	step = 11
	# --- 11. the title ---------------------------------------------------------------------------
	ui.show_letter(S.LETTER_FIRST_LINE, false)
	await ui.fade(true, 2.0).finished
	if audio:
		audio.shot("title.wav", -4.0)
	await ui.title_card(S.TITLE, S.SUBTITLE).finished
	await _wait(4.0)
	await ui.title_card(S.TITLE, S.SUBTITLE, false).finished
	finished = true


func _process(delta: float) -> void:
	if _shake > 0.0 and cam:
		cam.h_offset = randf_range(-_shake, _shake)
		cam.v_offset = randf_range(-_shake, _shake)
	elif cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	if not _ring_running:
		return
	_ring_r += _ring_speed * delta
	d.world.set_silence(_ring_r, _ring_speed)
	d.world.city.set_front(_ring_r, clampf(1.0 - (_ring_r - _silence_at) / 60.0, 0.0, 1.0))
	if not _silenced_audio and _ring_r >= _silence_at:
		_silenced_audio = true
		if audio:
			audio.silence()
		ui.fade(true, 0.06, Color(0.92, 0.94, 1.0)).tween_callback(func(): ui.fade(false, 0.9, Color(0.92, 0.94, 1.0)))
	# the crowd: as the ring reaches each of them, their gold stays; they do not
	var people: Array = []
	people.append_array(d.crowd)
	people.append_array(d.extras)
	people.append(d.festival_goer)
	for w in people:
		if _ghosted.has(w):
			continue
		if ColdOpenCity.tower_d(w.global_position) < _ring_r:
			_ghosted[w] = true
			_leave_gold(w)
	if _ring_r > 700.0:
		_ring_running = false
		d.world.city.set_front(-1.0, 0.0)


## The person's last moment stays at the rail in gold; the person, grey now, folds down and ages.
func _leave_gold(w: Node3D) -> void:
	var rig: RiggedCharacter3D = (w as NPC3D).model if w is NPC3D else w as RiggedCharacter3D
	if rig == null:
		return
	var ghost := ColdOpenCast.afterimage(rig, d)
	ghost.name = str(w.name) + "_Gold"
	ghost.add_to_group("silence_gold")
	var mats := ColdOpenCast.dress(rig)
	ColdOpenCast.set_param(mats, "to_gold", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): ColdOpenCast.set_param(mats, "age", v), 0.0, 1.0, 4.0)
	var fall: String = ["Sit_Floor_Down", "Lie_Down", "Sit_Floor_Down"][randi() % 3]
	get_tree().create_timer(randf_range(0.1, 0.9)).timeout.connect(func():
		rig.play_action(fall, "Lie_Idle" if fall == "Lie_Down" else "Sit_Floor_Idle"))


func _cheer_loop(r: RiggedCharacter3D) -> void:
	r.play_action("Cheer")
	if not r.action_finished.is_connected(_on_cheer_done.bind(r)):
		r.action_finished.connect(_on_cheer_done.bind(r))


func _on_cheer_done(anim: String, r: RiggedCharacter3D) -> void:
	if anim == "Cheer" and not r.has_meta("fallen"):
		r.play_action("Cheer")


func _put_out(stone: Node3D) -> void:
	for n in stone.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			continue
		var tw := create_tween()
		tw.tween_property(m, "albedo_color", Color(0.02, 0.02, 0.03), 0.5)
		if mi.name == "Beam":
			tw.tween_callback(func(): mi.visible = false)


func _fall(r: RiggedCharacter3D) -> void:
	r.set_meta("fallen", true)
	r.play_action("Lie_Down", "Lie_Idle")
	var start := r.global_position
	var dest := L.TOWER + Vector3(0, 0.2, 30.0)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var p := start.lerp(dest, k)
		p.y = lerpf(start.y, dest.y, k * k)
		r.global_position = p
		r.rotation.x = -k * 5.0, 0.0, 1.0, 5.4)


func _flash() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.9, 0.95, 1.0)
	l.light_energy = 0.0
	l.omni_range = 260.0
	d.add_child(l)
	l.global_position = L.TOWER + Vector3(0, 6, 0)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 40.0, 0.12)
	tw.tween_property(l, "light_energy", 0.0, 1.4)
	tw.tween_callback(l.queue_free)


## The garlands come down off the rail in the rush — Talindir sits among them.
func _scatter_garlands() -> void:
	var k := SolariKit.new(d.world.mats, 404)
	for p in d.world.archive.fallen_garland_spots:
		var a := randf() * TAU
		var dir := Vector3(sin(a), 0, cos(a))
		ColdOpenProps.garland(k, p + Vector3(0, 0.08, 0) - dir * 1.1, p + Vector3(0, 0.08, 0) + dir * 1.1, -0.05, true, "garland_fallen")
	k.commit(d, "FallenGarlands")
