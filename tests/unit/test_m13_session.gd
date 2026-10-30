## M13 lot A (ARCHITECTURE §12.4, §12.5) : session d'inspection — puces
## obtenues (`statement_given`), coûts en temps (`inspection_busy`, AG-01),
## question répétée, `cargo`, motif de fouille MF-1 → MF-5 figé à la demande,
## confirmation sans motif, activation et zones après leur durée (AG-03),
## trouvaille, fermeture, réouverture, confrontations M13.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")

var session: InspectionSession = null
var answers: Array[Array] = []
var reactions: Array[PassengerReaction.Kind] = []
var given: Array[Array] = []
var busy: Array[Array] = []
var opened: Array[StringName] = []
var confirmations: int = 0
var scanned: Array[Array] = []
var closed: int = 0


func before_each() -> void:
	session = InspectionSession.new()
	add_child_autofree(session)
	session.set_process(false)
	for list: Array in [answers, reactions, given, busy, opened, scanned]:
		list.clear()
	confirmations = 0
	closed = 0
	EventBus.interrogation_answered.connect(_on_answered)
	EventBus.passenger_reaction_triggered.connect(_on_reaction)
	EventBus.statement_given.connect(_on_given)
	EventBus.inspection_busy.connect(_on_busy)
	EventBus.search_opened.connect(_on_opened)
	EventBus.search_confirmation_required.connect(_on_confirmation)
	EventBus.search_zone_scanned.connect(_on_scanned)
	EventBus.search_closed.connect(_on_closed)


func after_each() -> void:
	EventBus.interrogation_answered.disconnect(_on_answered)
	EventBus.passenger_reaction_triggered.disconnect(_on_reaction)
	EventBus.statement_given.disconnect(_on_given)
	EventBus.inspection_busy.disconnect(_on_busy)
	EventBus.search_opened.disconnect(_on_opened)
	EventBus.search_confirmation_required.disconnect(_on_confirmation)
	EventBus.search_zone_scanned.disconnect(_on_scanned)
	EventBus.search_closed.disconnect(_on_closed)


func _on_answered(topic: StringName, line_key: String) -> void:
	answers.append([topic, line_key])


func _on_reaction(reaction: PassengerReaction.Kind) -> void:
	reactions.append(reaction)


func _on_given(case_id: StringName, statements: Array[Statement]) -> void:
	given.append([case_id, statements])


func _on_busy(_case_id: StringName, duration: float, action: StringName) -> void:
	busy.append([duration, action])


func _on_opened(_case_id: StringName, motive: StringName) -> void:
	opened.append(motive)


func _on_confirmation(_case_id: StringName) -> void:
	confirmations += 1


func _on_scanned(_case_id: StringName, zone: StringName, items: Array[SearchItem]) -> void:
	scanned.append([zone, items])


func _on_closed(_case_id: StringName) -> void:
	closed += 1


## R44 (procédure `search_cause`) et R47 (`belt_search`, CER, > 7 jours).
func _search_rules(with_search: bool = true, with_belt: bool = false) -> RuleSet:
	var rs: RuleSet = RuleSet.new()
	rs.id = &"rs_m13_test"
	if with_search:
		var r44: ProcedureRule = ProcedureRule.new()
		r44.id = &"r_search_cause"
		r44.procedure_id = ProcedureRule.PROCEDURE_SEARCH_CAUSE
		rs.rules.append(r44)
	if with_belt:
		var r47: ProcedureRule = ProcedureRule.new()
		r47.id = &"r_belt_search"
		r47.procedure_id = ProcedureRule.PROCEDURE_BELT_SEARCH
		r47.applies_to_faction_ids = [&"cer"] as Array[StringName]
		r47.min_stay_days = 7
		rs.rules.append(r47)
	return rs.make_shift_copy()


func _layout() -> SearchLayout:
	var layout: SearchLayout = SearchLayout.new()
	layout.add(SearchLayout.ZONE_LUGGAGE, SearchItem.make(&"ol09", SearchItem.Kind.LEGIT, &"clothes"))
	layout.add(SearchLayout.ZONE_TORSO, SearchItem.make(&"cb01", SearchItem.Kind.CONTRABAND, &"oxygen"))
	return layout


