## Famille « Implants déclarés » (R15, GDD §6 `UNDECLARED_IMPLANT`, LORE §8, M7).
##
## Les implants visibles sur le passager (`passenger_presented.implants`)
## doivent être exactement ceux de la liste « Implants déclarés » de la carte.
## Preuve : visage du passager ↔ champ déclaré (comparaison du mode Inspection).
## Sévérité : celle de la règle, portée à `escalated_severity` (DÉTENTION) si
## un implant non déclaré commence par un préfixe de `escalated_prefixes`
## (`MIL-`) à partir du jour `escalated_from_day` (GDD §7 : J7).
class_name ImplantsDeclaredRule
extends Rule

@export var document_id: StringName = &"id_card"
@export var escalated_prefixes: PackedStringArray = ["MIL-"]
@export var escalated_from_day: int = 7
@export var escalated_severity: int = 3


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var ref: FieldRef = Rule.find_ref(case, document_id, &"implants")
	if ref == null or case.passenger_presented == null:
		return violations
	var declared: PackedStringArray = FieldValue.normalize(as_list(case.get_value(ref)))
	var visible: PackedStringArray = FieldValue.normalize(case.passenger_presented.implants)
	if declared == visible:
		return violations
	var violation: Violation = make_violation([FieldRef.passenger_face(), ref, get_ref()], "viol_implant_undeclared")
	if ctx.get_day_number() >= escalated_from_day:
		for code: String in visible:
			if declared.has(code):
				continue
			for prefix: String in escalated_prefixes:
				if code.begins_with(prefix):
					violation.severity = maxi(violation.severity, escalated_severity)
	violations.append(violation)
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.UNDECLARED_IMPLANT]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if ref.document_id != document_id or field == null or field.truth_path != &"implants":
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if not evaluate(case, ctx).is_empty() else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"implants"]}


## Liste de codes d'une valeur de champ LIST (vide si absente).
static func as_list(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var result: PackedStringArray = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result
