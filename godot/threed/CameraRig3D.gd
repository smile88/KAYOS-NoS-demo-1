extends Camera3D
class_name CameraRig3D
## Camera for the HD-2D 3D game. Three ways to look:
##
##  • ORBIT (default): an iso-ish third-person camera that swings 360° around the target. Right-drag
##    orbits (+tilts), Q/E orbit from the keyboard, wheel zooms. Movement is relative to this frame.
##  • FREE-LOOK (hold `free_look` in ORBIT): swing the camera around the target WITHOUT changing where
##    the character walks or faces — the movement frame is frozen while you look. Release and the
##    camera swings back behind the character.
##  • FIRST_PERSON (toggle `toggle_view`): Daggerfall-style. Camera sits at eye height, mouse looks
##    around freely, WASD moves in the look direction, the player's own billboard is hidden.
##
## Sits in group "camera_rig" so actors read forward_xz()/right_xz() for their movement/facing —
## those return the MOVEMENT frame (from move_yaw in orbit, from the camera in first person), never
## the free-look offset, so looking around never disturbs the controls.

enum Mode { ORBIT, FIRST_PERSON }

@export var target_path: NodePath
@export var distance := 11.0
@export var min_distance := 4.0
@export var max_distance := 20.0
@export var pitch_deg := 48.0            # orbit elevation; wide range so you can look up at the Tower
@export var min_pitch := 6.0             # near-horizontal — camera drops low and angles up
@export var max_pitch := 85.0            # near top-down
@export var height := 1.4                # orbit look-at height on the target
@export var eye_height := 1.6            # first-person eye height
@export var follow_lerp := 8.0
@export var key_orbit_speed := 1.6
@export var drag_sensitivity := 0.008
@export var mouse_look_sensitivity := 0.004
@export var floor_min_y := 0.3           # camera never dips below this (anti floor-clip)

var mode: int = Mode.ORBIT
var move_yaw := 0.0                       # the frame WASD is relative to (orbit)
var _look_yaw := 0.0                      # free-look camera offset from move_yaw
var _look_pitch := 0.0
var _free_look := false
var fp_yaw := 0.0                         # first-person look
var fp_pitch := 0.0

var _target: Node3D


func _ready() -> void:
	add_to_group("camera_rig")
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		_place()


func is_first_person() -> bool:
	return mode == Mode.FIRST_PERSON


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view"):
		_toggle_view()
		return

	if mode == Mode.FIRST_PERSON:
		if event is InputEventMouseMotion:
			fp_yaw -= event.relative.x * mouse_look_sensitivity
			fp_pitch = clampf(fp_pitch - event.relative.y * mouse_look_sensitivity, -1.45, 1.45)
		return

	# ORBIT
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if _free_look:
			_look_yaw -= event.relative.x * drag_sensitivity
			_look_pitch = clampf(_look_pitch + event.relative.y * drag_sensitivity * 40.0, -40.0, 40.0)
		else:
			move_yaw -= event.relative.x * drag_sensitivity
			pitch_deg = clampf(pitch_deg + event.relative.y * drag_sensitivity * 40.0, min_pitch, max_pitch)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clampf(distance - 1.0, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clampf(distance + 1.0, min_distance, max_distance)


## Touch look (TouchControls): `rel` is already in radians. Orbits in third person, looks in first.
func touch_look(rel: Vector2) -> void:
	if mode == Mode.FIRST_PERSON:
		fp_yaw -= rel.x
		fp_pitch = clampf(fp_pitch - rel.y, -1.45, 1.45)
	else:
		move_yaw -= rel.x
		pitch_deg = clampf(pitch_deg + rad_to_deg(rel.y) * 0.6, min_pitch, max_pitch)


## Pinch zoom: `factor` > 1 when the fingers spread (move in).
func touch_zoom(factor: float) -> void:
	distance = clampf(distance / factor, min_distance, max_distance)


func _toggle_view() -> void:
	if mode == Mode.ORBIT:
		mode = Mode.FIRST_PERSON
		fp_yaw = move_yaw + _look_yaw       # continue looking the same way
		fp_pitch = 0.0
		if not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		mode = Mode.ORBIT
		move_yaw = fp_yaw                    # resume orbit behind where you were facing
		_look_yaw = 0.0
		_look_pitch = 0.0
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- update ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _target == null:
		return

	if mode == Mode.ORBIT:
		_free_look = Input.is_action_pressed("free_look")
		if not _free_look:
			# swing the camera back behind the movement frame
			_look_yaw = lerpf(_look_yaw, 0.0, clampf(follow_lerp * delta, 0.0, 1.0))
			_look_pitch = lerpf(_look_pitch, 0.0, clampf(follow_lerp * delta, 0.0, 1.0))
			if Input.is_action_pressed("cam_left"):
				move_yaw += key_orbit_speed * delta
			if Input.is_action_pressed("cam_right"):
				move_yaw -= key_orbit_speed * delta
		var want := _orbit_position()
		global_position = global_position.lerp(want, clampf(follow_lerp * delta, 0.0, 1.0))
		look_at(_target.global_position + Vector3.UP * height, Vector3.UP)
	else:
		# FIRST_PERSON: sit at the eye, aim from fp_yaw/fp_pitch
		global_position = _target.global_position + Vector3.UP * eye_height
		var basis := Basis.from_euler(Vector3(fp_pitch, fp_yaw, 0.0))
		global_transform.basis = basis


func _place() -> void:
	if mode == Mode.ORBIT:
		global_position = _orbit_position()
		look_at(_target.global_position + Vector3.UP * height, Vector3.UP)
	else:
		global_position = _target.global_position + Vector3.UP * eye_height


## Desired orbit position, including the free-look offset, pulled in so it never crosses the floor or
## world geometry (a manual spring-arm — the rig is the Camera3D, so no SpringArm3D node).
func _orbit_position() -> Vector3:
	var yaw := move_yaw + _look_yaw
	var p := deg_to_rad(pitch_deg + _look_pitch)
	var offset := Vector3(cos(p) * sin(yaw), sin(p), cos(p) * cos(yaw)) * distance
	var pivot := _target.global_position + Vector3.UP * height
	var want := pivot + offset

	# Pull in on collision with the world so we don't clip through walls/floor/props.
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(pivot, want)
		q.exclude = [_target.get_rid()] if _target is CollisionObject3D else []
		var hit := space.intersect_ray(q)
		if hit:
			want = (hit.position as Vector3)
			want += (pivot - want).normalized() * 0.2   # a little off the surface
	want.y = maxf(want.y, floor_min_y)
	return want


# --- movement frame (never the free-look offset) -----------------------------

## Ground forward (into the screen, away from the camera) that WASD is relative to.
func forward_xz() -> Vector3:
	if mode == Mode.FIRST_PERSON:
		var f := -global_transform.basis.z
		f.y = 0.0
		return f.normalized()
	return Vector3(-sin(move_yaw), 0.0, -cos(move_yaw))


func right_xz() -> Vector3:
	var f := forward_xz()
	return Vector3(-f.z, 0.0, f.x)   # f rotated +90° about Y = screen-right for a Y-up camera
