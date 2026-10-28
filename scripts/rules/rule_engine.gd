## Moteur de règles (ARCHITECTURE §6) — fonctions statiques pures.
##
## `validate()` évalue les règles **actives** (celles du RuleSet) et agrège
## leurs violations. Le verdict attendu en est déduit (ajustement « vérité
## terrain », D-005) : jamais des anomalies injectées.
class_name RuleEngine
extends RefCounted

## Sévérité à partir de laquelle une violation appelle une DÉTENTION (GDD §4.5).
const DETAIN_SEVERITY: int = 3


## Violations du cas pour le RuleSet donné (vide = cas conforme).
static func validate(case: Case, rule_set: RuleSet, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if case == null or rule_set == null:
		push_error("RuleEngine.validate: cas ou RuleSet manquant")
		return violations
	for rule: Rule in rule_set.rules:
		if rule == null:
			push_error("RuleEngine.validate: règle nulle dans « %s »" % rule_set.id)
			continue
		violations.append_array(rule.evaluate(case, ctx))
	return violations


## DETAIN si une violation a une sévérité ≥ 3, DENY si ≥ 1 violation, sinon APPROVE.
static func expected_verdict(violations: Array[Violation]) -> VerdictKind.Kind:
	if violations.is_empty():
		return VerdictKind.Kind.APPROVE
	for violation: Violation in violations:
		if violation.severity >= DETAIN_SEVERITY:
			return VerdictKind.Kind.DETAIN
	return VerdictKind.Kind.DENY


## Clé de réponse calculée sur le cas **final** (après injection).
static func build_case_key(case: Case, truth: Passenger, anomalies: Array[Anomaly],
		rule_set: RuleSet, ctx: RuleContext) -> CaseKey:
	var key: CaseKey = CaseKey.new()
	key.truth = truth
	key.anomalies = anomalies.duplicate()
	key.expected_violations = validate(case, rule_set, ctx)
	key.expected_verdict = expected_verdict(key.expected_violations)
	return key
