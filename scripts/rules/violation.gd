## Sortie d'une règle (ARCHITECTURE §5.3) : une infraction prouvée par des champs.
class_name Violation
extends RefCounted

var rule_id: StringName = &""
## Champs qui prouvent la violation (preuve recherchée par le joueur).
var refs: Array[FieldRef] = []
var reason_key: String = ""
## Copiée de la règle : `RuleEngine.expected_verdict` n'a pas à la rechercher.
var severity: int = 2


func _init(p_rule_id: StringName = &"", p_refs: Array[FieldRef] = [], p_reason_key: String = "", p_severity: int = 2) -> void:
	rule_id = p_rule_id
	refs = p_refs.duplicate()
	reason_key = p_reason_key
	severity = p_severity


func has_ref(ref: FieldRef) -> bool:
	for own: FieldRef in refs:
		if own.equals(ref):
			return true
	return false


## Vrai si une discordance confirmée recoupe cette violation
## (`Discrepancy.a/b` ∩ `refs` ≠ ∅, GDD §4.2, D-024).
func is_documented_by(discrepancy: Discrepancy) -> bool:
	if discrepancy == null or not discrepancy.confirmed:
		return false
	return has_ref(discrepancy.a) or has_ref(discrepancy.b)


func _to_string() -> String:
	var keys: PackedStringArray = []
	for ref: FieldRef in refs:
		keys.append(ref.key())
	return "Violation(%s, [%s])" % [rule_id, ", ".join(keys)]
