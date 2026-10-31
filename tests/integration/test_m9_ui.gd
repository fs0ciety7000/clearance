## M9 partie B — interfaces de l'Acte III (UI/UX, ARCHITECTURE §7.3) : onglets
## Main courante (paire Répondant ↔ entrée) et Convocations, colonne
## « RÉINTÉGRÉ·E LE », règles retirées barrées et quota « SUSPENDU », lignes
## optionnelles du permis, puces RETIRÉ / PROROGÉ, sujets de l'Acte III, carte
## « FIN DE L'ACTE II » et « Embarquer » au J20, Enquête et Déposition du J29,
## aides du soir, « CHAPITRE III », bilan du J30, dix fins, traces, figure
## finale, accessoires 3D, plan de travail lisible.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const ACTOR_SCENE: PackedScene = preload("res://scenes/passenger/passenger_actor.tscn")
const CAMPAIGN_SEED: int = 20_871_315
const SPONSOR_ID: String = "HG-1123-4567"

var ui: ComparisonUI = null
var case: Case = null
var data: DataCatalog = null
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = CaseFactory.catalog()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)


func after_each() -> void:
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _make_ui(day_number: int) -> DayDef:
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	var day: DayDef = data.get_day(day_number)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	case.index = 3
	return day


func _present() -> void:
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)


func _ledger_entry(id: StringName, citizen_id: String, index: int) -> LedgerEntry:
	var entry: LedgerEntry = LedgerEntry.new()
	entry.id = id
	entry.citizen_id = citizen_id
	entry.given_name = "Margaux"
	entry.family_name = "Lefèvre"
	entry.citizen_class = &"C-2"
	entry.faction_id = &"hal"
	entry.case_index = index
	return entry


func _last_pair() -> String:
	var count: int = get_signal_emit_count(EventBus, "discrepancy_check_requested")
	if count == 0:
		return ""
	var params: Array = get_signal_parameters(EventBus, "discrepancy_check_requested", count - 1)
	var a: FieldRef = params[0]
	var b: FieldRef = params[1]
	return InspectionSelection.pair_key(a, b)


# ---------------------------------------------------------------------------
# Rulebook : Main courante, Convocations, Révocations, retraits
# ---------------------------------------------------------------------------

func test_ledger_tab_grows_and_pairs_with_the_permit_sponsor() -> void:
	_make_ui(24)
	EventBus.ledger_changed.emit([] as Array[LedgerEntry])
	assert_true(ui.rulebook.visible_reference_tabs().has(RulebookReference.TAB_LEDGER), "Main courante ouverte dès le J24, même vide")
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_LEDGER))
	assert_not_null(ui.rulebook.find_child("LedgerEmpty", true, false), "« Aucun répondant admis pour l'instant. »")
	var margaux: LedgerEntry = _ledger_entry(&"ledger_01", SPONSOR_ID, 1)
	EventBus.ledger_changed.emit([margaux] as Array[LedgerEntry])
	var card: LedgerCardView = ui.rulebook.get_ledger_card(&"ledger_01")
	assert_not_null(card, "la liste s'allonge pendant le shift")
	assert_gt(card.glow, 0.0, "dernière entrée surlignée")
	assert_eq(card.ref.field_id, &"ledger_01")
	assert_true(card.ref.is_ledger())
	await wait_process_frames(1)
	assert_null(ui.rulebook.find_child("LedgerEmpty", true, false))
	# Permis d'un protégé : ligne Répondant présente, en bas, seule sur sa ligne.
	var permit: DocumentInstance = case.get_document(CaseFactory.PERMIT)
	permit.values[&"sponsor"] = SPONSOR_ID
	_present()
	var view: DocumentView = ui.workbench.get_view(CaseFactory.PERMIT)
	var sponsor_ref: FieldRef = FieldRef.new(CaseFactory.PERMIT, &"sponsor")
	var sponsor_item: InspectableItem = view.find_item(sponsor_ref)
	assert_not_null(sponsor_item, "champ Répondant affiché quand il est rempli")
	assert_null(view.find_item(FieldRef.new(CaseFactory.PERMIT, &"summons")), "Convocation vide : non affichée")
	assert_eq(sponsor_item.get_parent().get_child_count(), 1, "Répondant seul sur sa ligne")
	watch_signals(EventBus)
	ui.set_inspection_active(true)
	ui.pick(sponsor_ref)
	ui.pick(margaux.get_ref())
	assert_eq(_last_pair(), InspectionSelection.pair_key(sponsor_ref, margaux.get_ref()), "paire Répondant ↔ Main courante")
	# Résultat CONCORDANT expliqué avec le N° ID et le nom du répondant.
	var result: Discrepancy = Discrepancy.new(sponsor_ref, margaux.get_ref())
	result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_SPONSOR_MATCH)
	assert_string_contains(ui.describe(result), SPONSOR_ID)


