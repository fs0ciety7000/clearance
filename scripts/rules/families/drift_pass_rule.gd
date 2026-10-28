## Famille « Laissez-passer de dérive » (R26, Acte II J13 ; docs/ACT2.md §2.4) :
## un Dérivant (`DRV`) présente un Laissez-passer de dérive ; le vaisseau porté
## au laissez-passer est son nom de famille (carte) **et** figure au Registre
## des cargos (onglet du Rulebook, `registered_vessels` ; les cargos démantelés
## en sont retirés : SILLAGE au 20.03.2187).
##
## Anomalies détectées : `MISSING_DOCUMENT` (laissez-passer absent),
## `UNREGISTERED_VESSEL`. Preuve : Vaisseau ↔ règle (registre), puis Vaisseau ↔
## Nom (carte).
class_name DriftPassRule
extends RequireDocumentRule

const VESSEL_PATH: StringName = &"vessel"

## Registre des cargos (noms en capitales ou non : comparaison normalisée).
@export var registered_vessels: PackedStringArray = []
## Acte III (SC-72) : cargos **retirés** du registre à une date (`GameDate`) —
## ligne « Retirés » de l'onglet (BASSE-MARÉE au 02.04.2187). Avant cette
## date, ils restent inscrits (Acte II inchangé).
@export var retired_vessels: Dictionary[String, int] = {}


## Vrai si le vaisseau est inscrit au registre à la date `today` (−1 : sans
## tenir compte des retraits datés).
func is_registered(vessel: Variant, today: int = -1) -> bool:
	if today >= 0:
		for retired: String in retired_vessels:
			if FieldValue.equals(retired, vessel) and retired_vessels[retired] <= today:
				return false
	for name: String in registered_vessels:
		if FieldValue.equals(name, vessel):
			return true
	return false


## Vrai si le laissez-passer présent viole le registre ou le nom de famille.
func is_vessel_invalid(case: Case, ctx: RuleContext = null) -> bool:
	if not applies_to(case):
		return false
	var doc: DocumentInstance = case.get_own_document(document_id)
	if doc == null:
		return false
	var vessel: Variant = PurposeConsistentRule._value(case, document_id, VESSEL_PATH)
	if vessel == null or not is_registered(vessel, ctx.today if ctx != null else -1):
		return true
	var family: Variant = PurposeConsistentRule._value(case, card_id, &"family_name")
	return family != null and not FieldValue.equals(vessel, family)


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = super.evaluate(case, ctx)
	if is_vessel_invalid(case, ctx):
		var refs: Array[FieldRef] = []
		PurposeConsistentRule._append(refs, Rule.find_ref(case, document_id, VESSEL_PATH))
		refs.append(get_ref())
		PurposeConsistentRule._append(refs, Rule.find_ref(case, card_id, &"family_name"))
		violations.append(make_violation(refs, "viol_unregistered_vessel"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = super.get_detectable_anomalies()
	kinds.append(AnomalyType.Kind.UNREGISTERED_VESSEL)
	return kinds


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field != null and field.truth_path == VESSEL_PATH and ref.document_id == document_id:
		return Discrepancy.Result.DISCORDANT if is_vessel_invalid(case, ctx) else Discrepancy.Result.CONCORDANT
	return super.check_against(case, ref, ctx)


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [VESSEL_PATH], card_id: [&"family_name"]}
