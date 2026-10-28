## `BANNED_FACTION` (GDD §6, R19, M7) : un ressortissant d'une origine interdite
## du jour (THR après l'attentat du J8) se présente avec un motif non exempté
## (pas DIPLOMATIQUE). Les papiers restent cohérents : ce n'est pas une
## discordance mais une règle. Ne s'applique qu'aux passagers de l'origine
## interdite (le `CaseBuilder` donne aux autres le motif exempté, propre).
## Paramètre : `purpose`. Acte II (R31, exemption par le poste du contrat) :
## le poste du contrat devient un poste non exempté (`post` imposable).
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
		if not banned.exempt_posts.is_empty():
			var anomaly: Anomaly = _inject_post(state, banned)
			if anomaly != null:
				return anomaly
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


## Postes non exemptés de R31 (contrat sur un poste ordinaire).
const ORDINARY_POSTS: Array[StringName] = [&"post_manutention", &"post_logistique", &"post_maintenance", &"post_archives"]


func _inject_post(state: InjectionState, banned: FactionBannedRule) -> Anomaly:
	if not banned.has_exempt_post(state.case):
		return null
	var contract: DocumentInstance = state.case.get_own_document(banned.contract_id)
	var field_id: StringName = field_for(state.case, banned.contract_id, &"post")
	if field_id == &"" or not state.is_free(banned.contract_id, field_id):
		return null
	var original: Variant = contract.get_value(field_id)
	var post: StringName = StringName(str(state.param(&"post", "")))
	if post == &"":
		post = ORDINARY_POSTS[state.rng.randi_range(0, ORDINARY_POSTS.size() - 1)]
	if banned.exempt_posts.has(post):
		return null
	contract.set_value(field_id, post)
	state.truth.post = post
	state.case.passenger_presented.post = post
	state.mark(banned.contract_id, field_id)
	return make_anomaly(get_kind(), banned.contract_id, field_id, original, post)
