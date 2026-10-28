## M8 partie B — interfaces de l'Acte II (UI/UX, ARCHITECTURE §7.2) : compteur
## QUOTA affiché et comparable (paire Compteur ↔ R23), scanner partiel (lien
## suggéré pointillé confirmable), onglets Employeurs / Vaisseaux / Révocations
## du Rulebook, avis « visages seuls », soirée (textes `%d`, revenus, rations,
## confirmation « Embarquer » au J10), interstitiel « CHAPITRE II », fins F8 /
## F9, lumières coupées du J20, figure finale, accessoires 3D, voix.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const ACTOR_SCENE: PackedScene = preload("res://scenes/passenger/passenger_actor.tscn")

var ui: ComparisonUI = null
var case: Case = null
var _flags_before: Dictionary[StringName, Variant] = {}
var _credits_before: int = 0
var _day_before: int = 0
var _seed_before: int = 0
var _household_before: Household = null


func before_each() -> void:
	_flags_before = GameState.narrative_flags.duplicate()
	_credits_before = GameState.credits
	_day_before = GameState.current_day
	_seed_before = GameState.campaign_seed
	_household_before = GameState.household.duplicate_household()


func after_each() -> void:
	GameState.narrative_flags = _flags_before
	GameState.credits = _credits_before
	GameState.current_day = _day_before
	GameState.campaign_seed = _seed_before
	GameState.household = _household_before


func _make_ui(day_number: int) -> DayDef:
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	var day: DayDef = CaseFactory.catalog().get_day(day_number)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	case.index = 0
	return day


func _present() -> void:
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)


func _expired_permit_link() -> Discrepancy:
	var permit: DocumentInstance = case.get_document(CaseFactory.PERMIT)
	permit.expiry_date = CaseFactory.today() - 10
	var link: Discrepancy = Discrepancy.new(FieldRef.new(CaseFactory.PERMIT, &"expiry_date"), FieldRef.today())
	return link.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_EXPIRED)


func _requested_pairs() -> Array[String]:
	var pairs: Array[String] = []
	for i: int in get_signal_emit_count(EventBus, "discrepancy_check_requested"):
		var params: Array = get_signal_parameters(EventBus, "discrepancy_check_requested", i)
		var a: FieldRef = params[0]
		var b: FieldRef = params[1]
		pairs.append(InspectionSelection.pair_key(a, b))
	return pairs


# ---------------------------------------------------------------------------
# Compteur QUOTA (R23)
# ---------------------------------------------------------------------------

func test_quota_counter_is_shown_and_comparable_with_r23() -> void:
	_make_ui(12)
	var counter: QuotaCounterView = ui.top_bar.quota_view
	assert_false(counter.visible, "masqué tant que le quota n'est pas publié")
	EventBus.quota_changed.emit(2, 5)
	assert_true(counter.visible)
	assert_eq(counter.get_value_text(), "2 / 5")
	assert_false(counter.is_full())
	EventBus.quota_changed.emit(5, 5)
	assert_true(counter.is_full(), "QUOTA ATTEINT (ambre)")
	assert_string_contains(counter.get_value_text(), "ATTEINT")
	_present()
	await wait_process_frames(2)
	ui.set_inspection_active(true)
	assert_true(counter.inspection_active, "le compteur suit le Mode Inspection")
	watch_signals(EventBus)
	ui.pick(FieldRef.quota_counter())
	assert_true(counter.selected, "compteur = champ A")
	var rule_ref: FieldRef = FieldRef.rulebook_rule(&"r_air_quota")
	ui.pick(rule_ref)
	assert_eq(_requested_pairs(), [InspectionSelection.pair_key(FieldRef.quota_counter(), rule_ref)] as Array[String])
	var result: Discrepancy = Discrepancy.new(FieldRef.quota_counter(), rule_ref)
	EventBus.discrepancy_checked.emit(result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_RULE_VIOLATED))
	assert_true(counter.is_flagged(), "paire épinglée sur le compteur")
	assert_true(ui.available_topics().has(InterrogationTopics.ABOUT_QUOTA), "question « quota atteint » débloquée")
	assert_string_contains(ui.describe(result), "5 / 5")
	ui.ask(InterrogationTopics.ABOUT_QUOTA)
	assert_signal_emitted_with_parameters(EventBus, "interrogation_requested", [InterrogationTopics.ABOUT_QUOTA])