func test_summons_tab_and_reinstated_revocations() -> void:
	var day: DayDef = _make_ui(26)
	var entry: SummonsEntry = SummonsEntry.new()
	entry.id = &"summons_01"
	entry.number = "ENQ-0412"
	entry.given_name = "Lev"
	entry.family_name = "Antonov"
	EventBus.summons_published.emit([entry] as Array[SummonsEntry])
	assert_true(ui.rulebook.visible_reference_tabs().has(RulebookReference.TAB_SUMMONS))
	assert_true(ui.rulebook.find_item(entry.get_ref(), true) is SummonsCardView, "un lien vers une convocation rouvre l'onglet")
	var card: SummonsCardView = ui.rulebook.get_summons_card(&"summons_01")
	assert_not_null(card)
	assert_string_contains(card.display_label, "ENQ-0412")
	var named: Discrepancy = Discrepancy.new(FieldRef.new(CaseFactory.PERMIT, &"summons"), entry.get_ref())
	named.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_SUMMONS_NAME)
	_present()
	assert_string_contains(ui.describe(named), "ANTONOV", "convocation à un autre nom")
	# Révocations : colonne « RÉINTÉGRÉ·E LE » et motif d'exclusion.
	var back: RevokedEntry = RevokedEntry.new()
	back.id = &"rev_back"
	back.citizen_id = "HG-1404-0001"
	back.reinstated_on = day.game_date - 1
	var excluded: RevokedEntry = RevokedEntry.new()
	excluded.id = &"rev_excluded"
	excluded.citizen_id = "HG-1404-0002"
	excluded.excluded_reason_key = "rb_reinstated_excluded"
	EventBus.revocations_published.emit([back, excluded] as Array[RevokedEntry])
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_REVOKED))
	var back_card: RevokedCardView = ui.rulebook.get_revoked_card(&"rev_back")
	assert_true(back_card.reinstated, "réintégration atteinte : révocation levée")
	assert_not_null(back_card.find_child("ReinstatedOn", true, false))
	var excluded_card: RevokedCardView = ui.rulebook.get_revoked_card(&"rev_excluded")
	assert_false(excluded_card.reinstated)
	assert_not_null(excluded_card.find_child("Excluded", true, false), "motif d'exclusion affiché")


func test_retired_rules_are_struck_and_quota_suspended() -> void:
	_make_ui(23)
	var retired: Array[RuleCardView] = []
	for card: RuleCardView in ui.rulebook.cards:
		if card.is_retired():
			retired.append(card)
	assert_eq(retired.size(), 4, "règles du bio-scan barrées le jour du retrait")
	assert_false(retired[0].comparable, "une règle retirée n'est jamais comparable")
	assert_eq(retired[0].note_text, UiText.t("rb_retired_quais"), "motif : repris par les quais")
	assert_not_null(retired[0].find_child("Note", true, false))
	var quota_card: RuleCardView = ui.rulebook.get_rule_card(RulebookPanel.RULE_QUOTA)
	assert_not_null(quota_card)
	assert_eq(quota_card.note_text, UiText.t("rb_suspended_quota"), "R23 : SUSPENDU PENDANT L'ENQUÊTE")
	EventBus.quota_changed.emit(0, 0)
	var counter: QuotaCounterView = ui.top_bar.quota_view
	assert_true(counter.visible and counter.suspended, "compteur gris « QUOTA SUSPENDU »")
	assert_eq(counter.get_value_text(), UiText.t("tb_quota_suspended"))
	assert_false(counter.comparable)
	# Climat Vanne (J27+) : R23 en vigueur mais levée par le maximum 0.
	_make_ui(27)
	EventBus.quota_changed.emit(0, 0)
	assert_true(ui.quota_suspended)
	assert_eq(ui.rulebook.get_rule_card(RulebookPanel.RULE_QUOTA).note_text, UiText.t("rb_suspended_quota"))
	EventBus.quota_changed.emit(1, 4)
	assert_false(ui.top_bar.quota_view.suspended, "quota rétabli au J27 hors Vanne")


