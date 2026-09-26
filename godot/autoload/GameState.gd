extends Node
## GameState — the persistent flag registry + inventory + protagonist context.
##
## The Legacy System (GDD §5, §11) IS this dictionary, serialized to the save file.
## It is NEVER cleared mid-run: Part One writes flags, Part Two and the Coda read them.
## Human-readable JSON save so flags are testable in isolation (write in a P1 test scene,
## read in a P2 test scene — the Ledger checkpoint, GDD §11).

signal flag_changed(key: String, value)
signal strain_changed(value: int, band: int)
signal strain_silence_triggered()
signal quest_updated(quest_id: String, state: String, stage: int, data: Dictionary)

const SAVE_PATH := "user://kayos_save.json"

## The seven attributes (GDD §7.1). Point-buy at creation; 1-10 range.
const ATTRIBUTES := ["Vigor", "Resilience", "Celerity", "Arcana", "Acumen", "Magnetism", "Fortune"]

## Mental Strain bands (GDD §7.3).
enum StrainBand { CALM, FRAYED, STRAINED, BREAKING, SILENCE }

## Persistent run state -------------------------------------------------------
var flags: Dictionary = {}
var quests: Dictionary = {}                   # quest_id -> Dictionary
var inventory: Array[String] = []
var current_protagonist: String = "elorin"   # "elorin" | "grakkar" | "talindir"
var current_scene: String = ""
var player_position: Vector2 = Vector2.ZERO
var mental_strain: int = 0                    # 0-100 (GDD §7.3)
var attributes: Dictionary = {}               # attr name -> int (set at character creation)


func _ready() -> void:
	_seed_default_flags()
	_seed_default_attributes()


## Fresh run (New Game). The registry is reseeded — never call this mid-run: the Legacy
## System depends on the dictionary surviving from Part One into Part Two and the Coda.
func reset() -> void:
	flags.clear()
	_seed_default_flags()
	quests.clear()
	inventory.clear()
	attributes.clear()
	_seed_default_attributes()
	current_protagonist = "talindir"   # the game opens on the Cold Open
	current_scene = ""
	player_position = Vector2.ZERO
	mental_strain = 0
	strain_changed.emit(mental_strain, get_strain_band())


## Quest API ------------------------------------------------------------------
func start_quest(quest_id: String, title: String, desc: String, category: String = "side", stages: Array = [], rewards: Dictionary = {}) -> void:
	if quests.has(quest_id) and quests[quest_id].get("state") != "inactive":
		return
	quests[quest_id] = {
		"id": quest_id,
		"title": title,
		"desc": desc,
		"category": category, # "main" or "side"
		"state": "active",
		"stage": 1,
		"stages": stages,
		"rewards": rewards,
	}
	quest_updated.emit(quest_id, "active", 1, quests[quest_id])


func set_quest_stage(quest_id: String, stage: int, stage_desc: String = "") -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	q["stage"] = stage
	if stage_desc != "":
		if not q.has("stages"):
			q["stages"] = []
		while q["stages"].size() < stage:
			q["stages"].append("")
		q["stages"][stage - 1] = stage_desc
	quest_updated.emit(quest_id, str(q.get("state", "active")), stage, q)


func complete_quest(quest_id: String, rewards: Dictionary = {}) -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	q["state"] = "completed"
	if not rewards.is_empty():
		if not q.has("rewards"):
			q["rewards"] = {}
		q["rewards"].merge(rewards, true)
	quest_updated.emit(quest_id, "completed", int(q.get("stage", 1)), q)


func fail_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	q["state"] = "failed"
	quest_updated.emit(quest_id, "failed", int(q.get("stage", 1)), q)


func get_quest(quest_id: String) -> Dictionary:
	return quests.get(quest_id, {})


func get_quest_state(quest_id: String) -> String:
	if not quests.has(quest_id):
		return "inactive"
	return str(quests[quest_id].get("state", "inactive"))


func get_active_quests() -> Array:
	var list := []
	for q in quests.values():
		if q.get("state") == "active":
			list.append(q)
	return list


func get_completed_quests() -> Array:
	var list := []
	for q in quests.values():
		if q.get("state") == "completed":
			list.append(q)
	return list


## Attribute API --------------------------------------------------------------
func get_attribute(attr: String) -> int:
	return int(attributes.get(attr, 0))

func set_attribute(attr: String, value: int) -> void:
	attributes[attr] = clampi(value, 1, 10)

func _seed_default_attributes() -> void:
	# Base 3 in each (GDD §7.1). Real values set by character creation (Phase 2.4).
	for a in ATTRIBUTES:
		if not attributes.has(a):
			attributes[a] = 3


## Mental Strain API (GDD §7.3) -----------------------------------------------
## Never a game-over: at 100 a Silence scene fires and Strain resets to 60.
func add_strain(delta: int) -> void:
	var before := mental_strain
	mental_strain = clampi(mental_strain + delta, 0, 100)
	if mental_strain != before:
		strain_changed.emit(mental_strain, get_strain_band())
	if mental_strain >= 100:
		strain_silence_triggered.emit()
		mental_strain = 60
		strain_changed.emit(mental_strain, get_strain_band())

func get_strain_band() -> StrainBand:
	if mental_strain >= 100: return StrainBand.SILENCE
	if mental_strain >= 75:  return StrainBand.BREAKING
	if mental_strain >= 50:  return StrainBand.STRAINED
	if mental_strain >= 25:  return StrainBand.FRAYED
	return StrainBand.CALM


## Flag API -------------------------------------------------------------------
func get_flag(key: String, default_value = null):
	return flags.get(key, default_value)

func set_flag(key: String, value) -> void:
	flags[key] = value
	flag_changed.emit(key, value)

func has_flag(key: String) -> bool:
	return flags.has(key)

## Increment an int flag by delta, clamped to [min_v, max_v]. Used for 0-3 / 0-4 scales.
func bump_flag(key: String, delta: int, min_v: int = 0, max_v: int = 99) -> void:
	set_flag(key, clampi(int(flags.get(key, 0)) + delta, min_v, max_v))


## Save / load ----------------------------------------------------------------
func save_game() -> void:
	var data := {
		"flags": flags,
		"quests": quests,
		"inventory": inventory,
		"current_protagonist": current_protagonist,
		"current_scene": current_scene,
		"player_position": {"x": player_position.x, "y": player_position.y},
		"mental_strain": mental_strain,
		"attributes": attributes,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	flags = parsed.get("flags", {})
	quests = parsed.get("quests", {})
	inventory.assign(parsed.get("inventory", []))
	current_protagonist = parsed.get("current_protagonist", "elorin")
	current_scene = parsed.get("current_scene", "")
	var p: Dictionary = parsed.get("player_position", {"x": 0, "y": 0})
	player_position = Vector2(p.get("x", 0), p.get("y", 0))
	mental_strain = int(parsed.get("mental_strain", 0))
	var saved_attrs = parsed.get("attributes", {})
	if typeof(saved_attrs) == TYPE_DICTIONARY and not saved_attrs.is_empty():
		attributes = saved_attrs.duplicate()
	return true


## Default flag registry (GDD §11) --------------------------------------------
## Defaults only. Real values are written by reachable choices. Grouped by part.
func _seed_default_flags() -> void:
	# Demo 1 holds only the Cold Open; the full game's flag registry lives in the main project.
	flags["COLDOPEN_HONEST"] = false
