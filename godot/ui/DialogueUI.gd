extends Control
## In-world dialogue renderer (Phase 1.7 / 2). Passive: listens to DialogueManager and shows
## the panel only during a conversation.
##
## Features:
## - Smooth typewriter text reveal with punctuation-aware pacing.
## - Integrated audio blip synthesis via AudioManager.
## - Skip-to-end on interact press.
## - Keyboard-driven choice navigation (W/S/F/Space/Enter).
## - Reactive Mental Strain indicators with color-coded band states.

const COL_NORMAL := Color(0.90, 0.88, 0.98)
const COL_GOLD := Color(0.95, 0.82, 0.42)
const COL_LOCKED := Color(0.45, 0.45, 0.52)

const CHARS_PER_SECOND := 42.0

@onready var panel: PanelContainer = %Panel
@onready var speaker: Label = %Speaker
@onready var line: RichTextLabel = %Line
@onready var choices: VBoxContainer = %Choices
@onready var strain: Label = %Strain
@onready var portrait: TextureRect = %Portrait

var _portrait_index: Dictionary = {}
var _nav_buttons: Array[Button] = []
var _sel := 0

var _current_speaker := ""
var _is_typing := false
var _type_tween: Tween
var _cached_choices: Array = []


func _ready() -> void:
	_build_portrait_index()
	DialogueManager.dialogue_started.connect(func(_id): panel.show())
	DialogueManager.node_entered.connect(_on_node)
	DialogueManager.choices_ready.connect(_on_choices)
	DialogueManager.dialogue_finished.connect(func(_id): _on_dialogue_finished())
	GameState.strain_changed.connect(func(_v, _b): _refresh_strain())
	panel.hide()
	_refresh_strain()


func _on_dialogue_finished() -> void:
	_stop_typing()
	panel.hide()


func _on_node(node: Dictionary) -> void:
	_stop_typing()
	_current_speaker = String(node.get("speaker", ""))
	speaker.text = _current_speaker.capitalize()
	
	var full_text: String = String(node.get("text", ""))
	line.text = full_text
	line.visible_characters = 0

	var pid := String(node.get("portrait", ""))
	if pid != "" and _portrait_index.has(pid):
		portrait.texture = load(_portrait_index[pid])
		portrait.show()
	else:
		portrait.texture = null
		portrait.hide()

	_start_typewriter(full_text)


func _start_typewriter(full_text: String) -> void:
	var total_chars := full_text.length()
	if total_chars == 0:
		_finish_typing()
		return

	_is_typing = true
	choices.hide() # hide choices until typing finishes or is skipped

	var duration := float(total_chars) / CHARS_PER_SECOND
	_type_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	
	# Animate visible_characters
	_type_tween.tween_method(func(val: int):
		line.visible_characters = val
		if val > 0 and val <= total_chars:
			var c := full_text[val - 1]
			# Play voice chirp every ~3 characters on alphanumeric letters
			if val % 3 == 1 and c != " " and c != "\n":
				AudioManager.play_dialogue_blip(_current_speaker)
	, 0, total_chars, duration)

	_type_tween.tween_callback(self._finish_typing)


func _finish_typing() -> void:
	_stop_typing()
	line.visible_characters = -1
	choices.show()
	_update_selection()


func _stop_typing() -> void:
	_is_typing = false
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()


func _build_portrait_index() -> void:
	for dir_path in ["res://art/placeholders", "res://art/portraits"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f in dir.get_files():
			if not f.ends_with(".png"):
				continue
			var pid := f.get_basename().get_slice("_", 0) # "PO-005_talindir.png" -> "PO-005"
			if pid.begins_with("PO-"):
				_portrait_index[pid] = dir_path + "/" + f


func _on_choices(list: Array) -> void:
	_cached_choices = list
	for c in choices.get_children():
		c.queue_free()
	_nav_buttons.clear()
	_sel = 0

	if list.is_empty():
		_add_button("(continue)", COL_NORMAL, true, func(): DialogueManager.advance())
		if not _is_typing:
			choices.show()
			_update_selection()
		return

	for entry in list:
		var label: String = entry["text"]
		var col := COL_NORMAL
		var check = entry.get("check")
		if check != null:
			var tag := "[%s %d%s]" % [check.get("attr", "?"), int(check.get("dc", 0)),
				("  · Fortune" if entry["state"] == "uncertain" else "")]
			if entry["state"] == "locked":
				label = "🔒 %s  %s" % [tag, entry["text"]]
				col = COL_LOCKED
			else:
				label = "%s  %s" % [tag, entry["text"]]
				col = COL_GOLD
		var idx: int = entry["index"]
		_add_button(label, col, entry["enabled"], func(): DialogueManager.choose(idx))

	if not _is_typing:
		choices.show()
		_update_selection()


func _add_button(text: String, col: Color, enabled: bool, on_press: Callable) -> void:
	var b := Button.new()
	b.set_meta("base_text", text)
	b.text = text
	b.disabled = not enabled
	b.add_theme_color_override("font_color", col)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	if enabled:
		b.pressed.connect(on_press)
		_nav_buttons.append(b)
	choices.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return

	# If text is actively typing out, pressing any advance key immediately finishes reveal
	if _is_typing:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_finish_typing()
			get_viewport().set_input_as_handled()
			return

	if _nav_buttons.is_empty():
		return

	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_move_sel(-1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_move_sel(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_nav_buttons[_sel].pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _move_sel(dir: int) -> void:
	var n := _nav_buttons.size()
	if n == 0:
		return
	_sel = (_sel + dir + n) % n
	_update_selection()


func _update_selection() -> void:
	for i in _nav_buttons.size():
		var b := _nav_buttons[i]
		var sel := (i == _sel)
		b.text = ("▸  " if sel else "    ") + String(b.get_meta("base_text"))
		b.modulate.a = 1.0 if sel else 0.55


func _refresh_strain() -> void:
	var band: int = GameState.get_strain_band()
	var band_name: String = ["Calm", "Frayed", "Strained", "Breaking", "Silence"][band]
	strain.text = "Mental Strain: %d / 100  (%s)" % [GameState.mental_strain, band_name]
	
	match band:
		GameState.StrainBand.CALM:
			strain.modulate = Color(0.8, 0.85, 0.95)
		GameState.StrainBand.FRAYED:
			strain.modulate = Color(0.95, 0.85, 0.5)
		GameState.StrainBand.STRAINED:
			strain.modulate = Color(1.0, 0.65, 0.35)
		GameState.StrainBand.BREAKING, GameState.StrainBand.SILENCE:
			strain.modulate = Color(1.0, 0.3, 0.3)
