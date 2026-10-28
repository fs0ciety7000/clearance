## Famille « Répondant » (R34, Acte III J24 ; docs/ACT3.md §2.5 M2, D-087) :
## un ressortissant (origine visible hors `exempt_faction_ids`, HAL) au motif
## VISITE FAMILIALE présente un permis portant un **Répondant** (N° ID) qui
## figure à la **Main courante** du jour (`RuleContext.ledger` : Né·e-Halcyon
## de classe C-1 à C-3 admis·e aujourd'hui à cette vitre). Sinon : refus.
## Règle de **contexte du shift** : le verdict attendu est calculé au moment
## de la présentation (comme le quota, D-077) ; un agent ne se porte pas
## répondant à sa propre vitre (son N° n'est jamais à la Main courante).
## Contrôle « cas propre » du générateur (`RuleContext.trust_documents`) : un
## Répondant renseigné est tenu pour valide (le lien est vérifié à la
## présentation). Anomalie détectée : `SPONSOR_MISMATCH`. Preuve : Répondant
## (permis) ↔ R34, ou Répondant ↔ entrée de la Main courante.
class_name SponsorRule
extends Rule

const SPONSOR_PATH: StringName = &"sponsor_id"
## Classes admissibles comme répondant (lues sur la carte du répondant).
const ELIGIBLE_CLASSES: Array[StringName] = [&"C-1", &"C-2", &"C-3"]
const ELIGIBLE_FACTION: StringName = &"hal"

@export var exempt_faction_ids: Array[StringName] = [&"hal"]
@export var purposes: Array[StringName] = [Passenger.PURPOSE_FAMILY_VISIT]
@export var permit_id: StringName = &"entry_permit"


## Règle de répondant active d'un RuleSet, ou null.
static func find_in(rule_set: RuleSet) -> SponsorRule:
	if rule_set == null:
		return null
	for rule: Rule in rule_set.rules:
		if rule is SponsorRule:
			return rule as SponsorRule
	return null


## Vrai si un passager admis (lu sur sa carte) est admissible comme répondant.
static func is_eligible(faction_id: Variant, citizen_class: Variant) -> bool:
	if faction_id == null or citizen_class == null:
		return false
	if not FieldValue.equals(faction_id, ELIGIBLE_FACTION):
		return false
	for allowed: StringName in ELIGIBLE_CLASSES:
		if FieldValue.equals(citizen_class, allowed):
			return true
	return false


## Le cas doit présenter un répondant (ressortissant, motif visé).
func applies_to(case: Case) -> bool:
	if case == null or exempt_faction_ids.has(Rule.visible_origin(case)):
		return false
	var purpose: Variant = PurposeConsistentRule._value(case, permit_id, &"purpose")
	if purpose == null:
		return false
	for wanted: StringName in purposes:
		if FieldValue.equals(purpose, wanted):
			return true
	return false


## Répondant du permis (texte, vide si absent).
func sponsor_of(case: Case) -> String:
	var value: Variant = PurposeConsistentRule._value(case, permit_id, SPONSOR_PATH)
	return str(value) if value != null else ""


## Répondant valide : renseigné et présent à la Main courante (ou contrôle
## « cas propre »).
func is_sponsor_valid(case: Case, ctx: RuleContext) -> bool:
	var sponsor: String = sponsor_of(case)
	if sponsor.is_empty():
		return false
	if ctx == null:
		return false
	if ctx.trust_documents:
		return true
	return ctx.find_ledger_by_citizen(sponsor) != null


## Vrai si le cas porte un répondant valide au regard de la R34 active du
## jour (R37 : exemption « VISITE FAMILIALE avec Répondant valide »).
static func has_valid_sponsor(case: Case, ctx: RuleContext) -> bool:
	if ctx == null:
		return false
	var rule: SponsorRule = find_in(ctx.rule_set)
	return rule != null and rule.applies_to(case) and rule.is_sponsor_valid(case, ctx)


func is_violated(case: Case, ctx: RuleContext) -> bool:
	return applies_to(case) and not is_sponsor_valid(case, ctx)


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if not is_violated(case, ctx):
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, permit_id, SPONSOR_PATH))
	refs.append(get_ref())
	PurposeConsistentRule._append(refs, Rule.find_ref(case, permit_id, &"purpose"))
	violations.append(make_violation(refs, "viol_sponsor"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.SPONSOR_MISMATCH]


## Répondant ou motif (permis) ↔ R34.
func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or ref.document_id != permit_id:
		return Discrepancy.Result.INCOMPARABLE
	if field.truth_path != SPONSOR_PATH and field.truth_path != &"purpose":
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_violated(case, ctx) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {permit_id: [&"purpose", SPONSOR_PATH]}
