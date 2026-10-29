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
		if not banned.exempt_contract_codes.is_empty():
			# M12 (R38) : ressortissant de Tycho sans contrat Kessler-Ashe valide.
			var unexempted: Anomaly = _inject_contract(state, banned)
			if unexempted != null:
				return unexempted
			continue
		if not banned.exempt_posts.is_empty():
			var anomaly: Anomaly = _inject_post(state, banned)
			if anomaly != null:
				return anomaly
			continue
		if banned.exempt_if_sponsored:
			# Acte III (R37) : un ressortissant de Tycho sans répondant ni
			# convocation (motif hors VISITE FAMILIALE).
			var closed: Anomaly = _inject_closed(state, banned)
			if closed != null:
				return closed
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


## Acte III (R37) : motif COMMERCE / TRANSIT (le Répondant éventuel est
## effacé : sans motif VISITE FAMILIALE il n'exempte plus) ; jamais sur un convoqué.
func _inject_closed(state: InjectionState, banned: FactionBannedRule) -> Anomaly:
	if state.ctx.has_valid_summons(state.case):
		return null
	var field_id: StringName = field_for(state.case, banned.permit_id, &"purpose")
	if field_id == &"" or not state.is_free(banned.permit_id, field_id):
		return null
	var sponsor_field: StringName = field_for(state.case, banned.permit_id, SponsorRule.SPONSOR_PATH)
	if sponsor_field != &"" and not state.is_free(banned.permit_id, sponsor_field):
		return null
	var permit: DocumentInstance = state.case.get_document(banned.permit_id)
	var original: Variant = permit.get_value(field_id)
	var purpose: StringName = StringName(str(state.param(&"purpose", "")))
	if purpose == &"" or purpose == Passenger.PURPOSE_FAMILY_VISIT:
		purpose = [Passenger.PURPOSE_TRADE, Passenger.PURPOSE_TRANSIT][state.rng.randi_range(0, 1)]
	permit.set_value(field_id, purpose)
	state.truth.purpose = purpose
	state.case.passenger_presented.purpose = purpose
	if sponsor_field != &"":
		permit.set_value(sponsor_field, "")
		state.truth.sponsor_id = ""
		state.case.passenger_presented.sponsor_id = ""
		state.mark(banned.permit_id, sponsor_field)
	state.mark(banned.permit_id, field_id)
	return make_anomaly(get_kind(), banned.permit_id, field_id, original, purpose)


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


## M12 (R38 « Tycho rééquilibrée ») : le contrat du porteur passe chez un autre
## employeur (code non exempté), cohérent sur le permis et le contrat (R25) ;
## sans contrat exempté (SC-93a), l'origine seule prouve le refus.
func _inject_contract(state: InjectionState, banned: FactionBannedRule) -> Anomaly:
	var c: Case = state.case
	var origin_field: StringName = field_for(c, banned.card_id, &"faction_id")
	if not banned.has_exempt_contract(c, state.ctx):
		if origin_field == &"":
			return null
		state.mark(banned.card_id, origin_field)
		return make_anomaly(get_kind(), banned.card_id, origin_field, null, Rule.visible_origin(c))
	var contract: DocumentInstance = c.get_own_document(banned.contract_id)
	var code_field: StringName = field_for(c, banned.contract_id, ContractSuspendedRule.CODE_PATH)
	var employer_field: StringName = field_for(c, banned.contract_id, &"employer")
	var permit_field: StringName = field_for(c, banned.permit_id, &"employer")
	if code_field == &"" or not state.is_free(banned.contract_id, code_field) \
			or (employer_field != &"" and not state.is_free(banned.contract_id, employer_field)) \
			or (permit_field != &"" and not state.is_free(banned.permit_id, permit_field)):
		return null
	var registry: Dictionary[String, String] = {}
	for rule: Rule in state.get_rule_set().rules:
		if rule is ContractConsistentRule:
			registry = (rule as ContractConsistentRule).employer_codes
	var faction: FactionDef = state.get_faction(Rule.visible_origin(c))
	var options: PackedStringArray = []
	if faction != null:
		for employer: String in faction.employers:
			var code: String = registry.get(employer, "")
			if not code.is_empty() and not banned.exempt_contract_codes.has(code):
				options.append(employer)
	if options.is_empty():
		return null
	var employer: String = options[state.rng.randi_range(0, options.size() - 1)]
	var new_code: String = registry[employer]
	var original: Variant = contract.get_value(code_field)
	contract.set_value(code_field, new_code)
	contract.serial = contract.serial.replace("-%s-" % str(original), "-%s-" % new_code)
	if employer_field != &"":
		contract.set_value(employer_field, employer)
		state.mark(banned.contract_id, employer_field)
	var permit: DocumentInstance = c.get_own_document(banned.permit_id)
	if permit != null and permit_field != &"":
		permit.set_value(permit_field, employer)
		state.mark(banned.permit_id, permit_field)
	for p: Passenger in [state.truth, c.passenger_presented]:
		p.employer = employer
		p.employer_code = new_code
	state.mark(banned.contract_id, code_field)
	var serial_field: StringName = field_for(c, banned.contract_id, &"document.serial")
	if serial_field != &"":
		state.mark(banned.contract_id, serial_field)
	if origin_field != &"":
		state.mark(banned.card_id, origin_field)
	return make_anomaly(get_kind(), banned.contract_id, code_field, original, new_code)
