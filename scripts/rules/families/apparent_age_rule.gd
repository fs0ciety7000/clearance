## Famille « Âge apparent » (R18, GDD §6 `RELATIVE_DOCUMENTS`, M7) : l'âge
## apparent du porteur (`PassengerAppearance.age_band`) correspond à la date de
## naissance de la carte (tranches `PassengerGenerator.AGE_BANDS`). Porter les
## papiers d'un parent → DÉTENTION (sévérité 3). Preuve : visage ↔ naissance.
class_name ApparentAgeRule
extends Rule

@export var document_id: StringName = &"id_card"


static func band_of_birth(birth_date: int, today: int) -> int:
	return PassengerGenerator.age_band_for_age(GameDate.age_on(birth_date, today))


func is_violated(case: Case, ctx: RuleContext) -> bool:
	var ref: FieldRef = Rule.find_ref(case, document_id, &"birth_date")
	if ref == null or case.passenger_presented == null or case.passenger_presented.appearance == null:
		return false
	var birth: Variant = case.get_value(ref)
	if not birth is int:
		return false
	var birth_date: int = birth
	return band_of_birth(birth_date, ctx.today) != case.passenger_presented.appearance.age_band


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if is_violated(case, ctx):
		violations.append(make_violation([FieldRef.passenger_face(), Rule.find_ref(case, document_id, &"birth_date"),
				get_ref()], "viol_apparent_age"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.RELATIVE_DOCUMENTS]


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"birth_date"]}
