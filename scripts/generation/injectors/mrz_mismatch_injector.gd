## `MRZ_MISMATCH` (GDD §6, R21, M7) : la bande MRZ de la carte ne recopie pas
## fidèlement le N° ID, l'origine, le nom ou les prénoms (jamais les deux
## derniers caractères, GDD §4.1). Paramètres : `component` (`family_name`,
## `given_name`, `citizen_id`, `faction_id`), `mrz_value` (texte MRZ imposé de
## la composante, ex. « PHILIPA »).
class_name MrzMismatchInjector
extends AnomalyInjector

const MRZ_PATH: StringName = &"document.mrz"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.MRZ_MISMATCH


func inject(state: InjectionState) -> Anomaly:
	var rules: Array[Rule] = active_rules(state, MrzConsistentRule)
	if rules.is_empty():
		return null
	var rule: MrzConsistentRule = rules[0]
	var c: Case = state.case
	var mrz_field: StringName = field_for(c, rule.document_id, MRZ_PATH)
	if mrz_field == &"" or not state.is_free(rule.document_id, mrz_field) \
			or state.filter_documents([rule.document_id]).is_empty():
		return null
	var doc: DocumentInstance = c.get_document(rule.document_id)
	var forced: StringName = StringName(str(state.param(&"component", "")))
	var components: Array[StringName] = []
	for component: StringName in Mrz.COMPONENTS:
		var field_id: StringName = field_for(c, rule.document_id, component)
		if field_id != &"" and state.is_free(rule.document_id, field_id) and (forced == &"" or forced == component):
			components.append(component)
	if components.is_empty():
		return null
	var component: StringName = components[state.rng.randi_range(0, components.size() - 1)]
	var parsed: Dictionary[StringName, String] = Mrz.parse(doc.mrz)
	if parsed.is_empty():
		return null
	var current: String = parsed[component]
	var altered: String = str(state.param(&"mrz_value", ""))
	if altered.is_empty():
		altered = alter(state, component, current)
	if altered == current:
		return null
	var original: String = doc.mrz
	doc.mrz = Mrz.with_component(doc.mrz, component, altered)
	state.mark(rule.document_id, mrz_field)
	state.mark(rule.document_id, field_for(c, rule.document_id, component))
	return make_anomaly(get_kind(), rule.document_id, mrz_field, original, doc.mrz)


static func alter(state: InjectionState, component: StringName, value: String) -> String:
	match component:
		Mrz.COMPONENT_ORIGIN:
			var codes: Array[String] = []
			for faction: FactionDef in state.data.factions.values():
				if faction.code != value:
					codes.append(faction.code)
			codes.sort()
			return codes[state.rng.randi_range(0, codes.size() - 1)] if not codes.is_empty() else value
		Mrz.COMPONENT_ID:
			# M12 (Garde, subtil) : sosie visuel d'un caractère du bloc `XXXX`.
			if state.param_bool(CaseBuilder.SUBTLE_PARAM, false):
				var last: Array[int] = []
				for k: int in range(maxi(value.length() - 4, 0), value.length()):
					last.append(k)
				var confused: String = IdMismatchInjector.confuse_one(state.rng, value, last)
				if not confused.is_empty():
					return confused
			# Un caractère du bloc `XXXX` (le préfixe et le chiffre d'origine restent).
			var index: int = value.length() - 1 - state.rng.randi_range(0, 3)
			var pool: String = PassengerGenerator.ID_SAFE_CHARS.replace(value[index], "")
			return value.substr(0, index) + pool[state.rng.randi_range(0, pool.length() - 1)] + value.substr(index + 1)
	# Nom / prénoms : une lettre supprimée (doublée) ou remplacée.
	for i: int in range(1, value.length()):
		if value[i] == value[i - 1] and value[i] != Mrz.FILLER and state.rng.chance(0.5):
			return value.substr(0, i) + value.substr(i + 1)
	return FieldMismatchInjector.substitute_letter(state.rng, value)
