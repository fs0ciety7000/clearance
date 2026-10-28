## UI du signalement code 1 (NARRATIVE §4.9, D-062) et des dates des Dérivants
## (§4.10, D-068) : marque luciole et entrée du bulletin « Symboles subversifs »
## sélectionnables en Mode Inspection, ligne « 00.00.AAAA » de l'onglet
## « Codes d'origine », affichage des dates année seule.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const LUCIOLE: StringName = &"luciole"

var ui: ComparisonUI = null
var case: Case = null
var _day_before: int = 0


func before_each() -> void:
	_day_before = GameState.current_day


func after_each() -> void:
	GameState.current_day = _day_before


func _make_ui(day_number: int, marked: bool = true) -> void:
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	var day: DayDef = CaseFactory.catalog().get_day(day_number)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	case.index = 0
	if marked:
		case.get_document(CaseFactory.PERMIT).marks.append(LUCIOLE)
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)


func _mark_ref() -> FieldRef:
	return FieldRef.mark(CaseFactory.PERMIT, LUCIOLE)


# ---------------------------------------------------------------------------
# Marque ↔ bulletin
# ---------------------------------------------------------------------------

func test_mark_is_an_inspectable_item_only_on_marked_documents() -> void:
	_make_ui(7)
	var permit: DocumentView = ui.workbench.get_view(CaseFactory.PERMIT)
	var id_card: DocumentView = ui.workbench.get_view(CaseFactory.ID_CARD)
	assert_null(id_card.get_mark_item(LUCIOLE), "carte d'identité sans marque")
	var mark: DocMarkView = permit.get_mark_item(LUCIOLE)
	assert_not_null(mark, "marque luciole du permis")
	assert_true(mark.ref.equals(_mark_ref()))
	assert_true(permit.get_items().has(mark))
	assert_eq(ui.workbench.find_item(_mark_ref()), mark)
	assert_eq(mark.mouse_filter, Control.MOUSE_FILTER_IGNORE, "inerte hors inspection")
	ui.set_inspection_active(true)
	assert_eq(mark.mouse_filter, Control.MOUSE_FILTER_STOP, "cliquable en inspection")
	await get_tree().process_frame
	var center: Vector2 = mark.get_global_rect().get_center()
	var expected: Vector2 = permit.get_global_transform() * permit.luciole_mark_position()
	assert_almost_eq(center.distance_to(expected), 0.0, 1.0, "centrée sur le dessin du coin")


func test_mark_then_symbol_requests_a_check() -> void:
	_make_ui(7)
	ui.set_inspection_active(true)
	var mark: DocMarkView = ui.workbench.get_view(CaseFactory.PERMIT).get_mark_item(LUCIOLE)
	watch_signals(EventBus)
	mark.picked.emit(mark)
	assert_eq(ui.selection.a.key(), _mark_ref().key(), "marque = champ A")
	assert_true(mark.selected)
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_SYMBOLS), "bulletin ouvert au J7")
	var card: SymbolCardView = ui.rulebook.get_symbol_card(LUCIOLE)
	assert_not_null(card, "entrée luciole du bulletin")
	assert_true(card.ref.equals(FieldRef.symbol(LUCIOLE)))
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_STOP, "sélectionnable en inspection")
	card.picked.emit(card)
	assert_signal_emitted(EventBus, "discrepancy_check_requested")
	var params: Array = get_signal_parameters(EventBus, "discrepancy_check_requested")
	var a: FieldRef = params[0]
	var b: FieldRef = params[1]
	assert_true(a.equals(_mark_ref()), "A = marque")
	assert_true(b.equals(FieldRef.symbol(LUCIOLE)), "B = symbole")


func test_symbol_first_reveals_the_bulletin_and_flags_both_ends() -> void:
	_make_ui(7)
	ui.set_inspection_active(true)
	assert_eq(ui.pick(FieldRef.symbol(LUCIOLE)), InspectionSelection.Action.SELECTED_A)
	assert_eq(ui.rulebook.current_tab, RulebookPanel.reference_tab_id(RulebookReference.TAB_SYMBOLS),
			"l'onglet Symboles s'ouvre sur l'entrée choisie")
	assert_true(ui.rulebook.get_symbol_card(LUCIOLE).selected)
	watch_signals(EventBus)
	assert_eq(ui.pick(_mark_ref()), InspectionSelection.Action.REQUESTED)
	assert_signal_emitted(EventBus, "discrepancy_check_requested")
	# Réponse réelle du moteur (J7, bulletin ouvert) : DISCORDANCE « symbol_match ».
	var ctx: RuleContext = Gen.data().make_context(7)
	var result: Discrepancy = DiscrepancyChecker.check(case, FieldRef.symbol(LUCIOLE), _mark_ref(), ctx)
	assert_eq(result.reason_key, Discrepancy.REASON_SYMBOL_MATCH)
	EventBus.discrepancy_checked.emit(result)
	assert_eq(ui.discrepancies.size(), 1)
	assert_true(ui.workbench.get_view(CaseFactory.PERMIT).get_mark_item(LUCIOLE).is_flagged(), "marque épinglée")
	assert_true(ui.rulebook.get_symbol_card(LUCIOLE).is_flagged(), "bulletin épinglé")
	assert_eq(ui.workbench.get_view(CaseFactory.PERMIT).flag_count, 1)
	assert_eq(ui.describe(result), UiText.t("disc_symbol_match"))
	assert_eq(InterrogationTopics.topic_for(result), &"", "un signalement, pas une question")
	# Changement d'onglet : l'entrée recréée garde sa discordance.
	ui.rulebook.show_reference_tab(RulebookReference.TAB_ORIGINS)
	ui.rulebook.show_reference_tab(RulebookReference.TAB_SYMBOLS)
	assert_true(ui.rulebook.get_symbol_card(LUCIOLE).is_flagged(), "discordance conservée")


func test_no_symbol_entry_before_day_seven() -> void:
	_make_ui(6)
	assert_false(ui.rulebook.show_reference_tab(RulebookReference.TAB_SYMBOLS))
	assert_null(ui.rulebook.find_item(FieldRef.symbol(LUCIOLE), true), "bulletin absent au J6")


# ---------------------------------------------------------------------------
# Dates des Dérivants
# ---------------------------------------------------------------------------

func test_origins_tab_shows_the_drifter_birth_line() -> void:
	_make_ui(4, false)
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_ORIGINS))
	var note: Label = ui.rulebook.find_child("DrvBirthNote", true, false) as Label
	assert_not_null(note, "ligne rb_origins_drv_birth")
	assert_eq(note.text, UiText.t("rb_origins_drv_birth"))
	assert_string_contains(note.text, "00.00.AAAA")


func test_year_only_birth_is_shown_and_comparable() -> void:
	var p: Passenger = CaseFactory.passenger()
	p.birth_date = GameDate.year_only(2163)
	var doc: DocumentInstance = CaseFactory.document(CaseFactory.ID_CARD, p)
	var view: DocumentView = DocumentView.create(doc)
	add_child_autofree(view)
	var shown: int = 0
	for item: DocFieldView in view.fields:
		var field: FieldDef = doc.type_def.get_field(item.ref.field_id)
		if field != null and field.kind == FieldDef.FieldKind.DATE and doc.get_value(field.id) == p.birth_date:
			assert_eq(item.get_value_text(), "00.00.2163", "naissance année seule")
			assert_true(item.comparable, "comparable (R07 par année)")
			shown += 1
	assert_gt(shown, 0, "date de naissance affichée")
