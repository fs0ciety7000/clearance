## Décision du joueur (ARCHITECTURE §5.3) — émise par `EventBus.verdict_stamped`.
class_name Verdict
extends RefCounted

var case_id: StringName = &""
var kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE
## Discordances épinglées au moment du tampon (preuve d'un refus, D-024).
var flagged: Array[Discrepancy] = []
var questions_asked: Array[StringName] = []
## Mesuré depuis `documents_presented`.
var elapsed_sec: float = 0.0


func _init(p_case_id: StringName = &"", p_kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE) -> void:
	case_id = p_case_id
	kind = p_kind
