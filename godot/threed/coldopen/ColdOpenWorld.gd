extends Node3D
class_name ColdOpenWorld
## Astra'Thalas on the night of the two-thousandth Luminarae, assembled: the sky and light, the city
## and the Tower, the Astral Archive. The director (ColdOpenDirector) and the render harness
## (tests/ShotColdOpenV2) both build on this.
##
## It also owns the Silence's global state — the ring's centre, radius, speed and the grey settling
## over everything — because every shader in the Cold Open reads it.

const L = preload("res://threed/coldopen/ColdOpenLayout.gd")

var mats: Dictionary
var env: WorldEnvironment
var moon: DirectionalLight3D
var festival_light: DirectionalLight3D
var city: ColdOpenCity
var archive: ColdOpenArchive
var silence_radius := -1.0


func build_world() -> void:
	mats = ColdOpenPalette.build()
	env = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = ColdOpenEnv.make_environment()
	add_child(env)
	moon = ColdOpenEnv.make_moon()
	add_child(moon)
	festival_light = ColdOpenEnv.make_festival_light()
	add_child(festival_light)
	city = ColdOpenCity.new()
	city.name = "City"
	add_child(city)
	city.build(mats)
	archive = ColdOpenArchive.new()
	archive.name = "Archive"
	add_child(archive)
	archive.build(mats)
	reset_silence()


## The Song is whole.
func reset_silence() -> void:
	SilenceState.center = L.TOWER
	SilenceState.set_ring(-1.0)
	SilenceState.set_fade(0.0)
	RenderingServer.global_shader_parameter_set("silence_edge", 6.0)
	silence_radius = -1.0


## Put the ring at `radius` metres from the Tower (the cutscene drives this every frame).
func set_silence(radius: float, speed := 60.0) -> void:
	silence_radius = radius
	SilenceState.set_ring(radius, speed)
	# lights the ring has passed go out (the SongHeld nodes handle their own)
	for n in get_tree().get_nodes_in_group("song_light"):
		var l := n as Light3D
		if l == null:
			continue
		if l is DirectionalLight3D:
			continue
		var d := Vector2(l.global_position.x - L.TOWER.x, l.global_position.z - L.TOWER.z).length()
		if radius >= 0.0 and d < radius:
			l.visible = false


## 0..1: the grey settling over the whole world after the ring has passed (sky, air, everything).
func set_fade(f: float) -> void:
	SilenceState.set_fade(f)
	festival_light.light_energy = 0.55 * (1.0 - f)
	var e := env.environment
	# no global desaturation: the shaders grey the world, and the crowd's gold must stay gold
	e.glow_intensity = lerpf(0.85, 1.1, f)
	e.ambient_light_color = Color(0.36, 0.38, 0.62).lerp(Color(0.42, 0.44, 0.5), f)


## The web build (Compatibility renderer) draws a mesh again for every light that touches it, so there
## only the lights near the camera stay on: small lights fade out past a short distance, point lights
## cast no shadows, and the Tower's up-lights reach only as far as the Tower.
static func apply_light_budget(root: Node) -> void:
	for n in root.find_children("*", "Light3D", true, false):
		if n is DirectionalLight3D:
			continue
		var l := n as Light3D
		l.shadow_enabled = false
		if l is SpotLight3D:
			(l as SpotLight3D).spot_range = minf((l as SpotLight3D).spot_range, 130.0)
		elif (l as OmniLight3D).omni_range < 30.0:
			l.distance_fade_enabled = true
			l.distance_fade_begin = 14.0
			l.distance_fade_length = 5.0
