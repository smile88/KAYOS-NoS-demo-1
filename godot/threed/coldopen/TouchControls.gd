extends CanvasLayer
class_name TouchControls
## Phone controls for the web demo. Left thumb: a floating joystick that appears where it lands (push
## it to the rim to hurry). Right thumb: drag to look, pinch to zoom. USE examines and talks
## (it is the F key); the eye button toggles first person (the V key). In a conversation a tap on the
## text finishes the line, and choices are tapped directly.
##
## Everything is multi-touch — each finger is tracked by its index — so you can walk and look at once.
## The layer hides itself during cutscenes (the player's input is switched off) and conversations.

const GOLD := Color(0.96, 0.82, 0.48)
const IVORY := Color(0.95, 0.93, 0.88)
const JOY_RADIUS := 64.0          # knob travel, in canvas units
const RUN_AT := 0.92              # pushed this far to the rim = hurry
const LOOK_SENS := 0.010          # radians per canvas unit of drag
const USE_RADIUS := 46.0
const EYE_RADIUS := 30.0

var director: Node3D
var _pad: Control
var _joy_index := -1
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look := {}                   # finger index -> last position
var _pinch_dist := 0.0
var _use_index := -1
var _eye_index := -1
var _font: Font


## True on a touch screen, or when forced for testing (KAYOS_TOUCH=1, or ?touch=1 on the web page).
static func wanted() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.get_environment("KAYOS_TOUCH") == "1":
		return true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		return typeof(q) == TYPE_STRING and (q as String).contains("touch=1")
	return false


func _ready() -> void:
	layer = 8
	if not InputMap.has_action("run"):
		InputMap.add_action("run")
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	_font = ThemeDB.fallback_font


# --- state --------------------------------------------------------------------------------------
func _player() -> Node:
	return director.get("player") if director else null


## Walking and looking are live only while Talindir is the player's to move.
func _free() -> bool:
	var p := _player()
	return p != null and p.is_processing_unhandled_input() and p.is_physics_processing() \
		and not DialogueManager.is_active()


func _in_dialogue() -> bool:
	return DialogueManager.is_active()


func _prompt_live() -> bool:
	var ui = director.get("ui") if director else null
	return ui != null and ui.get("prompt_active") == true


func _screen() -> Vector2:
	return _pad.get_viewport_rect().size


func _use_center() -> Vector2:
	var s := _screen()
	return Vector2(s.x - 92.0, s.y - 96.0)


func _eye_center() -> Vector2:
	var s := _screen()
	return Vector2(s.x - 176.0, s.y - 58.0)


func _rig() -> CameraRig3D:
	return get_tree().get_first_node_in_group("camera_rig") as CameraRig3D


# --- input --------------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)


func _touch(e: InputEventScreenTouch) -> void:
	var pos := _pad.get_global_transform_with_canvas().affine_inverse() * e.position
	if e.pressed:
		if _in_dialogue():
			# a tap finishes a line that is still typing; once it is out, the choices take the taps
			var dui = director.get("dialogue_ui") if director else null
			if dui != null and dui.get("_is_typing") == true:
				_send_action("interact", true)
				_send_action("interact", false)
			return
		if _free() and pos.distance_to(_use_center()) < USE_RADIUS + 14.0:
			_use_index = e.index
			_send_action("interact", true)
			_pad.queue_redraw()
			return
		if not _free():
			return
		if pos.distance_to(_eye_center()) < EYE_RADIUS + 12.0:
			_eye_index = e.index
			_send_action("toggle_view", true)
			_send_action("toggle_view", false)
			_pad.queue_redraw()
			return
		if pos.x < _screen().x * 0.45 and _joy_index == -1:
			_joy_index = e.index
			_joy_origin = pos
			_joy_vec = Vector2.ZERO
		else:
			_look[e.index] = pos
			_pinch_dist = _pinch_distance()
		_pad.queue_redraw()
	else:
		if e.index == _use_index:
			_use_index = -1
			_send_action("interact", false)
		elif e.index == _eye_index:
			_eye_index = -1
		elif e.index == _joy_index:
			_joy_index = -1
			_set_move(Vector2.ZERO)
		else:
			_look.erase(e.index)
			_pinch_dist = _pinch_distance()
		_pad.queue_redraw()


