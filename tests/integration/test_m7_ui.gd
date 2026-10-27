## M7 partie B — interfaces J4–J10 (UI/UX) : objets glissés (chaque décision
## émet `item_decision_requested`, de bout en bout avec le DayController),
## DÉTENTION verrouillée avant le J7, onglets de référence et avis de recherche
## sélectionnable, phrase de passe, *lumika*, annonces du Hall, choix du soir
## appliqués, bilan (pots-de-vin, prime), écran de fin pour chaque fin, booth
## (implants, fil magenta, trois tapes, escorte de la Garde).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const BOOTH_SCENE: PackedScene = preload("res://scenes/booth/booth.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")

var ui: ComparisonUI = null
var case: Case = null
var _flags_before: Dictionary[StringName, Variant] = {}
var _credits_before: int = 0
var _day_before: int = 0


func before_each() -> void:
	_flags_before = GameState.narrative_flags.duplicate()
	_credits_before = GameState.credits
	_day_before = GameState.current_day


func after_each() -> void:
	GameState.narrative_flags = _flags_before
	GameState.credits = _credits_before
	GameState.current_day = _day_before


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


func _envelope(allowed: Array[SlippedItem.Decision]) -> SlippedItem:
	var item: SlippedItem = SlippedItem.new()
	item.id = StringName("%s_item0" % case.case_id)
	item.case_id = case.case_id
	item.kind = SlippedItem.Kind.ENVELOPE
	item.amount = 20
	item.label_key = "wb_envelope_label"
	item.allowed = allowed
	item.report_bonus = 10
	case.slipped_items.append(item)
	return item


# ---------------------------------------------------------------------------
# Objets glissés
# ---------------------------------------------------------------------------

func test_each_slipped_item_decision_emits_the_right_signal() -> void:
	_make_ui(4)
	var item: SlippedItem = _envelope([SlippedItem.Decision.KEEP, SlippedItem.Decision.RETURN, SlippedItem.Decision.REPORT])
	_present()
	EventBus.item_slipped.emit(item)
	await wait_process_frames(2)
	var view: SlippedItemView = ui.workbench.get_slipped_view(item.id)
	assert_not_null(view, "objet posé sur le plan de travail")
	var amount_label: Label = view.find_child("ItemLabel", true, false) as Label
	assert_string_contains(amount_label.text, "20", "montant visible")
	assert_eq(view.buttons.size(), 3)
	for decision: SlippedItem.Decision in [SlippedItem.Decision.KEEP, SlippedItem.Decision.RETURN, SlippedItem.Decision.REPORT]:
		watch_signals(EventBus)
		view.buttons[decision].pressed.emit()
		assert_signal_emitted_with_parameters(EventBus, "item_decision_requested", [item.id, decision])
		EventBus.item_decided.emit(item, decision)
		assert_eq(view.decision, decision, "décision confirmée affichée")
	assert_true(ui.available_topics().has(InterrogationTopics.ABOUT_ENVELOPE), "« Qu'est-ce que c'est que ça ? »")


func test_disallowed_or_late_decisions_are_not_requested() -> void:
	_make_ui(4)
	var item: SlippedItem = _envelope([SlippedItem.Decision.KEEP, SlippedItem.Decision.RETURN])
	_present()
	EventBus.item_slipped.emit(item)
	await wait_process_frames(2)
	var view: SlippedItemView = ui.workbench.get_slipped_view(item.id)
	assert_false(view.buttons.has(SlippedItem.Decision.REPORT), "REMETTRE À LA GARDE absent si non autorisé")
	watch_signals(EventBus)
	assert_false(view.request(SlippedItem.Decision.REPORT))
	assert_false(ui.request_item_decision(item.id, SlippedItem.Decision.REPORT))
	ui.get_stamp_button(VerdictKind.Kind.DENY).begin_hold()
	ui.get_stamp_button(VerdictKind.Kind.DENY).advance(DS.STAMP_HOLD + 0.05)
	assert_true(view.locked, "plus de décision après le tampon")
	assert_false(ui.request_item_decision(item.id, SlippedItem.Decision.KEEP))
	assert_signal_not_emitted(EventBus, "item_decision_requested")


