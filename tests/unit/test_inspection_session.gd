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
	assert_eq(_last_line(), session.scripted_line("visor", InspectionSession.LINE_VISOR_REMOVED))
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


func test_base_topics_answer_from_presented_passenger() -> void:
	var c: Case = _begin(0)
	EventBus.documents_presented.emit(c.case_id)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
	assert_eq(_last_line(), InspectionSession.LINE_PURPOSE_PREFIX + String(c.passenger_presented.purpose))
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_STAY)
	var short: bool = c.passenger_presented.stay_days <= InspectionSession.SHORT_STAY_DAYS
	assert_eq(_last_line(), InspectionSession.LINE_STAY_SHORT if short else InspectionSession.LINE_STAY_LONG)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_ORIGIN)
	assert_eq(_last_line(), InspectionSession.LINE_ORIGIN_PREFIX + String(c.passenger_presented.faction_id))
	assert_eq(reactions.size(), 0, "questions neutres : pas de réaction")
	for line: String in [_last_line(), InspectionSession.LINE_STAY_SHORT, InspectionSession.LINE_STAY_LONG]:
		assert_true(UiText.has(line), "réplique traduite : %s" % line)


func test_about_topic_confronts_real_discrepancy_only() -> void:
	var generated: GeneratedCase = builder.build_with(4, [AnomalyType.Kind.EXPIRED_DOCUMENT])
	var c: Case = generated.case
	session.begin(c, builder.ctx)
	EventBus.documents_presented.emit(c.case_id)
	# Non constatée : accusation sans preuve.
	EventBus.interrogation_requested.emit(&"about_expired")
	assert_string_starts_with(_last_line(), InspectionSession.about_stem(InspectionSession.FAMILY_VALIDITY, false),
			"indignation propre à la validité")
	assert_eq(_last_reaction(), PassengerReaction.Kind.ANGRY)
	var doc: StringName = &""
	for ref: FieldRef in c.find_refs_by_truth_path(DiscrepancyChecker.EXPIRY_PATH):
		EventBus.discrepancy_check_requested.emit(ref, FieldRef.today())
		if _last_check().confirmed:
			doc = ref.document_id
	assert_ne(doc, &"", "expiration constatée")
	EventBus.interrogation_requested.emit(StringName("about_expired:%s" % doc))
	assert_string_starts_with(_last_line(), InspectionSession.about_stem(InspectionSession.FAMILY_VALIDITY, true))
	assert_eq(_last_reaction(), PassengerReaction.Kind.NERVOUS)
	assert_true(UiText.has(_last_line()))
	EventBus.interrogation_requested.emit(&"about_expired:other_doc")
	assert_eq(_last_reaction(), PassengerReaction.Kind.ANGRY, "autre document : non constaté")


# --- Répliques de confrontation par famille de discordance -------------------

## Contexte du J3 où **toutes** les règles des données sont actives (les
## familles émetteur / origine / santé n'apparaissent qu'après la démo).
func _ctx_all_rules() -> RuleContext:
	var rule_set: RuleSet = RuleSet.new()
	for file: String in DirAccess.get_files_at("res://data/rules"):
		if file.ends_with(".tres"):
			rule_set.rules.append(load("res://data/rules/" + file) as Rule)
	var ctx: RuleContext = RuleContext.new(builder.ctx.today, rule_set)
	ctx.faction_db = builder.ctx.faction_db
	return ctx


func _ref(c: Case, path: StringName) -> FieldRef:
	var refs: Array[FieldRef] = c.find_refs_by_truth_path(path)
	return refs[0] if not refs.is_empty() else null


func _disc(a: FieldRef, b: FieldRef, reason: String) -> Discrepancy:
	return Discrepancy.new(a, b).set_result(Discrepancy.Result.DISCORDANT, reason)