func _drag(e: InputEventScreenDrag) -> void:
	var pos := _pad.get_global_transform_with_canvas().affine_inverse() * e.position
	if e.index == _joy_index:
		var v := (pos - _joy_origin) / JOY_RADIUS
		if v.length() > 1.0:
			# the base follows a thumb that slides past the rim, so it never gets "stuck"
			_joy_origin = pos - v.normalized() * JOY_RADIUS
			v = v.normalized()
		_set_move(v if _free() else Vector2.ZERO)
		_pad.queue_redraw()
		return
	if not _look.has(e.index):
		return
	var last: Vector2 = _look[e.index]
	_look[e.index] = pos
	var rig := _rig()
	if rig == null or not _free():
		return
	if _look.size() >= 2:
		var d := _pinch_distance()
		if _pinch_dist > 1.0 and d > 1.0:
			rig.touch_zoom(d / _pinch_dist)
		_pinch_dist = d
	else:
		rig.touch_look((pos - last) * LOOK_SENS)


func _pinch_distance() -> float:
	if _look.size() < 2:
		return 0.0
	var pts: Array = _look.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _set_move(v: Vector2) -> void:
	_joy_vec = v
	_axis("move_left", "move_right", v.x)
	_axis("move_up", "move_down", v.y)
	if v.length() >= RUN_AT:
		Input.action_press("run")
	else:
		Input.action_release("run")


func _axis(neg: String, pos: String, x: float) -> void:
	if x < -0.05:
		Input.action_press(neg, -x)
		Input.action_release(pos)
	elif x > 0.05:
		Input.action_press(pos, x)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


## Feed an action through the input pipeline as an event, so the handlers that read events
## (Player3D's interact, the dialogue's advance, the camera's view toggle) all see it.
func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _process(_delta: float) -> void:
	# a cutscene or a conversation took over mid-gesture: let go of everything
	if not _free() and (_joy_index != -1 or not _look.is_empty()):
		_joy_index = -1
		_look.clear()
		_set_move(Vector2.ZERO)
	_pad.queue_redraw()


# --- drawing ------------------------------------------------------------------------------------
func _draw_pad() -> void:
	if not _free():
		return
	# USE
	var uc := _use_center()
	var live := _prompt_live()
	var pressed := _use_index != -1
	var a := 0.95 if live else 0.45
	_pad.draw_circle(uc, USE_RADIUS, Color(0.06, 0.07, 0.16, 0.55 if not pressed else 0.8))
	_pad.draw_arc(uc, USE_RADIUS, 0, TAU, 48, Color(GOLD, a), 2.5 if live else 1.5, true)
	_label(uc, "USE", Color(GOLD if live else IVORY, a), 17)
	# the eye: first person
	var ec := _eye_center()
	var rig := _rig()
	var fp := rig != null and rig.is_first_person()
	_pad.draw_circle(ec, EYE_RADIUS, Color(0.06, 0.07, 0.16, 0.5))
	_pad.draw_arc(ec, EYE_RADIUS, 0, TAU, 40, Color(IVORY, 0.8 if fp else 0.45), 1.5, true)
	_eye_glyph(ec, Color(GOLD if fp else IVORY, 0.85))
	# joystick
	if _joy_index != -1:
		_pad.draw_circle(_joy_origin, JOY_RADIUS + 12.0, Color(0.06, 0.07, 0.16, 0.35))
		_pad.draw_arc(_joy_origin, JOY_RADIUS + 12.0, 0, TAU, 48, Color(IVORY, 0.35), 1.5, true)
		var knob := _joy_origin + _joy_vec * JOY_RADIUS
		var hurry := _joy_vec.length() >= RUN_AT
		_pad.draw_circle(knob, 26.0, Color(GOLD, 0.75) if hurry else Color(IVORY, 0.55))
	else:
		# a quiet hint of where the left thumb goes
		var s := _screen()
		var hint := Vector2(118.0, s.y - 110.0)
		_pad.draw_arc(hint, JOY_RADIUS + 12.0, 0, TAU, 48, Color(IVORY, 0.18), 1.5, true)
		_pad.draw_circle(hint, 22.0, Color(IVORY, 0.14))


func _label(c: Vector2, text: String, col: Color, size: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	_pad.draw_string(_font, c + Vector2(-w * 0.5, size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _eye_glyph(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0 * PI
		pts.append(c + Vector2(-cos(t) * 15.0, -sin(t) * 8.0))
	for i in range(1, 16):
		var t := float(i) / 16.0 * PI
		pts.append(c + Vector2(cos(t) * 15.0, sin(t) * 8.0))
	pts.append(pts[0])
	_pad.draw_polyline(pts, col, 1.6, true)
	_pad.draw_circle(c, 4.0, col)
