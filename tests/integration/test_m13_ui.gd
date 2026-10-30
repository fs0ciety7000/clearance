## M13 lot C — interfaces (M13 §6.1 I35 → I41 ; ARCHITECTURE §12 ; UI_FLOW §8.7) :
## journal de dialogue à puces (cadre → puces, prose → rangée à part),
## épinglage journal ↔ document au clavier et à la manette (dans les deux
## sens), réplique figée ; menu Interroger (cargo, portique) ; fouille avec et
## sans motif (boîte modale, focus ANNULER), zones, objets épinglables
## (objet ↔ onglet Contrebande), onglet FOUILLE du journal, retour Ⓑ ;
## blocage `inspection_busy` ; Rulebook (onglet Contrebande, implants « non
## visible — fouille », ligne R47) ; Économat (un achat par soir, jamais
## présélectionné) ; bilan (fouilles, citations) ; cartes d'aide ; effets
## visibles des améliorations (AG-02, AG-05, AG-06, pastilles).
## Une vraie `InspectionSession` répond à l'interface (signaux du contrat).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")

var ui: ComparisonUI = null
var session: InspectionSession = null
var day: DayDef = null
var ctx: RuleContext = null
var _saved_flags: Dictionary[StringName, Variant] = {}


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	_saved_flags = GameState.narrative_flags.duplicate()
	DocumentView.wood_lamp = false
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	session = InspectionSession.new()
	add_child_autofree(session)
	session.set_process(false)
	day = CaseFactory.catalog().get_day(8)
	ctx = CaseFactory.context(day.rule_set.make_shift_copy())
	ui.rule_context_provider = func() -> RuleContext: return ctx
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	await wait_process_frames(2)


func after_each() -> void:
	if ui != null and is_instance_valid(ui) and ui.search_dialog != null and is_instance_valid(ui.search_dialog):
		ui.search_dialog.queue_free()
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	GameState.narrative_flags = _saved_flags
	DocumentView.wood_lamp = false


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


## Cas « travail, trois semaines » (le permis dit 30 jours : la durée dite est
## discordante), cadre composé, fouille : une cartouche d'O₂ sans scellé sous la
## veste, des vêtements au bagage.
func _case(with_cue: bool = true) -> Case:
	var c: Case = CaseFactory.valid_case()
	c.index = 0
	c.case_seed = 4242
	c.statements = [Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_WORK, "stmt_purpose_work_2"),
			Statement.duration(18, 24, "stmt_dur_w3")] as Array[Statement]
	c.statement_frames = {&"purpose": "line_stmt_frame_gen_1"} as Dictionary[StringName, String]
	var layout: SearchLayout = SearchLayout.new()
	layout.add(SearchLayout.ZONE_LUGGAGE, SearchItem.make(&"ol09", SearchItem.Kind.LEGIT, &"clothes"))
	var o2: SearchItem = SearchItem.make(&"cb01", SearchItem.Kind.CONTRABAND, &"oxygen")
	o2.args = [6]
	layout.add(SearchLayout.ZONE_TORSO, o2)
	c.search_layout = layout
	if with_cue:
		c.search_cues = [SearchLayout.CUE_BULGE] as Array[StringName]
	return c


## Arrivée → documents posés → INSPECTING, session ouverte sur le cas.
func _present(c: Case) -> Case:
	session.begin(c, ctx)
	session.configure(InterrogationTiming.new(), {} as Dictionary[StringName, Variant])
	EventBus.case_presented.emit(c)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, c.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, c.case_id)
	EventBus.documents_presented.emit(c.case_id)
	await wait_process_frames(2)
	return c


## L'attente annoncée (`inspection_busy`) s'écoule, côté session et côté UI.
func _elapse(seconds: float) -> void:
	session.advance(seconds)
	ui.passenger_panel.busy.advance(seconds)


func _permit_stay() -> FieldRef:
	return FieldRef.new(CaseFactory.PERMIT, &"stay_days")


# ---------------------------------------------------------------------------
# I35 — journal de dialogue à puces
# ---------------------------------------------------------------------------

