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
	# M12 : liste de chaque règle active (onglet Révocations, Liste du Conseil,
	# cartes volées — `RevokedIdRule.entries`).
	for rule: Rule in active_rules(state, RevokedIdRule):
		var listed: RevokedIdRule = rule
		for entry: RevokedEntry in listed.entries(state.ctx):
			if entry.case_index == state.case.index and not (listed.honor_reinstatements and entry.is_reinstated(state.ctx.today)):
				var field_id: StringName = field_for(state.case, listed.document_id, &"citizen_id")
				return make_anomaly(get_kind(), listed.document_id, field_id, entry.citizen_id, String(entry.id))
	return null
