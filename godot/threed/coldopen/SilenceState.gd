extends RefCounted
class_name SilenceState
## The Silence's ring, as game state. Shaders read it from global uniforms; scripts read it from here
## (Godot will not read a global shader uniform back at runtime). ColdOpenWorld is the only writer.

const L = preload("res://threed/coldopen/ColdOpenLayout.gd")

static var center := L.TOWER
static var radius := -1.0
static var speed := 60.0
static var fade := 0.0


static func set_ring(r: float, spd := 60.0) -> void:
	radius = r
	speed = spd
	RenderingServer.global_shader_parameter_set("silence_center", center)
	RenderingServer.global_shader_parameter_set("silence_radius", r)
	RenderingServer.global_shader_parameter_set("silence_speed", spd)


static func set_fade(f: float) -> void:
	fade = f
	RenderingServer.global_shader_parameter_set("silence_fade", f)


## Has the ring passed over this point?
static func reached(p: Vector3) -> bool:
	return radius >= 0.0 and Vector2(p.x - center.x, p.z - center.z).length() < radius
