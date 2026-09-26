extends Resource
class_name CharacterData
## One data resource per character (the "database entry"). A single reusable NPC.tscn reads this
## to know who it is: which sprite sheet to animate, which portrait to show in dialogue, its name,
## faction palette, and default conversation. Create instances as .tres files in data/characters/
## and pick them in the Inspector — GDD §13 ("NPCs = base NPC scene + per-character data resource").

enum Faction { NOCTARI, SOLARI, ORC, TERRAN, HUMAN, SYLVARI, OTHER }

@export var id: String = ""                       # Asset Bible ID, e.g. "CH-001"
@export var display_name: String = ""             # e.g. "Elorin Voidweaver"
@export var faction: Faction = Faction.NOCTARI    # drives palette / social reactions
@export var portrait: Texture2D                    # PO-### (painterly, Linear filter)
@export var sprite: Texture2D                       # CH-### static/idle sprite (48x72, locked). Drag
                                                    # cleaned PNG here to swap this character's look
                                                    # everywhere at once. Superseded by sprite_frames
                                                    # once walk animations exist.
@export var sprite_frames: SpriteFrames            # 4-dir walk animations (Nearest filter)
## The 3D model this character wears: a rigged Meshy character from res://assets/meshy/rigged/
## (see res://data/character_rigs.json). Empty = the primitive CharacterModel3D figure.
@export_file("*.glb") var model_rig: String = ""
@export_file("*.tres", "*.json") var default_dialogue: String = ""  # conversation resource
@export_multiline var editor_notes: String = ""   # designer notes, not shown in game