func test_rule_cards_show_the_quota_of_the_day() -> void:
	var day: DayDef = _make_ui(12)
	EventBus.quota_changed.emit(0, day.air_quota)
	var card: RuleCardView = ui.rulebook.find_item(FieldRef.rulebook_rule(&"r_air_quota"), true) as RuleCardView
	assert_not_null(card, "R23 au Rulebook du J12")
	var entry: RulebookEntry = card.entry
	var text: String = RuleCardView.rule_text(entry, day.air_quota)
	assert_false(text.contains("%d"), "jamais de %d brut")
	assert_string_contains(text, str(day.air_quota))


func test_act2_topics_map_to_families() -> void:
	var quota: Discrepancy = Discrepancy.new(FieldRef.quota_counter(), FieldRef.rulebook_rule(&"r_air_quota"))
	quota.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_RULE_VIOLATED)
	assert_eq(InterrogationTopics.topic_for(quota), InterrogationTopics.ABOUT_QUOTA)
	var revoked: Discrepancy = Discrepancy.new(FieldRef.revoked(&"r1"), FieldRef.new(&"id_card", &"citizen_id"))
	revoked.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_REVOKED_MATCH)
	assert_eq(InterrogationTopics.topic_for(revoked), InterrogationTopics.ABOUT_REVOKED)
	for rule_id: StringName in [&"r_curfew", &"r_contract_consistent"]:
		var d: Discrepancy = Discrepancy.new(FieldRef.rulebook_rule(rule_id), FieldRef.new(&"queue_ticket", &"presented_at"))
		d.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_RULE_VIOLATED)
		assert_eq(InterrogationTopics.topic_for(d), InterrogationTopics.RULE_TOPICS[rule_id])
	for topic: StringName in [InterrogationTopics.ABOUT_QUOTA, InterrogationTopics.ABOUT_CURFEW, InterrogationTopics.ABOUT_REVOKED,
			InterrogationTopics.ABOUT_CONTRACT]:
		assert_true(UiText.has(InterrogationTopics.question_key(topic)), "question %s traduite" % topic)


# ---------------------------------------------------------------------------
# Scanner partiel
# ---------------------------------------------------------------------------

func test_scanner_link_is_suggested_then_confirmed_by_the_player() -> void:
	_make_ui(14)
	var link: Discrepancy = _expired_permit_link()
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	# Ordre réel : le DayController émet la suggestion pendant `documents_presented`.
	EventBus.scanner_suggested.emit(case.case_id, [link] as Array[Discrepancy], PartialScanner.SOURCE_LUCIOLE)
	EventBus.documents_presented.emit(case.case_id)
	await wait_process_frames(3)
	assert_eq(ui.links.suggested_links().size(), 1, "lien pointillé tracé")
	assert_eq(ui.links.suggested_links()[0].tint, DS.ACCENT_MAGENTA, "source Lucioles : magenta")
	assert_ne(ui.workbench.get_scanner_text(), "", "pastille de source affichée")
	assert_eq(ui.pending_suggestion_count(), 1)
	assert_true(ui.discrepancies.is_empty(), "rien n'est épinglé sans le joueur")
	watch_signals(EventBus)
	assert_true(ui.confirm_suggestion(), "le joueur confirme d'un clic")
	assert_eq(_requested_pairs(), [InspectionSelection.pair_key(link.a, link.b)] as Array[String])
	assert_eq(ui.pending_suggestion_count(), 0)
	assert_false(ui.confirm_suggestion(), "déjà confirmé")
	EventBus.discrepancy_checked.emit(_expired_permit_link())
	assert_eq(ui.discrepancies.size(), 1, "discordance épinglée")
	assert_true(ui.links.suggested_links().is_empty(), "le pointillé devient un lien confirmé")


func test_scanner_header_button_and_acv_source() -> void:
	_make_ui(14)
	var link: Discrepancy = _expired_permit_link()
	_present()
	EventBus.scanner_suggested.emit(case.case_id, [link] as Array[Discrepancy], PartialScanner.SOURCE_ACV)
	await wait_process_frames(2)
	assert_eq(ui.links.suggested_links()[0].tint, DS.STATE_AMBER, "ACV-2 : ambre")
	assert_true(ui.workbench.scanner_button.visible)
	watch_signals(EventBus)
	ui.workbench.scanner_button.pressed.emit()
	assert_signal_emitted(EventBus, "discrepancy_check_requested")
	EventBus.scanner_suggested.emit(&"other_case", [link] as Array[Discrepancy], PartialScanner.SOURCE_ACV)
	assert_eq(ui.suggestions.size(), 1, "suggestion d'un autre cas ignorée")