func _begin(c: Case, rs: RuleSet = null, flags: Dictionary[StringName, Variant] = {}) -> Case:
	var ctx: RuleContext = CaseFactory.context(rs if rs != null else _search_rules())
	session.begin(c, ctx)
	session.configure(InterrogationTiming.new(), flags)
	EventBus.documents_presented.emit(c.case_id)
	return c


func _statement_case() -> Case:
	var c: Case = CaseFactory.valid_case()
	c.case_seed = 4242
	var stay: Statement = Statement.duration(18, 24, "stmt_dur_w3")
	c.statements = [Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_WORK, "stmt_purpose_work_2"), stay,
			Statement.make(Statement.ID_ORIGIN, &"tyc", "stmt_origin_tyc"),
			Statement.make(Statement.ID_PROVENANCE, &"tyc", "stmt_prov_tessar")] as Array[Statement]
	c.statement_frames = {&"purpose": "line_stmt_frame_gen_1", &"origin": "line_stmt_origin_1"} as Dictionary[StringName, String]
	return c


func _last_line() -> String:
	var line: String = answers[answers.size() - 1][1]
	return line


func _last_busy() -> Array:
	return busy[busy.size() - 1]


# --- Déclarations et coûts ---------------------------------------------------------

func test_purpose_question_gives_its_chips_with_the_frame() -> void:
	var c: Case = _begin(_statement_case())
	assert_false(c.is_statement_given(Statement.ID_STAY), "pas obtenue avant la question")
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
	assert_eq(_last_line(), "line_stmt_frame_gen_1", "cadre composé du cas")
	assert_eq(given.size(), 1)
	var chips: Array[Statement] = given[0][1]
	assert_eq(chips.map(func(s: Statement) -> StringName: return s.id), [&"purpose", &"stay"], "motif + durée")
	assert_true(c.is_statement_given(Statement.ID_PURPOSE))
	assert_true(c.is_statement_given(Statement.ID_STAY))
	assert_false(c.is_statement_given(Statement.ID_ORIGIN))
	assert_eq(_last_busy(), [3.0, InspectionSession.BUSY_QUESTION], "question de base : 3 s")
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_STAY)
	assert_eq(_last_line(), InspectionSession.LINE_STAY_LONG, "sans cadre : réplique générique (30 jours)")
	var stay_chips: Array[Statement] = given[1][1]
	assert_eq(stay_chips.size(), 1)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_ORIGIN)
	var origin_chips: Array[Statement] = given[2][1]
	assert_eq(origin_chips.map(func(s: Statement) -> StringName: return s.id), [&"origin", &"provenance"])
	assert_eq(_last_line(), "line_stmt_origin_1")


func test_case_without_statements_keeps_the_pre_m13_answer() -> void:
	var c: Case = _begin(CaseFactory.valid_case())
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
	assert_eq(_last_line(), "line_purpose_work")
	assert_eq(given.size(), 0, "aucune puce")
	assert_eq(c.statements.size(), 0)


func test_scripted_line_wins_but_chips_are_still_given() -> void:
	var c: Case = _statement_case()
	c.dialogue_tags = [&"sc06_amara"] as Array[StringName]
	_begin(c)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
	assert_eq(_last_line(), "sc06_amara_purpose", "prose scénarisée")
	assert_eq(given.size(), 1, "puces affichées à part")


func test_hygiaphone_correction_and_repeated_question_costs() -> void:
	var c: Case = _statement_case()
	c.get_statement(Statement.ID_STAY).corrected_from = "stmt_dur_w1"
	_begin(c, null, {&"upg_ag01": true} as Dictionary[StringName, Variant])
	assert_true(session.hygiaphone)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_STAY)
	assert_eq(_last_busy(), [3.0, InspectionSession.BUSY_QUESTION], "AG-01 2 s + auto-correction 1 s")
	var before: int = reactions.size()
	var line: String = _last_line()
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_STAY)
	assert_eq(_last_line(), line, "même réponse")
	assert_eq(reactions.size(), before + 1)
	assert_eq(reactions[reactions.size() - 1], PassengerReaction.Kind.ANGRY, "question répétée : ANGRY")
	assert_eq(_last_busy(), [2.0, InspectionSession.BUSY_REPEAT])
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
	assert_eq(_last_busy(), [2.0, InspectionSession.BUSY_QUESTION], "autre geste avec AG-01")
	assert_gt(session.busy_remaining_sec, 0.0)
	session.advance(5.0)
	assert_eq(session.busy_remaining_sec, 0.0)


