@tool
extends NPC3D
class_name Wanderer3D
## An NPC with somewhere to be — HD-2D twin of actors/Wanderer.gd. Drifts around `roam_rect` on the
## ground plane, pausing, so the balcony reads as populated rather than staged. Deliberately dumb:
## no pathing, no avoidance. Freezes during dialogue and when the director calls freeze(); at the
## Silence the whole crowd rush_to()s the rail at once — the point of having a crowd.

## Roam area on the XZ ground: Rect2(minX, minZ, width, depth). Zero size = stand still.
@export var roam_rect: Rect2 = Rect2()
@export var speed := 1.1
@export var pause_min := 1.2
@export var pause_max := 5.0

var _target := Vector3.ZERO
var _pause_left := 0.0
var _frozen := false


func _ready() -> void:
	super._ready()
	add_to_group("wanderer3d")
	_target = global_position
	_pause_left = randf_range(0.0, pause_max)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return   # never roam or touch DialogueManager while just previewing the scene
	if _frozen or roam_rect.size == Vector2.ZERO:
		return
	if DialogueManager.is_active():
		stop_walking()
		return

	if _pause_left > 0.0:
		_pause_left -= delta
		stop_walking()
		if _pause_left <= 0.0:
			_target = Vector3(
				randf_range(roam_rect.position.x, roam_rect.end.x),
				global_position.y,
				randf_range(roam_rect.position.y, roam_rect.end.y))
		return

	var to := _target - global_position
	to.y = 0.0
	if to.length() <= 0.15:
		_pause_left = randf_range(pause_min, pause_max)
		stop_walking()
		return
	var dir := to.normalized()
	walk_toward(dir, speed)
	global_position += dir * speed * delta


## Stop where you are. The director uses this the instant the Song stops.
func freeze() -> void:
	_frozen = true
	stop_walking()


## Everyone turns and moves to the rail to look. Spread wide along the balustrade rather than
## converging on one point, so it reads as a crowd lining the rail, not a scrum.
func rush_to(point: Vector3, over: float) -> void:
	_frozen = true
	var dest := Vector3(clampf(point.x + randf_range(-7.0, 7.0), -8.5, 8.5), global_position.y, point.z + randf_range(0.0, 0.6))
	walk_toward(dest - global_position)
	var tw := create_tween()
	tw.tween_property(self, "global_position", dest, over).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): stop_walking())