func test_retired_document_and_prorogated_chips() -> void:
	_make_ui(23)
	var bioscan: DocumentInstance = CaseFactory.document(CaseFactory.BIOSCAN, case.passenger_presented)
	bioscan.retired = true
	case.documents.append(bioscan)
	_present()
	var view: DocumentView = ui.workbench.get_view(CaseFactory.BIOSCAN)
	assert_not_null(view.find_child("Retired", true, false), "puce RETIRÉ sur le certificat repris par les quais")
	var permit_view: DocumentView = ui.workbench.get_view(CaseFactory.PERMIT)
	assert_null(permit_view.prorogated_chip)
	var dated: FieldRef = FieldRef.new(CaseFactory.PERMIT, &"expiry_date")
	ui.set_inspection_active(true)
	ui.pick(dated)
	ui.pick(FieldRef.today())
	var result: Discrepancy = Discrepancy.new(dated, FieldRef.today())
	result.set_result(Discrepancy.Result.CONCORDANT, Discrepancy.REASON_PROROGATED)
	EventBus.discrepancy_checked.emit(result)
	assert_not_null(permit_view.prorogated_chip, "PROROGÉ (R32) posé sur le document")
	assert_string_contains(ui.describe(result), UiText.t("cmp_prorogated"))


func test_act3_topics_have_their_questions() -> void:
	for topic: StringName in [InterrogationTopics.ABOUT_SPONSOR, InterrogationTopics.ABOUT_SUMMONS, InterrogationTopics.ABOUT_LOCKOUT]:
		var key: String = InterrogationTopics.question_key(topic)
		assert_true(UiText.has(key), key)
		assert_false(UiText.t(key).contains("§"), "texte définitif (%s)" % key)
	var violated: Discrepancy = Discrepancy.new(FieldRef.new(CaseFactory.PERMIT, &"sponsor"), FieldRef.rulebook_rule(&"r_sponsor"))
	violated.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_RULE_VIOLATED)
	assert_eq(InterrogationTopics.topic_for(violated), InterrogationTopics.ABOUT_SPONSOR)
	_make_ui(24)
	_present()
	ui.unlocked_topics.append(InterrogationTopics.ABOUT_SPONSOR)
	assert_true(ui.available_topics().has(InterrogationTopics.ABOUT_SPONSOR), "bouton du sujet proposé")


# ---------------------------------------------------------------------------
# Soirées : J20 (carte, Embarquer), Enquête, Déposition, aides
# ---------------------------------------------------------------------------

func _start_at(day_number: int, flags: Dictionary, credits: int = 200) -> void:
	Campaign.new_game(data, CAMPAIGN_SEED)
	GameState.current_day = day_number
	GameState.credits = credits
	for flag: Variant in flags:
		GameState.set_flag(StringName(str(flag)), flags[flag])


func _evening_screen() -> EveningScreen:
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(data.get_day(GameState.current_day), GameState.credits, 20, lines, GameState.household, false)
	screen.set_events(events)
	screen.audit_preview = func(choices: Dictionary[StringName, StringName]) -> void:
		Campaign.preview_evening(data, lines, events, choices)
	return screen