func test_cargo_answer_and_evasive_motive() -> void:
	var c: Case = CaseFactory.valid_case()
	c.cargo_reply = Case.CARGO_EVASIVE
	c.cargo_line_key = "line_cargo_evasive_1"
	_begin(c)
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_NONE, "évasive non obtenue : pas de motif")
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_CARGO)
	assert_eq(_last_line(), "line_cargo_evasive_1")
	assert_eq(_last_busy(), [3.0, InspectionSession.BUSY_QUESTION])
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_EVASIVE, "MF-3")
	var plain: Case = _begin(CaseFactory.valid_case())
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_CARGO)
	assert_eq(_last_line(), InspectionSession.LINE_CARGO_DEFAULT)
	assert_eq(plain.cargo_reply, &"")


# --- Motif de fouille --------------------------------------------------------------

func test_search_motive_order_mf1_to_mf5() -> void:
	var c: Case = _begin(CaseFactory.valid_case())
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_NONE)
	c.search_cues = [SearchLayout.CUE_GLOVE] as Array[StringName]
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_CUE, "MF-2")
	var d: Discrepancy = Discrepancy.new(FieldRef.statement(&"stay"), FieldRef.new(&"entry_permit", &"stay_days"))
	session.confirmed.append(d.set_result(Discrepancy.Result.DISCORDANT, "disc_statement_mismatch"))
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_DISCORD, "MF-1 d'abord")
	# MF-4 : EV-09 (surcharge de R44 pour une origine).
	var rs: RuleSet = _search_rules()
	var directive: Case = _begin(CaseFactory.valid_case(), rs)
	rs.apply_changes([RuleChangeDef.override(&"r_search_cause",
			{InspectionSession.PARAM_SEARCH_AUTHORIZED: true} as Dictionary[StringName, Variant],
			[&"tyc"] as Array[StringName])] as Array[RuleChangeDef], &"ev_09")
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_DIRECTIVE, "MF-4 : TYC couvert")
	directive.passenger_presented.faction_id = &"ter"
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_NONE, "hors du profil")
	# MF-4 : directive du briefing.
	var day: DayDef = DayDef.new()
	day.search_directive_purposes = [Passenger.PURPOSE_WORK] as Array[StringName]
	session.ctx.day_def = day
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_DIRECTIVE, "briefing : motif TRAVAIL")
	# MF-5 : R47, Ceinturier au séjour > 7 jours (permis).
	var belt: Case = _begin(CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT] as Array[StringName], &"cer"),
			_search_rules(true, true))
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_MANDATORY, "MF-5 : 30 jours")
	belt.get_document(CaseFactory.PERMIT).values[&"stay_days"] = 5
	assert_eq(session.compute_search_motive(), SearchLayout.MOTIVE_NONE, "5 jours : pas de fouille obligatoire")


func test_search_unavailable_without_r44() -> void:
	_begin(CaseFactory.valid_case(), RuleSet.new().make_shift_copy())
	assert_false(session.search_available())
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_SEARCH)
	assert_eq(_last_line(), InspectionSession.LINE_GENERIC_SHRUG)
	assert_eq(opened.size(), 0)
	assert_false(session.search_done)
	assert_false(session.questions_asked.has(InspectionSession.TOPIC_SEARCH))


func test_search_without_motive_needs_confirmation_and_freezes_the_motive() -> void:
	var c: Case = _begin(CaseFactory.valid_case())
	c.search_layout = _layout()
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_SEARCH)
	assert_eq(confirmations, 1, "AUCUN MOTIF ÉTABLI : confirmation")
	assert_eq(opened.size(), 0)
	assert_false(session.search_done, "rien n'est compté avant la confirmation")
	EventBus.search_requested.emit(InspectionSession.SEARCH_CANCEL)
	assert_eq(session.search_state, InspectionSession.SearchState.IDLE)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_SEARCH)
	assert_eq(confirmations, 2)
	# Une discordance trouvée après la demande ne change pas le motif figé.
	var d: Discrepancy = Discrepancy.new(FieldRef.statement(&"stay"), FieldRef.new(&"entry_permit", &"stay_days"))
	session.confirmed.append(d.set_result(Discrepancy.Result.DISCORDANT, "disc_statement_mismatch"))
	EventBus.search_requested.emit(InspectionSession.SEARCH_CONFIRM)
	assert_eq(opened, [&""] as Array[StringName], "fouille sans motif confirmée")
	assert_true(session.search_done)
	assert_false(session.questions_asked.has(InspectionSession.TOPIC_SEARCH), "ne vaut pas interrogatoire (R08)")
	var verdict: Verdict = Verdict.new(c.case_id)
	session.end(verdict)
	assert_true(verdict.search_done)
	assert_eq(verdict.search_motive, &"", "motif figé à la demande")
	assert_eq(closed, 1, "le tampon referme le portique")


