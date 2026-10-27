## Famille « La photo correspond au porteur » (R03 ; R17/R18 plus tard).
##
## Compare chaque champ `PORTRAIT` au visage réel du passager
## (`passenger_presented.appearance`) et, en option, les photos entre elles,
## avec `FaceComparator` (slots d'identité de `RuleContext.identity_slots`).
## La visière n'est pas prise en compte ici : la règle dit la vérité terrain ;
## le contrôle du visage découvert est une procédure (R06, `ProcedureRule`).
## Anomalies détectées : `PORTRAIT_MISMATCH`, `IMPOSTOR_LOOKALIKE`, `RELATIVE_DOCUMENTS`.
class_name PortraitMatchRule
extends Rule

@export var check_passenger_face: bool = true
@export var check_between_documents: bool = true


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var portraits: Array[FieldRef] = case.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)
	var face: PassengerAppearance = case.passenger_presented.appearance if case.passenger_presented != null else null
	if check_passenger_face and face != null:
		for ref: FieldRef in portraits:
			var photo: PassengerAppearance = _photo_of(case, ref)
			if photo != null and not FaceComparator.compare(photo, face, ctx.identity_slots).is_empty():
				violations.append(make_violation([FieldRef.passenger_face(), ref], "viol_portrait_mismatch"))
	if check_between_documents:
		for i: int in portraits.size():
			for j: int in range(i + 1, portraits.size()):
				var photo_i: PassengerAppearance = _photo_of(case, portraits[i])
				var photo_j: PassengerAppearance = _photo_of(case, portraits[j])
				if photo_i == null or photo_j == null:
					continue
				if not FaceComparator.compare(photo_i, photo_j, ctx.identity_slots).is_empty():
					violations.append(make_violation([portraits[i], portraits[j]], "viol_portraits_differ"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [
		AnomalyType.Kind.PORTRAIT_MISMATCH,
		AnomalyType.Kind.IMPOSTOR_LOOKALIKE,
		AnomalyType.Kind.RELATIVE_DOCUMENTS,
	]


static func _photo_of(case: Case, ref: FieldRef) -> PassengerAppearance:
	var value: Variant = case.get_value(ref)
	if value is PortraitValue:
		var portrait: PortraitValue = value
		return portrait.appearance
	return null
