extends Node3D
class_name SongHeld
## Anything in Astra'Thalas that the Song holds up or lights: the floating lamps, the book-lift, the
## self-writing quill, the fountain's hanging water. While the Song is whole it bobs gently where it
## is and its light burns. When the Silence ring reaches it (the director's `silence_radius`), it is
## let go: the light gutters and dies, and the thing falls to `rest_y` and lies there.
##
## This is the main device that makes the Silence understandable (docs/Cold_Open_v2_Proposal.md): the
## player has been using these for twenty minutes, and the cutscene takes each one away.

## World height it falls to.
@export var rest_y := 0.0
@export var bob := 0.12
@export var bob_speed := 0.8
## Spin while it falls (rad/s).
@export var tumble := 2.0
## Seconds it flickers before it goes (the Song does not snap off; it is pulled).
@export var gutter := 0.5

var lights: Array[Light3D] = []
var glow_mats: Array[ShaderMaterial] = []
var fallen := false
var _base_y := 0.0
var _phase := 0.0
var _falling := false
var _vel := 0.0
var _t := 0.0
var _energy: Array[float] = []
var _glow0: Array[float] = []


func _ready() -> void:
	add_to_group("song_held")
	_base_y = position.y
	_phase = randf() * TAU


func register_light(l: Light3D) -> void:
	lights.append(l)
	_energy.append(l.light_energy)


func register_glow(m: ShaderMaterial) -> void:
	glow_mats.append(m)
	_glow0.append(float(m.get_shader_parameter("emission_energy")))


## Has the Silence reached this point yet? (The director keeps the radius; tests set it directly.)
func _silenced() -> bool:
	return SilenceState.reached(global_position)


func _process(delta: float) -> void:
	_t += delta
	if not _falling and not fallen:
		if _silenced():
			_let_go()
			return
		position.y = _base_y + sin(_t * bob_speed + _phase) * bob
		return
	if _falling:
		_vel += 9.8 * delta
		global_position.y -= _vel * delta
		rotate_object_local(Vector3(1, 0, 0.3).normalized(), tumble * delta)
		if global_position.y <= rest_y:
			global_position.y = rest_y
			_falling = false
			fallen = true


## The Song lets go of it: the light gutters, then it drops.
func _let_go() -> void:
	_falling = true
	_vel = 0.0
	if lights.is_empty() and glow_mats.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	for i in lights.size():
		var l := lights[i]
		tw.tween_method(func(v: float): l.light_energy = v * (0.6 + 0.4 * randf()), _energy[i], 0.0, gutter)
	for i in glow_mats.size():
		var m := glow_mats[i]
		tw.tween_method(func(v: float): m.set_shader_parameter("emission_energy", v), _glow0[i], 0.0, gutter * 1.4)


## Glide the hover height to `y` (local) over `over` seconds — the book-lift coming down.
func glide_to(y: float, over: float) -> Tween:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_base_y", y, over)
	return tw


## For tests and resets: the Song is whole again.
func restore() -> void:
	_falling = false
	fallen = false
	position.y = _base_y
	rotation = Vector3.ZERO
	for i in lights.size():
		lights[i].light_energy = _energy[i]
	for i in glow_mats.size():
		glow_mats[i].set_shader_parameter("emission_energy", _glow0[i])


## A floating Song-lamp: a faceted orb of gold light under a small gilded cap, with its own light.
## `size` is the orb's radius. Returns the SongHeld root; place it, then add it to the tree.
static func make_lamp(mats: Dictionary, size := 0.28, energy := 2.2, light_range := 8.0, shadows := false) -> SongHeld:
	var root := SongHeld.new()
	root.name = "SongLamp"
	var glow: ShaderMaterial = (mats["song_glow"] as ShaderMaterial).duplicate()
	var kit := SolariKit.new({"orb": glow, "gold": mats["gold"]}, randi())
	kit.facet_jitter = 0.0
	kit.dome("orb", Vector3.ZERO, size, size, 8, 2)
	kit.dome("orb", Vector3.ZERO, size, -size, 8, 2)
	kit.prism("gold", Vector3.UP * size * 0.8, size * 0.55, size * 0.35, 8, size * 0.25)
	kit.prism("gold", Vector3.UP * size * 1.15, size * 0.08, size * 0.5, 4, size * 0.02)
	var mi := kit.commit(root, "Orb")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.74, 0.4)
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.2
	root.add_child(l)
	root.register_light(l)
	root.register_glow(glow)
	return root