# ---------------------------------------------------------------------------
# Rulebook de l'Acte II
# ---------------------------------------------------------------------------

func _revoked_entry() -> RevokedEntry:
	var entry: RevokedEntry = RevokedEntry.new()
	entry.id = &"revoked_test"
	entry.citizen_id = case.passenger_presented.citizen_id if case.passenger_presented != null else "HG-0000-TEST"
	entry.given_name = "Valentin"
	entry.family_name = "Choi"
	return entry


func test_rulebook_employers_vessels_and_revocations_tabs() -> void:
	var day: DayDef = _make_ui(17)
	for tab: String in ["employers", "vessels", "revoked"]:
		assert_true(day.rulebook_tabs.has(tab), "onglet %s ouvert au J17" % tab)
	assert_false(ui.rulebook.visible_reference_tabs().has(RulebookReference.TAB_REVOKED), "pas d'onglet sans révocation")
	var entry: RevokedEntry = _revoked_entry()
	EventBus.revocations_published.emit([entry] as Array[RevokedEntry])
	var tabs: Array[StringName] = ui.rulebook.visible_reference_tabs()
	for tab: StringName in [RulebookReference.TAB_EMPLOYERS, RulebookReference.TAB_VESSELS, RulebookReference.TAB_REVOKED]:
		assert_true(tabs.has(tab), "onglet %s" % tab)
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_EMPLOYERS))
	assert_not_null(ui.rulebook.find_child("Code_KA", true, false), "code employeur KA listé")
	assert_eq(RulebookReference.employer_rows().size(), 13)
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_VESSELS))
	assert_not_null(ui.rulebook.find_child("RemovedNote", true, false), "cargos retirés rappelés")
	assert_true(RulebookReference.registered_vessels().has("BASSE-MARÉE"))
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_REVOKED))
	var card: RevokedCardView = ui.rulebook.get_revoked_card(entry.id)
	assert_not_null(card, "révocation affichée")
	# Sélectionnable en Mode Inspection, révélée même depuis un autre onglet.
	_present()
	await wait_process_frames(2)
	ui.rulebook.show_reference_tab(RulebookReference.TAB_EMPLOYERS)
	ui.set_inspection_active(true)
	ui.pick(entry.get_ref())
	var shown: RevokedCardView = ui.rulebook.get_revoked_card(entry.id)
	assert_not_null(shown, "onglet Révocations rouvert pour la sélection")
	assert_true(shown.selected)
	var result: Discrepancy = Discrepancy.new(entry.get_ref(), FieldRef.new(CaseFactory.ID_CARD, &"citizen_id"))
	result.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_REVOKED_MATCH)
	assert_string_contains(ui.describe(result), entry.citizen_id)


func test_firmware_line_and_faces_only_notices() -> void:
	_make_ui(14)
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_IMPLANTS))
	assert_not_null(ui.rulebook.find_child("FirmwareNote", true, false), "ligne firmware NX (R27)")
	var notice: WantedNotice = WantedNotice.new()
	notice.id = &"face_only"
	notice.appearance = CaseFactory.appearance()
	notice.reason_key = "wanted_ilan_reason"
	EventBus.wanted_notices_published.emit([notice] as Array[WantedNotice])
	assert_true(ui.rulebook.faces_only())
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_WANTED))
	assert_not_null(ui.rulebook.find_child("FacesOnly", true, false), "bandeau « visages seuls »")
	var card: WantedCardView = ui.rulebook.get_wanted_card(notice.id)
	assert_string_contains(card.display_label, UiText.t("rb_wanted_unknown"))


# ---------------------------------------------------------------------------
# Figure finale, répliques, accessoires
# ---------------------------------------------------------------------------

func test_final_figure_and_scripted_line_variants() -> void:
	_make_ui(20)
	case.dialogue_tags = [&"sc50_mira"] as Array[StringName]
	case.line_overrides = {"arrival": "sc50_mira_arrival_detained"}
	assert_eq(ComparisonUI.scripted_key(case, "arrival", "bark_arrival"), "sc50_mira_arrival_detained",
			"variante conditionnelle (Case.scripted_key)")
	_present()
	assert_eq(ui.passenger_panel.accent, DS.ACCENT_MAGENTA, "Mira : accent des Lucioles")
	assert_string_contains(ui.passenger_panel.get_line(), UiText.t("sc50_mira_present").left(12))
	case.dialogue_tags = [&"sc50_ilan"] as Array[StringName]
	assert_eq(ComparisonUI.final_figure_color(case), DS.TEXT_SECONDARY, "Ilan : voix de la famille")
	case.dialogue_tags = [&"companion_child"] as Array[StringName]
	assert_eq(ComparisonUI.arrival_tag(case), UiText.t("tag_companion_child"))
	case.dialogue_tags = [] as Array[StringName]
	assert_eq(ComparisonUI.final_figure_color(case), Color.TRANSPARENT)


