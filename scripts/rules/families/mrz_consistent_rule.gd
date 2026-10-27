## Famille « MRZ fidèle » (R21, GDD §6 `MRZ_MISMATCH`, M7) : la bande MRZ de la
## carte recopie N° ID, origine, nom et prénoms de la carte (`Mrz`). Les deux
## derniers caractères (guichet émetteur, code Luciole `07`) ne sont jamais
## comparés. Une violation par composante fausse ; preuve : MRZ ↔ champ.
class_name MrzConsistentRule
extends Rule

const MRZ_PATH: StringName = &"document.mrz"

@export var document_id: StringName = &"id_card"


## Composantes (`Mrz.COMPONENTS`) mal recopiées.
func wrong_components(case: Case, ctx: RuleContext) -> Array[StringName]:
	var wrong: Array[StringName] = []
	var doc: DocumentInstance = case.get_document(document_id)
	if doc == null or Rule.find_ref(case, document_id, MRZ_PATH) == null:
		return wrong
	for component: StringName in Mrz.COMPONENTS:
		var ref: FieldRef = Rule.find_ref(case, document_id, component)
		if ref == null:
			continue
		if not Mrz.component_matches(doc.mrz, component, case.get_value(ref), origin_code(case, ctx)):
			wrong.append(component)
	return wrong


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var mrz_ref: FieldRef = Rule.find_ref(case, document_id, MRZ_PATH)
	for component: StringName in wrong_components(case, ctx):
		violations.append(make_violation([mrz_ref, Rule.find_ref(case, document_id, component), get_ref()],
				"viol_mrz_mismatch"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.MRZ_MISMATCH]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if ref.document_id != document_id or field == null:
		return Discrepancy.Result.INCOMPARABLE
	var wrong: Array[StringName] = wrong_components(case, ctx)
	if field.truth_path == MRZ_PATH:
		return Discrepancy.Result.DISCORDANT if not wrong.is_empty() else Discrepancy.Result.CONCORDANT
	if Mrz.COMPONENTS.has(field.truth_path):
		return Discrepancy.Result.DISCORDANT if wrong.has(field.truth_path) else Discrepancy.Result.CONCORDANT
	return Discrepancy.Result.INCOMPARABLE


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [MRZ_PATH, &"family_name", &"given_name", &"citizen_id", &"faction_id"]}


## Code à 3 lettres de l'origine affichée sur la carte.
func origin_code(case: Case, ctx: RuleContext) -> String:
	var ref: FieldRef = Rule.find_ref(case, document_id, &"faction_id")
	var origin: String = str(case.get_value(ref)) if ref != null else ""
	var faction: FactionDef = ctx.get_faction(StringName(origin)) if ctx != null else null
	return faction.code if faction != null else origin.to_upper()
