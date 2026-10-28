## Famille « Implants interdits » (R16, GDD §6 `BANNED_IMPLANT`, LORE §8, M7).
##
## Sur la liste « Implants déclarés » de la carte : un code de
## `always_banned` (`DER-19`) est toujours interdit ; un code commençant par un
## préfixe de `waiver_prefixes` (`MIL-`) n'est admis qu'avec une dérogation
## valide (`waiver_document_id`) : non expirée, même N° ID que la carte, et qui
## liste ce code. Preuve : champ déclaré ↔ règle.
class_name BannedImplantsRule
extends Rule

@export var document_id: StringName = &"id_card"
@export var always_banned: PackedStringArray = ["DER-19"]
@export var waiver_prefixes: PackedStringArray = ["MIL-"]
@export var waiver_document_id: StringName = &"mil_waiver"


## Codes déclarés interdits (sans dérogation valide).
func banned_codes(case: Case, ctx: RuleContext) -> PackedStringArray:
	var result: PackedStringArray = []
	var ref: FieldRef = Rule.find_ref(case, document_id, &"implants")
	if ref == null:
		return result
	for code: String in FieldValue.normalize(ImplantsDeclaredRule.as_list(case.get_value(ref))):
		if always_banned.has(code):
			result.append(code)
			continue
		for prefix: String in waiver_prefixes:
			if code.begins_with(prefix) and not has_valid_waiver(case, ctx, code):
				result.append(code)
				break
	return result


func has_valid_waiver(case: Case, ctx: RuleContext, code: String) -> bool:
	var waiver: DocumentInstance = case.get_document(waiver_document_id)
	if waiver == null or ctx.is_document_expired(waiver.expiry_date):
		return false
	var card_id: Variant = PurposeConsistentRule._value(case, document_id, &"citizen_id")
	var waiver_id: Variant = PurposeConsistentRule._value(case, waiver_document_id, &"citizen_id")
	if card_id == null or not FieldValue.equals(card_id, waiver_id):
		return false
	var listed: Variant = PurposeConsistentRule._value(case, waiver_document_id, &"implants")
	var codes: PackedStringArray = FieldValue.normalize(ImplantsDeclaredRule.as_list(listed))
	return codes.has(code)


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if banned_codes(case, ctx).is_empty():
		return violations
	var refs: Array[FieldRef] = [Rule.find_ref(case, document_id, &"implants"), get_ref()]
	violations.append(make_violation(refs, "viol_implant_banned"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.BANNED_IMPLANT]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if ref.document_id != document_id or field == null or field.truth_path != &"implants":
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if not banned_codes(case, ctx).is_empty() else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"implants"]}
