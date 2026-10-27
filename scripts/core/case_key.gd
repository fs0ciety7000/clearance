## Clé de réponse d'un cas (ARCHITECTURE §5.3, §6) — jamais transmise à l'UI.
##
## `expected_violations` et `expected_verdict` sont **calculés par le
## `RuleEngine`** sur le cas final (`RuleEngine.build_case_key`), jamais déduits
## des anomalies (D-005, ajustement « vérité terrain »).
class_name CaseKey
extends RefCounted

## Identité réelle du passager.
var truth: Passenger = null
var anomalies: Array[Anomaly] = []
var expected_violations: Array[Violation] = []
var expected_verdict: VerdictKind.Kind = VerdictKind.Kind.APPROVE


## Identifiants des règles violées (dédoublonnés, ordre d'apparition).
func get_violated_rule_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for violation: Violation in expected_violations:
		if not ids.has(violation.rule_id):
			ids.append(violation.rule_id)
	return ids