func test_slipped_item_end_to_end_with_the_day_controller() -> void:
	GameState.current_day = 4
	var h: DayHarness = DayHarness.new()
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	h.setup(self, NullBooth.new(), 4)
	var dc: DayController = h.controller
	dc.close_intro()
	dc.next_index = 4 # SC-07, le fils Valcourt (première enveloppe)
	EventBus.next_case_requested.emit()
	var case_id: StringName = dc.current_case_id()
	await wait_until(func() -> bool: return h.events_for(case_id).has(&"documents_presented"), 3.0)
	await wait_process_frames(2)
	assert_true(dc.current_case.has_envelope())
	var item: SlippedItem = dc.current_case.slipped_items[0]
	var view: SlippedItemView = ui.workbench.get_slipped_view(item.id)
	assert_not_null(view, "item_slipped → objet affiché (après les documents)")
	view.buttons[SlippedItem.Decision.KEEP].pressed.emit()
	assert_eq(item.decision, SlippedItem.Decision.KEEP, "le DayController a accepté la décision")
	assert_eq(view.decision, SlippedItem.Decision.KEEP)
	h.stamp(VerdictKind.Kind.DENY)
	var result: CaseResult = h.results.back()
	assert_eq(result.bribe_credits, item.amount, "enveloppe gardée créditée")
	h.teardown()


# ---------------------------------------------------------------------------
# DÉTENTION
# ---------------------------------------------------------------------------

func test_detain_is_locked_before_day_seven() -> void:
	for day_number: int in [4, 5, 6]:
		_make_ui(day_number)
		assert_false(ui.detain_available, "J%d" % day_number)
		assert_false(ui.get_stamp_button(VerdictKind.Kind.DETAIN).visible)
		_present()
		watch_signals(EventBus)
		ui._on_stamped(VerdictKind.Kind.DETAIN)
		assert_signal_not_emitted(EventBus, "verdict_stamped", "J%d : DÉTENTION refusée par l'UI" % day_number)
		ui.queue_free()
	_make_ui(7)
	assert_true(ui.detain_available, "J7 : tampon DÉTENTION")
	var detain: StampButton = ui.get_stamp_button(VerdictKind.Kind.DETAIN)
	assert_true(detain.visible)
	_present()
	watch_signals(EventBus)
	detain.begin_hold()
	detain.advance(DS.STAMP_HOLD * 0.5)
	assert_signal_not_emitted(EventBus, "verdict_stamped", "maintien 0,4 s comme les autres")
	detain.advance(DS.STAMP_HOLD)
	assert_signal_emitted(EventBus, "verdict_stamped")
	var verdict: Verdict = get_signal_parameters(EventBus, "verdict_stamped")[0]
	assert_eq(verdict.kind, VerdictKind.Kind.DETAIN)


# ---------------------------------------------------------------------------
# Rulebook : onglets de référence, avis de recherche
# ---------------------------------------------------------------------------

func test_reference_tabs_follow_the_day() -> void:
	_make_ui(9)
	var tabs: Array[StringName] = ui.rulebook.visible_reference_tabs()
	assert_eq(tabs, [&"origins", &"implants", &"symbols", &"seals"] as Array[StringName])
	for tab: StringName in tabs:
		assert_true(ui.rulebook.show_reference_tab(tab), String(tab))
		assert_eq(ui.rulebook.current_tab, RulebookPanel.reference_tab_id(tab))
	assert_false(ui.rulebook.show_reference_tab(&"wanted"), "pas d'avis avant le J10")
	_make_ui(3)
	assert_true(ui.rulebook.visible_reference_tabs().is_empty())


func test_wanted_notice_is_selectable_like_the_face() -> void:
	_make_ui(10)
	var notice: WantedNotice = WantedNotice.new()
	notice.id = &"wanted_test"
	notice.given_name = "Arkady"
	notice.family_name = "Novak"
	notice.appearance = CaseFactory.appearance()
	notice.reason_key = "wanted_novak_reason"
	var notices: Array[WantedNotice] = [notice]
	EventBus.wanted_notices_published.emit(notices)
	assert_true(ui.rulebook.visible_reference_tabs().has(&"wanted"))
	_present()
	ui.set_inspection_active(true)
	assert_eq(ui.pick(notice.get_ref()), InspectionSelection.Action.SELECTED_A)
	var card: WantedCardView = ui.rulebook.get_wanted_card(notice.id)
	assert_not_null(card, "l'onglet Avis de recherche s'ouvre sur l'avis choisi")
	assert_true(card.selected)
	assert_not_null(card.get_portrait().appearance, "portrait de l'avis")
	watch_signals(EventBus)
	ui.pick(FieldRef.passenger_face())
	assert_signal_emitted(EventBus, "discrepancy_check_requested")
	var params: Array = get_signal_parameters(EventBus, "discrepancy_check_requested")
	var a: FieldRef = params[0]
	var b: FieldRef = params[1]
	assert_true(a.equals(notice.get_ref()), "avis = champ A")
	assert_true(b.is_passenger_face(), "visage = champ B")


