extends Node
## The phone controls, driven by real touch events (run with KAYOS_TOUCH=1 so they are built headless):
##   KAYOS_TOUCH=1 $G --headless --path godot res://tests/TouchControlsTest.tscn
const SCENE := preload("res://threed/coldopen/ColdOpen2.tscn")
var dir: Node3D
var passed := 0
var failed := 0


func _ready() -> void:
	# headless has a zero-size window, which scales every event position; give it a phone's screen
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.size = Vector2i(844, 390)
	dir = SCENE.instantiate()
	dir.set("skip_opening", true)
	add_child(dir)
	await _frames(10)
	var tc := dir.get("touch") as TouchControls
	_check(tc != null, "the phone controls are built when a touch screen is present")
	if tc == null:
		_done()
		return
	_check(dir.ui.touch, "and the prompt drops the F key")
	var size := tc._screen()
	var player := dir.player as Node3D
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig3D

	# left thumb: walk (back, away from the desk he starts at)
	var p0 := player.global_position
	var at := Vector2(120, size.y - 110)
	_touch(0, at, true)
	for i in 6:
		_drag(0, at + Vector2(0, 12 * (i + 1)), Vector2(0, 12))
	await _frames(45)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.9, "the joystick drives the move actions")
	_check(Input.is_action_pressed("run"), "pushed to the rim, he hurries")
	_touch(0, at + Vector2(0, 72), false)
	await _frames(20)
	var moved := player.global_position.distance_to(p0)
	_check(moved > 1.0, "the left thumb walks him (%.1f m)" % moved)
	_check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "and lifting it stops him")

	# right thumb: look
	var yaw0 := rig.move_yaw
	var r := Vector2(size.x * 0.7, size.y * 0.45)
	_touch(1, r, true)
	for i in 8:
		_drag(1, r + Vector2(-15 * (i + 1), 0), Vector2(-15, 0))
	_touch(1, r + Vector2(-120, 0), false)
	await _frames(5)
	_check(absf(rig.move_yaw - yaw0) > 0.5, "the right thumb turns the camera")

	# pinch
	rig.distance = rig.max_distance
	var d0 := rig.distance
	_touch(2, r + Vector2(-40, 0), true)
	_touch(3, r + Vector2(40, 0), true)
	for i in 6:
		_drag(3, r + Vector2(40 + 15 * (i + 1), 0), Vector2(15, 0))
	await _frames(3)
	_touch(2, r, false)
	_touch(3, r, false)
	_check(rig.distance < d0, "spreading two fingers zooms in (%.1f -> %.1f m)" % [d0, rig.distance])

	# the eye
	var uc := tc._use_center()
	var ec := tc._eye_center()
	_touch(4, ec, true)
	_touch(4, ec, false)
	await _frames(3)
	_check(rig.is_first_person(), "the eye button goes to first person")
	_touch(4, ec, true)
	_touch(4, ec, false)
	await _frames(3)
	_check(not rig.is_first_person(), "and back")

	# USE on the letter at his desk
	player.global_position = p0
	await _frames(30)
	_check(dir.ui.prompt_active, "standing at his desk, there is something to use")
	_touch(5, uc, true)
	await _frames(2)
	_touch(5, uc, false)
	await _frames(5)
	_check(DialogueManager.is_active(), "USE opens it")
	_touch(6, Vector2(size.x * 0.5, size.y * 0.75), true)
	_touch(6, Vector2(size.x * 0.5, size.y * 0.75), false)
	await _frames(3)
	_check(dir.dialogue_ui.get("_is_typing") == false, "a tap on the text finishes the line")
	_done()


func _touch(i: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = down
	Input.parse_input_event(e)


func _drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("  [PASS] " + what)
	else:
		failed += 1
		print("  [FAIL] " + what)


func _done() -> void:
	print("==== Touch controls: %d passed, %d failed ====" % [passed, failed])
	get_tree().quit(1 if failed else 0)
