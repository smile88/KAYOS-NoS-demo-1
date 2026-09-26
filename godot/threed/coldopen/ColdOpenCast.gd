extends RefCounted
class_name ColdOpenCast
## People in the Cold Open: the generated low-poly cast (godot/assets/characters/lowpoly/) wearing
## shaders/figure.gdshader, so the Silence can grey them, age them, or leave behind the flat gold
## afterimages of 03b_after.png.

const FIGURE := preload("res://threed/coldopen/shaders/figure.gdshader")
const LOWPOLY := "res://assets/characters/lowpoly/%s.glb"


static func rig_path(file: String) -> String:
	return LOWPOLY % file


## Swap every surface under `root` onto the figure shader, keeping its painted atlas. Returns the
## materials so a caller can drive to_gold / gold_now / age. Idempotent: a figure is dressed once.
static func dress(root: Node, to_gold := 0.0) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if root.has_meta("figure_mats"):
		for m in root.get_meta("figure_mats"):
			out.append(m)
		return out
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var tex: Texture2D = null
			var tint := Color(1, 1, 1)
			if src is StandardMaterial3D:
				tex = (src as StandardMaterial3D).albedo_texture
				tint = (src as StandardMaterial3D).albedo_color
			var m := ShaderMaterial.new()
			m.shader = FIGURE
			if tex:
				m.set_shader_parameter("atlas", tex)
			m.set_shader_parameter("tint", tint)
			m.set_shader_parameter("to_gold", to_gold)
			mi.set_surface_override_material(s, m)
			out.append(m)
	root.set_meta("figure_mats", out)
	return out


static func set_param(mats: Array, key: String, v) -> void:
	for m in mats:
		(m as ShaderMaterial).set_shader_parameter(key, v)


## A gold afterimage of `figure` (a RiggedCharacter3D) exactly as it stands this instant: a second
## copy of its rig, frozen on the current frame of its current animation, flat gold. The person
## underneath is free to fall; the afterimage keeps reaching for the Tower.
static func afterimage(figure: RiggedCharacter3D, parent: Node) -> Node3D:
	var ghost := RiggedCharacter3D.new()
	ghost.rig_path = figure.rig_path
	ghost.name = figure.name + "_Gold"
	parent.add_child(ghost)
	ghost.global_transform = figure.global_transform
	var src_player := figure.find_children("*", "AnimationPlayer", true, false)
	var dst_player := ghost.find_children("*", "AnimationPlayer", true, false)
	if not src_player.is_empty() and not dst_player.is_empty():
		var sp := src_player[0] as AnimationPlayer
		var dp := dst_player[0] as AnimationPlayer
		if sp.current_animation != "":
			dp.play(sp.current_animation)
			dp.seek(sp.current_animation_position, true)
		dp.pause()
		dp.set_process(false)
	ghost.set_process(false)
	var mats := dress(ghost, 1.0)
	set_param(mats, "gold_now", 1.0)
	return ghost