# ---------------------------------------------------------------------------
# Lucioles, répliques, annonces
# ---------------------------------------------------------------------------

func test_password_reply_needs_the_tag_and_trust() -> void:
	_make_ui(7)
	case.dialogue_tags.append(CaseBuilder.TAG_LUCIOLE_PASSWORD)
	GameState.set_flag(CaseConsequences.FLAG_TRUST, 1)
	_present()
	assert_false(ui.available_topics().has(InterrogationTopics.LUCIOLE_REPLY), "confiance < 2")
	GameState.set_flag(CaseConsequences.FLAG_TRUST, 2)
	assert_true(ui.available_topics().has(InterrogationTopics.LUCIOLE_REPLY))
	watch_signals(EventBus)
	ui.ask(InterrogationTopics.LUCIOLE_REPLY)
	assert_signal_emitted_with_parameters(EventBus, "interrogation_requested", [InterrogationTopics.LUCIOLE_REPLY])
	assert_false(ui.available_topics().has(InterrogationTopics.LUCIOLE_REPLY), "une seule fois")


func test_lumika_stays_unknown_until_learned() -> void:
	var unknown: String = UiText.t("tag_unknown_word")
	assert_eq(ComparisonUI.lumika_text("Lumika, ça veut dire luciole.", false), unknown + ", ça veut dire luciole.")
	assert_eq(ComparisonUI.lumika_text("Il pleut… %s." % unknown, true), "Il pleut… lumika.")
	assert_eq(ComparisonUI.lumika_text("Illumikateur", false), "Illumikateur", "mot entier seulement")


func test_exit_lines_and_hall_announcements() -> void:
	_make_ui(7)
	case.dialogue_tags.append(&"sc13_lev")
	assert_eq(ComparisonUI.departure_key(case, VerdictKind.Kind.DETAIN), "sc13_lev_exit_detain")
	ui.show_announcement(UiText.t("hall_j7_okonkwo_citation"))
	EventBus.hall_announced.emit("hall_j7_okonkwo_citation")
	assert_eq(ui.announcement_text, UiText.t("hall_j7_okonkwo_citation"))
	assert_true(ui.pa_strip.visible, "sous-titre discret du haut-parleur")


func test_luciole_mark_drawn_on_marked_documents() -> void:
	var doc: DocumentInstance = CaseFactory.document(CaseFactory.PERMIT, CaseFactory.passenger())
	var plain: DocumentView = DocumentView.create(doc)
	add_child_autofree(plain)
	assert_false(plain.has_luciole_mark())
	doc.marks.append(DocumentView.MARK_LUCIOLE)
	var marked: DocumentView = DocumentView.create(doc)
	add_child_autofree(marked)
	assert_true(marked.has_luciole_mark())


# ---------------------------------------------------------------------------
# Écrans : soirée, bilan, briefing, fin
# ---------------------------------------------------------------------------

func _day9_evening(balance: int, flags: Dictionary[StringName, Variant]) -> EveningScreen:
	var data: DataCatalog = Gen.data()
	var events: Array[EveningEvent] = EveningService.build_events(data.get_day(9).evening_events, flags, data.get_economy())
	var lines: Array[ExpenseLine] = EveningService.build_lines(data.get_economy(), 9, Household.new())
	EveningService.default_selection(lines, balance)
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(data.get_day(9), balance, 0, lines, Household.new(), false)
	screen.set_events(events)
	add_child_autofree(screen)
	return screen


func test_evening_choices_are_applied() -> void:
	var flags: Dictionary[StringName, Variant] = {&"drift_offer": true, &"suspicion": 0}
	var screen: EveningScreen = await _ready_screen(_day9_evening(120, flags))
	assert_eq(screen.events.size(), 4, "J9 : audit → aveu → déposition → laissez-passer")
	assert_eq(screen.events[0].kind, EveningEventDef.Kind.AUDIT)
	assert_eq(screen.pending_choice_count(), 3)
	assert_true(screen.confirm_button.disabled, "« Valider » attend les décisions")
	screen.show_step(1)
	assert_true(screen.option_buttons.has(&"denounce"), "dénoncer Ilan reste possible (D-053)")
	screen.option_buttons[&"support"].pressed.emit()
	assert_true(screen.choose(&"d09_okonkwo", &"warn"))
	assert_true(screen.choose(&"d09_drift", &"buy"))
	assert_eq(screen.pending_choice_count(), 0)
	assert_false(screen.confirm_button.disabled)
	var choices: Dictionary[StringName, StringName] = screen.get_choices()
	var data: DataCatalog = Gen.data()
	var report: EveningReport = EveningService.apply(data.get_economy(), 9, Household.new(), screen.lines, 120, 1,
			screen.events, choices, flags)
	assert_eq(report.choices[&"d09_ilan"], &"support")
	assert_eq(report.choices[&"d09_drift"], &"buy")
	assert_true(report.flag_changes.has(&"ilan_supported"))
	assert_true(report.flag_changes.has(&"drift_passes_bought"))


