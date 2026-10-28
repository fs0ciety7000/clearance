## Famille « Origine interdite » (R19, GDD §6 `BANNED_FACTION`, M7) : les
## ressortissants des origines `banned_faction_ids` (THR après l'attentat du J8)
## sont refusés, sauf motif de `exempt_purposes` (DIPLOMATIQUE) sur le permis.
## Preuve : Origine (carte) ↔ règle, puis Motif (permis).
class_name FactionBannedRule
extends Rule

@export var banned_faction_ids: Array[StringName] = []
@export var exempt_purposes: Array[StringName] = [Passenger.PURPOSE_DIPLOMATIC]
@export var card_id: StringName = &"id_card"
@export var permit_id: StringName = &"entry_permit"
## Acte II (R31, « Le Puits est clos ») : exemption par le **poste** du contrat
## de travail du porteur (postes en pénurie : RECYCLEUR, SOINS, HYDROPONIE).
@export var exempt_posts: Array[StringName] = []
@export var contract_id: StringName = &"work_contract"


func is_banned_origin(faction_id: StringName) -> bool:
	return banned_faction_ids.has(faction_id)


func is_violated(case: Case) -> bool:
	if not is_banned_origin(Rule.visible_origin(case)):
		return false
	if has_exempt_post(case):
		return false
	var purpose: Variant = PurposeConsistentRule._value(case, permit_id, &"purpose")
	if purpose == null:
		return true
	for exempt: StringName in exempt_purposes:
		if FieldValue.equals(purpose, exempt):
			return false
	return true


## Acte II : contrat du porteur sur un poste exempté (R31).
func has_exempt_post(case: Case) -> bool:
	if exempt_posts.is_empty() or case.get_own_document(contract_id) == null:
		return false
	var post: Variant = PurposeConsistentRule._value(case, contract_id, &"post")
	if post == null:
		return false
	for exempt: StringName in exempt_posts:
		if FieldValue.equals(post, exempt):
			return true
	return false


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if not is_violated(case):
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, card_id, &"faction_id"))
	refs.append(get_ref())
	PurposeConsistentRule._append(refs, Rule.find_ref(case, permit_id, &"purpose"))
	if not exempt_posts.is_empty() and case.get_own_document(contract_id) != null:
		PurposeConsistentRule._append(refs, Rule.find_ref(case, contract_id, &"post"))
	violations.append(make_violation(refs, "viol_faction_banned"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.BANNED_FACTION]


func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null:
		return Discrepancy.Result.INCOMPARABLE
	var on_origin: bool = ref.document_id == card_id and field.truth_path == &"faction_id"
	var on_purpose: bool = ref.document_id == permit_id and field.truth_path == &"purpose"
	var on_post: bool = not exempt_posts.is_empty() and ref.document_id == contract_id and field.truth_path == &"post"
	if not on_origin and not on_purpose and not on_post:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_violated(case) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {card_id: [&"faction_id"], permit_id: [&"purpose"]}