func test_frame_answer_becomes_a_journal_line_with_chips() -> void:
	await _present(_case())
	ui.ask(InterrogationTopics.PURPOSE)
	await wait_process_frames(2)
	var journal: DialogueJournal = ui.passenger_panel.journal
	var chips: Array[StatementChipView] = journal.chips()
	assert_eq(chips.size(), 2, "motif + durée en puces")
	var stay: StatementChipView = journal.find_chip(FieldRef.statement(Statement.ID_STAY))
	assert_not_null(stay)
	assert_eq(stay.get_text(), UiText.t("stmt_dur_w3"), "fragment de la durée")
	assert_false(ui.passenger_panel.get_line().contains("{"), "sous-titre composé, sans emplacement brut")
	assert_string_contains(ui.passenger_panel.get_line(), UiText.t("stmt_dur_w3"))
	var caption: Label = (journal.last_entry()["node"] as Node).get_node_or_null("Caption") as Label
	assert_not_null(caption, "la question posée légende la réplique")
	assert_true(journal.visible, "journal affiché")
	# Repère non coloré : glyphe de déclaration devant la valeur.
	assert_true(stay.find_children("", "Label", true, false).any(func(l: Label) -> bool: return l.text == DS.STATEMENT_GLYPH))


func test_scripted_prose_keeps_its_text_and_gets_a_separate_chip_row() -> void:
	var c: Case = await _present(_case())
	EventBus.interrogation_answered.emit(InterrogationTopics.PURPOSE, "line_purpose_work")
	EventBus.statement_given.emit(c.case_id, c.statements_for_question(InterrogationTopics.PURPOSE))
	await wait_process_frames(1)
	var entry: Dictionary = ui.passenger_panel.journal.last_entry()
	var box: Node = entry["node"]
	assert_not_null(box.get_node_or_null("ChipRow"), "puces sur une rangée à part")
	var chips: Array[StatementChipView] = entry["chips"]
	assert_eq(chips.size(), 2)


func test_journal_keeps_eight_lines_and_vague_or_struck_chips_are_marked() -> void:
	var c: Case = _case()
	var stay: Statement = c.get_statement(Statement.ID_STAY)
	stay.corrected_from = "stmt_dur_w1"
	await _present(c)
	for i: int in 12:
		ui.passenger_panel.set_line("Réplique %d" % i)
	assert_eq(ui.passenger_panel.journal.entries.size(), DS.JOURNAL_MAX_LINES, "8 répliques gardées")
	EventBus.interrogation_answered.emit(InterrogationTopics.STAY, "line_stay_long")
	EventBus.statement_given.emit(c.case_id, c.statements_for_question(InterrogationTopics.STAY))
	await wait_process_frames(1)
	var chips: Array[StatementChipView] = ui.passenger_panel.journal.last_entry()["chips"]
	assert_eq(chips.size(), 2, "valeur barrée + valeur finale")
	assert_true(chips[0].struck and not chips[0].comparable, "valeur barrée non sélectionnable")
	assert_false(chips[1].struck)


func test_keyboard_pins_chip_then_document_and_freezes_the_line() -> void:
	var c: Case = await _present(_case())
	ui.ask(InterrogationTopics.PURPOSE)
	_elapse(3.1)
	ui.set_inspection_active(true)
	await wait_process_frames(2)
	var chip: StatementChipView = ui.passenger_panel.journal.find_chip(FieldRef.statement(Statement.ID_STAY))
	assert_eq(chip.focus_mode, Control.FOCUS_ALL, "puce focalisable en inspection")
	chip.grab_focus()
	_press(&"ui_accept")
	await wait_process_frames(2)
	assert_not_null(ui.selection.a)
	assert_true(ui.selection.a.is_statement(), "A = puce")
	var field: InspectableItem = ui.workbench.find_item(_permit_stay())
	field.grab_focus()
	_press(&"ui_accept")
	await wait_process_frames(3)
	assert_eq(ui.discrepancies.size(), 1, "durée dite ≠ durée du permis")
	assert_eq(ui.discrepancies[0].reason_key, Discrepancy.REASON_STATEMENT_MISMATCH)
	assert_true(chip.is_flagged(), "puce hachurée et numérotée")
	assert_true(ui.passenger_panel.journal.is_frozen(chip.ref), "réplique figée")
	assert_string_contains(ui.describe(ui.discrepancies[0]), UiText.t("stmt_dur_w3").to_upper())
	assert_true(ui.available_topics().has(StringName("about_statement:" + String(CaseFactory.PERMIT))),
			"confrontation débloquée")
	# La réplique figée survit au défilement du journal.
	for i: int in 10:
		ui.passenger_panel.set_line("Bavardage %d" % i)
	assert_true(ui.passenger_panel.journal.is_frozen(chip.ref))
	assert_not_null(ui.passenger_panel.journal.find_chip(chip.ref))
	assert_true(c.is_statement_given(Statement.ID_STAY))


