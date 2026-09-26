extends CanvasLayer
class_name ColdOpenUI
## The Cold Open's screen furniture, all quiet: a small objective list top-left (the quest), an
## interaction prompt, Talindir's interior line (the "whisper"), and the cinema layer the cutscene
## uses — letterbox bars, subtitles, centred narration, the letter, the title card and a fade.
## No nameplates, no counters, nothing floating over anyone's head.

const GOLD := Color(0.96, 0.82, 0.48)
const IVORY := Color(0.95, 0.93, 0.88)
const DIM := Color(0.72, 0.74, 0.84)

var _obj_box: VBoxContainer
var _obj_title: Label
var _obj_lines: Array[Label] = []
var _prompt: Label
var _whisper: Label
var _whisper_tw: Tween
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _subtitle: Label
var _narration: Label
var _narr_back: ColorRect
var _letter: PanelContainer
var _letter_text: Label
var _title: VBoxContainer
var _fade: ColorRect
var hud: Control
var touch := false            # phone controls: the USE button is the prompt's key, not F
var prompt_active := false


func _ready() -> void:
	layer = 5
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	# objectives
	_obj_box = VBoxContainer.new()
	_obj_box.position = Vector2(22, 18)
	_obj_box.add_theme_constant_override("separation", 3)
	hud.add_child(_obj_box)
	_obj_title = _label(15, GOLD)
	_obj_box.add_child(_obj_title)
	_obj_box.modulate.a = 0.0
	# prompt
	_prompt = _label(15, IVORY, true)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-300, -118)
	_prompt.size = Vector2(600, 28)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(_prompt)
	# whisper
	_whisper = _label(17, DIM, true)
	_whisper.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_whisper.position = Vector2(-380, -86)
	_whisper.size = Vector2(760, 70)
	_whisper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_whisper.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_whisper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_whisper.modulate.a = 0.0
	hud.add_child(_whisper)
	# cinema
	var cine := Control.new()
	cine.set_anchors_preset(Control.PRESET_FULL_RECT)
	cine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cine)
	_bar_top = _bar(cine, true)
	_bar_bot = _bar(cine, false)
	_subtitle = _label(19, IVORY, true)
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.position = Vector2(-420, -70)
	_subtitle.size = Vector2(840, 50)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.modulate.a = 0.0
	cine.add_child(_subtitle)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine.add_child(_fade)
	_narr_back = ColorRect.new()
	_narr_back.color = Color(0, 0, 0, 0.0)
	_narr_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narr_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cine.add_child(_narr_back)
	_narration = _label(26, IVORY, true)
	_narration.set_anchors_preset(Control.PRESET_CENTER)
	_narration.position = Vector2(-420, -80)
	_narration.size = Vector2(840, 160)
	_narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration.modulate.a = 0.0
	cine.add_child(_narration)
	_letter = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.87, 0.72)
	sb.border_color = Color(0.55, 0.42, 0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(36)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	_letter.add_theme_stylebox_override("panel", sb)
	_letter.set_anchors_preset(Control.PRESET_CENTER)
	_letter.position = Vector2(-300, -170)
	_letter.size = Vector2(600, 340)
	_letter_text = _label(26, Color(0.18, 0.12, 0.2))
	_letter_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter_text.custom_minimum_size = Vector2(520, 240)
	_letter.add_child(_letter_text)
	_letter.modulate.a = 0.0
	cine.add_child(_letter)
	_title = VBoxContainer.new()
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.position = Vector2(-300, -70)
	_title.size = Vector2(600, 140)
	_title.alignment = BoxContainer.ALIGNMENT_CENTER
	var t1 := _label(64, GOLD)
	t1.name = "Title"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := _label(20, IVORY)
	t2.name = "Sub"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_child(t1)
	_title.add_child(t2)
	_title.modulate.a = 0.0
	cine.add_child(_title)


func _label(size: int, col: Color, shadow := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(parent: Control, top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	parent.add_child(r)
	return r


# --- objectives -------------------------------------------------------------------------------
## `items`: [[text, done], ...]. Empty = hide the box.
func set_objectives(title: String, items: Array) -> void:
	for l in _obj_lines:
		l.queue_free()
	_obj_lines.clear()
	_obj_title.text = title.to_upper()
	for it in items:
		var done: bool = it[1]
		var l := _label(14, DIM if done else IVORY, true)
		l.text = ("  ✓  " if done else "  ·  ") + str(it[0])
		if done:
			l.modulate.a = 0.55
		_obj_box.add_child(l)
		_obj_lines.append(l)
	var tw := create_tween()
	tw.tween_property(_obj_box, "modulate:a", 0.0 if items.is_empty() else 1.0, 0.6)


## Phone layout: the prompt and the interior line sit between the thumbs, clear of the joystick
## (bottom left) and the USE and eye buttons (bottom right).
func use_touch_layout() -> void:
	touch = true
	_prompt.position = Vector2(-240, -118)
	_prompt.size = Vector2(480, 28)
	_whisper.position = Vector2(-240, -96)
	_whisper.size = Vector2(480, 84)


# --- prompt and whisper -----------------------------------------------------------------------
func set_prompt(text: String) -> void:
	prompt_active = text != ""
	if touch:
		_prompt.text = text
	else:
		_prompt.text = ("F   " + text) if text != "" else ""


func whisper(text: String, hold := 5.0) -> void:
	# never over someone speaking: an interior line waits for the conversation to end
	while DialogueManager.is_active():
		await DialogueManager.dialogue_finished
	if not is_inside_tree():
		return
	if _whisper_tw and _whisper_tw.is_valid():
		_whisper_tw.kill()
	_whisper.text = text
	_whisper_tw = create_tween()
	_whisper_tw.tween_property(_whisper, "modulate:a", 1.0, 0.8)
	_whisper_tw.tween_interval(hold)
	_whisper_tw.tween_property(_whisper, "modulate:a", 0.0, 1.2)


## Someone is speaking: the interior line gets out of the way.
func hush() -> void:
	if _whisper_tw and _whisper_tw.is_valid():
		_whisper_tw.kill()
	var tw := create_tween()
	tw.tween_property(_whisper, "modulate:a", 0.0, 0.25)


func hide_hud(hidden: bool) -> void:
	var tw := create_tween()
	tw.tween_property(hud, "modulate:a", 0.0 if hidden else 1.0, 0.8)


# --- cinema -----------------------------------------------------------------------------------
func letterbox(on: bool, over := 1.2) -> Tween:
	var h := get_viewport().get_visible_rect().size.y * 0.12
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bar_top, "offset_bottom", h if on else 0.0, over)
	tw.tween_property(_bar_bot, "offset_top", -h if on else 0.0, over)
	return tw


func subtitle(text: String, hold := 3.0) -> Tween:
	_subtitle.text = text
	var tw := create_tween()
	tw.tween_property(_subtitle, "modulate:a", 1.0, 0.5)
	tw.tween_interval(hold)
	tw.tween_property(_subtitle, "modulate:a", 0.0, 0.7)
	return tw


func narrate(text: String, hold := 3.5) -> Tween:
	_narration.text = text
	var tw := create_tween()
	tw.tween_property(_narration, "modulate:a", 1.0, 1.4)
	tw.tween_interval(hold)
	tw.tween_property(_narration, "modulate:a", 0.0, 1.4)
	return tw


## Darken the picture behind the narration so it can be read.
func narration_backdrop(on: bool, over := 1.5) -> Tween:
	var tw := create_tween()
	tw.tween_property(_narr_back, "color:a", 0.55 if on else 0.0, over)
	return tw


func show_letter(text: String, on := true) -> Tween:
	_letter_text.text = text
	var tw := create_tween()
	tw.tween_property(_letter, "modulate:a", 1.0 if on else 0.0, 1.6)
	return tw


func title_card(title: String, sub: String, on := true) -> Tween:
	(_title.get_node("Title") as Label).text = title
	(_title.get_node("Sub") as Label).text = sub
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0 if on else 0.0, 2.2)
	return tw


func fade(to_black: bool, over := 1.0, col := Color.BLACK) -> Tween:
	_fade.color = Color(col.r, col.g, col.b, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if to_black else 0.0, over)
	return tw