## Chaque type de discordance → une réplique de sa famille (réelle : NERVOUS),
## puis l'indignation quand rien n'a été constaté (ANGRY).
func test_about_line_matches_discrepancy_family() -> void:
	var c: Case = builder.build(0).case
	var ctx: RuleContext = _ctx_all_rules()
	var id_ref: FieldRef = _ref(c, &"citizen_id")
	var name_ref: FieldRef = _ref(c, &"family_name")
	var birth_ref: FieldRef = _ref(c, &"birth_date")
	var expiry_ref: FieldRef = _ref(c, DiscrepancyChecker.EXPIRY_PATH)
	var issuer_ref: FieldRef = _ref(c, &"document.issuer_id")
	var photo: FieldRef = c.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)[0]
	for ref: FieldRef in [id_ref, name_ref, birth_ref, expiry_ref, issuer_ref]:
		assert_not_null(ref, "champ présent sur les documents du J3")
	var other_doc: StringName = &"entry_permit" if id_ref.document_id != &"entry_permit" else &"id_card"
	var cases: Array[Array] = [
		[_disc(FieldRef.passenger_face(), photo, Discrepancy.REASON_FACE_MISMATCH), InspectionSession.FAMILY_FACE],
		[_disc(expiry_ref, FieldRef.today(), Discrepancy.REASON_EXPIRED), InspectionSession.FAMILY_VALIDITY],
		[_disc(id_ref, FieldRef.new(other_doc, &"citizen_id"), Discrepancy.REASON_MISMATCH), InspectionSession.FAMILY_ID_NUMBER],
		[_disc(name_ref, FieldRef.new(other_doc, &"family_name"), Discrepancy.REASON_MISMATCH), InspectionSession.FAMILY_NAME],
		[_disc(birth_ref, FieldRef.new(other_doc, &"birth_date"), Discrepancy.REASON_MISMATCH), InspectionSession.FAMILY_BIRTH],
		[_disc(FieldRef.rulebook_rule(&"r_permit_required"), id_ref, Discrepancy.REASON_RULE_VIOLATED), InspectionSession.FAMILY_MISSING],
		[_disc(FieldRef.rulebook_rule(&"r_bioscan_issuer"), issuer_ref, Discrepancy.REASON_RULE_VIOLATED), InspectionSession.FAMILY_ISSUER],
		[_disc(FieldRef.rulebook_rule(&"r_origin_block"), id_ref, Discrepancy.REASON_RULE_VIOLATED), InspectionSession.FAMILY_ORIGIN],
		[_disc(FieldRef.rulebook_rule(&"r_bioscan_fit"), issuer_ref, Discrepancy.REASON_RULE_VIOLATED), InspectionSession.FAMILY_HEALTH],
		[_disc(FieldRef.rulebook_rule(&"r_id_card_valid"), expiry_ref, Discrepancy.REASON_RULE_VIOLATED), InspectionSession.FAMILY_VALIDITY],
		[_disc(FieldRef.rulebook_rule(&"r_portrait_match"), photo, Discrepancy.REASON_RULE_VIOLATED), InspectionSession.FAMILY_FACE],
		[_disc(FieldRef.rulebook_rule(&"r_identity_fields_match"), name_ref, Discrepancy.REASON_RULE_VIOLATED), InspectionSession.FAMILY_NAME],
	]
	for entry: Array in cases:
		var d: Discrepancy = entry[0]
		var family: String = entry[1]
		var topic: StringName = InterrogationTopics.topic_for(d)
		session.begin(c, ctx)
		EventBus.documents_presented.emit(c.case_id)
		session.confirmed.append(d)
		EventBus.interrogation_requested.emit(topic)
		assert_string_starts_with(_last_line(), InspectionSession.about_stem(family, true), "%s → %s" % [topic, family])
		assert_false(_last_line().contains(InspectionSession.LINE_OUTRAGE_INFIX), "%s : réplique de discordance réelle" % topic)
		assert_true(UiText.has(_last_line()), "traduite : %s" % _last_line())
		assert_eq(_last_reaction(), PassengerReaction.Kind.NERVOUS)
		# Même sujet sans discordance constatée : indignation, colère.
		session.begin(c, ctx)
		EventBus.documents_presented.emit(c.case_id)
		EventBus.interrogation_requested.emit(topic)
		assert_string_starts_with(_last_line(), InspectionSession.LINE_ABOUT_PREFIX, "indignation : %s" % topic)
		assert_true(_last_line().contains(InspectionSession.LINE_OUTRAGE_INFIX), "indignation : %s" % _last_line())
		assert_true(UiText.has(_last_line()))
		assert_eq(_last_reaction(), PassengerReaction.Kind.ANGRY)


func test_about_line_variant_is_deterministic_per_case_seed() -> void:
	var c: Case = builder.build(0).case
	session.begin(c, builder.ctx)
	var first: String = session.about_line(InspectionSession.FAMILY_ID_NUMBER, true)
	assert_eq(session.about_line(InspectionSession.FAMILY_ID_NUMBER, true), first, "même graine → même réplique")
	var seen: Dictionary[String, bool] = {}
	for s: int in 24:
		c.case_seed = 1000 + s
		seen[session.about_line(InspectionSession.FAMILY_ID_NUMBER, true)] = true
	assert_gt(seen.size(), 1, "les graines varient les répliques")
	assert_eq(session.about_line("unknown_family", true).begins_with(
			InspectionSession.about_stem(InspectionSession.FAMILY_OTHER, true)), true, "repli : famille « autre »")


func test_scripted_passenger_visor_line_replaces_generic() -> void:
	var c: Case = _begin(2) # SC-04 : Mira, visière baissée
	assert_true(c.dialogue_tags.has(&"sc04_mira"), "étiquette de dialogue de SC-04")
	EventBus.documents_presented.emit(c.case_id)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
	assert_eq(_last_line(), "sc04_mira_visor", "réplique scénarisée de la visière")
	assert_true(UiText.has(_last_line()))
	assert_false(c.passenger_presented.appearance.is_face_covered())
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
	assert_eq(_last_line(), InspectionSession.LINE_VISOR_NONE, "plus rien à retirer")


func test_every_family_has_real_and_outrage_variants() -> void:
	for family: String in InspectionSession.FAMILIES:
		for real: bool in [true, false]:
			var stem: String = InspectionSession.about_stem(family, real)
			assert_true(UiText.has(stem + "1") and UiText.has(stem + "2"), "%s : au moins 2 variantes" % stem)
		assert_true(UiText.has(InspectionSession.about_stem(family, true) + "3"), "%s : 3 variantes réelles" % family)


func test_scripted_passenger_keeps_dedicated_about_line() -> void:
	var c: Case = builder.build(0).case
	c.dialogue_tags = [&"sc03_nervous_miner"] as Array[StringName]
	session.begin(c, builder.ctx)
	EventBus.documents_presented.emit(c.case_id)
	var photo: FieldRef = c.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)[0]
	session.confirmed.append(_disc(FieldRef.passenger_face(), photo, Discrepancy.REASON_FACE_MISMATCH))
	EventBus.interrogation_requested.emit(&"about_face_mismatch")
	assert_eq(_last_line(), "sc03_nervous_miner_about_face_mismatch")
