extends Node
## Plays Cold Open v2 from the desk to the hand-off to Part One, headless (docs/Cold_Open_v2_Proposal.md).
##
## It drives the night the way a player does: waits for Maelis, answers her, calls the Record down,
## fills the ink, reads the Song-glass, gets the key — then WALKS the player's own body up all three
## flights of the stair tower to the balcony (a stair that looks right can still stop a
## CharacterBody3D dead; CLAUDE.md), makes the one choice, opens the Record, and lets the cutscene run
## through the Silence to the title.
##
##   godot --headless --path godot res://tests/ColdOpenV2Test.tscn

const SCENE := "res://threed/coldopen/ColdOpen2.tscn"
const L = preload("res://threed/coldopen/ColdOpenLayout.gd")
const TIME_SCALE := 12.0
const SPEED := 3.0
const GRAVITY := 26.0

var _passed := 0
var _failed := 0
var _started := ""
var _changed_to := ""
var dir: ColdOpenDirector


func _ready() -> void:
	DialogueManager.dialogue_started.connect(func(id: String): _started = id)
	SceneManager.scene_changing.connect(func(p: String): _changed_to = p)
	GameState.reset()
	DirAccess.remove_absolute(GameState.SAVE_PATH)
	GameState.current_protagonist = "nobody"
	dir = (load(SCENE) as PackedScene).instantiate()
	add_child(dir)
	for i in 3:
		await get_tree().process_frame

	# --- the room, and the people in it -----------------------------------------------------------
	_check(GameState.current_protagonist == "talindir", "the Cold Open sets the protagonist to Talindir")
	_check(dir.stage == ColdOpenDirector.Stage.DESK, "the night opens at his desk")
	_check(dir.player.global_position.distance_to(L.SPAWN) < 0.6, "Talindir starts in the scriptorium")
	_check((dir.player.model as RiggedCharacter3D) != null, "he wears his generated model (CH-007)")
	var examinables := get_tree().get_nodes_in_group("interactable3d").size()
	_check(examinables >= 40, "every room rewards looking (%d examinable things and people)" % examinables)
	_check(dir.crowd.size() >= 8, "the balcony has its crowd (%d)" % dir.crowd.size())
	for w in dir.crowd:
		if w.examine_text == "" or not (w.model is RiggedCharacter3D):
			_check(false, "crowd member %s has a model and something to say" % w.display_name)
	_check(get_tree().get_nodes_in_group("song_held").size() >= 60,
		"the Song holds things up all over the Archive (%d lamps, drops, the lift, the quill)" % get_tree().get_nodes_in_group("song_held").size())
	_check(dir.world.city.echo_stones.size() >= 10, "the echo stones stand on the far hills")
	_check(dir.celebrant != null, "Sulvaine stands at the Tower's apex")

	# --- the quest is locked until Maelis gives it ------------------------------------------------
	_use("USE_TheSongGlass")
	await _talk_through()
	_check(not dir.got.glass, "nothing can be gathered before the duty is given")
	_check(dir.stair_door_body.collision_layer != 0, "the stair door starts locked")

	# --- Maelis comes in on her own -----------------------------------------------------------------
	Engine.time_scale = TIME_SCALE
	await _until(func(): return _started == "co2_maelis_duty", 60.0)
	_check(_started == "co2_maelis_duty", "Maelis comes in and gives him the duty unprompted")
	Engine.time_scale = 1.0
	await _talk_through()
	_check(dir.stage == ColdOpenDirector.Stage.GATHER, "the quest begins: the Record, the ink, the reading")
	_check(GameState.get_flag("CO2_LETTER_TAKEN", false), "Elorin's letter is in his satchel either way")

	# --- the three things ---------------------------------------------------------------------------
	_use("USE_TheBookLift")
	Engine.time_scale = TIME_SCALE
	await _wait(5.0)
	Engine.time_scale = 1.0
	_check(dir.world.archive.book_lift.position.y < 2.0, "the book-lift comes down to him")
	_use("USE_TheBookLift")
	_check(dir.got.record and dir.carried_record != null, "he takes the Record, and carries it")
	_use("USE_TheStarInkFont")
	await _talk_through()
	_check(dir.got.ink, "he fills the ink-horn")
	_use("USE_TheSongGlass")
	await _talk_through()
	_check(dir.got.glass, "he takes the Song-glass reading")
	_check(dir.letter_stage >= 2, "and the seal on the letter wakes")
	_check(dir.stage == ColdOpenDirector.Stage.KEY, "with all three, the key is next")

	# --- the key, and the stair ------------------------------------------------------------------
	dir.maelis.interact()
	await _talk_through()
	_check(GameState.get_flag("CO2_HAS_KEY", false), "Maelis gives him the key")
	_check(dir.stage == ColdOpenDirector.Stage.CLIMB, "the climb is next")
	_check(dir.stair_door_body.collision_layer == 0, "the stair door opens")

	var sw := (L.STAIR_Z1 - L.STAIR_Z0) * 0.5 - 0.2
	var lane_s := L.STAIR_Z0 + sw * 0.5
	var lane_n := L.STAIR_Z1 - sw * 0.5
	var r := L.FLIGHT_RISE
	var route := [
		Vector3(-40.0, 0, -5.5), Vector3(-33.0, 0, -5.8), Vector3(-28.8, 0, -5.8), Vector3(-28.4, 0, lane_s),
		Vector3(L.STAIR_HEAD_X + 0.6, r, lane_s), Vector3(-14.3, r, lane_s), Vector3(-14.3, r, lane_n),
		Vector3(L.STAIR_FOOT_X - 0.4, 2 * r, lane_n), Vector3(-28.6, 2 * r, lane_n), Vector3(-28.6, 2 * r, lane_s),
		Vector3(L.STAIR_HEAD_X + 0.6, 3 * r, lane_s), Vector3(-14.3, 3 * r, lane_s), Vector3(-14.3, 3 * r, -5.5),
		Vector3(-9.0, L.BAL_Y, -5.5), Vector3(-2.0, L.BAL_Y, -6.0),
	]
	var ok := await _walk(route)
	_check(ok, "a player-sized body walks from the cloister up all three flights and out onto the balcony")
	await _settle()
	_check(dir.stage == ColdOpenDirector.Stage.BALCONY, "reaching the balcony moves the night on")

	# --- the one choice --------------------------------------------------------------------------
	Engine.time_scale = TIME_SCALE
	await _until(func(): return _started == "coldopen_festivalgoer", 40.0)
	Engine.time_scale = 1.0
	_check(_started == "coldopen_festivalgoer", "the festival-goer comes to him and asks")
	await _talk_through(0)
	_check(GameState.get_flag("COLDOPEN_HONEST") == true, "telling the truth sets COLDOPEN_HONEST")

	# --- the Record opened at the rail; the ninth bell ---------------------------------------------
	dir.player.global_position = L.LECTERN + Vector3(0, 0, 1.0)
	_use("USE_TheLectern")
	await _talk_through(0)
	_check(GameState.get_flag("CO2_RECORD_OPEN", false), "he opens the Record at the lectern")
	_check(dir.stage == ColdOpenDirector.Stage.SILENCE, "and the Night of Silence begins")

	Engine.time_scale = 20.0
	var lamp: SongHeld = dir.world.archive.balcony_lamps[0]
	await _until(func(): return SilenceState.radius > 400.0, 200.0)
	_check(SilenceState.radius > 400.0, "the ring goes out across the whole city")
	await _wait(3.0)
	_check(lamp.fallen, "the Song lets go of the lamps: they fall")
	var ghosts := get_tree().get_nodes_in_group("silence_gold").size()
	_check(ghosts >= dir.crowd.size(), "the crowd leave their gold at the rail (%d afterimages)" % ghosts)
	var audio := ColdOpenAudio.of(dir)
	_check(audio != null and audio._silenced, "and every sound stops")
	await _until(func(): return dir.demo_over, 400.0)
	Engine.time_scale = 1.0
	if not dir.demo_over:
		print("  (the cutscene stopped at beat %d)" % dir.cutscene.step)
	_check(dir.demo_over, "the night ends on the demo's end card")
	_check(_changed_to == "", "and does not try to leave for Part One (not in the demo)")
	_check(GameState.get_flag("COLDOPEN_DONE") == true, "COLDOPEN_DONE written")
	_check(FileAccess.file_exists(GameState.SAVE_PATH), "autosave written at the end")

	print("\n%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _use(node_name: String) -> void:
	var n := dir.get_node_or_null(node_name) as Interactable3D
	if n == null:
		_check(false, "quest spot %s exists" % node_name)
		return
	n.interact()


## Answer whatever is open, taking choice `pick` each time, until it closes.
func _talk_through(pick := 0) -> void:
	var guard := 0
	while DialogueManager.is_active() and guard < 40:
		var node: Dictionary = DialogueManager._nodes.get(DialogueManager._current_node_id, {})
		if node.get("choices", []).is_empty():
			DialogueManager.advance()
		else:
			DialogueManager.choose(mini(pick, node["choices"].size() - 1))
		guard += 1
		await get_tree().process_frame
	await get_tree().process_frame


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()


## Steer the player's own CharacterBody3D through `pts` (Starfall's route-walk rules).
func _walk(pts: Array) -> bool:
	var body := dir.player
	body.set_physics_process(false)
	body.global_position = pts[0] + Vector3(0, 0.3, 0)
	body.velocity = Vector3.ZERO
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for i in range(1, pts.size()):
		var wp: Vector3 = pts[i]
		var best := INF
		var since := 0.0
		var steps := 0
		while true:
			var pos := body.global_position
			var flat := Vector3(wp.x - pos.x, 0, wp.z - pos.z)
			var dist := flat.length()
			if dist < 0.9 and absf(pos.y - wp.y) < 1.6:
				break
			if dist < best - 0.2:
				best = dist
				since = 0.0
			else:
				since += dt
			if since > 4.0 or pos.y < minf(wp.y, (pts[i - 1] as Vector3).y) - 3.0:
				print("  stuck/fell heading for waypoint %d %s at %s" % [i, str(wp), str(pos.snapped(Vector3.ONE * 0.1))])
				body.set_physics_process(true)
				return false
			var dv := flat / maxf(dist, 0.001)
			body.velocity.x = dv.x * SPEED
			body.velocity.z = dv.z * SPEED
			if body.is_on_floor():
				body.velocity.y = minf(body.velocity.y, 0.0)
			else:
				body.velocity.y -= GRAVITY * dt
			body.move_and_slide()
			steps += 1
			if steps % 20 == 0:
				await get_tree().physics_frame
	body.set_physics_process(true)
	return true


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		print("  [FAIL] ", label)
