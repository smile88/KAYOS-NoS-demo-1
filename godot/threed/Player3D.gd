@tool
extends CharacterBody3D
class_name Player3D
## 3D-model player for the Cold Open: a CharacterBody3D whose body is a CharacterModel3D (a low-poly
## hooded figure) that turns to face its movement direction. Movement is camera-relative — WASD pushes
## along the orbiting camera's ground axes — and the model simply rotates to its heading, so there is
## no billboard-facing-camera and no quantised diagonal walk. In first person the model is hidden
## (you're inside it).

@export var speed := 4.0
## How close (world m, on the ground plane) the player must be to examine an Interactable3D.
@export var interact_reach := 1.8
## And no more than this far above or below (m), so a stair or a balcony never reaches through a floor.
@export var interact_height := 2.6
## Robe colour of the player figure. The Cold Open dresses Talindir in a cool grey-blue.
@export var robe_color := Color(0.36, 0.40, 0.52)
## The rigged character the player wears (res://assets/characters/lowpoly/, built by
## tools/gen_characters.py). Empty = the primitive hooded CharacterModel3D in robe_color.
@export_file("*.glb") var model_rig := ""
## Off = the Cold Open's flat-plane movement (Y never changes). On = a real terraced world: the body
## falls, stands on floors and walks up/down ramps (Starfall). Kept opt-in so the Cold Open is unchanged.
@export var gravity_enabled := false
@export var gravity := 26.0
## Upward launch speed for a jump (only when gravity_enabled). ~1.2 m hop at the default gravity.
@export var jump_velocity := 8.0
## Hold to move faster — handy for crossing a large zone. Uses the "run" action if present, else Shift.
@export var run_multiplier := 1.9

## --- feel (gravity path only; the Cold Open's flat movement ignores all of these) --------------------
## Ground movement eases in/out instead of snapping, so starting, stopping and changing direction read
## as weight rather than an on/off switch. m/s² toward the target speed / back to rest.
@export var acceleration := 60.0
@export var friction := 70.0
## In the air you keep most of your momentum — only gentle steering — so jumps arc instead of pivoting.
@export var air_acceleration := 16.0
## Grace window (s) after walking off an edge in which a jump still fires — forgiving, standard platformer feel.
@export var coyote_time := 0.10
## Press jump this many seconds before landing and it still fires the instant you touch down.
@export var jump_buffer_time := 0.10
## Below this world-Y the body is returned to the last solid ground it stood on — the star-lake "Mirror"
## is sky, not water, and will not hold you (the causeway is the crossing). -1000 = off (the Cold Open).
@export var fall_limit := -1000.0

## Emitted when the body drops past `fall_limit` and is returned to safe ground (for zone flavour text).
signal fell

## CharacterModel3D (primitive) or RiggedCharacter3D; both answer face_dir / set_moving.
var model: Node3D
var _rig: CameraRig3D
var _coyote := 0.0
var _jump_buffer := 0.0
var _last_safe := Vector3.ZERO


func _ready() -> void:
	# A script hot-reload while the scene is open in the editor re-fires _ready() on the same node
	# without a fresh scene load — drop any previous preview model first so it doesn't double up.
	var old := get_node_or_null("Model")
	if old:
		old.queue_free()
	if model_rig != "":
		var r := RiggedCharacter3D.new()
		r.rig_path = model_rig
		model = r
	else:
		var c := CharacterModel3D.new()
		c.robe_color = robe_color
		model = c
	model.name = "Model"
	add_child(model)
	if Engine.is_editor_hint():
		return   # just show the figure standing at its spawn point; no movement/physics/groups
	add_to_group("player")               # so SceneManager can place us on a zone handoff
	_last_safe = global_position
	if gravity_enabled:
		floor_snap_length = 0.6          # stay glued descending ramps/steps
		floor_max_angle = deg_to_rad(50) # our terrace ramps sit well under this


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("interact") and not DialogueManager.is_active():
		_try_interact()


