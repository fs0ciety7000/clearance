## Famille « Avis de recherche » (R22, GDD §6 `WANTED_PERSON`, M7) : toute
## personne de l'avis du jour (`RuleContext.wanted`), reconnue **par le nom**
## (prénom et nom de la carte) **ou par le visage** (`FaceComparator` : aucun
## trait comparé différent), est mise en attente (sévérité 3).
## Preuve : entrée de l'avis (`FieldRef.wanted`) ↔ visage ou nom.
class_name WantedRule
extends Rule

@export var document_id: StringName = &"id_card"


static func face_matches(notice: WantedNotice, case: Case, ctx: RuleContext) -> bool:
	if notice.appearance == null or case.passenger_presented == null or case.passenger_presented.appearance == null:
		return false
	return FaceComparator.compare(notice.appearance, case.passenger_presented.appearance, ctx.identity_slots).is_empty()


func name_matches(notice: WantedNotice, case: Case) -> bool:
	var family: Variant = PurposeConsistentRule._value(case, document_id, &"family_name")
	var given: Variant = PurposeConsistentRule._value(case, document_id, &"given_name")
	return family != null and given != null and FieldValue.equals(family, notice.family_name) \
			and FieldValue.equals(given, notice.given_name)


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	for notice: WantedNotice in ctx.wanted:
		var by_face: bool = face_matches(notice, case, ctx)
		var by_name: bool = name_matches(notice, case)
		if not by_face and not by_name:
			continue
		var refs: Array[FieldRef] = [notice.get_ref()]
		if by_face:
			refs.append(FieldRef.passenger_face())
		if by_name:
			PurposeConsistentRule._append(refs, Rule.find_ref(case, document_id, &"family_name"))
		refs.append(get_ref())
		violations.append(make_violation(refs, "viol_wanted"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.WANTED_PERSON]


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"family_name", &"given_name"]}
