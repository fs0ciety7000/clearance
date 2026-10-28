## Base des discordances entre documents (`FieldsMatchRule`, R07) : une même
## donnée (`truth_path`) est altérée sur **un** des documents qui la portent.
## Tous les champs de cette donnée deviennent des preuves (marqués utilisés),
## pour qu'aucune autre anomalie ne retire un document témoin.
## Paramètres : `document_id` (document altéré), `field_path` ; Acte II :
## `injected_value` (valeur imposée, SC-38 « Satō » ; `injected_value_from_case`
## est résolu par le `CaseBuilder` en `injected_value`, SC-31/32).
@abstract
class_name FieldMismatchInjector
extends AnomalyInjector


## `truth_path` que ce type d'anomalie peut altérer.
@abstract func get_paths() -> Array[StringName]


## Valeur altérée (différente après normalisation) ; `null` si impossible.
@abstract func alter(state: InjectionState, path: StringName, value: Variant) -> Variant


func inject(state: InjectionState) -> Anomaly:
	var options: Array[Array] = [] # [path, refs]
	var forced_path: StringName = StringName(str(state.param(&"field_path", "")))
	for rule: Rule in active_rules(state, FieldsMatchRule):
		var match_rule: FieldsMatchRule = rule
		for path: StringName in match_rule.truth_paths:
			if not get_paths().has(path) or (forced_path != &"" and path != forced_path):
				continue
			var path_refs: Array[FieldRef] = []
			for ref: FieldRef in state.case.find_refs_by_truth_path(path):
				if match_rule.document_ids.is_empty() or match_rule.document_ids.has(ref.document_id):
					path_refs.append(ref)
			if path_refs.size() >= 2 and _all_free(state, path_refs):
				options.append([path, path_refs])
	if options.is_empty():
		return null
	var choice: Array = options[state.rng.randi_range(0, options.size() - 1)]
	var chosen_path: StringName = choice[0]
	var refs: Array[FieldRef] = choice[1]
	var targets: Array[FieldRef] = []
	var allowed: Array[StringName] = []
	for ref: FieldRef in refs:
		allowed.append(ref.document_id)
	allowed = state.filter_documents(allowed)
	for ref: FieldRef in refs:
		if allowed.has(ref.document_id):
			targets.append(ref)
	if targets.is_empty():
		return null
	var target: FieldRef = targets[state.rng.randi_range(0, targets.size() - 1)]
	var original: Variant = state.case.get_value(target)
	var altered: Variant = state.params[&"injected_value"] if state.params.has(&"injected_value") \
			else alter(state, chosen_path, original)
	if altered == null or FieldValue.equals(original, altered):
		return null
	state.case.get_document(target.document_id).set_value(target.field_id, altered)
	for ref: FieldRef in refs:
		state.mark(ref.document_id, ref.field_id)
	return make_anomaly(get_kind(), target.document_id, target.field_id, original, altered)


static func _all_free(state: InjectionState, refs: Array[FieldRef]) -> bool:
	for ref: FieldRef in refs:
		if not state.is_free(ref.document_id, ref.field_id):
			return false
	return true


## Remplace 1 caractère ASCII (lettre) par une autre lettre de même casse.
static func substitute_letter(rng: SeededRng, text: String) -> String:
	var positions: Array[int] = []
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			positions.append(i)
	if positions.is_empty():
		return text
	var index: int = positions[rng.randi_range(0, positions.size() - 1)]
	var current: String = text[index].to_upper()
	var letters: String = "ABCDEFGHJKLMNPRSTUVWZ".replace(current, "")
	var replacement: String = letters[rng.randi_range(0, letters.length() - 1)]
	if text[index] != text[index].to_upper():
		replacement = replacement.to_lower()
	return text.substr(0, index) + replacement + text.substr(index + 1)
