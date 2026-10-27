## `INVALID_SEAL` (GDD §6, R20, M7) : sceau d'un ancien modèle (`<sceau>_old`,
## surtout l'anneau barré remplacé le 21.03) ou sceau d'un autre émetteur.
## Paramètre : `document_id`.
class_name InvalidSealInjector
extends AnomalyInjector

const SEAL_PATH: StringName = &"document.seal_id"
const OLD_SUFFIX: String = "_old"
const SEALS: Array[StringName] = [&"seal_solar_hexagon", &"seal_barred_ring", &"seal_orbit_cross"]
## Le permis (nouveau modèle d'anneau barré au 21.03) est la cible privilégiée.
const PREFERRED: StringName = &"entry_permit"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.INVALID_SEAL


func inject(state: InjectionState) -> Anomaly:
	if active_rules(state, SealValidRule).is_empty():
		return null
	var candidates: Array[StringName] = []
	for doc: DocumentInstance in state.case.documents:
		var field_id: StringName = field_for(state.case, doc.get_document_id(), SEAL_PATH)
		if field_id != &"" and state.is_free(doc.get_document_id(), field_id):
			candidates.append(doc.get_document_id())
	candidates = state.filter_documents(candidates)
	if candidates.is_empty():
		return null
	var document_id: StringName = PREFERRED if candidates.has(PREFERRED) and state.rng.chance(0.6) \
			else candidates[state.rng.randi_range(0, candidates.size() - 1)]
	var doc: DocumentInstance = state.case.get_document(document_id)
	var original: StringName = doc.seal_id
	var seal: StringName = StringName(String(original) + OLD_SUFFIX)
	if state.rng.chance(0.3):
		var others: Array[StringName] = []
		for other: StringName in SEALS:
			if other != original:
				others.append(other)
		seal = others[state.rng.randi_range(0, others.size() - 1)]
	doc.seal_id = seal
	var field: StringName = field_for(state.case, document_id, SEAL_PATH)
	state.mark(document_id, field)
	return make_anomaly(get_kind(), document_id, field, original, seal)
