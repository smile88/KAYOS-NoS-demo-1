@tool
extends Node3D
class_name RiggedCharacter3D
## A rigged, animated character model — one of the user's Meshy characters, rigged by
## tools/rig_meshy_character.py (catalogue: res://data/character_rigs.json).
##
## Drop-in for CharacterModel3D: the same `face_dir` / `set_moving` calls drive it, so NPC3D,
## Wanderer3D and the director's crowd code work unchanged. It adds `set_talking` (NPC3D turns that
## on for the length of a conversation) and `play_action` for one-off moments — sitting, lying down,
## reaching for something, cheering.
##
## Every rig carries the same animation set:
##   Idle, Talk, Walking_A/B/C, Walking_Backwards, Running_A, Interact, Use_Item, PickUp, Cheer,
##   Sit_Chair_Down/Idle/StandUp, Sit_Floor_Down/Idle/StandUp, Lie_Down/Idle/StandUp
## The rig is built at the character's canon height (Asset Bible: elf/human ~2.1 m, orc ~2.3 m) with
## its origin at its feet, so it sits at scale 1 in a 1-unit = 1-metre world.

signal action_finished(anim: String)

## Path to a rigged .glb (res://assets/meshy/rigged/<name>.glb).
@export_file("*.glb") var rig_path := "" : set = _set_rig_path
## Which walk this character uses; the three KayKit walks differ in gait.
@export_enum("Walking_A", "Walking_B", "Walking_C") var walk_anim := "Walking_A"
## Metres per second the walk cycle was authored for; playback is scaled to the real speed.
@export var walk_cycle_speed := 1.25
## Seconds to blend between animations.
@export var blend := 0.22

## Kept so code written for CharacterModel3D keeps working (NPC3D positions its nameplate from it).
var character_scale := Vector3.ONE
var height_m := 2.1

var _model: Node3D
var _player: AnimationPlayer
var _moving := false
var _talking := false
var _move_speed := 0.0
var _action := ""            # a one-off animation currently playing, or ""
var _held := ""              # a looping action to return to (e.g. Sit_Chair_Idle) instead of Idle


func _ready() -> void:
	if _model == null and rig_path != "":
		_load()


func _set_rig_path(v: String) -> void:
	rig_path = v
	if is_inside_tree():
		_load()


func _load() -> void:
	if _model:
		_model.queue_free()
		_model = null
		_player = null
	var ps := load(rig_path) as PackedScene
	if ps == null:
		push_warning("RiggedCharacter3D: cannot load %s" % rig_path)
		return
	_model = ps.instantiate() as Node3D
	_model.name = "Rig"
	add_child(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0] as AnimationPlayer
		_player.animation_finished.connect(_on_finished)
		for anim_name in _player.get_animation_list():
			var a := _player.get_animation(anim_name)
			if _loops(str(anim_name)):
				a.loop_mode = Animation.LOOP_LINEAR
	height_m = _measure_height()
	# NPC3D puts its nameplate at 2.15 * character_scale.y and the talk prompt 0.28 m under that;
	# both have to clear the top of the head
	character_scale = Vector3.ONE * (height_m + 0.5) / 2.15
	_update()


## Looping animations are the states; everything else is a one-off action.
static func _loops(anim: String) -> bool:
	return anim == "Idle" or anim == "Talk" or anim.begins_with("Walking") \
			or anim.begins_with("Running") or anim.ends_with("_Idle")


func _measure_height() -> float:
	var box := AABB()
	var first := true
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab := mi.transform * mi.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
	return box.size.y if not first else 2.1


# --- the CharacterModel3D interface -------------------------------------------

## Face a world-space ground direction. The rig's front is +Z at yaw 0, like CharacterModel3D.
func face_dir(world_dir: Vector3) -> void:
	var d := Vector3(world_dir.x, 0, world_dir.z)
	if d.length() < 0.001:
		return
	rotation.y = atan2(d.x, d.z)


func set_moving(m: bool, speed := -1.0) -> void:
	_moving = m
	if speed >= 0.0:
		_move_speed = speed
	if m:
		_cancel_action()
	_update()


# CharacterModel3D compatibility: palette and race do not apply to a textured model.
func apply_faction(_f) -> void:
	pass


func apply_race(_r) -> void:
	pass


# --- conversation and actions ------------------------------------------------

func set_talking(t: bool) -> void:
	_talking = t
	_update()


## Play a one-off animation (Interact, Cheer, PickUp, Sit_Chair_Down …). If `then_hold` names a
## looping animation (Sit_Chair_Idle) the character stays in it afterwards instead of returning to
## Idle, until `release_hold()` — which plays `release_anim` (Sit_Chair_StandUp) if given.
func play_action(anim: String, then_hold := "") -> void:
	if _player == null or not _player.has_animation(anim):
		return
	_action = anim
	_held = then_hold
	_player.play(anim, blend)


func release_hold(release_anim := "") -> void:
	_held = ""
	if release_anim != "" and _player and _player.has_animation(release_anim):
		_action = release_anim
		_player.play(release_anim, blend)
	else:
		_update()


func current_animation() -> String:
	return _player.current_animation if _player else ""


func _cancel_action() -> void:
	_action = ""
	_held = ""


func _on_finished(anim: StringName) -> void:
	if str(anim) != _action:
		return
	_action = ""
	action_finished.emit(str(anim))
	_update()


func _update() -> void:
	if _player == null or _action != "":
		return
	var want := "Idle"
	var speed_scale := 1.0
	if _moving:
		want = walk_anim
		if _move_speed > 0.0:
			if _move_speed > walk_cycle_speed * 2.2 and _player.has_animation("Running_A"):
				want = "Running_A"
				speed_scale = clampf(_move_speed / (walk_cycle_speed * 3.0), 0.6, 1.6)
			else:
				speed_scale = clampf(_move_speed / walk_cycle_speed, 0.5, 1.8)
	elif _held != "":
		want = _held
	elif _talking:
		want = "Talk"
	if not _player.has_animation(want):
		want = "Idle"
	if _player.current_animation != want:
		_player.play(want, blend)
	_player.speed_scale = speed_scale
