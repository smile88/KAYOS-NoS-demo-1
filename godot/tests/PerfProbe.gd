extends Node
## Where the draw calls go: loads the Cold Open, then switches things off one at a time and prints
## the draw-call count for each. Run windowed (needs a GPU context):
##   $G --path godot --rendering-driver opengl3 res://tests/PerfProbe.tscn
const SCENE := preload("res://threed/coldopen/ColdOpen2.tscn")
var dir: Node3D

func _ready() -> void:
	dir = SCENE.instantiate()
	dir.set("skip_opening", true)
	add_child(dir)
	await _settle()
	_report("baseline (scriptorium)")
	ColdOpenWorld.apply_light_budget(dir)
	await _settle()
	_report("light budget (scriptorium)")
	dir.skip_to(5)
	for i in 90: await get_tree().process_frame
	_report("light budget (balcony)")
	var lights: Array = []
	_collect(dir, lights, func(n): return n is OmniLight3D or n is SpotLight3D)
	var mis: Array = []
	_collect(dir, mis, func(n): return n is MeshInstance3D)
	var mms: Array = []
	_collect(dir, mms, func(n): return n is MultiMeshInstance3D)
	print("omni/spot lights: %d   MeshInstance3D: %d   MultiMesh: %d" % [lights.size(), mis.size(), mms.size()])
	var shadowed := lights.filter(func(l): return l.shadow_enabled)
	print("  with shadows: %d" % shadowed.size())
	for l in lights: l.visible = false
	await _settle()
	_report("omni/spot lights off")
	var moon := dir.find_child("Moon", true, false) as DirectionalLight3D
	if moon: moon.shadow_enabled = false
	await _settle()
	_report("+ moon shadow off")
	var city := dir.find_child("City", true, false)
	if city: city.visible = false
	await _settle()
	_report("+ city hidden")
	get_tree().quit()

func _collect(n: Node, out: Array, pred: Callable) -> void:
	if pred.call(n): out.append(n)
	for c in n.get_children(): _collect(c, out, pred)

func _settle() -> void:
	for i in 20: await get_tree().process_frame

func _report(what: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/probe_%s.png" % what.replace(" ", "_").replace("(", "").replace(")", "").replace("/", "_").replace("+", "p"))
	print("%-28s draws %5d   objects %5d   prims %8d   fps %d" % [what,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		Engine.get_frames_per_second()])