func test_search_with_motive_opens_scans_zones_after_their_duration() -> void:
	var c: Case = CaseFactory.valid_case()
	c.case_seed = 77
	c.search_layout = _layout()
	c.search_cues = [SearchLayout.CUE_SATCHEL] as Array[StringName]
	_begin(c)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_SEARCH)
	assert_eq(confirmations, 0)
	assert_eq(opened, [SearchLayout.MOTIVE_CUE] as Array[StringName])
	assert_eq(answers[answers.size() - 1][0], InspectionSession.TOPIC_SEARCH)
	assert_true(_last_line().begins_with("line_search_"), "réplique d'entrée au portique")
	assert_eq(_last_busy(), [2.0, InspectionSession.BUSY_SEARCH_ACTIVATION])
	EventBus.search_requested.emit(SearchLayout.ZONE_LUGGAGE)
	session.advance(1.9)
	assert_eq(session.search_state, InspectionSession.SearchState.ACTIVATING)
	assert_eq(scanned.size(), 0)
	session.advance(0.2)
	assert_eq(session.search_state, InspectionSession.SearchState.OPEN)
	assert_eq(_last_busy(), [2.0, InspectionSession.BUSY_SEARCH_ZONE], "zone : 2 s")
	session.advance(1.8)
	assert_eq(scanned.size(), 0, "la zone n'est pas finie")
	session.advance(0.2)
	assert_eq(scanned.size(), 1)
	assert_eq(scanned[0][0], SearchLayout.ZONE_LUGGAGE)
	assert_eq((scanned[0][1] as Array).size(), 1)
	assert_true(c.is_scan_item_revealed(FieldRef.scan(&"z5", 0)))
	assert_false(c.is_scan_item_revealed(FieldRef.scan(&"z2", 0)), "torse non scanné")
	EventBus.search_requested.emit(SearchLayout.ZONE_LUGGAGE)
	EventBus.search_requested.emit(SearchLayout.ZONE_ALL)
	session.advance(7.9)
	assert_eq(scanned.size(), 4, "TOUT SCANNER : 2 s par zone restante")
	session.advance(0.2)
	assert_eq(scanned.size(), 5, "les 5 zones, la z5 une seule fois")
	assert_eq(reactions[reactions.size() - 1], PassengerReaction.Kind.NERVOUS, "cartouche trouvée au torse")
	EventBus.search_requested.emit(InspectionSession.SEARCH_CLOSE)
	assert_eq(closed, 1)
	var verdict: Verdict = Verdict.new(c.case_id)
	session.end(verdict)
	assert_eq(verdict.search_motive, SearchLayout.MOTIVE_CUE)
	assert_eq(verdict.zones_scanned.size(), 5)
	assert_eq(verdict.zones_scanned[0], SearchLayout.ZONE_LUGGAGE)


func test_calibrated_gate_halves_the_search() -> void:
	var c: Case = CaseFactory.valid_case()
	c.search_layout = _layout()
	c.search_cues = [SearchLayout.CUE_BULGE] as Array[StringName]
	_begin(c, null, {&"upg_ag03": true} as Dictionary[StringName, Variant])
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_SEARCH)
	assert_eq(_last_busy(), [1.0, InspectionSession.BUSY_SEARCH_ACTIVATION], "AG-03 : 1 s")
	EventBus.search_requested.emit(SearchLayout.ZONE_ALL)
	session.advance(5.9)
	assert_eq(scanned.size(), 4)
	session.advance(0.2)
	assert_eq(scanned.size(), 5, "fouille complète 6 s")


