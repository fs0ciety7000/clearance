## Résultat d'un cas après le tampon (ARCHITECTURE §5.3, §7) — émis par
## `EventBus.case_resolved`.
##
## M4 : scoring **minimal** (verdict correct / incorrect, violations manquées).
## Crédits, citations et prime (GDD §5) arrivent avec le `ScoringService`
## complet en M5 : les champs existent déjà, à 0.
## Le booth n'en lit que `verdict_kind` (choix de la sortie).
class_name CaseResult
extends RefCounted

var case_id: StringName = &""
## Verdict tamponné par le joueur.
var verdict_kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE
## Verdict attendu (`CaseKey.expected_verdict`), révélé après le tampon.
var expected_verdict: VerdictKind.Kind = VerdictKind.Kind.APPROVE
var correct: bool = false
## Violations du cas non sanctionnées (approbation d'un cas fautif) : feedback.
var missed_violations: Array[Violation] = []
## Temps d'inspection depuis `documents_presented`.
var elapsed_sec: float = 0.0
## Le verdict tamponné (discordances épinglées, questions posées).
var verdict: Verdict = null
## M5 : crédits gagnés / perdus, citation émise.
var credits_delta: int = 0
var citation_reason_key: String = ""


func _init(p_case_id: StringName = &"") -> void:
	case_id = p_case_id
