@tool
extends Interactable3D
class_name NPC3D
## A 3D-model NPC for KAYOS: The Night of Silence (Starfall & the Cold Open).
## Uses CharacterModel3D for low-poly robed figure rendering with racial color palettes,
## scale variations, world-space nameplate, and interaction prompt indicators.
##
## Drop into a 3D scene, assign a CharacterData or configure race/colors in the Inspector.

@export var character_data: CharacterData : set = _set_character_data
@export var race: CharacterModel3D.Race = CharacterModel3D.Race.CUSTOM : set = _set_race
@export var robe_color := Color(0, 0, 0, 0) : set = _set_robe_color
@export var show_label := true : set = _set_show_label
@export var show_prompt := true : set = _set_show_prompt
@export var prompt_text := "[E] Talk" : set = _set_prompt_text
## A rigged model to wear instead of the primitive figure. Overrides character_data.model_rig.
@export_file("*.glb") var rig_model := ""

## CharacterModel3D (primitive) or RiggedCharacter3D (a rigged Meshy character). Both answer
## face_dir / set_moving; only the rigged one talks and performs actions.
var model: Node3D
var _label_anchor: Node3D
var _name_label: Label3D
var _prompt_label: Label3D


func _ready() -> void:
	super._ready()   # Interactable3D: joins group "interactable3d"
	_setup_model()
	if character_data:
		_apply_character_data()
	elif race != CharacterModel3D.Race.CUSTOM:
		_apply_race()
	elif robe_color.a > 0.0 and model is CharacterModel3D:
		(model as CharacterModel3D).robe_color = robe_color
	_setup_labels()
	_update_labels()


func _setup_model() -> void:
	var old := get_node_or_null("CharacterModel")
	if old:
		old.queue_free()
	var rig := rig_model
	if rig == "" and character_data and "model_rig" in character_data:
		rig = str(character_data.model_rig)
	if rig != "":
		var r := RiggedCharacter3D.new()
		r.name = "CharacterModel"
		r.rig_path = rig
		model = r
		add_child(model)
		return
	var c := CharacterModel3D.new()
	c.name = "CharacterModel"
	if race != CharacterModel3D.Race.CUSTOM:
		c.race = race
	elif robe_color.a > 0.0:
		c.robe_color = robe_color
	model = c
	add_child(model)


func is_rigged() -> bool:
	return model is RiggedCharacter3D


func _setup_labels() -> void:
	var old := get_node_or_null("LabelAnchor")
	if old:
		old.queue_free()

	_label_anchor = Node3D.new()
	_label_anchor.name = "LabelAnchor"
	var height := 2.15
	if model:
		height = 2.15 * model.character_scale.y
	_label_anchor.position = Vector3(0, height, 0)
	add_child(_label_anchor)

	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.font_size = 28
	_name_label.outline_size = 8
	_name_label.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	_name_label.modulate = Color(0.96, 0.96, 1.0)
	_name_label.no_depth_test = false
	_label_anchor.add_child(_name_label)

	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.position = Vector3(0, -0.28, 0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.font_size = 18
	_prompt_label.outline_size = 6
	_prompt_label.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	_prompt_label.modulate = Color(0.95, 0.85, 0.45)   # Warm soft gold
	_prompt_label.no_depth_test = false
	_label_anchor.add_child(_prompt_label)


func _set_character_data(value: CharacterData) -> void:
	character_data = value
	if is_inside_tree():
		_apply_character_data()
		_update_labels()


func _apply_character_data() -> void:
	if not character_data:
		return
	if display_name == "" or Engine.is_editor_hint():
		display_name = character_data.display_name
	if dialogue == "" and character_data.default_dialogue != "":
		dialogue = character_data.default_dialogue
	if portrait_id == "" and character_data.id != "":
		portrait_id = character_data.id
	if examine_text == "" and character_data.editor_notes != "":
		examine_text = character_data.editor_notes
	if model:
		model.apply_faction(character_data.faction)
		if robe_color.a > 0.0 and model is CharacterModel3D:
			(model as CharacterModel3D).robe_color = robe_color
		if _label_anchor:
			_label_anchor.position.y = 2.15 * model.character_scale.y


func _set_race(value: CharacterModel3D.Race) -> void:
	race = value
	if model is CharacterModel3D:
		(model as CharacterModel3D).race = race
	if _label_anchor and model:
		_label_anchor.position.y = 2.15 * model.character_scale.y


func _apply_race() -> void:
	if model is CharacterModel3D and race != CharacterModel3D.Race.CUSTOM:
		(model as CharacterModel3D).race = race
		if _label_anchor:
			_label_anchor.position.y = 2.15 * model.character_scale.y


func _set_robe_color(value: Color) -> void:
	robe_color = value
	if model is CharacterModel3D and robe_color.a > 0.0:
		(model as CharacterModel3D).robe_color = robe_color


func _set_show_label(value: bool) -> void:
	show_label = value
	if _name_label:
		_name_label.visible = show_label


func _set_show_prompt(value: bool) -> void:
	show_prompt = value
	if _prompt_label:
		_prompt_label.visible = show_prompt


func _set_prompt_text(value: String) -> void:
	prompt_text = value
	if _prompt_label:
		_prompt_label.text = prompt_text


func _update_labels() -> void:
	if _name_label:
		var txt := display_name
		if txt == "" and character_data:
			txt = character_data.display_name
		_name_label.text = txt
		_name_label.visible = show_label and (txt != "")
	if _prompt_label:
		_prompt_label.text = prompt_text
		_prompt_label.visible = show_prompt and (_name_label != null and _name_label.visible)


## Face and animate along a world-space ground direction. `speed` (m/s) lets a rigged model match
## its walk cycle to how fast it is actually moving, so feet do not slide.
func walk_toward(world_dir: Vector3, speed := -1.0) -> void:
	if model is RiggedCharacter3D:
		(model as RiggedCharacter3D).face_dir(world_dir)
		(model as RiggedCharacter3D).set_moving(true, speed)
	elif model:
		model.face_dir(world_dir)
		model.set_moving(true)


func stop_walking() -> void:
	if model:
		model.set_moving(false)


func face(world_dir: Vector3) -> void:
	if model:
		model.face_dir(world_dir)


## Talking to the player: a rigged NPC turns toward whoever spoke to it and gestures for as long as
## the conversation lasts.
func interact() -> void:
	super.interact()
	if not (model is RiggedCharacter3D) or not DialogueManager.is_active():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		face(player.global_position - global_position)
	(model as RiggedCharacter3D).set_talking(true)
	if not DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished(_id: String) -> void:
	if model is RiggedCharacter3D:
		(model as RiggedCharacter3D).set_talking(false)
