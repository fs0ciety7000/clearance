## `UNDECLARED_IMPLANT` (GDD §6, R15, M7) : un implant visible manque à la
## liste « Implants déclarés » de la carte — soit la carte omet un implant du
## passager, soit le passager porte un implant (visible) jamais déclaré
## (contrebande `DER-19`, vétéran `MIL-`). L'apparence n'est jamais touchée.
## Paramètre : `implant` (code imposé, ex. `DER-19`).
class_name UndeclaredImplantInjector
extends AnomalyInjector

const CIVIL_FALLBACK: PackedStringArray = ["OPT-3", "NX-12", "KIN-5", "DER-6"]
const CONTRABAND: PackedStringArray = ["DER-19"]
const MILITARY: PackedStringArray = ["MIL-2", "MIL-9"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.UNDECLARED_IMPLANT


func inject(state: InjectionState) -> Anomaly:
	var rules: Array[Rule] = active_rules(state, ImplantsDeclaredRule)
	if rules.is_empty():
		return null
	var rule: ImplantsDeclaredRule = rules[0]
	var field_id: StringName = field_for(state.case, rule.document_id, &"implants")
	if field_id == &"" or not state.is_free(rule.document_id, field_id) \
			or state.filter_documents([rule.document_id]).is_empty():
		return null
	var card: DocumentInstance = state.case.get_document(rule.document_id)
	var declared: PackedStringArray = ImplantsDeclaredRule.as_list(card.get_value(field_id)).duplicate()
	var original: PackedStringArray = declared.duplicate()
	var forced: String = str(state.param(&"implant", ""))
	var presented: Passenger = state.case.passenger_presented
	if forced.is_empty() and not presented.implants.is_empty() and state.rng.chance(0.5):
		# La carte omet un implant réel.
		var code: String = presented.implants[state.rng.randi_range(0, presented.implants.size() - 1)]
		declared.remove_at(declared.find(code))
		card.set_value(field_id, declared)
	else:
		var code: String = forced if not forced.is_empty() else pick_code(state, presented.faction_id, presented.implants)
		if code.is_empty() or presented.implants.has(code):
			return null
		presented.implants.append(code)
		state.truth.implants.append(code)
	state.mark(rule.document_id, field_id)
	return make_anomaly(get_kind(), rule.document_id, field_id, original, presented.implants.duplicate())


## Implant visible tiré : civil de l'origine, contrebande, ou `MIL-` (Tharsis).
static func pick_code(state: InjectionState, faction_id: StringName, exclude: PackedStringArray = []) -> String:
	var pool: PackedStringArray = CONTRABAND.duplicate()
	var faction: FactionDef = state.get_faction(faction_id)
	var civil: PackedStringArray = []
	if faction != null:
		for code: StringName in faction.implant_weights:
			civil.append(String(code))
	pool.append_array(civil if not civil.is_empty() else CIVIL_FALLBACK)
	if faction_id == &"thr":
		pool.append_array(MILITARY)
	for code: String in exclude:
		while pool.has(code):
			pool.remove_at(pool.find(code))
	return pool[state.rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else ""