func test_gamepad_pins_document_then_chip_by_dpad_up() -> void:
	await _present(_case())
	ui.ask(InterrogationTopics.PURPOSE)
	_elapse(3.1)
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	ui.set_inspection_active(true)
	await wait_process_frames(2)
	var field: InspectableItem = ui.workbench.find_item(_permit_stay())
	field.grab_focus()
	_press(&"ui_accept")
	await wait_process_frames(2)
	assert_true(ui.selection.a != null and ui.selection.a.equals(_permit_stay()), "A = champ du permis")
	var reached: bool = false
	for i: int in 12:
		_press(&"ui_up")
		await wait_process_frames(2)
		if _focus_owner() is StatementChipView:
			reached = true
			break
	assert_true(reached, "croix ↑ : du plan de travail au journal (focus %s)" % _focus_owner())
	if not reached:
		return
	var chip: StatementChipView = _focus_owner() as StatementChipView
	if chip.ref.get_statement_id() != Statement.ID_STAY:
		ui.passenger_panel.journal.find_chip(FieldRef.statement(Statement.ID_STAY)).grab_focus()
	_press(&"ui_accept")
	await wait_process_frames(3)
	assert_eq(ui.discrepancies.size(), 1, "B = puce : discordance épinglée")
	_press(&"ui_down")
	await wait_process_frames(2)
	assert_false(_focus_owner() is StatementChipView, "croix ↓ : retour vers les documents")


# ---------------------------------------------------------------------------
# Menu Interroger, attente
# ---------------------------------------------------------------------------

func test_menu_offers_cargo_and_gate_and_gate_is_not_a_question() -> void:
	await _present(_case())
	var topics: Array[StringName] = ui.available_topics()
	assert_true(topics.has(InterrogationTopics.CARGO), "« Quelque chose à déclarer ? » au J8")
	assert_true(topics.has(InterrogationTopics.SEARCH), "portique (R44)")
	assert_lte(topics.size(), PassengerPanel.MAX_QUESTIONS)
	ui.ask(InterrogationTopics.SEARCH)
	assert_false(ui.asked_topics.has(InterrogationTopics.SEARCH), "la fouille ne compte pas comme question (R08)")
	assert_false(ui.available_topics().has(InterrogationTopics.SEARCH), "portique ouvert : plus au menu")


func test_busy_suspends_interrogation_and_gate_then_gives_control_back() -> void:
	watch_signals(EventBus)
	await _present(_case())
	ui.ask(InterrogationTopics.PURPOSE)
	await wait_process_frames(1)
	assert_true(ui.is_busy(), "la réponse prend son temps (3 s)")
	assert_true(ui.tool_bar.interrogate_button.disabled, "INTERROGER suspendu")
	assert_string_contains(ui.passenger_panel.busy.get_text().to_lower(), UiText.t("busy_answer", "Le passager répond").to_lower())
	ui.open_question_menu()
	assert_false(ui.question_menu_open, "menu fermé pendant l'attente")
	ui._on_question_chosen(InterrogationTopics.STAY)
	assert_signal_emit_count(EventBus, "interrogation_requested", 1, "aucune question pendant l'attente")
	# « Réduire les animations » : la barre avance par quarts.
	ui.passenger_panel.busy.advance(1.0)
	assert_almost_eq(ui.passenger_panel.busy.progress(), 0.25, 0.001)
	_elapse(2.2)
	assert_false(ui.is_busy())
	assert_false(ui.tool_bar.interrogate_button.disabled, "interface rendue")
	ui.open_question_menu()
	assert_true(ui.question_menu_open)