func test_props_stay_within_the_render_budget() -> void:
	assert_eq(PropDecor.surface_count("child"), 1, "enfant : un maillage, une surface")
	assert_eq(PropDecor.surface_count("drone"), 1, "drone : un maillage, une surface")
	var actor: PassengerActor = ACTOR_SCENE.instantiate() as PassengerActor
	add_child_autofree(actor)
	await wait_process_frames(1)
	actor.apply_markings(PackedStringArray(), false)
	actor.apply_props(PropDecor.ALL_TAGS)
	var child: MeshInstance3D = actor.get_node_or_null(PropDecor.NODE_CHILD) as MeshInstance3D
	var drone: MeshInstance3D = actor.get_node_or_null(PropDecor.NODE_DRONE) as MeshInstance3D
	assert_not_null(child)
	assert_not_null(drone)
	assert_eq(drone.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "drone : 1 draw call (sans ombre)")
	assert_eq(child.material_override, drone.material_override, "matériau partagé")
	assert_not_null(actor.rig.implants_hand.find_child("CrateShell", true, false), "caisse tenue à la main")
	assert_not_null(actor.rig.implants_head.find_child("ShuntLed", true, false), "LED du shunt")
	await wait_process_frames(2)
	var crate: MeshInstance3D = actor.rig.implants_hand.find_child("CrateShell", true, false) as MeshInstance3D
	assert_false(crate.visible, "caisse fusionnée au maillage de l'acteur (0 draw call de plus)")
	actor.apply_markings(PackedStringArray(), false)
	actor.apply_props([] as Array[StringName])
	await wait_process_frames(1)
	assert_null(actor.get_node_or_null(PropDecor.NODE_CHILD), "accessoires retirés au cas suivant")
	assert_null(actor.rig.implants_hand.find_child("CrateShell", true, false))


# ---------------------------------------------------------------------------
# Soirée de l'Acte II
# ---------------------------------------------------------------------------

func _evening(day_number: int, flags: Dictionary[StringName, Variant], balance: int = 60) -> EveningScreen:
	var data: DataCatalog = CaseFactory.catalog()
	var day: DayDef = data.get_day(day_number)
	var economy: EconomyDef = data.get_economy()
	var home: Household = GameState.household
	var context: Dictionary[StringName, Variant] = EveningService.context_flags(flags, home, 0.9,
			economy.levy_for(day_number, balance))
	var events: Array[EveningEvent] = EveningService.build_events(day.evening_events, context, economy)
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, home, flags, balance)
	EveningService.default_selection(lines, balance)
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(day, balance, 20, lines, home, false)
	screen.set_events(events)
	screen.set_income(EveningService.income_lines(economy, day_number, home, context))
	return screen


func test_evening_text_values_income_and_grouped_rations() -> void:
	GameState.household = Household.new()
	GameState.household.send_away(Household.ILAN, Household.AWAY_SOUTE)
	var job: ExpenseLine = ExpenseLine.new(EveningService.LINE_ILAN_JOB, 6, true)
	job.label_key = "inc_ilan_job"
	var screen: EveningScreen = _evening(11, {&"act2_started": true}, 80)
	screen.set_income([job] as Array[ExpenseLine])
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_eq(screen.income_total(), 6)
	assert_eq(screen.funds(), 86, "revenus comptés dans les fonds du soir")
	assert_not_null(screen.find_child("Incomes", true, false), "section Revenus")
	var rations: Control = screen.find_child("Rations", true, false) as Control
	assert_not_null(rations, "rations d'air groupées")
	assert_not_null(rations.find_child("Line_ration_self", true, false), "votre ration, prélevée")
	assert_not_null(rations.find_child("Line_ration_noa", true, false), "ration de Noa cochable")
	assert_null(rations.find_child("Line_ration_ilan", true, false), "pas de ration pour un proche absent")
	assert_not_null(rations.find_child("Absent_ilan", true, false), "Ilan rappelé·e grisé·e")
	var levy: EveningEvent = screen.get_event(&"d11_levy")
	if levy != null:
		var index: int = screen.events.find(levy)
		screen.show_step(index)
		await wait_process_frames(1)
		var text: Label = screen.find_child("EventText", true, false) as Label
		assert_false(text.text.contains("%d"), "prélèvement formaté")
		assert_string_contains(text.text, str(levy.text_args[0]))
	assert_eq(EveningScreen.format_args("%d pages · %s · 100 %%", [3]), "3 pages · — · 100 %")


