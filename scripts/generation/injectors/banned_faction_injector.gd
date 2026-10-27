## `BANNED_FACTION` (GDD §6, R19, M7) : un ressortissant d'une origine interdite
## du jour (THR après l'attentat du J8) se présente avec un motif non exempté
## (pas DIPLOMATIQUE). Les papiers restent cohérents : ce n'est pas une
## discordance mais une règle. Ne s'applique qu'aux passagers de l'origine
## interdite (le `CaseBuilder` donne aux autres le motif exempté, propre).
## Paramètre : `purpose`.
class_name BannedFactionInjector
extends AnomalyInjector

const PURPOSES: Array[StringName] = [Passenger.PURPOSE_FAMILY_VISIT, Passenger.PURPOSE_TRADE, Passenger.PURPOSE_TRANSIT]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.BANNED_FACTION


func inject(state: InjectionState) -> Anomaly:
	for rule: Rule in active_rules(state, FactionBannedRule):
		var banned: FactionBannedRule = rule
		if not banned.is_banned_origin(Rule.visible_origin(state.case)):
			continue
		var field_id: StringName = field_for(state.case, banned.permit_id, &"purpose")
		if field_id == &"" or not state.is_free(banned.permit_id, field_id):
			continue
		var permit: DocumentInstance = state.case.get_document(banned.permit_id)
		var original: Variant = permit.get_value(field_id)
		var purpose: StringName = StringName(str(state.param(&"purpose", "")))
		if purpose == &"":
			purpose = PURPOSES[state.rng.randi_range(0, PURPOSES.size() - 1)]
		if banned.exempt_purposes.has(purpose):
			return null
		permit.set_value(field_id, purpose)
		state.truth.purpose = purpose
		state.case.passenger_presented.purpose = purpose
		state.mark(banned.permit_id, field_id)
		return make_anomaly(get_kind(), banned.permit_id, field_id, original, purpose)
	return null