## Examine the nearest Interactable3D within reach (ground-plane distance) — a group scan, plenty for
## the handful of props on the balcony.
func _try_interact() -> void:
	var nearest: Interactable3D = null
	var best := interact_reach
	var here := global_position
	for node in get_tree().get_nodes_in_group("interactable3d"):
		var it := node as Interactable3D
		if it == null:
			continue
		var d := Vector2(it.global_position.x - here.x, it.global_position.z - here.z).length()
		if absf(it.global_position.y - here.y) > interact_height:
			continue   # not something on another floor directly above or below
		if d <= best:
			best = d
			nearest = it
	if nearest:
		nearest.interact()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _rig == null:
		_rig = get_tree().get_first_node_in_group("camera_rig") as CameraRig3D

	# In first person you're inside your own body — hide the model so it doesn't fill the view.
	if _rig:
		model.visible = not _rig.is_first_person()

	if DialogueManager.is_active():
		velocity.x = 0.0
		velocity.z = 0.0
		if gravity_enabled and not is_on_floor():
			velocity.y -= gravity * _delta
		model.set_moving(false)
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := Vector3.ZERO
	if _rig and input != Vector2.ZERO:
		# input.y is +1 when pressing "down" (toward the player on screen), so move along -forward.
		move = _rig.right_xz() * input.x - _rig.forward_xz() * input.y
		move = move.normalized()

	if gravity_enabled:
		var spd := speed
		if Input.is_key_pressed(KEY_SHIFT) or (InputMap.has_action("run") and Input.is_action_pressed("run")):
			spd *= run_multiplier
		var on_floor := is_on_floor()

		# Coyote grace and jump buffering, so a jump feels responsive at the exact edges.
		_coyote = coyote_time if on_floor else maxf(0.0, _coyote - _delta)
		if InputMap.has_action("jump") and Input.is_action_just_pressed("jump"):
			_jump_buffer = jump_buffer_time
		else:
			_jump_buffer = maxf(0.0, _jump_buffer - _delta)

		# Ease the ground velocity toward the desired heading (accelerate) or toward rest (friction),
		# with only light steering in the air — momentum carries, so movement has weight.
		var target := Vector3(move.x, 0.0, move.z) * spd
		var rate: float
		if move == Vector3.ZERO:
			rate = friction if on_floor else air_acceleration
		else:
			rate = acceleration if on_floor else air_acceleration
		var horiz := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * _delta)
		velocity.x = horiz.x
		velocity.z = horiz.z

		if _coyote > 0.0 and _jump_buffer > 0.0:
			velocity.y = jump_velocity
			_coyote = 0.0
			_jump_buffer = 0.0
		elif on_floor:
			velocity.y = -1.0            # small downward bias so floor snapping holds
		else:
			velocity.y -= gravity * _delta
		move_and_slide()

		# Remember the last solid ground above the lake, and fish the player back out of the void.
		if is_on_floor() and global_position.y > -0.5:
			_last_safe = global_position
		if global_position.y < fall_limit:
			_respawn()
	else:
		velocity = move * speed          # Cold Open: flat-plane movement, no gravity
		move_and_slide()

	if move != Vector3.ZERO:
		model.face_dir(move)
		if model is RiggedCharacter3D:
			# the walk cycle is scaled to the real ground speed, and a run takes over when running
			(model as RiggedCharacter3D).set_moving(true, Vector2(velocity.x, velocity.z).length())
		else:
			model.set_moving(true)
	else:
		model.set_moving(false)


## Return the body to the last solid ground it stood on (the star-lake will not hold you). Zero the
## velocity so it doesn't carry the fall's momentum through the respawn.
func _respawn() -> void:
	global_position = _last_safe + Vector3(0.0, 0.4, 0.0)
	velocity = Vector3.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	fell.emit()
