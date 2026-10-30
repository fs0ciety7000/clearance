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
## M13 (D-145, D-146) : une fouille a été faite (portique engagé, motif
## confirmé ou fouille « sans motif » confirmée).
var search_done: bool = false
## Motif figé à la **demande** (`SearchLayout.MOTIVE_*`), `&""` = aucun
## motif : FOUILLE SANS MOTIF si le passager était en règle (R44).
var search_motive: StringName = &""
## Zones scannées, dans l'ordre (`SearchLayout.ZONE_*`).
var zones_scanned: Array[StringName] = []


func _init(p_case_id: StringName = &"", p_kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE) -> void:
	case_id = p_case_id
	kind = p_kind