# ---------------------------------------------------------------------------
# I36 — fouille
# ---------------------------------------------------------------------------

func test_search_with_motive_reveals_zone_items_and_pins_them_to_the_contraband_tab() -> void:
	watch_signals(EventBus)
	await _present(_case(true))
	ui.ask(InterrogationTopics.SEARCH)
	await wait_process_frames(1)
	assert_null(ui.search_dialog, "motif présent : pas de confirmation")
	assert_true(ui.search_panel.is_open(), "silhouette à la place de la File")
	assert_false(ui.queue_panel.visible)
	assert_string_contains(ui.search_panel.get_motive_text(), UiText.t("srch_cue_bulge"))
	assert_true(ui.is_busy(), "activation du portique")
	assert_false(ui.search_panel.request_zone(SearchLayout.ZONE_TORSO), "zones suspendues pendant l'activation")
	_elapse(2.1)
	assert_true(ui.search_panel.request_zone(SearchLayout.ZONE_TORSO))
	assert_signal_emitted_with_parameters(EventBus, "search_requested", [SearchLayout.ZONE_TORSO])
	session.advance(0.01)
	await wait_process_frames(1)
	assert_eq(ui.search_panel.zone_status_text(SearchLayout.ZONE_TORSO), UiText.t("srch_zone_scanning", "SCAN…"))
	_elapse(2.1)
	await wait_process_frames(1)
	assert_eq(ui.search_panel.item_views.size(), 1, "objet révélé")
	var view: SearchItemView = ui.search_panel.item_views[0]
	assert_string_contains(view.get_detail_text(), "6")
	assert_string_contains(view.get_detail_text().to_lower(), "sans scellé")
	# Objet ↔ entrée de l'onglet Contrebande.
	ui.set_inspection_active(true)
	ui.pick(view.ref)
	ui.pick(FieldRef.contraband_entry(&"oxygen"))
	await wait_process_frames(3)
	assert_eq(ui.discrepancies.size(), 1, "objet interdit épinglé")
	assert_eq(ui.discrepancies[0].reason_key, Discrepancy.REASON_CONTRABAND)
	assert_not_null(ui.rulebook.get_contraband_card(&"oxygen"), "onglet Contrebande ouvert sur l'entrée")
	assert_true(ui.available_topics().has(InterrogationTopics.ABOUT_CONTRABAND))
	# Ⓑ : la sélection d'abord, puis la silhouette (avant de quitter l'inspection).
	ui.set_inspection_active(false)
	assert_true(ui.cancel(), "Ⓑ referme le portique")
	await wait_process_frames(2)
	assert_false(ui.search_panel.is_open())
	assert_true(ui.queue_panel.visible, "la File revient")
	var journal: DialogueJournal = ui.passenger_panel.journal
	assert_eq(journal.current_tab, DialogueJournal.TAB_SEARCH, "objets gardés à l'onglet FOUILLE")
	assert_eq(journal.search_views.size(), 1)
	assert_true(journal.search_views[0].is_flagged(), "la discordance reste marquée")


func test_search_without_motive_asks_confirmation_with_focus_on_cancel() -> void:
	watch_signals(EventBus)
	await _present(_case(false))
	ui.ask(InterrogationTopics.SEARCH)
	await wait_process_frames(2)
	assert_signal_emitted(EventBus, "search_confirmation_required")
	assert_not_null(ui.search_dialog, "boîte « AUCUN MOTIF ÉTABLI »")
	assert_eq(_focus_owner(), ui.search_dialog.cancel_button, "focus sur ANNULER")
	assert_true(FocusGuard.modal_over(ui), "le guichet se tait derrière la boîte")
	_press(&"ui_accept")
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(EventBus, "search_requested", [InspectionSession.SEARCH_CANCEL])
	assert_null(ui.search_dialog)
	assert_false(ui.search_panel.is_open(), "annulée : rien n'est ouvert")
	assert_false(session.search_done, "rien n'est compté")
	ui.ask(InterrogationTopics.SEARCH)
	await wait_process_frames(2)
	ui.search_dialog.accept()
	await wait_process_frames(2)
	assert_signal_emitted(EventBus, "search_opened")
	assert_true(ui.search_panel.is_open(), "fouille engagée sans motif")
	assert_eq(ui.search_panel.get_motive_text(), UiText.t("srch_motive_none"), "bandeau ambre AUCUN MOTIF")
	assert_true(session.search_done)
	assert_eq(session.search_motive, SearchLayout.MOTIVE_NONE)


