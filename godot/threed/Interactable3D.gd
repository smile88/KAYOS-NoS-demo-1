@tool
extends Area3D
class_name Interactable3D
## A world object the player can examine in the 3D Cold Open — the HD-2D twin of actors/Interactable.gd.
## interact() behaves identically (starts `dialogue` if set, else shows `examine_text` as a one-node
## conversation through the shared DialogueUI), so the examine writing — ~30% of the game's
## characterisation (GDD §8.4) — carries over verbatim. If `prop_texture` is set it also stands a
## billboard sprite here reusing the existing 2D prop PNG; leave it empty for an invisible zone on a
## piece of the environment (the rail, the floor mosaic).

@export var display_name: String = ""
@export_multiline var examine_text: String = ""
@export_file("*.json", "*.tres") var dialogue: String = ""
@export var flag_on_interact: String = ""
@export var portrait_id: String = ""

@export_group("Class Verbs")
## Optional contextual class verb required to access this interactable's true dialogue/examine text.
## Verbs: 'unmake' (Voidweaver), 'resonate' (Harmonist), 'restore' (Mender),
## 'decipher' (Scholar), 'break' (Chainbreaker), 'vanish' (Whisper)
@export_enum("none", "unmake", "resonate", "restore", "decipher", "break", "vanish") var required_class_verb: String = "none"
@export_multiline var failed_verb_text: String = "A shattered glyph, unreadable to most."

@export_group("Visuals")
## Optional 3D model to stand here — a key into PropModels3D (e.g. "desk", "banner"). Preferred over
## prop_texture now that the world is 3D models rather than billboards.
@export var prop_model: String = ""
## Legacy: a 2D billboard prop. Kept for anything not yet modelled; prop_model wins if both are set.
@export var prop_texture: Texture2D
@export var prop_pixel_size := 0.03
## How tall (world m) to lift the sprite so its base sits on the ground at this node's y.
@export var prop_base_lift := true


func _ready() -> void:
	add_to_group("interactable3d")
	if prop_model != "":
		var m := PropModels3D.build(prop_model)
		m.name = "PropModel"
		add_child(m)
	elif prop_texture:
		var s := Sprite3D.new()
		s.name = "Prop"
		s.texture = prop_texture
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.shaded = false
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.pixel_size = prop_pixel_size
		if prop_base_lift:
			s.position.y = (prop_texture.get_height() * prop_pixel_size) * 0.5
		add_child(s)


func _has_required_verb() -> bool:
	if required_class_verb == "none" or required_class_verb == "":
		return true
		
	var v := required_class_verb.to_lower()
	var p1 := str(GameState.get_flag("P1_CLASS", "")).to_lower()
	var p2 := str(GameState.get_flag("P2_CLASS", "")).to_lower()
	
	if v == "unmake" and p1 == "voidweaver": return true
	if v == "resonate" and p1 == "harmonist": return true
	if v == "restore" and p1 == "mender": return true
	
	if v == "decipher" and p2 == "scholar": return true
	if v == "break" and p2 == "chainbreaker": return true
	if v == "vanish" and p2 == "whisper": return true
	
	return false

## Identical to actors/Interactable.interact() — same DialogueManager calls, same one-node wrap.
func interact() -> void:
	if not _has_required_verb():
		DialogueManager.start({
			"id": "examine_fail",
			"start": "n",
			"nodes": { "n": {
				"speaker": "",
				"text": "[color=#888888][i]" + failed_verb_text + "[/i][/color]",
				"portrait": "",
			} }
		})
		return
		
	if flag_on_interact != "":
		GameState.set_flag(flag_on_interact, true)
	if dialogue != "":
		DialogueManager.start(dialogue)
	elif examine_text != "":
		var _t := examine_text
		if required_class_verb != "":
			_t = "[color=#88bbff][i](" + required_class_verb.capitalize() + ")[/i][/color] " + _t
		DialogueManager.start({
			"id": "examine",
			"start": "n",
			"nodes": { "n": {
				"speaker": display_name,
				"text": _t,
				"portrait": portrait_id,
			} }
		})
