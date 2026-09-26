extends Node
## DialogueManager — loads conversation resources, walks nodes, evaluates checks/flags,
## emits signals to the UI. Full spec: GDD §8.1.
##
## Conversation format (JSON or Dictionary):
##   { "id": "conv_id", "start": "node_key", "nodes": { "node_key": <node>, ... } }
## Node:
##   { "speaker": "elorin", "portrait": "PO-001", "text": "...",
##     "set_flags": {"KEY": val}?, "strain": +5?, "choices": [<choice>, ...]? }
## Choice:
##   { "text": "...", "check": {"attr":"Acumen","dc":7,"uncertain":false}?,
##     "require_flag": {"KEY": ">=2"}?, "goto": "next", "goto_fail": "fail"?, "set_flags": {...}? }
##
## Rules (GDD §8.1):
##  - Unmet require_flag  -> choice HIDDEN.
##  - Failed check        -> choice SHOWN but LOCKED (Fallout transparency).
##  - goto_fail routes a failed check somewhere meaningful (never a dead stop).
##  - Flags/strain apply immediately and re-evaluate availability on the next node.

signal dialogue_started(conversation_id: String)
signal node_entered(node: Dictionary)          # {speaker, portrait, text}
signal choices_ready(choices: Array)           # [{index, text, state, enabled, check}]
signal dialogue_finished(conversation_id: String)

var _conversation: Dictionary = {}
var _nodes: Dictionary = {}
var _current_node_id: String = ""
var _active: bool = false


func is_active() -> bool:
	return _active


## Start a conversation. `source` may be a conversation Dictionary or a res:// JSON path.
func start(source, start_node: String = "") -> void:
	if source is String:
		_conversation = _load_conversation_file(source)
	elif source is Dictionary:
		_conversation = source
	else:
		push_error("DialogueManager.start: source must be a path or Dictionary.")
		return
	_nodes = _conversation.get("nodes", {})
	if _nodes.is_empty():
		push_error("DialogueManager.start: conversation has no nodes.")
		return
	_active = true
	dialogue_started.emit(str(_conversation.get("id", "")))
	var start_key := start_node if start_node != "" else str(_conversation.get("start", ""))
	_enter_node(start_key)


## Dismiss a terminal (choiceless) node — the UI calls this on a "continue" click.
func advance() -> void:
	if not _active:
		return
	var node: Dictionary = _nodes.get(_current_node_id, {})
	if node.get("choices", []).is_empty():
		_finish()


## Advance by choosing an option. `index` is the choice's ORIGINAL index within the node.
func choose(index: int) -> void:
	if not _active:
		return
	var node: Dictionary = _nodes.get(_current_node_id, {})
	var choices: Array = node.get("choices", [])
	if index < 0 or index >= choices.size():
		push_error("DialogueManager.choose: invalid index %d" % index)
		return
	var choice: Dictionary = choices[index]

	var next_id: String = str(choice.get("goto", ""))
	# Resolve a check, if present: pass -> goto, fail -> goto_fail (fallback to goto).
	if choice.has("check"):
		var c: Dictionary = choice["check"]
		var result := CheckResolver.resolve(
			str(c.get("attr", "")), int(c.get("dc", 0)), bool(c.get("uncertain", false)))
		if not result["passed"]:
			next_id = str(choice.get("goto_fail", choice.get("goto", "")))

	# Apply flags and quest actions set by choosing this option.
	_apply_set_flags(choice.get("set_flags", {}))
	_apply_quest_actions(choice)

	if next_id == "":
		_finish()
	else:
		_enter_node(next_id)