func test_gate_is_driven_by_pad_and_closed_by_back() -> void:
	await _present(_case(true))
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	ui.ask(InterrogationTopics.SEARCH)
	_elapse(2.1)
	await wait_process_frames(3)
	var first: Control = ui.search_panel.first_focus()
	first.grab_focus()
	assert_eq(_focus_owner(), ui.search_panel.zone_buttons[SearchLayout.ZONE_HEAD], "focus sur Z1")
	_press(&"ui_down")
	await wait_process_frames(2)
	assert_eq(_focus_owner(), ui.search_panel.zone_buttons[SearchLayout.ZONE_TORSO], "croix ↓ : zone suivante")
	_press(&"ui_accept")
	await wait_process_frames(2)
	assert_eq(ui.search_panel.zone_states[SearchLayout.ZONE_TORSO], SearchPanel.STATE_SCANNING, "Ⓐ : scan")
	# Ⓑ vaut `cancel` (et `ui_cancel`) : le guichet referme le portique.
	_press(&"cancel")
	await wait_process_frames(2)
	assert_false(ui.search_panel.is_open(), "Ⓑ : silhouette refermée")


func test_scan_all_queues_every_zone_in_order() -> void:
	watch_signals(EventBus)
	await _present(_case(true))
	ui.ask(InterrogationTopics.SEARCH)
	_elapse(2.1)
	assert_true(ui.search_panel.request_all())
	assert_signal_emitted_with_parameters(EventBus, "search_requested", [SearchLayout.ZONE_ALL])
	for i: int in 6:
		_elapse(2.1)
	await wait_process_frames(1)
	assert_eq(ui.search_panel.scanned_zones().size(), 5, "cinq zones scannées")
	assert_eq(ui.search_panel.zone_status_text(SearchLayout.ZONE_HEAD), UiText.t("srch_nothing", "RAS"))
	assert_eq(ui.search_panel.item_views.size(), 2)


# ---------------------------------------------------------------------------
# I37 — Rulebook
# ---------------------------------------------------------------------------

func test_contraband_tab_entries_hidden_implants_and_belt_line() -> void:
	assert_true(ui.rulebook.visible_reference_tabs().has(RulebookReference.TAB_CONTRABAND), "onglet Contrebande au J8")
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_CONTRABAND))
	await wait_process_frames(1)
	assert_eq(ui.rulebook.contraband_cards.size(), ContrabandEntryView.ENTRIES.size())
	var print_card: ContrabandEntryView = ui.rulebook.get_contraband_card(&"print")
	assert_false(print_card.comparable, "CB-08 : renvoi au bulletin, non sélectionnable")
	assert_true(ui.rulebook.get_contraband_card(&"oxygen").comparable)
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_IMPLANTS))
	await wait_process_frames(1)
	var hidden: Node = ui.rulebook.find_child("Hidden_NX", true, false)
	assert_not_null(hidden, "NX : implants dissimulés « non visible — fouille »")
	var origins: Control = RulebookReference.build(RulebookReference.TAB_ORIGINS, [RulebookReference.RULE_BELT_SEARCH] as Array[StringName])
	add_child_autofree(origins)
	assert_not_null(origins.find_child("BeltSearchNote", true, false), "ligne R47 dans l'onglet Origines")


func test_permit_shows_sponsor_name_on_its_own_line() -> void:
	var doc: DocumentInstance = CaseFactory.document(CaseFactory.PERMIT, CaseFactory.passenger())
	doc.set_value(&"sponsor_name", "Tomás Moreno-Lind")
	var view: DocumentView = DocumentView.create(doc)
	add_child_autofree(view)
	await wait_process_frames(1)
	var item: InspectableItem = view.find_item(FieldRef.new(CaseFactory.PERMIT, &"sponsor_name"))
	assert_not_null(item, "champ « Nom du répondant »")
	assert_true(DocumentView.WIDE_FIELD_IDS.has(&"sponsor_name"))
	assert_eq(UiText.t("field_sponsor_name"), "Nom du répondant")


