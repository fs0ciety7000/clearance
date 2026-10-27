## InspectionSession minimale (M4) : comparaison A↔B via DiscrepancyChecker,
## retrait de visière (D-021), confrontation, réactions, complément du verdict.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var session: InspectionSession = null
var builder: CaseBuilder = null
var checked: Array[Discrepancy] = []
var answers: Array[Array] = []
var reactions: Array[PassengerReaction.Kind] = []


func before_each() -> void:
	session = InspectionSession.new()
	add_child_autofree(session)
	session.set_process(false)
	checked.clear()
	answers.clear()
	reactions.clear()
	EventBus.discrepancy_checked.connect(_on_checked)
	EventBus.interrogation_answered.connect(_on_answered)
	EventBus.passenger_reaction_triggered.connect(_on_reaction)
	# J3, cas 2 = SC-04 (Mira, visière baissée, sans anomalie).
	builder = CaseBuilder.new(Gen.data(), Gen.data().get_day(3), Gen.day_seed(0, 3))


func after_each() -> void:
	EventBus.discrepancy_checked.disconnect(_on_checked)
	EventBus.interrogation_answered.disconnect(_on_answered)
	EventBus.passenger_reaction_triggered.disconnect(_on_reaction)


func _on_checked(result: Discrepancy) -> void:
	checked.append(result)


func _on_answered(topic: StringName, line_key: String) -> void:
	answers.append([topic, line_key])


func _on_reaction(reaction: PassengerReaction.Kind) -> void:
	reactions.append(reaction)


func _last_check() -> Discrepancy:
	return checked[checked.size() - 1]


func _last_reaction() -> PassengerReaction.Kind:
	return reactions[reactions.size() - 1]


func _last_topic() -> StringName:
	var topic: StringName = answers[answers.size() - 1][0]
	return topic


func _last_line() -> String:
	var line: String = answers[answers.size() - 1][1]
	return line


func _begin(index: int) -> Case:
	var generated: GeneratedCase = builder.build(index)
	session.begin(generated.case, builder.ctx)
	return generated.case


func test_face_masked_then_comparable_after_visor_removal() -> void:
	var c: Case = _begin(2)
	assert_true(c.passenger_presented.appearance.is_face_covered(), "SC-04 arrive visière baissée")
	var photo: FieldRef = c.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)[0]
	EventBus.discrepancy_check_requested.emit(FieldRef.passenger_face(), photo)
	assert_eq(_last_check().reason_key, Discrepancy.REASON_FACE_MASKED)
	# Avant les documents : la question est ignorée.
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
	assert_eq(answers.size(), 0)
	EventBus.documents_presented.emit(c.case_id)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
	assert_eq(_last_topic(), InspectionSession.TOPIC_REMOVE_VISOR)
	assert_eq(_last_line(), InspectionSession.LINE_VISOR_REMOVED)
	assert_false(c.passenger_presented.appearance.is_face_covered())
	EventBus.discrepancy_check_requested.emit(FieldRef.passenger_face(), photo)
	assert_eq(_last_check().result, Discrepancy.Result.CONCORDANT)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
	assert_eq(_last_line(), InspectionSession.LINE_VISOR_NONE, "plus rien à retirer")


func test_confront_without_discrepancy_angers() -> void:
	var c: Case = _begin(0)
	EventBus.documents_presented.emit(c.case_id)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_CONFRONT)
	assert_eq(_last_line(), InspectionSession.LINE_CONFRONT_ANGRY)
	assert_eq(_last_reaction(), PassengerReaction.Kind.ANGRY)


func test_confirmed_discrepancy_recorded_once_and_flagged_in_verdict() -> void:
	var generated: GeneratedCase = builder.build_with(5, [AnomalyType.Kind.NAME_MISMATCH])
	var c: Case = generated.case
	session.begin(c, builder.ctx)
	EventBus.documents_presented.emit(c.case_id)
	var refs: Array[FieldRef] = c.find_refs_by_truth_path(&"family_name")
	var given: Array[FieldRef] = c.find_refs_by_truth_path(&"given_name")
	refs.append_array(given)
	var found: bool = false
	for i: int in refs.size():
		for j: int in range(i + 1, refs.size()):
			EventBus.discrepancy_check_requested.emit(refs[i], refs[j])
			EventBus.discrepancy_check_requested.emit(refs[j], refs[i])
			found = found or _last_check().confirmed
	assert_true(found, "l'anomalie de nom est détectable")
	var unique: int = session.confirmed.size()
	assert_gt(unique, 0)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_CONFRONT)
	assert_eq(_last_reaction(), PassengerReaction.Kind.NERVOUS)
	session.elapsed_sec = 7.0
	var verdict: Verdict = Verdict.new(c.case_id, VerdictKind.Kind.DENY)
	session.end(verdict)
	assert_eq(verdict.flagged.size(), unique, "discordances dédoublonnées (A↔B = B↔A)")
	assert_eq(verdict.questions_asked, [InspectionSession.TOPIC_CONFRONT] as Array[StringName])
	assert_eq(verdict.elapsed_sec, 7.0)
	assert_eq(_last_reaction(), PassengerReaction.Kind.ANGRY, "réaction au refus")
	assert_false(session.active)


func test_inactive_session_ignores_requests() -> void:
	EventBus.discrepancy_check_requested.emit(FieldRef.passenger_face(), FieldRef.today())
	EventBus.interrogation_requested.emit(&"anything")
	assert_eq(checked.size(), 0)
	assert_eq(answers.size(), 0)


func test_elapsed_counts_only_after_documents() -> void:
	var c: Case = _begin(0)
	session.advance(2.0)
	assert_eq(session.elapsed_sec, 0.0)
	EventBus.documents_presented.emit(&"other")
	session.advance(1.0)
	assert_eq(session.elapsed_sec, 0.0, "documents d'un autre cas ignorés")
	EventBus.documents_presented.emit(c.case_id)
	session.advance(1.5)
	assert_almost_eq(session.elapsed_sec, 1.5, 0.0001)


func test_reaction_for_verdict() -> void:
	assert_eq(InspectionSession.reaction_for_verdict(VerdictKind.Kind.APPROVE), PassengerReaction.Kind.RELIEVED)
	assert_eq(InspectionSession.reaction_for_verdict(VerdictKind.Kind.DENY), PassengerReaction.Kind.ANGRY)
	assert_eq(InspectionSession.reaction_for_verdict(VerdictKind.Kind.DETAIN), PassengerReaction.Kind.NERVOUS)
