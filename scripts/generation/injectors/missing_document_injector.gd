## `MISSING_DOCUMENT` (GDD §6) : retire un document exigé par une règle active
## qui s'applique au passager (jamais le permis d'un `HAL`, dispensé par R04).
## Un document dont un champ porte déjà une anomalie (ou sert de preuve à une
## discordance entre documents) n'est jamais retiré. Paramètre : `document_id`.
class_name MissingDocumentInjector
extends AnomalyInjector


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.MISSING_DOCUMENT


func inject(state: InjectionState) -> Anomaly:
	var candidates: Array[StringName] = []
	for rule: Rule in active_rules(state, RequireDocumentRule):
		var require: RequireDocumentRule = rule
		var required: StringName = require.document_id
		if candidates.has(required) or not state.case.has_document(required):
			continue
		if require.applies_to(state.case) and state.is_document_untouched(required):
			candidates.append(required)
	candidates = state.filter_documents(candidates)
	if candidates.is_empty():
		return null
	var document_id: StringName = candidates[state.rng.randi_range(0, candidates.size() - 1)]
	var kept: Array[DocumentInstance] = []
	for doc: DocumentInstance in state.case.documents:
		if doc.get_document_id() != document_id:
			kept.append(doc)
	state.case.documents = kept
	state.mark(document_id, &"")
	return make_anomaly(get_kind(), document_id, &"", String(document_id), null)