## --- internals ---------------------------------------------------------------
func _enter_node(node_id: String) -> void:
	if not _nodes.has(node_id):
		_finish()
		return
	_current_node_id = node_id
	var node: Dictionary = _nodes[node_id]

	# Side effects on entry (GDD §8.1): set_flags, then strain, then quest actions.
	_apply_set_flags(node.get("set_flags", {}))
	_apply_quest_actions(node)
	if node.has("strain"):
		GameState.add_strain(int(node["strain"]))

	node_entered.emit({
		"speaker": str(node.get("speaker", "")),
		"portrait": str(node.get("portrait", "")),
		"text": str(node.get("text", "")),
	})

	var raw_choices: Array = node.get("choices", [])
	if raw_choices.is_empty():
		# Terminal node: let the UI show the line, then finish.
		choices_ready.emit([])
		return

	var available: Array = []
	var band: int = GameState.get_strain_band()   # 0 Calm..4 Silence (GDD §7.3)
	for i in raw_choices.size():
		var ch: Dictionary = raw_choices[i]
		# require_flag -> hidden if unmet.
		if ch.has("require_flag") and not _require_flags_met(ch["require_flag"]):
			continue
		# Strain-band gating: `min_band` reveals desperate options only at/above a band;
		# `max_band` hides composed options once Strain climbs past a band.
		if ch.has("min_band") and band < int(ch["min_band"]):
			continue
		if ch.has("max_band") and band > int(ch["max_band"]):
			continue
		var state := "normal"
		var enabled := true
		var check_info = null
		if ch.has("check"):
			var c: Dictionary = ch["check"]
			check_info = c
			var ts := CheckResolver.tag_state(
				str(c.get("attr", "")), int(c.get("dc", 0)), bool(c.get("uncertain", false)))
			match ts:
				CheckResolver.TagState.PASSABLE:  state = "passable"
				CheckResolver.TagState.UNCERTAIN: state = "uncertain"
				CheckResolver.TagState.LOCKED:
					state = "locked"
					enabled = false   # shown, but not selectable
		available.append({
			"index": i, "text": str(ch.get("text", "")),
			"state": state, "enabled": enabled, "check": check_info,
		})
	choices_ready.emit(available)


func _finish() -> void:
	_active = false
	var id := str(_conversation.get("id", ""))
	dialogue_finished.emit(id)


func _apply_set_flags(set_flags) -> void:
	if typeof(set_flags) != TYPE_DICTIONARY:
		return
	for key in set_flags:
		GameState.set_flag(key, set_flags[key])


func _apply_quest_actions(data: Dictionary) -> void:
	if data.has("start_quest"):
		var sq = data["start_quest"]
		if sq is Dictionary:
			GameState.start_quest(
				str(sq.get("id", "")),
				str(sq.get("title", "")),
				str(sq.get("desc", "")),
				str(sq.get("category", "side")),
				sq.get("stages", []),
				sq.get("rewards", {})
			)
		elif sq is String:
			GameState.start_quest(sq, sq, "")

	if data.has("advance_quest") or data.has("set_quest_stage"):
		var aq = data.get("advance_quest", data.get("set_quest_stage"))
		if aq is Dictionary:
			GameState.set_quest_stage(str(aq.get("id", "")), int(aq.get("stage", 1)), str(aq.get("desc", "")))

	if data.has("complete_quest"):
		var cq = data["complete_quest"]
		if cq is Dictionary:
			GameState.complete_quest(str(cq.get("id", "")), cq.get("rewards", {}))
		elif cq is String:
			GameState.complete_quest(cq)

	if data.has("fail_quest"):
		var fq = data["fail_quest"]
		if fq is Dictionary:
			GameState.fail_quest(str(fq.get("id", "")))
		elif fq is String:
			GameState.fail_quest(fq)


func _require_flags_met(require: Dictionary) -> bool:
	for key in require:
		if not _flag_condition_met(key, require[key]):
			return false
	return true


## Condition may be a direct value (equality) or a string operator like ">=2", "<1", "!=X".
func _flag_condition_met(key: String, cond) -> bool:
	var current = GameState.get_flag(key)
	if typeof(cond) == TYPE_STRING:
		var s: String = cond
		for op in [">=", "<=", "!=", "==", ">", "<"]:
			if s.begins_with(op):
				var rhs := s.substr(op.length()).strip_edges()
				return _compare(current, op, rhs)
	return current == cond   # direct equality (bool/int/string)


func _compare(current, op: String, rhs: String) -> bool:
	# Numeric comparison when both sides look numeric; else string equality ops only.
	var cur_num := float(current) if (typeof(current) in [TYPE_INT, TYPE_FLOAT]) else NAN
	var rhs_is_num := rhs.is_valid_float()
	if not is_nan(cur_num) and rhs_is_num:
		var r := float(rhs)
		match op:
			">=": return cur_num >= r
			"<=": return cur_num <= r
			">":  return cur_num > r
			"<":  return cur_num < r
			"==": return is_equal_approx(cur_num, r)
			"!=": return not is_equal_approx(cur_num, r)
	# Non-numeric: only == / != are meaningful.
	match op:
		"==": return str(current) == rhs
		"!=": return str(current) != rhs
	return false


func _load_conversation_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueManager: conversation file not found: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueManager: conversation file is not a JSON object: " + path)
		return {}
	return parsed
