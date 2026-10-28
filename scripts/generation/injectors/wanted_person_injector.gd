## `WANTED_PERSON` (GDD §6, R22, M7) : le passager figure sur l'avis de
## recherche du jour. L'avis est calculé par le `CaseBuilder` à partir du cas
## lui-même (portrait, nom) : l'injecteur ne modifie rien, il vérifie que
## l'avis existe pour cet index et renvoie l'anomalie (preuve : le visage).
## Jamais tiré au hasard (aucun avis ne vise un index non prévu).
class_name WantedPersonInjector
extends AnomalyInjector


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.WANTED_PERSON


func inject(state: InjectionState) -> Anomaly:
	if active_rules(state, WantedRule).is_empty():
		return null
	for notice: WantedNotice in state.ctx.wanted:
		if notice.case_index == state.case.index:
			return make_anomaly(get_kind(), FieldRef.PASSENGER_DOCUMENT_ID, FieldRef.FACE_FIELD_ID,
					notice.full_name(), String(notice.id))
	return null
