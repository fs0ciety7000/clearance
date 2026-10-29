## Famille « Convocations de l'Enquête » (R36, Acte III J26 ; docs/ACT3.md
## §2.4) : une **Convocation** présentée sur le permis (`ENQ-NNNN`) doit
## figurer à l'onglet Convocations du jour (`RuleContext.summons`) au nom de la
## carte ; sinon c'est un faux : refus (même si le porteur n'en avait pas
## besoin, SC-76). Une convocation authentique **exempte** des règles
## déclarées `summons_exempt` (R19, R23, R30, R31, R34, R35, R37) mais pas de
## l'avis de recherche (R22) ni des contrôles d'identité.
## Contrôle « cas propre » (`RuleContext.trust_documents`) : toute
## convocation renseignée est tenue pour authentique.
## Anomalie détectée : `FORGED_SUMMONS`. Preuve : Convocation (permis) ↔ R36,
## ou Convocation ↔ entrée de l'onglet (même N°, autre nom).
class_name SummonsRule
extends Rule

const SUMMONS_PATH: StringName = &"summons_id"

@export var permit_id: StringName = &"entry_permit"
@export var card_id: StringName = &"id_card"


## Convocation présentée (texte, vide si aucune).
func summons_of(case: Case) -> String:
	var value: Variant = PurposeConsistentRule._value(case, permit_id, SUMMONS_PATH)
	return str(value) if value != null else ""


## Le nom de la carte (ou du passager présenté) est celui de l'entrée.
static func name_matches(case: Case, entry: SummonsEntry) -> bool:
	var family: Variant = PurposeConsistentRule._value(case, &"id_card", &"family_name")
	var given: Variant = PurposeConsistentRule._value(case, &"id_card", &"given_name")
	if family == null and case.passenger_presented != null:
		family = case.passenger_presented.family_name
		given = case.passenger_presented.given_name
	return FieldValue.equals(family, entry.family_name) and FieldValue.equals(given, entry.given_name)


## Convocation renseignée et authentique.
func is_valid_summons(case: Case, ctx: RuleContext) -> bool:
	var number: String = summons_of(case)
	if number.is_empty() or ctx == null:
		return false
	if ctx.trust_documents:
		return true
	var entry: SummonsEntry = ctx.find_summons_by_number(number)
	return entry != null and name_matches(case, entry)


## Convocation présentée et fausse (absente de l'onglet ou sous un autre nom).
func is_forged(case: Case, ctx: RuleContext) -> bool:
	return not summons_of(case).is_empty() and not is_valid_summons(case, ctx)


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if not is_forged(case, ctx):
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, permit_id, SUMMONS_PATH))
	refs.append(get_ref())
	violations.append(make_violation(refs, "viol_summons_forged"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.FORGED_SUMMONS]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or ref.document_id != permit_id or field.truth_path != SUMMONS_PATH:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_forged(case, ctx) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {permit_id: [SUMMONS_PATH]}
