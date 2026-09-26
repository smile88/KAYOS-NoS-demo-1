extends Node3D
## Renders Cold Open v2 from fixed cameras for comparison with art/style_frames/cold_open/.
##   $G --path godot res://tests/ShotColdOpenV2.tscn            # every shot
##   SHOT=s01 $G --path godot res://tests/ShotColdOpenV2.tscn   # one
##   SILENCE=150 ...                                            # with the ring at 150 m
## Writes art/greybox_renders/co2_<shot>.png (or $OUT/<shot>.png).

const L = preload("res://threed/coldopen/ColdOpenLayout.gd")

const SHOTS := {
	"s01_scriptorium": [Vector3(-2.3, 3.1, 24.6), Vector3(-0.6, 4.6, -2.0), 62.0],
	"s02_balcony": [Vector3(0.9, 20.4, 3.0), Vector3(0.0, 62.0, -225.0), 62.0],
	"s03_hall": [Vector3(-26.0, 2.6, 30.5), Vector3(20.0, 3.0, 37.0), 70.0],
	"s04_cloister": [Vector3(-33.5, 2.2, -6.5), Vector3(-45.0, 3.5, 25.0), 70.0],
	"s05_stairs": [Vector3(-29.0, 1.8, -7.3), Vector3(-15.0, 6.5, -7.3), 70.0],
	"s06_exterior": [Vector3(45.0, 34.0, -95.0), Vector3(-8.0, 12.0, 5.0), 60.0],
	"s07_gate": [Vector3(-50.0, 1.8, 15.0), Vector3(-70.0, 3.5, 15.0), 70.0],
	"s08_balcony_back": [Vector3(0.0, 21.0, -21.0), Vector3(0.0, 19.0, -5.0), 62.0],
}


## Gameplay shots: the real director running, the player's own camera, the HUD. [stage, player pos,
## player facing, camera yaw offset, camera distance, camera pitch]
const GAME_SHOTS := {
	"g01_desk": [0, L.SPAWN, Vector3(0, 0, -1), 0.35, 4.2, 16.0],
	"g02_balcony": [5, Vector3(0.6, L.BAL_Y, -2.2), Vector3(0, 0, -1), 0.0, 5.0, 8.0],
	"g03_hall": [2, Vector3(-4.0, 0, 34.5), Vector3(0, 0, 1), 0.6, 5.0, 18.0],
	"g04_cloister": [3, Vector3(-48.0, 0, 16.0), Vector3(-1, 0, 0), -0.9, 5.5, 14.0],
	"g05_dialogue": [0, L.SPAWN, Vector3(0.5, 0, 0.8), 2.4, 4.4, 14.0],
	"g06_stairs": [4, Vector3(-24.0, 1.7, -7.3), Vector3(1, 0, 0), 0.0, 4.0, 22.0],
}


func _ready() -> void:
	get_tree().create_timer(600).timeout.connect(func(): get_tree().quit(1))
	if OS.get_environment("MODE") == "game":
		await _game_shots()
		return
	var world := ColdOpenWorld.new()
	add_child(world)
	world.build_world()
	var sil := OS.get_environment("SILENCE")
	if sil != "":
		world.set_silence(float(sil))
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var only := OS.get_environment("SHOT")
	var out := OS.get_environment("OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://../art/greybox_renders")
	for key in SHOTS:
		if only != "" and not str(key).begins_with(only):
			continue
		var s: Array = SHOTS[key]
		cam.fov = s[2]
		cam.position = s[0]
		cam.look_at(s[1], Vector3.UP)
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/co2_%s.png" % [out, key]
		img.save_png(path)
		print("shot ", path)
	get_tree().quit()


func _game_shots() -> void:
	var only := OS.get_environment("SHOT")
	var out := OS.get_environment("OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://../art/greybox_renders")
	for key in GAME_SHOTS:
		if only != "" and not str(key).begins_with(only):
			continue
		var g: Array = GAME_SHOTS[key]
		GameState.reset()
		var dir: ColdOpenDirector = (load("res://threed/coldopen/ColdOpen2.tscn") as PackedScene).instantiate()
		dir.skip_opening = true
		add_child(dir)
		await get_tree().process_frame
		if int(g[0]) > 0:
			dir.skip_to(int(g[0]))
		dir.player.global_position = g[1]
		dir.player.model.face_dir(g[2])
		dir.rig.move_yaw = atan2(-(g[2] as Vector3).x, -(g[2] as Vector3).z) + float(g[3])
		dir.rig.distance = g[4]
		dir.rig.pitch_deg = g[5]
		if str(key) == "g05_dialogue":
			dir.maelis.visible = true
			dir.maelis.global_position = L.SPAWN + Vector3(0.9, 0, 1.4)
			dir.maelis.face(Vector3(-0.5, 0, -1))
			DialogueManager.start(ColdOpenScript.maelis_duty())
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/co2_%s.png" % [out, key]
		get_viewport().get_texture().get_image().save_png(path)
		print("shot ", path)
		if DialogueManager.is_active():
			DialogueManager._finish()
		dir.queue_free()
		await get_tree().process_frame
	get_tree().quit()
