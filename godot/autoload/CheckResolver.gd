extends RefCounted
class_name CheckResolver
## Skill-check resolution (GDD §7.2). Transparent, no hidden dice-hell.
##
## A check compares (Attribute + situational modifier + optional Fortune wildcard) vs a Threshold.
##   Deterministic core: if Attribute + flat mods >= Threshold, it passes (builds are legible).
##   Fortune wildcard: on `uncertain` checks, add rand(0, Fortune) — a lucky low-stat char can squeak
##   through without turning the game into a slot machine.
## Checks are content, not gates: every critical check must have a non-check alternative (§7.2, pillar 1).

## Difficulty thresholds (DCs). Values ARE the DC.
enum Difficulty { TRIVIAL = 3, EASY = 5, MODERATE = 7, HARD = 9, EXTREME = 11 }

## For UI tag colouring (UI-005): gold=passable, grey+lock=not, +Fortune=uncertain.
enum TagState { PASSABLE, LOCKED, UNCERTAIN }


## The flat, no-luck total for an attribute check.
static func deterministic_total(attr: String, situational_mod: int = 0) -> int:
	return GameState.get_attribute(attr) + situational_mod


## Would this check pass deterministically (before any Fortune)?
static func passes_deterministic(attr: String, dc: int, situational_mod: int = 0) -> bool:
	return deterministic_total(attr, situational_mod) >= dc


## Could this check pass at all, given Fortune's best roll? (Used for the UI tag on uncertain checks.)
static func could_pass_with_fortune(attr: String, dc: int, situational_mod: int = 0) -> bool:
	return deterministic_total(attr, situational_mod) + GameState.get_attribute("Fortune") >= dc


## The UI state for a dialogue option's inline check tag (UI-005).
static func tag_state(attr: String, dc: int, uncertain: bool, situational_mod: int = 0) -> TagState:
	if passes_deterministic(attr, dc, situational_mod):
		return TagState.PASSABLE
	if uncertain and could_pass_with_fortune(attr, dc, situational_mod):
		return TagState.UNCERTAIN
	return TagState.LOCKED


## Actually resolve a check when the player commits to it.
## Returns { passed:bool, total:int, dc:int, roll:int, uncertain:bool }.
static func resolve(attr: String, dc: int, uncertain: bool = false, situational_mod: int = 0) -> Dictionary:
	var roll := 0
	if uncertain:
		var fortune := GameState.get_attribute("Fortune")
		roll = randi_range(0, fortune)
	var total := deterministic_total(attr, situational_mod) + roll
	return {
		"passed": total >= dc,
		"total": total,
		"dc": dc,
		"roll": roll,
		"uncertain": uncertain,
	}