func test_end_of_act_card_opens_the_pivot_evening() -> void:
	_start_at(20, {"act2_started": true, "final2_passed": true, "lucioles_trust": 8, "suspicion": 6, "drift2_passes_bought": true})
	var screen: EveningScreen = _evening_screen()
	screen.act_card_auto_close = false
	add_child_autofree(screen)
	await wait_process_frames(2)
	var card: EveningEvent = screen.act_card_event()
	assert_not_null(card, "carte « FIN DE L'ACTE II » au J20")
	assert_eq(screen.events.find(card), 0, "panneau 0")
	assert_not_null(screen.act_card_layer, "plein cadre à l'ouverture de la soirée")
	var title: Label = screen.act_card_layer.find_child("CardTitle", true, false) as Label
	assert_eq(title.text, UiText.t(card.title_key), "titre de la fin de l'Acte II")
	assert_eq(screen.act_card_layer.find_children("CardLine_*", "", true, false).size(), 2, "deux lignes")
	assert_eq(EveningScreen.act_card_accent(card), EndScreen.accent_of(EndingService.F5_AIR), "couleur de la fin rappelée")
	screen.close_act_card()
	assert_null(screen.act_card_layer, "passable")
	# « Embarquer » : même boîte modale qu'au J10, jamais par défaut.
	var drift: EveningEvent = screen.get_event(&"d20_drift")
	assert_not_null(drift)
	var board: EveningOptionDef = null
	for option: EveningOptionDef in drift.options:
		if option.ends_campaign != &"":
			board = option
	assert_not_null(board)
	var default_choice: StringName = screen.get_choices().get(drift.id, &"")
	assert_ne(default_choice, board.id, "défaut : rester")
	assert_false(screen.request_choice(drift.id, board.id))
	assert_not_null(screen.confirm_layer, "confirmation « QUITTER HALCYON ? »")
	assert_true(screen.accept_final_confirm())
	assert_eq(screen.choices[drift.id], board.id)


func test_act_card_passes_by_itself() -> void:
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, false)
	_start_at(20, {"act2_started": true})
	var screen: EveningScreen = _evening_screen()
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_not_null(screen.act_card_layer)
	await wait_seconds(EveningScreen.ACT_CARD_HOLD_SEC + DS.DUR_DRAMATIC + 0.3)
	assert_null(screen.act_card_layer, "la carte passe seule après ≈ 3 s")


func test_enquiry_question_panel_speaks_with_ravel() -> void:
	_start_at(22, {"act2_started": true, "act3_started": true, "final_passed": true, "final2_passed": true})
	var screen: EveningScreen = _evening_screen()
	add_child_autofree(screen)
	await wait_process_frames(2)
	var question: EveningEvent = screen.get_event(&"d22_q1")
	assert_not_null(question)
	screen.show_step(screen.events.find(question))
	await wait_process_frames(1)
	assert_not_null(screen.find_child("Speaker", true, false), "« ENQUÊTE · C. RAVEL »")
	assert_eq(screen._event_accent(question), DS.STATE_AMBER, "voix de l'Inspection (ambre)")
	for option_id: StringName in [&"tell", &"silent", &"accuse"]:
		assert_true(screen.option_buttons.has(option_id), "option %s" % option_id)


func test_deposition_verdict_follows_the_players_choice() -> void:
	_start_at(29, {"act2_started": true, "act3_started": true, "suspicion": 4}, 300)
	var screen: EveningScreen = _evening_screen()
	add_child_autofree(screen)
	await wait_process_frames(2)
	var verdict: EveningEvent = screen.get_event(&"d29_verdict")
	var deposition: EveningEvent = screen.get_event(&"d29_deposition")
	assert_not_null(verdict)
	assert_true(screen.is_audit_pending(verdict), "verdict en délibéré tant que la déposition n'est pas choisie")
	screen.show_step(screen.events.find(verdict))
	await wait_process_frames(1)
	assert_not_null(screen.find_child("VerdictPending", true, false))
	# « Dire ce qu'on attend » (−2) : rien à retenir ; le verdict est révélé.
	screen.show_step(screen.events.find(deposition))
	assert_true(screen.choose(deposition.id, &"loyal"))
	await wait_process_frames(1)
	assert_eq(screen.step, screen.events.find(verdict), "le choix fait, le verdict s'affiche")
	assert_eq(str(verdict.audit.get("result_key", "")), "evt_d29_verdict_clean")
	var consequence: Label = screen.find_child("Consequence", true, false) as Label
	assert_eq(consequence.text, UiText.t("ev_dep_clean"))
	assert_not_null(screen.find_child("Said", true, false), "rappel de ce qui a été dit")
	# « Tout dire » (+2) : blâme, retenue visible.
	screen.show_step(screen.events.find(deposition))
	assert_true(screen.choose(deposition.id, &"truth"))
	await wait_process_frames(1)
	assert_eq(str(verdict.audit.get("result_key", "")), "evt_d29_verdict_blame")
	assert_eq(SaveService.as_int(verdict.audit.get("cost", 0)), data.get_economy().deposition_retention)
	# Arrestation : la suite de la soirée est sautée.
	_start_at(29, {"act2_started": true, "act3_started": true, "suspicion": 4, "enquete_cible": true, "aveux": 1})
	var arrested: EveningScreen = _evening_screen()
	add_child_autofree(arrested)
	await wait_process_frames(2)
	assert_true(arrested.choose(&"d29_deposition", &"silent"))
	var outcome: EveningEvent = arrested.get_event(&"d29_verdict")
	var ending: StringName = outcome.audit.get("ending", &"")
	assert_eq(ending, EndingService.F1_ARRESTED)
	var after: int = arrested.events.find(outcome) + 1
	if after < arrested.events.size():
		assert_true(arrested.is_skipped(arrested.events[after]), "la soirée s'arrête au verdict")


