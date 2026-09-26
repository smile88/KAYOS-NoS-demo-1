extends RefCounted
class_name ColdOpenEnv
## The night's light: the WorldEnvironment (sky, fog, glow, grading) and the moon. Lighting does most
## of the work in the style frames — warm gold pools against deep blue-violet shadow, bloom on every
## light source, haze for depth — and this is where it is set.

const SKY_SHADER := preload("res://threed/coldopen/shaders/night_sky.gdshader")


static func make_environment() -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY_SHADER
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.38, 0.62)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.6)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.2, 0.22, 0.4)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.9, 0.85, 0.8)
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# WebGL 2 (the phone demo) has no SSAO or volumetric fog; a little more plain fog stands in
		# for the haze.
		env.ssao_enabled = false
		env.volumetric_fog_enabled = false
		env.fog_density = 0.0016
		env.fog_light_color = Color(0.26, 0.26, 0.44)
	return env


static func make_moon() -> DirectionalLight3D:
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.7, 1.0)
	moon.light_energy = 0.55
	moon.light_volumetric_fog_energy = 0.4
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 140.0
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		moon.directional_shadow_max_distance = 70.0
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	return moon


## The festival's own light: warm gold from the lit city below and behind the viewer, lifting the
## ivory walls to the gold the frames show. It belongs to the Song — the cutscene puts it out.
static func make_festival_light() -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = "FestivalLight"
	l.light_color = Color(1.0, 0.72, 0.42)
	l.light_energy = 0.55
	l.light_volumetric_fog_energy = 0.0
	l.shadow_enabled = false
	l.rotation_degrees = Vector3(14.0, 20.0, 0.0)
	l.add_to_group("song_light")
	return l