func test_day_ten_board_requires_an_explicit_confirmation() -> void:
	var screen: EveningScreen = _evening(10, {&"drift_passes_bought": true, &"final_passed": true})
	add_child_autofree(screen)
	await wait_process_frames(2)
	var drift: EveningEvent = screen.get_event(&"d10_drift")
	assert_not_null(drift, "panneau « Quai 6, demain 05:00 »")
	var board: EveningOptionDef = null
	for option: EveningOptionDef in drift.options:
		if option.ends_campaign != &"":
			board = option
	assert_not_null(board, "option Embarquer")
	screen.show_step(screen.events.find(drift))
	await wait_process_frames(1)
	assert_not_null(screen.option_buttons[board.id].find_child("FinalChip", true, false), "« FIN DE LA CAMPAGNE » signalée")
	screen.option_buttons[board.id].pressed.emit()
	assert_not_null(screen.confirm_layer, "boîte de confirmation ouverte")
	assert_false(screen.choices.has(drift.id), "rien n'est choisi avant la confirmation")
	screen.close_final_confirm()
	assert_null(screen.confirm_layer)
	assert_false(screen.choices.has(drift.id), "annuler laisse le choix en suspens")
	assert_false(screen.request_choice(drift.id, board.id))
	assert_true(screen.accept_final_confirm(), "CONFIRMER LE DÉPART")
	assert_eq(screen.choices[drift.id], board.id)
	# Le choix par défaut (sans UI, ou validation pressée) n'embarque jamais.
	var other: EveningScreen = _evening(10, {&"drift_passes_bought": true})
	add_child_autofree(other)
	await wait_process_frames(1)
	var default_choice: StringName = other.get_choices().get(&"d10_drift", &"")
	assert_ne(default_choice, board.id)


# ---------------------------------------------------------------------------
# Foyer, voix, bilan
# ---------------------------------------------------------------------------

func test_household_act2_states_are_distinct() -> void:
	var home: Household = Household.new()
	var ilan: Household.Member = home.get_member(Household.ILAN)
	var noa: Household.Member = home.get_member(Household.NOA)
	var dora: Household.Member = home.get_member(Household.DORA)
	ilan.detained = true
	noa.breathless = true
	dora.away = Household.AWAY_TYCHO
	assert_eq(HouseholdView.state_icon(ilan), UiIcon.Kind.DETAIN, "mis·e en attente ≠ perdu·e")
	assert_eq(HouseholdView.state_icon(noa), UiIcon.Kind.BREATH)
	assert_eq(HouseholdView.state_color(noa), DS.STATE_AMBER)
	assert_eq(HouseholdView.state_icon(dora), UiIcon.Kind.AWAY)
	assert_eq(HouseholdView.state_text(dora), UiText.t("hh_state_away_tycho"))
	ilan.health = Household.Health.LOST
	assert_eq(HouseholdView.state_icon(ilan), UiIcon.Kind.LOCK)


func test_commission_and_brulants_voices_are_distinct() -> void:
	var commission: Color = BriefingScreen.voice_color(BriefingContent.Voice.COMMISSION)
	var brulants: Color = BriefingScreen.voice_color(BriefingContent.Voice.BRULANTS)
	assert_eq(commission, DS.VOICE_COMMISSION)
	assert_eq(brulants, DS.VOICE_BRULANTS)
	for voice: BriefingContent.Voice in [BriefingContent.Voice.CONSORTIUM, BriefingContent.Voice.MENTOR, BriefingContent.Voice.FAMILY,
			BriefingContent.Voice.LUCIOLES, BriefingContent.Voice.INSPECTION]:
		assert_ne(BriefingScreen.voice_color(voice), commission)
		assert_ne(BriefingScreen.voice_color(voice), brulants)
	assert_ne(BriefingScreen.voice_icon(BriefingContent.Voice.BRULANTS), BriefingScreen.voice_icon(BriefingContent.Voice.COMMISSION))


