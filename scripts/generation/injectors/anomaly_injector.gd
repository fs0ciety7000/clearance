## Injecteur d'anomalie (strategy, ARCHITECTURE §9.2 étape 5) — classe de base.
##
## Contrat : `inject()` corrompt `state.case` (ou `state.truth`) de façon à
## provoquer une violation d'une règle **active** qui détecte ce type, marque
## les champs touchés et renvoie l'`Anomaly` ; s'il est impossible d'injecter
## (règle inactive, document absent, champ déjà pris…), il renvoie `null`
## **sans rien modifier**. Jamais d'accès à `CaseKey` : le verdict est
## recalculé par le `RuleEngine` sur le cas final (D-005).
@abstract
class_name AnomalyInjector
extends RefCounted


@abstract func get_kind() -> AnomalyType.Kind


## Vrai pour les anomalies de visage (mutuellement exclusives).
func is_face_anomaly() -> bool:
	return false


@abstract func inject(state: InjectionState) -> Anomaly


## Règles actives de la classe `script` (ex. `DocumentNotExpiredRule`) qui
## détectent ce type d'anomalie.
func active_rules(state: InjectionState, script: Script) -> Array[Rule]:
	var result: Array[Rule] = []
	for rule: Rule in state.get_rule_set().rules:
		# Acte III : une règle levée par une convocation valide (R36) ne peut
		# pas porter l'anomalie de ce passager.
		if rule != null and is_instance_of(rule, script) and rule.get_detectable_anomalies().has(get_kind()) \
				and not rule.is_exempted(state.case, state.ctx):
			result.append(rule)
	return result


## Champ (`FieldDef.id`) d'un document présent portant ce `truth_path`, ou `&""`.
static func field_for(case: Case, document_id: StringName, truth_path: StringName) -> StringName:
	var doc: DocumentInstance = case.get_document(document_id)
	if doc == null:
		return &""
	var field: FieldDef = doc.type_def.find_field_by_truth_path(truth_path)
	return field.id if field != null else &""


static func make_anomaly(kind: AnomalyType.Kind, document_id: StringName, field_id: StringName,
		original: Variant, injected: Variant) -> Anomaly:
	var anomaly: Anomaly = Anomaly.new(kind, document_id, field_id)
	anomaly.original_value = original
	anomaly.injected_value = injected
	return anomaly