# ---------------------------------------------------------------------------
# Améliorations (effets visibles), Économat, bilan, aides
# ---------------------------------------------------------------------------

func test_upgrade_effects_are_visible_at_the_booth() -> void:
	GameState.set_flag(UpgradeDef.flag_of(UpgradeDef.ID_QUEUE_MONITOR), true)
	GameState.set_flag(UpgradeDef.flag_of(UpgradeDef.ID_WOOD_LAMP), true)
	GameState.set_flag(UpgradeDef.flag_of(UpgradeDef.ID_ANNOTATED_BOOK), true)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	await wait_process_frames(1)
	assert_eq(ui.queue_panel.upgrade_count(), 3, "pastilles du guichet")
	assert_true(DocumentView.wood_lamp)
	var c: Case = _case()
	session.begin(c, ctx)
	EventBus.case_presented.emit(c)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, c.case_id)
	assert_string_contains(ui.queue_panel.get_manifest_text(), "TYC", "AG-06 : manifeste pendant la marche")
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, c.case_id)
	EventBus.documents_presented.emit(c.case_id)
	await wait_process_frames(2)
	var permit: DocumentView = ui.workbench.get_view(CaseFactory.PERMIT)
	assert_not_null(permit.find_child("WoodLampCaption", true, false), "AG-02 : modèle du sceau en clair")
	ui.set_inspection_active(true)
	ui.pick(FieldRef.new(CaseFactory.PERMIT, &"expiry_date"))
	await wait_process_frames(2)
	assert_ne(ui.rulebook.last_focused_rule, &"", "AG-05 : Rulebook ouvert à la bonne page")
	assert_false(ui.rulebook.margin_note.is_empty(), "note de marge d'Okonkwo")


func _evening(day_number: int, balance: int) -> EveningScreen:
	var data: DataCatalog = CaseFactory.catalog()
	var evening_day: DayDef = data.get_day(day_number)
	var economy: EconomyDef = data.get_economy()
	var flags: Dictionary[StringName, Variant] = {}
	var home: Household = Household.new()
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, home, flags, balance)
	EveningService.default_selection(lines, balance)
	lines.append_array(EveningService.shop_lines(economy, day_number, flags))
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(evening_day, balance, 20, lines, home, false)
	screen.shop_flags = flags
	return screen


func test_shop_offers_one_purchase_never_preselected() -> void:
	var screen: EveningScreen = _evening(9, 200)
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_not_null(screen.shop, "Économat sous les dépenses (J9)")
	assert_gte(screen.shop.rows.size(), 2)
	for row: Button in screen.shop.rows:
		assert_false(row.button_pressed, "jamais présélectionné")
	var first: Button = screen.shop.rows[0]
	var second: Button = screen.shop.rows[1]
	first.button_pressed = true
	await wait_process_frames(1)
	var first_line: ExpenseLine = first.get_meta(&"line")
	assert_true(first_line.paid, "achat coché")
	second.button_pressed = true
	await wait_process_frames(1)
	var second_line: ExpenseLine = second.get_meta(&"line")
	assert_false(second_line.paid, "un seul achat par soir")
	assert_true((second.find_child("Reason", true, false) as Label).visible, "raison écrite")
	assert_not_null(first.find_child("Effect", true, false), "effet expliqué")
	var after: Label = screen.shop.find_child("AfterPurchase", true, false).get_child(1) as Label
	assert_string_contains(after.text, str(200 - EveningService.total_spent(screen.lines)), "solde après achat")
	screen.confirm()
	await wait_process_frames(1)


func test_shop_refuses_credit() -> void:
	var screen: EveningScreen = _evening(9, 12)
	add_child_autofree(screen)
	await wait_process_frames(2)
	if screen.shop == null or screen.shop.rows.is_empty():
		pending("aucune offre au J9")
		return
	var row: Button = screen.shop.rows[0]
	row.button_pressed = true
	await wait_process_frames(1)
	var line: ExpenseLine = row.get_meta(&"line")
	assert_false(line.paid, "l'Économat ne fait pas crédit")
	assert_eq((row.find_child("Reason", true, false) as Label).text, UiText.t("ev_insufficient", "Fonds insuffisants"))