func test_shift_summary_shows_overruns() -> void:
	var day: DayDef = CaseFactory.catalog().get_day(12)
	var summary: DaySummary = DaySummary.new()
	summary.day_number = 12
	summary.planned_cases = 2
	var over: CaseResult = CaseResult.new(&"c1")
	over.verdict_kind = VerdictKind.Kind.APPROVE
	over.correct = true
	over.verdict_correct = true
	over.quota_overrun = true
	summary.results.append(over)
	var screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
	screen.setup(summary, day)
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_not_null(screen.find_child("OverrunTile", true, false), "tuile « entrées imputées »")


# ---------------------------------------------------------------------------
# Scène de jour : Chapitre II, fins F8 / F9, lumières coupées
# ---------------------------------------------------------------------------

func _scene(day_number: int) -> DayScene:
	GameState.new_campaign(20_871_315)
	GameState.current_day = day_number
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	return scene


func test_chapter_two_interstitial_after_the_pivot_evening() -> void:
	var scene: DayScene = _scene(10)
	assert_false(scene.chapter_two_pending(), "pas d'interstitiel avant la soirée du J10")
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(&"vannes_opened", true)
	GameState.current_day = 11
	assert_true(scene.chapter_two_pending())
	scene._after_evening(&"next")
	var chapter: ChapterScreen = scene.screen as ChapterScreen
	assert_not_null(chapter, "« CHAPITRE II » plutôt que le rechargement direct")
	var last_screen: StringName = scene.screen_history.back()
	assert_eq(last_screen, &"chapter2")
	assert_true(chapter.recap_keys.has("chapter2_recap_opened"), "rappel de la nuit des vannes")
	assert_not_null(chapter.find_child("Numeral", true, false))
	assert_not_null(chapter.continue_button)
	GameState.current_day = 12
	assert_false(scene.chapter_two_pending(), "une seule fois")


func test_end_screen_f8_and_f9() -> void:
	var scene: DayScene = _scene(20)
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(&"registre_sent", true)
	for ending: StringName in [EndingService.F8_REGISTRE, EndingService.F9_STRIKE]:
		scene.show_end(ending)
		var end: EndScreen = scene.screen as EndScreen
		assert_not_null(end)
		var title_key: String = end.epilogue["title_key"]
		var eyebrow_key: String = end.epilogue["eyebrow_key"]
		var act: int = end.epilogue["act"]
		assert_eq(title_key, "end2_%s_title" % String(ending).get_slice("_", 0))
		assert_eq(act, 2)
		assert_true(UiText.has(title_key), "titre traduit")
		assert_true(UiText.has(eyebrow_key), "surtitre traduit")
		assert_not_null(end.find_child("ActChip", true, false), "puce ACTE II")
		assert_gt(end.epilogue_lines().size(), 4)
		assert_ne(EndScreen.accent_of(ending), DS.STATE_RED, "couleur dédiée")
		await wait_process_frames(1)
	assert_ne(EndScreen.accent_of(EndingService.F8_REGISTRE), EndScreen.accent_of(EndingService.F9_STRIKE))


func test_lights_out_on_the_last_shift() -> void:
	var scene: DayScene = _scene(20)
	assert_false(scene.ends_shift_announcement(DayController.HALL_QUOTA_FULL))
	assert_true(scene.ends_shift_announcement("hall_j20_strike"), "la grève termine le shift")
	EventBus.hall_announced.emit("hall_j20_strike")
	assert_true(scene.lights_out_active, "les vitres s'éteignent")
	var comparison: ComparisonUI = scene.ui as ComparisonUI
	assert_true(comparison.lights_out)
	assert_true(scene.booth.lights_dimmed, "lampes du guichet coupées")
	await wait_seconds(DayScene.LIGHTS_OUT_SEC + 0.2)
	assert_lt(comparison.workbench.modulate.r, 0.5, "panneaux assombris")
	assert_eq(comparison.pa_strip.modulate.r, 1.0, "le haut-parleur reste lisible")
	var summary: DaySummary = DaySummary.new()
	summary.day_number = 20
	EventBus.day_ended.emit(summary)
	assert_true(scene.blackout.visible, "fondu au noir avant le bilan")
	await wait_until(func() -> bool: return scene.screen is ShiftSummaryScreen, DayScene.BLACKOUT_SEC + 1.0)
	assert_true(scene.screen is ShiftSummaryScreen, "bilan après le noir")
	assert_eq(scene.blackout.color.a, 1.0)