func test_unaffordable_option_is_greyed_with_its_reason() -> void:
	var flags: Dictionary[StringName, Variant] = {&"drift_offer": true}
	var screen: EveningScreen = await _ready_screen(_day9_evening(5, flags))
	screen.show_step(3)
	var buy: Button = screen.option_buttons[&"buy"]
	assert_true(buy.disabled, "40 ₵ : fonds insuffisants")
	assert_true((buy.find_child("Reason", true, false) as Label).visible)
	assert_false(screen.choose(&"d09_drift", &"buy"))
	assert_true(screen.choose(&"d09_drift", &"keep"), "l'option gratuite reste possible")
	# Valider sans tout trancher : choix par défaut (D-058), jamais de dénonciation.
	var defaults: Dictionary[StringName, StringName] = screen.get_choices()
	assert_eq(defaults[&"d09_ilan"], &"forbid")
	assert_eq(defaults[&"d09_drift"], &"keep")


func test_audit_arrest_skips_the_rest_of_the_evening() -> void:
	var flags: Dictionary[StringName, Variant] = {&"suspicion": 5}
	var screen: EveningScreen = await _ready_screen(_day9_evening(60, flags))
	var audit_ending: StringName = screen.events[0].audit.get("ending", &"")
	assert_eq(audit_ending, EndingService.F1_ARRESTED)
	assert_eq(screen.pending_choice_count(), 0, "F1 à l'audit : plus rien à décider")
	assert_false(screen.confirm_button.disabled)


func _ready_screen(screen: EveningScreen) -> EveningScreen:
	await wait_process_frames(2)
	return screen


func test_summary_shows_bribes_and_report_bonus() -> void:
	var summary: DaySummary = DaySummary.new()
	summary.day_number = 7
	summary.planned_cases = 2
	var kept: CaseResult = CaseResult.new(&"a")
	kept.correct = true
	kept.wage = 5
	kept.credits_delta = 5
	kept.bribe_credits = 20
	var reported: CaseResult = CaseResult.new(&"b")
	reported.correct = true
	reported.report_credits = 10
	summary.add_result(kept)
	summary.add_result(reported)
	var screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
	screen.setup(summary, Gen.data().get_day(7))
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_not_null(screen.find_child("BribeTile", true, false), "ligne « Divers non déclaré »")
	assert_not_null(screen.find_child("ReportTile", true, false), "ligne « Prime de signalement »")


func test_briefing_voices_have_their_own_colors() -> void:
	assert_eq(BriefingScreen.voice_color(BriefingContent.Voice.LUCIOLES), DS.ACCENT_MAGENTA)
	assert_eq(BriefingScreen.voice_color(BriefingContent.Voice.INSPECTION), DS.STATE_AMBER)
	assert_ne(BriefingScreen.voice_color(BriefingContent.Voice.INSPECTION), BriefingScreen.voice_color(BriefingContent.Voice.MENTOR))


func test_end_screen_for_every_ending() -> void:
	var flags: Dictionary[StringName, Variant] = {&"final_passed": true, &"ilan_supported": true, &"sc16_hana_passed": true}
	for ending: StringName in EndingService.ALL_ENDINGS:
		var end: EndScreen = EndScreen.new()
		end.epilogue = EndingService.epilogue(ending, flags, Household.new())
		end.setup(ending, [], Household.new(), 30, flags, 0.9)
		add_child_autofree(end)
		await wait_process_frames(1)
		var lines: PackedStringArray = end.epilogue["lines"]
		assert_gt(lines.size(), 3, String(ending))
		assert_eq(end.epilogue_labels.size(), lines.size(), "%s : une ligne par entrée" % ending)
		var title: Label = end.find_child("EndingTitle", true, false)
		var title_key: String = end.epilogue["title_key"]
		assert_eq(title.text, UiText.t(title_key), String(ending))
		assert_true(UiText.has(title_key), "%s : titre traduit" % ending)
		end.reveal_all()
		assert_true(end.is_reveal_done())
		assert_not_null(end.title_button, "retour au titre")
		# (pas de `watch_signals` : l'écran se libère en se fermant)
		var choices: Array[StringName] = []
		end.finished.connect(func(choice: StringName) -> void: choices.append(choice))
		end.title_button.pressed.emit()
		assert_eq(choices, [&"title"] as Array[StringName], "%s : retour au titre" % ending)
	assert_gt(EndScreen.trace_keys(flags).size(), 0)
	for key: String in EndScreen.trace_keys(flags):
		assert_true(UiText.has(key), key)