func test_clean_search_closes_with_its_line_and_reopens_with_the_same_motive() -> void:
	var c: Case = CaseFactory.valid_case()
	c.case_seed = 9
	var layout: SearchLayout = SearchLayout.new()
	layout.add(SearchLayout.ZONE_LUGGAGE, SearchItem.make(&"ol09", SearchItem.Kind.LEGIT))
	c.search_layout = layout
	c.search_cues = [SearchLayout.CUE_SATCHEL] as Array[StringName]
	_begin(c)
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_SEARCH)
	EventBus.search_requested.emit(SearchLayout.ZONE_LUGGAGE)
	session.advance(4.0)
	var before: int = answers.size()
	EventBus.search_requested.emit(InspectionSession.SEARCH_CLOSE)
	if UiText.has("line_search_clean_1"):
		assert_eq(answers.size(), before + 1)
		assert_true(_last_line().begins_with(InspectionSession.LINE_SEARCH_CLEAN_PREFIX), "rien d'interdit")
	assert_eq(session.search_state, InspectionSession.SearchState.CLOSED)
	c.search_cues.clear()
	EventBus.interrogation_requested.emit(InspectionSession.TOPIC_SEARCH)
	assert_eq(opened, [SearchLayout.MOTIVE_CUE, SearchLayout.MOTIVE_CUE] as Array[StringName], "réouverture : même motif")
	assert_eq(confirmations, 0)
	assert_eq(session.search_state, InspectionSession.SearchState.ACTIVATING)


# --- Confrontations ----------------------------------------------------------------

func test_about_statement_confrontation_and_families() -> void:
	var c: Case = _begin(_statement_case())
	EventBus.interrogation_requested.emit(&"about_statement:entry_permit")
	assert_eq(reactions[reactions.size() - 1], PassengerReaction.Kind.ANGRY, "rien de constaté : indignation")
	var d: Discrepancy = Discrepancy.new(FieldRef.statement(&"stay"), FieldRef.new(&"entry_permit", &"stay_days"))
	d.set_result(Discrepancy.Result.DISCORDANT, "disc_statement_mismatch")
	session.confirmed.append(d)
	assert_eq(InspectionSession.family_of(d, c, session.ctx), InspectionSession.FAMILY_STATEMENT)
	EventBus.interrogation_requested.emit(&"about_statement:entry_permit")
	assert_eq(reactions[reactions.size() - 1], PassengerReaction.Kind.NERVOUS)
	if UiText.has("line_about_statement_1"):
		assert_true(_last_line().begins_with("line_about_statement_"), "réplique de la famille")
	assert_eq(_last_busy(), [4.0, InspectionSession.BUSY_CONFRONT], "confrontation : 4 s")
	var line: String = _last_line()
	EventBus.interrogation_requested.emit(&"about_statement:entry_permit")
	assert_eq(_last_line(), line, "même réponse")
	assert_eq(reactions[reactions.size() - 1], PassengerReaction.Kind.ANGRY, "confrontation répétée : ANGRY")
	assert_eq(_last_busy(), [2.0, InspectionSession.BUSY_REPEAT])
	assert_eq(session.find_confirmed("statement", &"id_card"), null, "le document filtre")
	assert_eq(session.find_confirmed("statement"), d)
	assert_eq(c.statements.size(), 4, "aucune réponse ne retire la discordance")
	var contraband: Discrepancy = Discrepancy.new(FieldRef.scan(&"z2", 0), FieldRef.rulebook_rule(&"r_contraband"))
	contraband.set_result(Discrepancy.Result.DISCORDANT, "disc_contraband")
	assert_eq(InspectionSession.family_of(contraband, c, session.ctx), InspectionSession.FAMILY_CONTRABAND)
	var weapon: Discrepancy = Discrepancy.new(FieldRef.scan(&"z5", 0), FieldRef.rulebook_rule(&"r_weapons_detain"))
	weapon.set_result(Discrepancy.Result.DISCORDANT, "disc_weapon")
	assert_eq(InspectionSession.family_of(weapon, c, session.ctx), InspectionSession.FAMILY_WEAPON)
	var implant: Discrepancy = Discrepancy.new(FieldRef.scan(&"z3", 0), FieldRef.new(&"id_card", &"implants"))
	implant.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_IMPLANT_MISMATCH)
	assert_eq(InspectionSession.family_of(implant, c, session.ctx), InspectionSession.FAMILY_CONCEALED_IMPLANT)
	assert_eq(InspectionSession.family_of_reason("contraband"), InspectionSession.FAMILY_CONTRABAND)
	assert_eq(InspectionSession.family_of_reason("statement"), InspectionSession.FAMILY_STATEMENT)
