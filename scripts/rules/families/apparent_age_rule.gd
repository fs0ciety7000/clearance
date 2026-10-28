## Famille « Âge apparent » (R18, GDD §6 `RELATIVE_DOCUMENTS`, M7) : l'âge
## apparent du porteur (`PassengerAppearance.age_band`) correspond à la date de
## naissance de la carte (tranches `PassengerGenerator.AGE_BANDS`). Porter les
## papiers d'un parent → DÉTENTION (sévérité 3). Preuve : visage ↔ naissance.
## Date « année seule » (Dérivants, NARRATIVE §4.10) : âges possibles
## {âge − 1, âge} ; violation seulement si **aucun** n'est dans la tranche.
class_name ApparentAgeRule
extends Rule

@export var document_id: StringName = &"id_card"


static func band_of_birth(birth_date: int, today: int) -> int:
	return PassengerGenerator.age_band_for_age(GameDate.age_on(birth_date, today))


## Vrai si la naissance est compatible avec la tranche d'âge apparent (une
## date « année seule » l'est si l'un de ses deux âges possibles l'est).
static func birth_matches_band(birth_date: int, today: int, band: int) -> bool:
	var ages: Vector2i = GameDate.possible_ages(birth_date, today)
	for age: int in [ages.x, ages.y]:
		if PassengerGenerator.age_band_for_age(age) == band:
			return true
	return false


func is_violated(case: Case, ctx: RuleContext) -> bool:
	var ref: FieldRef = Rule.find_ref(case, document_id, &"birth_date")
	if ref == null or case.passenger_presented == null or case.passenger_presented.appearance == null:
		return false
	var birth: Variant = case.get_value(ref)
	if not birth is int:
		return false
	var birth_date: int = birth
	return not birth_matches_band(birth_date, ctx.today, case.passenger_presented.appearance.age_band)


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
