extends RefCounted
class_name ColdOpenPalette
## Every material in the Cold Open, in one place — colours picked off the approved style frames
## (art/style_frames/cold_open/): warm white marble with blue-grey veins, flat yellow-gold, honey wood,
## ivory cloth, and the Song's gold glow. All of them run on shaders/world.gdshader, so all of them
## drain when the Silence passes.

const WORLD := preload("res://threed/coldopen/shaders/world.gdshader")

## The Song's colour — lamps, light-lines, threads, the Tower's column.
const SONG := Color(1.0, 0.76, 0.34)
const FIRE := Color(1.0, 0.55, 0.18)


static func mat(albedo: Color, rough := 0.78, marble := 0.0, metal := 0.0, emit := Color(0, 0, 0),
		energy := 0.0, song := 1.0, facet := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WORLD
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("marble", marble)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("emission_color", emit)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("song", song)
	m.set_shader_parameter("facet", facet)
	return m


static func build() -> Dictionary:
	var p := {}
	p["marble"] = mat(Color(0.93, 0.91, 0.87), 0.7, 1.0)
	p["marble_warm"] = mat(Color(0.95, 0.89, 0.8), 0.72, 0.8)
	p["marble_floor"] = mat(Color(0.86, 0.85, 0.84), 0.45, 1.0)
	p["marble_blue"] = mat(Color(0.62, 0.66, 0.76), 0.6, 0.6)
	p["marble_dark"] = mat(Color(0.34, 0.36, 0.44), 0.7, 0.5)
	p["stone_base"] = mat(Color(0.72, 0.7, 0.68), 0.85, 0.5)
	p["gold"] = mat(Color(0.95, 0.72, 0.3), 0.32, 0.0, 0.55, Color(0, 0, 0), 0.0, 1.0, 0.5)
	p["gold_dim"] = mat(Color(0.78, 0.58, 0.26), 0.45, 0.0, 0.4)
	p["bronze"] = mat(Color(0.55, 0.38, 0.2), 0.4, 0.0, 0.6)
	p["wood"] = mat(Color(0.66, 0.41, 0.2), 0.62)
	p["wood_dark"] = mat(Color(0.38, 0.22, 0.12), 0.7)
	p["paper"] = mat(Color(0.95, 0.9, 0.76), 0.9)
	p["leather"] = mat(Color(0.42, 0.26, 0.15), 0.8)
	p["books"] = mat(Color(1, 1, 1), 0.85)          # colour comes from vertex colour
	p["ivory"] = mat(Color(0.96, 0.92, 0.82), 0.85)
	p["cloth_gold"] = mat(Color(0.95, 0.74, 0.3), 0.7)
	p["cloth_blue"] = mat(Color(0.2, 0.25, 0.45), 0.85)
	p["garland"] = mat(Color(0.2, 0.38, 0.2), 0.85)
	p["garland_fallen"] = mat(Color(0.5, 0.62, 0.46), 0.85, 0.0, 0.0, Color(0, 0, 0), 0.0, 1.0, 1.0)
	p["flower"] = mat(Color(0.98, 0.95, 0.85), 0.8, 0.0, 0.0, Color(1.0, 0.9, 0.6), 0.25)
	p["glass_dark"] = mat(Color(0.06, 0.07, 0.14), 0.2)
	p["ink"] = mat(Color(0.05, 0.05, 0.1), 0.2)
	p["iron"] = mat(Color(0.18, 0.18, 0.21), 0.6, 0.0, 0.5)
	p["city_wall"] = mat(Color(0.88, 0.84, 0.76), 0.85, 0.3)
	p["city_wall_b"] = mat(Color(0.8, 0.76, 0.7), 0.85, 0.3)
	p["city_roof"] = mat(Color(0.9, 0.66, 0.28), 0.5, 0.0, 0.3)
	p["city_roof_b"] = mat(Color(0.55, 0.6, 0.72), 0.6)
	p["street"] = mat(Color(0.62, 0.58, 0.54), 0.9, 0.4)
	# --- the Song's light -------------------------------------------------------------------
	p["song_line"] = mat(Color(1.0, 0.85, 0.5), 0.3, 0.0, 0.0, SONG, 3.0)
	p["song_glow"] = mat(Color(1.0, 0.86, 0.55), 0.3, 0.0, 0.0, SONG, 2.6)
	p["song_soft"] = mat(Color(1.0, 0.9, 0.7), 0.4, 0.0, 0.0, SONG, 1.6)
	p["window_lit"] = mat(Color(1.0, 0.8, 0.45), 0.5, 0.0, 0.0, Color(1.0, 0.72, 0.36), 2.4)
	p["fire"] = mat(Color(1.0, 0.6, 0.2), 0.5, 0.0, 0.0, FIRE, 5.0, 0.0)
	p["ember"] = mat(Color(0.5, 0.2, 0.08), 0.8, 0.0, 0.0, Color(1.0, 0.35, 0.1), 1.2, 0.0)
	return p
