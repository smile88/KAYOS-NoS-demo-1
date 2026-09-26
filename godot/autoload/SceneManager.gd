extends Node
## SceneManager — scene transitions with fade + era title cards (UI-013) + spawn markers.
## GDD §13 / Implementation Plan Phase 2.2.
##
## change_zone(path)                                  — plain fade-through-black.
## change_zone(path, "SpawnFromColdOpen")             — also places the player (group "player")
##                                                      at the Marker2D/Marker3D with that name in
##                                                      the target zone (2D or 3D, matched to player).
## change_zone(path, spawn, "PART ONE — THE ARCHITECT", "Starfall · c. 1450 AO")
##                                                    — holds a title card over black between
##                                                      the zones (UI-013 placeholder panel).

signal scene_changing(to_path: String)
signal scene_changed(to_path: String)

const TITLE_CARD_TEXTURE := "res://art/placeholders/UI-013_title_card.png"
const FADE_DURATION := 0.5
const TITLE_CARD_HOLD := 2.8

var _current_zone_path: String = ""
var _busy := false

var _layer: CanvasLayer
var _fade: ColorRect
var _card: Control
var _card_title: Label
var _card_subtitle: Label


func _ready() -> void:
	_build_overlay()


func change_zone(scene_path: String, spawn_point: String = "",
		card_title: String = "", card_subtitle: String = "") -> void:
	if _busy:
		push_warning("SceneManager: change_zone ignored, a transition is already running.")
		return
	_busy = true
	scene_changing.emit(scene_path)

	await _fade_to(1.0, FADE_DURATION)
	if card_title != "":
		await _show_title_card(card_title, card_subtitle)

	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneManager.change_zone failed for %s (err %d)" % [scene_path, err])
		_busy = false
		await _fade_to(0.0, FADE_DURATION)
		return
	_current_zone_path = scene_path
	GameState.current_scene = scene_path

	# Wait for the new scene to enter the tree, then place the player.
	await get_tree().process_frame
	await get_tree().process_frame
	if spawn_point != "":
		_place_player(spawn_point)

	await _fade_to(0.0, FADE_DURATION)
	_busy = false
	scene_changed.emit(scene_path)


## --- internals ---------------------------------------------------------------
func _place_player(spawn_point: String) -> void:
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player")
	if scene == null or player == null:
		return
	var marker := scene.find_child(spawn_point, true, false)
	if marker is Node3D and player is Node3D:
		(player as Node3D).global_position = (marker as Node3D).global_position
	elif marker is Node2D and player is Node2D:
		(player as Node2D).global_position = (marker as Node2D).global_position
	else:
		push_warning("SceneManager: spawn point '%s' not found (or type mismatch) in %s" % [spawn_point, scene.name])


func _fade_to(alpha: float, duration: float) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, duration)
	await tw.finished
	if alpha <= 0.0:
		_fade.visible = false


func _show_title_card(title: String, subtitle: String) -> void:
	_card_title.text = title
	_card_subtitle.text = subtitle
	_card_subtitle.visible = subtitle != ""
	_card.modulate.a = 0.0
	_card.visible = true
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(TITLE_CARD_HOLD)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	await tw.finished
	_card.visible = false


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	_layer.add_child(_fade)

	_card = CenterContainer.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_layer.add_child(_card)

	# UI-013 placeholder panel behind the text; swaps out with the illuminated card set later.
	var panel := TextureRect.new()
	panel.texture = load(TITLE_CARD_TEXTURE)
	panel.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_card.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	_card_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_card_title)

	_card_subtitle = Label.new()
	_card_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_subtitle.add_theme_color_override("font_color", Color(0.89, 0.84, 0.71))
	_card_subtitle.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_card_subtitle)
