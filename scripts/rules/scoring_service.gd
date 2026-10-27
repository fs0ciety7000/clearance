## Notation d'un verdict (ARCHITECTURE §8, GDD §4.5, §5) — pur, statique.
##
## M4 : **minimal** — correct si le verdict tamponné est celui de la clé
## (`CaseKey.expected_verdict`, D-005). Un REFUS là où une DÉTENTION était
## attendue est correct (GDD §4.5 : « pas une citation »). Les violations
## manquées sont celles d'un cas fautif approuvé.
## M5 : preuve du refus (D-024/D-032), procédures (D-031), crédits, citations.
class_name ScoringService
extends RefCounted


static func score(verdict: Verdict, key: CaseKey, case_id: StringName) -> CaseResult:
	var result: CaseResult = CaseResult.new(case_id)
	if verdict == null or key == null:
		push_error("ScoringService.score: verdict ou clé manquant (%s)" % case_id)
		return result
	result.verdict = verdict
	result.verdict_kind = verdict.kind
	result.expected_verdict = key.expected_verdict
	result.elapsed_sec = verdict.elapsed_sec
	result.correct = is_correct(verdict.kind, key.expected_verdict)
	if verdict.kind == VerdictKind.Kind.APPROVE and key.expected_verdict != VerdictKind.Kind.APPROVE:
		result.missed_violations = key.expected_violations.duplicate()
	return result


static func is_correct(given: VerdictKind.Kind, expected: VerdictKind.Kind) -> bool:
	if given == expected:
		return true
	return given == VerdictKind.Kind.DENY and expected == VerdictKind.Kind.DETAIN
