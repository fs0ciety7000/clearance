## Famille « Couvre-feu respiratoire » (R29, Acte II J16 ; docs/ACT2.md §2.5
## M1) : présenté après `curfew_minute` (heure du **ticket de file**, fixée à
## la présentation : un joueur lent ne fait pas basculer un passager déjà
## présenté), un passager aux motifs `banned_purposes` (VISITE FAMILIALE,
## COMMERCE, TRANSIT) est refusé ; Nés-Halcyon exemptés. Règle de contexte :
## sans ticket (jours précédents, outils), elle ne s'applique pas.
## Preuve : Présentation (ticket) ↔ règle, puis Motif (permis).
class_name CurfewRule
extends Rule

const PRESENTED_PATH: StringName = &"document.presented_at"

@export var ticket_id: StringName = &"queue_ticket"
@export var permit_id: StringName = &"entry_permit"
## Minutes depuis minuit (960 = 16:00).
@export var curfew_minute: int = 960
@export var banned_purposes: Array[StringName] = [Passenger.PURPOSE_FAMILY_VISIT, Passenger.PURPOSE_TRADE,
		Passenger.PURPOSE_TRANSIT]
@export var exempt_faction_ids: Array[StringName] = [&"hal"]


## Heure de présentation imprimée sur le ticket, −1 sans ticket.
func presented_minute(case: Case) -> int:
	var doc: DocumentInstance = case.get_own_document(ticket_id)
	return doc.presented_at if doc != null else -1


func is_after_curfew(case: Case) -> bool:
	var minute: int = presented_minute(case)
	return minute >= 0 and minute >= curfew_minute


func is_violated(case: Case) -> bool:
	if not is_after_curfew(case) or exempt_faction_ids.has(Rule.visible_origin(case)):
		return false
	var purpose: Variant = PurposeConsistentRule._value(case, permit_id, &"purpose")
	if purpose == null:
		return false
	for banned: StringName in banned_purposes:
		if FieldValue.equals(purpose, banned):
			return true
	return false


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if not is_violated(case):
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, ticket_id, PRESENTED_PATH))
	refs.append(get_ref())
	PurposeConsistentRule._append(refs, Rule.find_ref(case, permit_id, &"purpose"))
	violations.append(make_violation(refs, "viol_curfew"))
	return violations


func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null:
		return Discrepancy.Result.INCOMPARABLE
	var on_ticket: bool = ref.document_id == ticket_id and field.truth_path == PRESENTED_PATH
	var on_purpose: bool = ref.document_id == permit_id and field.truth_path == &"purpose"
	if not on_ticket and not on_purpose:
		return Discrepancy.Result.INCOMPARABLE
	if presented_minute(case) < 0:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_violated(case) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {ticket_id: [PRESENTED_PATH], permit_id: [&"purpose"]}