func test_letter_aids_are_counted_as_income() -> void:
	_start_at(21, {"act2_started": true, "act3_started": true, "quota_overrun": 3}, 20)
	var screen: EveningScreen = _evening_screen()
	add_child_autofree(screen)
	await wait_process_frames(2)
	var aid: int = 0
	for event: EveningEvent in screen.events:
		aid += EveningScreen.letter_gain(event)
	assert_gt(aid, 0, "rappel des salaires imputés versé ce soir")
	var row: Control = screen.find_child("Income_d21_recall", true, false) as Control
	assert_not_null(row, "ligne « Rappel des salaires imputés » dans les revenus")
	assert_eq(screen.event_balance_delta(), aid + _option_net(screen), "aide comptée dans le solde après la soirée")


func _option_net(screen: EveningScreen) -> int:
	var net: int = 0
	for event: EveningEvent in screen.events:
		var chosen: StringName = screen.choices.get(event.id, &"")
		var option: EveningOptionDef = event.get_option(chosen)
		if option != null:
			net += option.gain - option.cost
	return net


# ---------------------------------------------------------------------------
# Scène de jour : Chapitre III, bilan du J30, dix fins
# ---------------------------------------------------------------------------

func _scene(day_number: int) -> DayScene:
	GameState.new_campaign(CAMPAIGN_SEED)
	GameState.current_day = day_number
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	return scene


func test_chapter_three_interstitial_after_the_pivot() -> void:
	var scene: DayScene = _scene(20)
	assert_false(scene.chapter_three_pending())
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(EndingService.FLAG_ACT3, true)
	GameState.set_flag(&"climate_vitres", true)
	GameState.current_day = 21
	assert_false(scene.chapter_two_pending(), "pas de Chapitre II au J21")
	assert_true(scene.chapter_three_pending())
	scene._after_evening(&"next")
	var chapter: ChapterScreen = scene.screen as ChapterScreen
	assert_not_null(chapter, "« CHAPITRE III · TÉMOINS »")
	var last_screen: StringName = scene.screen_history.back()
	assert_eq(last_screen, &"chapter3")
	assert_eq(chapter.act, 3)
	assert_eq(chapter.recap_keys, PackedStringArray(["chapter3_recall", "chapter3_climate_vitres"]))
	for key: String in chapter.recap_keys:
		assert_true(UiText.has(key), key)
	assert_eq(UiText.t(chapter.text_key("title")), "TÉMOINS")
	var numeral: ChapterScreen.RomanTwo = chapter.find_child("Numeral", true, false) as ChapterScreen.RomanTwo
	assert_eq(numeral.stems, 3, "chiffre « Ⅲ »")
	assert_eq(chapter.accent(), DS.STATE_AMBER)
	GameState.current_day = 22
	assert_false(scene.chapter_three_pending(), "une seule fois")


