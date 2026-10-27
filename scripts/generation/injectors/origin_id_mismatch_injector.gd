## `ORIGIN_ID_MISMATCH` (🟡 GDD §6, LORE §5) : « ID d'origine falsifiée » — le
## premier chiffre du bloc du N° ID ne correspond plus au code d'origine. Le
## N° est réécrit **sur tous les documents** (et dans la déclaration du
## passager) : ce n'est pas une discordance entre documents mais une règle (R10).
class_name OriginIdMismatchInjector
extends AnomalyInjector

const CITIZEN_ID_PATH: StringName = &"citizen_id"
const DIGIT_INDEX: int = 3
const DIGITS: String = "123456789"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.ORIGIN_ID_MISMATCH


func inject(state: InjectionState) -> Anomaly:
	if active_rules(state, OriginIdBlockRule).is_empty():
		return null
	var refs: Array[FieldRef] = state.case.find_refs_by_truth_path(CITIZEN_ID_PATH)
	if refs.is_empty():
		return null
	for ref: FieldRef in refs:
		if not state.is_free(ref.document_id, ref.field_id):
			return null
	var faction: FactionDef = state.get_faction(Rule.visible_origin(state.case))
	if faction == null:
		return null
	var original: String = str(state.case.get_value(refs[0]))
	if not PassengerGenerator.is_valid_citizen_id_format(original):
		return null
	var pool: String = DIGITS.replace(str(faction.get_id_block_digit()), "")
	var forged: String = original.substr(0, DIGIT_INDEX) + pool[state.rng.randi_range(0, pool.length() - 1)] + original.substr(DIGIT_INDEX + 1)
	for ref: FieldRef in refs:
		state.case.get_document(ref.document_id).set_value(ref.field_id, forged)
		state.mark(ref.document_id, ref.field_id)
	state.case.passenger_presented.citizen_id = forged
	return make_anomaly(get_kind(), refs[0].document_id, refs[0].field_id, original, forged)