func test_f5_variants_are_signalled() -> void:
	for variant_flags: Array in [[{&"final_passed": true}, "end_variant_veilleurs"], [{&"sc20_passed": true}, "end_variant_brulants"]]:
		var flags: Dictionary[StringName, Variant] = {}
		var source: Dictionary = variant_flags[0]
		for key: Variant in source:
			flags[key] = source[key]
		var end: EndScreen = EndScreen.new()
		end.epilogue = EndingService.epilogue(EndingService.F5_AIR, flags, Household.new())
		end.setup(EndingService.F5_AIR, [], Household.new(), 0, flags, 0.5)
		add_child_autofree(end)
		await wait_process_frames(1)
		var chip: Control = end.find_child("VariantChip", true, false)
		assert_not_null(chip)
		var texts: Array[String] = []
		for l: Node in chip.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
		assert_has(texts, UiText.t(str(variant_flags[1])))


func test_show_end_leaves_no_save() -> void:
	GameState.new_campaign(20_871_315)
	GameState.current_day = 10
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	GameState.save_to_slot()
	assert_false(SaveService.load_slot().is_empty())
	scene.show_end(EndingService.F7_REOPENS)
	assert_true(SaveService.load_slot().is_empty(), "D-041 : aucune sauvegarde après une fin")
	assert_true(scene.screen is EndScreen)


# ---------------------------------------------------------------------------
# Booth : implants, fil magenta, trois tapes, escorte
# ---------------------------------------------------------------------------

func test_booth_markings_knock_and_escort() -> void:
	var reduce_before: bool = Settings.reduce_motion
	Settings.set_value(Settings.KEY_REDUCE_MOTION, true, false)
	var booth: BoothDirector = BOOTH_SCENE.instantiate()
	add_child_autofree(booth)
	var builder: CaseBuilder = CaseBuilder.new(Gen.data(), Gen.data().get_day(3), Gen.day_seed(0, 3))
	var c: Case = builder.build(0).case
	c.passenger_presented.implants = PackedStringArray(["MIL-9", "OPT-3", "DER-19"])
	c.dialogue_tags.append(BoothDirector.MAGENTA_THREAD_TAG)
	c.presentation = BoothDirector.PRESENTATION_KNOCK
	var knocks: Array[int] = []
	booth.glass_knocked.connect(func(_id: StringName, n: int) -> void: knocks.append(n))
	var documents: Array[StringName] = []
	var on_docs: Callable = func(id: StringName) -> void: documents.append(id)
	EventBus.documents_presented.connect(on_docs)
	EventBus.case_presented.emit(c)
	var actor: PassengerActor = booth.get_actor(c.case_id)
	for part: String in ["MilTemple", "MilEye", "OptIris"]:
		assert_not_null(actor.rig.implants_head.get_node_or_null(part), part)
	assert_not_null(actor.rig.implants_hand.get_node_or_null(^"MagentaThread"), "fil magenta au poignet")
	assert_not_null(actor.rig.implants_hand.get_node_or_null(^"Der19"))
	await wait_until(func() -> bool: return documents.has(c.case_id), 6.0)
	assert_eq(knocks, [1, 2, 3] as Array[int], "trois tapes avant les papiers")
	var result: CaseResult = CaseResult.new(c.case_id)
	result.verdict_kind = VerdictKind.Kind.DETAIN
	EventBus.case_resolved.emit(c.case_id, result)
	assert_true(booth.is_escorting(), "la Garde entre")
	assert_true(booth.guard.visible)
	var done: bool = await wait_until(func() -> bool: return not booth.is_escorting(), 12.0)
	assert_true(done, "la Garde repart avec le passager")
	assert_true(booth.guard.is_free())
	EventBus.documents_presented.disconnect(on_docs)
	Settings.set_value(Settings.KEY_REDUCE_MOTION, reduce_before, false)