func test_last_day_summary_counts_tycho_families() -> void:
	var day: DayDef = data.get_day(30)
	var summary: DaySummary = DaySummary.new()
	summary.day_number = 30
	summary.planned_cases = 3
	for i: int in 3:
		var result: CaseResult = CaseResult.new(StringName("c%d" % i))
		result.verdict_kind = VerdictKind.Kind.APPROVE
		result.correct = true
		if i < 2:
			result.narrative_changes[&"pont"] = i + 1
		summary.results.append(result)
	assert_eq(ShiftSummaryScreen.admission_count(summary, day), 2)
	var screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
	screen.setup(summary, day)
	add_child_autofree(screen)
	await wait_process_frames(2)
	var tile: Control = screen.find_child("PontTile", true, false) as Control
	assert_not_null(tile, "« FAMILLES DE TYCHO ADMISES »")
	var screen29: ShiftSummaryScreen = ShiftSummaryScreen.new()
	screen29.setup(summary, data.get_day(29))
	add_child_autofree(screen29)
	await wait_process_frames(1)
	assert_null(screen29.find_child("PontTile", true, false), "seulement le jour des familles")


func test_end_screen_has_ten_act_three_endings() -> void:
	var scene: DayScene = _scene(30)
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(EndingService.FLAG_ACT3, true)
	GameState.set_flag(&"pont", 6)
	GameState.set_flag(&"final3_dora", true)
	GameState.set_flag(&"final3_detained", true)
	GameState.set_flag(&"deposition_truth", true)
	for ending: StringName in [EndingService.F1_ARRESTED, EndingService.F4_GLORY, EndingService.F5_AIR, EndingService.F6_DRIFT,
			EndingService.F7_REOPENS, EndingService.F8_REGISTRE, EndingService.F9_STRIKE, EndingService.F10_PONT]:
		scene.show_end(ending)
		# M14 : la cinématique de la fin passe d'abord (testée par test_m14_ui).
		var sequence: CinematicScreen = scene.screen as CinematicScreen
		assert_not_null(sequence, "%s : cinématique avant l'écran de fin" % ending)
		if sequence != null:
			sequence.skip_all()
		var end: EndScreen = scene.screen as EndScreen
		var act: int = end.epilogue["act"]
		assert_eq(act, 3, "%s : épilogue de l'Acte III" % ending)
		var title_key: String = end.epilogue["title_key"]
		var eyebrow_key: String = end.epilogue["eyebrow_key"]
		assert_true(UiText.has(title_key), title_key)
		assert_true(UiText.has(eyebrow_key), eyebrow_key)
		var chip: PanelContainer = end.find_child("ActChip", true, false) as PanelContainer
		assert_not_null(chip, "puce ACTE III")
		var chip_label: Label = chip.find_children("", "Label", true, false)[0] as Label
		assert_eq(chip_label.text, UiText.t("end_act3_chip"))
		assert_not_null(end.find_child("FigureChip", true, false), "figure finale du J30")
		for line: String in end.epilogue_lines():
			assert_false(line.contains("%d"), "%s : valeurs formatées" % ending)
		var variant: String = str(end.epilogue.get("variant", ""))
		if not variant.is_empty():
			assert_true(UiText.has("end_variant_%s" % variant), "variante %s traduite" % variant)
			assert_not_null(end.find_child("VariantChip", true, false))
		assert_ne(EndScreen.accent_of(ending, variant), Color.TRANSPARENT)
		await wait_process_frames(1)
	assert_eq(UiText.t("end_eyebrow_f10_pont"), UiText.t(str(Campaign.epilogue(EndingService.F10_PONT)["eyebrow_key"])), "surtitre F10")
	assert_eq(EndScreen.accent_of(EndingService.F10_PONT), DS.STATE_GREEN)
	assert_eq(EndScreen.icon_of(EndingService.F10_PONT), UiIcon.Kind.APPROVED)


func test_act_three_traces_and_final_figure() -> void:
	var flags: Dictionary[StringName, Variant] = {&"deposition_truth": true, &"strike2_joined": true, &"pont": 5}
	var keys: PackedStringArray = EndScreen.trace_keys(flags)
	assert_true(keys.has("end_trace_deposition_truth"))
	assert_true(keys.has("end_trace_pont"))
	for key: String in keys:
		assert_true(UiText.has(key), key)
	assert_string_contains(EndScreen.trace_text("end_trace_pont", flags), "5 personnes")
	assert_eq(EndScreen.final_figure({&"final3_dora": true, &"final3_detained": true} as Dictionary[StringName, Variant]), "dora")
	assert_eq(EndScreen.final_figure({&"final3_passed": true} as Dictionary[StringName, Variant]), "mira")
	assert_eq(EndScreen.final_figure({} as Dictionary[StringName, Variant]), "")