func test_shop_has_its_own_focusable_rows_and_back_does_not_buy() -> void:
	var screen: EveningScreen = _evening(5, 200)
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_not_null(screen.shop)
	assert_not_null(screen.shop.find_child("Intro", true, false), "premier soir : Okonkwo présente l'Économat")
	for row: Button in screen.shop.rows:
		assert_eq(row.focus_mode, Control.FOCUS_ALL)
		assert_gte(row.custom_minimum_size.y, DS.HIT_TARGET_MIN)
	assert_eq(screen.default_focus(), screen.confirm_button, "focus initial inchangé : VALIDER")


func test_summary_counts_searches_and_explains_new_citations() -> void:
	var summary: DaySummary = DaySummary.new()
	summary.day_number = 8
	summary.planned_cases = 2
	var searched: CaseResult = CaseResult.new()
	searched.verdict = Verdict.new(&"a", VerdictKind.Kind.APPROVE)
	searched.verdict.search_done = true
	searched.verdict.search_motive = &""
	searched.verdict_kind = VerdictKind.Kind.APPROVE
	searched.citation_reason_key = ScoringService.CIT_UNWARRANTED_SEARCH
	searched.citation_rule_id = &"r_search_cause"
	searched.passenger_label = "A. TEST"
	summary.results.append(searched)
	var screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
	screen.setup(summary, day)
	add_child_autofree(screen)
	await wait_process_frames(2)
	var stats: Node = screen.find_child("M13Stats", true, false)
	assert_not_null(stats, "ligne fouilles · déclarations")
	var text: String = ""
	for label: Label in stats.find_children("", "Label", true, false):
		text += label.text + " | "
	assert_string_contains(text, UiText.tf("ss_searches", [1, 1]))
	var all: String = ""
	for label: Label in screen.find_children("", "Label", true, false):
		all += label.text + "\n"
	assert_string_contains(all, UiText.t("cit_unwarranted_search_desc"), "FOUILLE SANS MOTIF expliquée")
	assert_eq(screen.default_focus(), screen.continue_button)


func test_help_cards_follow_settings_and_are_passable_by_pad() -> void:
	Settings.set_session_value(Settings.KEY_TUTORIAL_M13_STATEMENTS, true)
	Settings.set_session_value(Settings.KEY_TUTORIAL_M13_SEARCH, true)
	var due: Array[StringName] = Settings.m13_tutorials_due(true, true)
	assert_eq(due.size(), 2)
	var card: HelpCard = HelpCard.make(due)
	card.persist = false
	add_child_autofree(card)
	await wait_process_frames(2)
	assert_eq(_focus_owner(), card.ok_button, "focus sur SUIVANT / COMPRIS")
	assert_not_null(card.find_child("Page", true, false), "1 / 2")
	_press(&"ui_accept")
	await wait_process_frames(2)
	assert_eq(card.current_key(), Settings.KEY_TUTORIAL_M13_SEARCH, "carte suivante")
	assert_false(Settings.get_bool(Settings.KEY_TUTORIAL_M13_STATEMENTS), "carte lue : réglage à faux")
	_press(&"ui_cancel")
	await wait_process_frames(2)
	assert_true(not is_instance_valid(card) or card.is_dismissed(), "Ⓑ passe la dernière carte")
	assert_eq(Settings.m13_tutorials_due(true, true).size(), 0, "plus d'aide due")
	Settings.clear_session_value(Settings.KEY_TUTORIAL_M13_STATEMENTS)
	Settings.clear_session_value(Settings.KEY_TUTORIAL_M13_SEARCH)


func test_pause_lists_owned_upgrades() -> void:
	GameState.set_flag(UpgradeDef.flag_of(UpgradeDef.ID_HYGIAPHONE), true)
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(1)
	pause.refresh_upgrades()
	assert_true(pause.upgrades_box.visible, "améliorations possédées rappelées")
	assert_not_null(pause.upgrades_box.find_child("Upgrade_ag01", true, false))
