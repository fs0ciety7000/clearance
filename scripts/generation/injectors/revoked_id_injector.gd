## `REVOKED_ID` (Acte II, R30 ; docs/ACT2.md §2.2) : le N° ID du passager
## figure à l'onglet Révocations du jour. Comme `WANTED_PERSON` (D-056), la
## liste est calculée par le `CaseBuilder` au début du jour à partir du cas
## lui-même : l'injecteur ne modifie rien, il vérifie qu'une entrée vise cet
## index. Jamais combiné à une autre anomalie, jamais tiré au hasard.
class_name RevokedIdInjector
extends AnomalyInjector


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.REVOKED_ID


func inject(state: InjectionState) -> Anomaly:
	if active_rules(state, RevokedIdRule).is_empty():
		return null
	for entry: RevokedEntry in state.ctx.revoked:
		if entry.case_index == state.case.index:
			var field_id: StringName = field_for(state.case, &"id_card", &"citizen_id")
			return make_anomaly(get_kind(), &"id_card", field_id, entry.citizen_id, String(entry.id))
	return null
