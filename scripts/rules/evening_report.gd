## Conséquences d'une soirée (GDD §5.4) — produit par `EveningService.apply()`.
class_name EveningReport
extends RefCounted

## Fins anticipées (GDD §11.2) évaluées le soir.
const ENDING_NONE: StringName = &""
## F2 — Réaffectation (loyers impayés / dette prolongée).
const ENDING_REASSIGNED: StringName = &"f2_reassigned"
## F3 — Famille perdue (tous les proches `PERDU`).
const ENDING_FAMILY_LOST: StringName = &"f3_family_lost"

## Gravité d'un événement (couleur + icône à l'écran).
enum Tone { INFO, GOOD, WARNING, BAD }

var day_number: int = 0
var balance_before: int = 0
var spent: int = 0
var balance_after: int = 0
## Postes de la soirée, tels que réglés.
var lines: Array[ExpenseLine] = []
## Événements dans l'ordre : `{key: String, member: StringName, tone: Tone}`.
var events: Array[Dictionary] = []
## Foyer après la soirée.
var household: Household = null
var ending: StringName = ENDING_NONE


func add_event(key: String, tone: Tone, member: StringName = &"") -> void:
	events.append({"key": key, "member": member, "tone": tone})


func has_event(key: String, member: StringName = &"") -> bool:
	for event: Dictionary in events:
		if event["key"] == key and (member == &"" or event["member"] == member):
			return true
	return false


func is_game_over() -> bool:
	return ending != ENDING_NONE
