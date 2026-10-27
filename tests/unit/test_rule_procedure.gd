## Famille ProcedureRule (R06 visage découvert, R08 interrogatoire TYC) :
## jamais de violation, présente au Rulebook, vérifiée par le scoring (M5).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")


func test_never_produces_violations() -> void:
	var c: Case = CaseFactory.valid_case()
	c.passenger_presented.appearance = c.passenger_presented.appearance.derive({&"headwear": &"visor_down"})
	for rule_id: StringName in [&"r_face_uncovered", &"r_tycho_interview"]:
		var r: Rule = CaseFactory.rule(rule_id)
		assert_eq(r.evaluate(c, CaseFactory.context()).size(), 0, String(rule_id))
		assert_eq(r.get_detectable_anomalies().size(), 0, String(rule_id))


func test_procedure_ids_and_scope() -> void:
	var face: ProcedureRule = CaseFactory.rule(&"r_face_uncovered") as ProcedureRule
	var interview: ProcedureRule = CaseFactory.rule(&"r_tycho_interview") as ProcedureRule
	assert_eq(face.procedure_id, ProcedureRule.PROCEDURE_FACE_UNCOVERED)
	assert_eq(interview.procedure_id, ProcedureRule.PROCEDURE_TYCHO_INTERVIEW)
	assert_true(face.applies_to(CaseFactory.valid_case([CaseFactory.ID_CARD], &"hal")))
	assert_true(interview.applies_to(CaseFactory.valid_case([CaseFactory.ID_CARD], &"tyc")))
	assert_false(interview.applies_to(CaseFactory.valid_case([CaseFactory.ID_CARD], &"ter")))


func test_rulebook_entry_and_severity() -> void:
	var entry: RulebookEntry = CaseFactory.rule(&"r_face_uncovered").get_rulebook_entry()
	assert_eq(entry.rule_id, &"r_face_uncovered")
	assert_eq(entry.category, Rule.RuleCategory.SPECIAL)
	assert_eq(entry.severity, 1)
	assert_true(entry.ref.equals(FieldRef.rulebook_rule(&"r_face_uncovered")))