# ---------------------------------------------------------------------------
# Guichet : figure finale, accessoires, plan de travail
# ---------------------------------------------------------------------------

func test_final_figure_of_the_last_day() -> void:
	_make_ui(30)
	case.dialogue_tags = [&"sc82_dora"] as Array[StringName]
	_present()
	assert_eq(ui.passenger_panel.accent, DS.TEXT_SECONDARY, "Dora : voix de la famille")
	case.dialogue_tags = [&"sc82_mira"] as Array[StringName]
	assert_eq(ComparisonUI.final_figure_color(case), DS.ACCENT_MAGENTA)
	for tag: StringName in [&"prop_bandaged_hands", &"prop_certificate_crate", &"prop_armband_pocket", &"prop_school_satchel", &"sc81b"]:
		case.dialogue_tags = [tag] as Array[StringName]
		var expected: String = ComparisonUI.PROP_TAGS[tag]
		assert_true(UiText.has(expected), expected)
		assert_eq(ComparisonUI.arrival_tag(case), UiText.t(expected), "didascalie de %s" % tag)


func test_act_three_props_merge_into_the_actor() -> void:
	var actor: PassengerActor = ACTOR_SCENE.instantiate() as PassengerActor
	add_child_autofree(actor)
	await wait_process_frames(1)
	var cases: Dictionary[StringName, Array] = {
		PropDecor.TAG_BANDAGES: [&"implants_hand", "BandagePalm"],
		PropDecor.TAG_CERTIFICATES: [&"implants_hand", "CertBox"],
		PropDecor.TAG_SATCHEL: [&"implants_hand", "SatchelBody"],
		PropDecor.TAG_ARMBAND: [&"outfit_root", "PropArmband"],
		PropDecor.TAG_SPONSOR_BADGE: [&"outfit_root", "PropBadge"],
	}
	for tag: StringName in cases:
		var spec: Array = cases[tag]
		var root_name: StringName = spec[0]
		var piece_name: String = spec[1]
		actor.apply_markings(PackedStringArray(), false)
		actor.apply_props([tag] as Array[StringName])
		var root: Node3D = actor.rig.implants_hand if root_name == &"implants_hand" else actor.rig.outfit_root
		var piece: MeshInstance3D = root.find_child(piece_name, true, false) as MeshInstance3D
		assert_not_null(piece, "%s posé" % tag)
		await wait_process_frames(2)
		assert_false(piece.visible, "%s fusionné au maillage de l'acteur (0 draw call de plus)" % tag)
		assert_null(actor.get_node_or_null(PropDecor.NODE_CHILD))
	actor.apply_markings(PackedStringArray(), false)
	actor.apply_props([] as Array[StringName])
	await wait_process_frames(1)
	assert_null(actor.rig.outfit_root.find_child("PropBadge", true, false), "retiré au cas suivant")
	assert_null(actor.rig.implants_hand.find_child("SatchelBody", true, false))


func test_workbench_goes_back_side_by_side_in_act_three() -> void:
	# D-085 : l'Acte III présente 2–4 documents ; ils tiennent côte à côte.
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.disable_3d = true
	add_child_autofree(vp)
	ui = UI_SCENE.instantiate() as ComparisonUI
	vp.add_child(ui)
	var day: DayDef = data.get_day(24)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	case.get_document(CaseFactory.PERMIT).values[&"sponsor"] = SPONSOR_ID
	_present()
	await wait_until(func() -> bool: return not ui.workbench.layout_pending, 2.0)
	await wait_process_frames(3)
	assert_false(ui.workbench.is_stacked(), "deux documents côte à côte")
	var contract: DocumentInstance = CaseFactory.document(&"work_contract", case.passenger_presented)
	case.documents.append(contract)
	case.case_id = &"case_three"
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	_present()
	await wait_until(func() -> bool: return not ui.workbench.layout_pending, 2.0)
	await wait_process_frames(3)
	assert_false(ui.workbench.is_stacked(), "trois documents côte à côte (bio-scan et ticket retirés)")
	assert_gte(ui.workbench.fit_scale, ui.workbench.readable_scale() - 0.001, "valeurs lisibles (≥ 12 px)")
