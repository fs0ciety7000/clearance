## Famille « Bloc ID ↔ origine » (R10, 🟡 GDD) : le premier chiffre du bloc du
## N° ID (`HG-4…`) correspond au code d'origine (onglet Origines, LORE §5).
##
## Pour chaque document portant un N° ID : l'origine lue est celle du même
## document si elle y figure, sinon l'origine visible du dossier. Une origine
## inconnue de `RuleContext.faction_db` n'est pas évaluée (avertissement).
## Anomalie détectée : `ORIGIN_ID_MISMATCH`.
class_name OriginIdBlockRule
extends Rule

const CITIZEN_ID_PATH: StringName = &"citizen_id"
const ORIGIN_PATH: StringName = &"faction_id"


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	for doc: DocumentInstance in case.documents:
		if doc.third_party:
			continue # Acte II : document d'un tiers (SC-27).
		var violation: Violation = _check_document(case, doc, ctx)
		if violation != null:
			violations.append(violation)
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.ORIGIN_ID_MISMATCH]


## Règle ↔ N° ID ou Origine d'un document.
func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or (field.truth_path != CITIZEN_ID_PATH and field.truth_path != ORIGIN_PATH):
		return Discrepancy.Result.INCOMPARABLE
	var doc: DocumentInstance = case.get_document(ref.document_id)
	if doc.type_def.find_field_by_truth_path(CITIZEN_ID_PATH) == null:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if _check_document(case, doc, ctx) != null else Discrepancy.Result.CONCORDANT


func _check_document(case: Case, doc: DocumentInstance, ctx: RuleContext) -> Violation:
	var id_field: FieldDef = doc.type_def.find_field_by_truth_path(CITIZEN_ID_PATH)
	if id_field == null:
		return null
	var origin_field: FieldDef = doc.type_def.find_field_by_truth_path(ORIGIN_PATH)
	var origin: StringName = Rule.visible_origin(case)
	if origin_field != null:
		origin = StringName(str(doc.get_value(origin_field.id)))
	var faction: FactionDef = ctx.get_faction(origin)
	if faction == null:
		push_warning("OriginIdBlockRule: origine inconnue « %s »" % origin)
		return null
	if faction.matches_citizen_id(str(doc.get_value(id_field.id))):
		return null
	var refs: Array[FieldRef] = [FieldRef.new(doc.get_document_id(), id_field.id)]
	if origin_field != null:
		refs.append(FieldRef.new(doc.get_document_id(), origin_field.id))
	refs.append(get_ref())
	return make_violation(refs, "viol_origin_id_mismatch")
