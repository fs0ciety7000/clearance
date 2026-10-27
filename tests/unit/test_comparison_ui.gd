## Tests de l'interface de comparaison (M4) : construction des documents,
## sélection A → B, verrouillage et maintien des tampons, déblocage de
## questions, traductions, thème mis à l'échelle.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")

var ui: ComparisonUI = null
var case: Case = null
var day: DayDef = null


func before_each() -> void:
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	day = CaseFactory.catalog().get_day(3)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	case.index = 0


## Arrivée → documents posés → INSPECTING (ordre du DayController / booth).
func _present_case() -> void:
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)


func _expire_permit() -> FieldRef:
	var permit: DocumentInstance = case.get_document(CaseFactory.PERMIT)
	permit.expiry_date = CaseFactory.today() - 10
	return FieldRef.new(CaseFactory.PERMIT, &"expiry_date")


# ---------------------------------------------------------------------------
# DocumentView
# ---------------------------------------------------------------------------

func test_document_view_builds_every_document_type() -> void:
	var passenger: Passenger = CaseFactory.passenger()
	var defs: Dictionary[StringName, DocumentTypeDef] = CaseFactory.catalog().documents
	assert_gt(defs.size(), 0)
	for document_id: StringName in defs:
		var def: DocumentTypeDef = defs[document_id]
		var doc: DocumentInstance = CaseFactory.document(document_id, passenger)
		var view: DocumentView = DocumentView.create(doc)
		add_child_autofree(view)
		var items: Array[InspectableItem] = view.get_items()
		assert_eq(items.size(), def.fields.size(), "%s : un élément par champ" % document_id)
		for field: FieldDef in def.fields:
			var item: InspectableItem = view.find_item(FieldRef.new(document_id, field.id))
			assert_not_null(item, "%s/%s affiché" % [document_id, field.id])
			if item == null:
				continue
			assert_eq(item.comparable, field.comparable, "%s/%s comparable" % [document_id, field.id])
			var field_view: DocFieldView = item as DocFieldView
			if field.kind == FieldDef.FieldKind.PORTRAIT:
				assert_true(field_view.is_portrait())
				assert_eq(view.portrait_field, field_view)
			else:
				var expected: String = UiText.value_text(field, doc.get_value(field.id))
				assert_eq(field_view.get_value_text(), expected, "%s/%s valeur" % [document_id, field.id])
				if field.kind != FieldDef.FieldKind.LIST:
					assert_ne(expected, "—", "%s/%s renseigné" % [document_id, field.id])
		# Ordre d'affichage = `display_order` (photo à part).
		var shown: Array[StringName] = []
		for field_view: DocFieldView in view.fields:
			shown.append(field_view.field.id)
		var expected_order: Array[StringName] = []
		for field: FieldDef in def.get_sorted_fields():
			if field.kind != FieldDef.FieldKind.PORTRAIT:
				expected_order.append(field.id)
		assert_eq(shown, expected_order, "%s : ordre display_order" % document_id)


func test_document_view_uses_portrait_provider() -> void:
	var doc: DocumentInstance = CaseFactory.document(CaseFactory.ID_CARD, CaseFactory.passenger())
	var texture: ImageTexture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var received: Array[PassengerAppearance] = []
	var provider: Callable = func(appearance: PassengerAppearance) -> Texture2D:
		received.append(appearance)
		return texture
	var view: DocumentView = DocumentView.create(doc, provider)
	add_child_autofree(view)
	assert_eq(received.size(), 1, "fournisseur appelé une fois")
	var portrait: PortraitView = view.portrait_field.get_child(0) as PortraitView
	assert_eq(portrait.texture, texture)


func test_document_view_falls_back_to_placeholder() -> void:
	var doc: DocumentInstance = CaseFactory.document(CaseFactory.ID_CARD, CaseFactory.passenger())
	var view: DocumentView = DocumentView.create(doc, func(_a: PassengerAppearance) -> Texture2D: return null)
	add_child_autofree(view)
	var portrait: PortraitView = view.portrait_field.get_child(0) as PortraitView
	assert_null(portrait.texture)
	assert_not_null(portrait.appearance, "placeholder dérivé de l'apparence")


# ---------------------------------------------------------------------------
# Mode Inspection : A → B
# ---------------------------------------------------------------------------

func test_documents_appear_only_after_documents_presented() -> void:
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	assert_eq(ui.workbench.views.size(), 0, "rien sur le plan pendant la marche")
	EventBus.documents_presented.emit(&"autre_cas")
	assert_eq(ui.workbench.views.size(), 0, "signal d'un autre cas ignoré")
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)
	assert_eq(ui.workbench.views.size(), 2)
	EventBus.documents_presented.emit(case.case_id)
	assert_eq(ui.workbench.views.size(), 2, "second documents_presented ignoré")


func test_selecting_a_then_b_emits_check_requested() -> void:
	var expiry: FieldRef = _expire_permit()
	_present_case()
	watch_signals(EventBus)
	ui.set_inspection_active(true)
	assert_signal_emitted_with_parameters(EventBus, "inspection_mode_changed", [true])
	# Clic réel sur le champ (signal `picked` de l'élément).
	var item: InspectableItem = ui.workbench.find_item(expiry)
	assert_not_null(item)
	item.picked.emit(item)
	assert_signal_not_emitted(EventBus, "discrepancy_check_requested", "A seul : rien")
	assert_true(item.selected, "A marqué")
	var today_item: InspectableItem = ui.rulebook.find_item(FieldRef.today())
	today_item.picked.emit(today_item)
	assert_signal_emit_count(EventBus, "discrepancy_check_requested", 1)
	var params: Array = get_signal_parameters(EventBus, "discrepancy_check_requested")
	var a: FieldRef = params[0]
	var b: FieldRef = params[1]
	assert_true(a.equals(expiry), "A = date d'expiration du permis")
	assert_true(b.is_today(), "B = date du jour")
	assert_false(item.selected, "A libéré après la demande")


func test_same_pair_is_not_requested_twice() -> void:
	_present_case()
	ui.set_inspection_active(true)
	watch_signals(EventBus)
	var a: FieldRef = FieldRef.new(CaseFactory.ID_CARD, &"family_name")
	var b: FieldRef = FieldRef.new(CaseFactory.PERMIT, &"family_name")
	assert_eq(ui.pick(a), InspectionSelection.Action.SELECTED_A)
	assert_eq(ui.pick(b), InspectionSelection.Action.REQUESTED)
	assert_eq(ui.pick(b), InspectionSelection.Action.SELECTED_A)
	assert_eq(ui.pick(a), InspectionSelection.Action.ALREADY_DONE, "paire déjà demandée (ordre inversé)")
	assert_signal_emit_count(EventBus, "discrepancy_check_requested", 1)


func test_reclick_deselects_and_same_document_replaces_a() -> void:
	_present_case()
	ui.set_inspection_active(true)
	var name_ref: FieldRef = FieldRef.new(CaseFactory.ID_CARD, &"family_name")
	var birth_ref: FieldRef = FieldRef.new(CaseFactory.ID_CARD, &"birth_date")
	assert_eq(ui.pick(name_ref), InspectionSelection.Action.SELECTED_A)
	assert_eq(ui.pick(name_ref), InspectionSelection.Action.DESELECTED)
	assert_false(ui.selection.has_a())
	ui.pick(name_ref)
	assert_eq(ui.pick(birth_ref), InspectionSelection.Action.REPLACED_A)
	assert_true(ui.selection.a.equals(birth_ref))
	assert_true(ui.workbench.find_item(birth_ref).selected)
	assert_false(ui.workbench.find_item(name_ref).selected)
	ui.cancel()
	assert_false(ui.selection.has_a(), "Échap annule A")
	assert_true(ui.inspection_active, "le mode reste actif")
	ui.cancel()
	assert_false(ui.inspection_active, "second Échap : sortie du mode")


func test_pick_is_ignored_outside_inspection() -> void:
	_present_case()
	watch_signals(EventBus)
	assert_eq(ui.pick(FieldRef.new(CaseFactory.ID_CARD, &"family_name")), InspectionSelection.Action.IGNORED)
	assert_signal_not_emitted(EventBus, "discrepancy_check_requested")


func test_inspection_unavailable_before_documents() -> void:
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	ui.set_inspection_active(true)
	assert_false(ui.inspection_active)


func test_face_picked_in_3d_is_a_comparable_field() -> void:
	_present_case()
	watch_signals(EventBus)
	EventBus.inspection_target_picked.emit(FieldRef.passenger_face())
	assert_true(ui.inspection_active, "le clic visage active le mode")
	assert_true(ui.selection.a.is_passenger_face())
	ui.pick(FieldRef.new(CaseFactory.ID_CARD, &"portrait"))
	assert_signal_emit_count(EventBus, "discrepancy_check_requested", 1)


func test_discordance_flags_fields_and_unlocks_question() -> void:
	var expiry: FieldRef = _expire_permit()
	_present_case()
	ui.set_inspection_active(true)
	ui.pick(expiry)
	ui.pick(FieldRef.today())
	var ctx: RuleContext = CaseFactory.context(day.rule_set, day.game_date)
	var result: Discrepancy = DiscrepancyChecker.check(case, expiry, FieldRef.today(), ctx)
	assert_eq(result.result, Discrepancy.Result.DISCORDANT)
	EventBus.discrepancy_checked.emit(result)
	assert_eq(ui.discrepancies.size(), 1)
	assert_true(ui.workbench.find_item(expiry).is_flagged(), "champ A flagged")
	assert_true(ui.rulebook.find_item(FieldRef.today()).is_flagged(), "date du jour flagged")
	var topic: StringName = InterrogationTopics.topic_for(result)
	assert_eq(topic, &"about_expired:entry_permit")
	assert_true(ui.available_topics().has(topic), "question débloquée")
	assert_eq(ui.queue_panel.get_status_text(), UiText.plural("qp_documented", 1, "%d DOCUMENTÉE", "%d DOCUMENTÉES"))
	assert_true(ui.workbench.is_banner_visible())
	# Un résultat qui ne correspond à aucune demande est ignoré.
	var stray: Discrepancy = DiscrepancyChecker.check(case, FieldRef.new(CaseFactory.ID_CARD, &"family_name"),
			FieldRef.new(CaseFactory.PERMIT, &"family_name"), ctx)
	EventBus.discrepancy_checked.emit(stray)
	assert_eq(ui.discrepancies.size(), 1)


func test_interrogation_request_and_answer() -> void:
	_present_case()
	watch_signals(EventBus)
	ui.ask(InterrogationTopics.PURPOSE)
	assert_signal_emitted_with_parameters(EventBus, "interrogation_requested", [InterrogationTopics.PURPOSE])
	assert_true(ui.asked_topics.has(InterrogationTopics.PURPOSE))
	EventBus.interrogation_answered.emit(InterrogationTopics.PURPOSE, "ans_purpose")
	assert_string_contains(ui.passenger_panel.get_line(), UiText.t("ans_purpose"))


func test_reaction_after_answer_keeps_the_answer_subtitle() -> void:
	_present_case()
	EventBus.interrogation_answered.emit(&"about_mismatch:id_card", "line_about_id_number_1")
	EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
	assert_string_contains(ui.subtitles.get_text(), UiText.t("line_about_id_number_1"), "la réplique reste affichée")
	assert_false(ui.subtitles.get_text().contains(UiText.t("react_nervous")))
	assert_string_contains(ui.passenger_panel.get_line(), UiText.t("line_about_id_number_1"))
	# Réaction suivante (déjà « consommée » par la réponse) : sa propre réplique.
	EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
	assert_string_contains(ui.subtitles.get_text(), UiText.t("react_nervous"))


func test_public_feedback_signals() -> void:
	watch_signals(ui)
	ui.toasts.push(ToastStack.Kind.SUCCESS, "ok", "")
	assert_signal_emitted_with_parameters(ui, "toast_shown", [ToastStack.Kind.SUCCESS])
	var next_button: BaseButton = ui.tool_bar.find_children("*", "BaseButton", true, false)[0] as BaseButton
	next_button.disabled = false
	next_button.mouse_entered.emit()
	assert_signal_emitted(ui, "hovered", "survol d'un bouton actif")
	var late: Button = Button.new()
	ui.passenger_panel.add_child(late)
	late.mouse_entered.emit()
	assert_signal_emit_count(ui, "hovered", 2, "boutons créés après coup branchés aussi")
	late.disabled = true
	late.mouse_entered.emit()
	assert_signal_emit_count(ui, "hovered", 2, "bouton inactif : pas de son")


func test_departure_line_after_verdict() -> void:
	_present_case()
	watch_signals(ui)
	EventBus.day_phase_changed.emit(DayPhase.Kind.RESOLVING, case.case_id)
	var result: CaseResult = CaseResult.new(case.case_id)
	result.verdict_kind = VerdictKind.Kind.DENY
	EventBus.case_resolved.emit(case.case_id, result)
	EventBus.day_phase_changed.emit(DayPhase.Kind.DEPARTING, case.case_id)
	assert_signal_not_emitted(ui, "departure_line_shown", "après la réaction au tampon")
	ui.show_departure_line(case.case_id, VerdictKind.Kind.DENY)
	assert_signal_emitted_with_parameters(ui, "departure_line_shown", ["bark_depart_denied", UiText.t("bark_depart_denied")])
	assert_string_contains(ui.subtitles.get_text(), UiText.t("bark_depart_denied"))
	ui.show_departure_line(case.case_id, VerdictKind.Kind.DENY)
	assert_signal_emit_count(ui, "departure_line_shown", 1, "une seule fois par passager")
	assert_eq(ComparisonUI.departure_key(case, VerdictKind.Kind.APPROVE), "bark_depart_ok")
	# M7 (ARCHITECTURE §7.1) : la détention a sa réplique de sortie générique.
	assert_eq(ComparisonUI.departure_key(case, VerdictKind.Kind.DETAIN), InspectionSession.LINE_EXIT_DETAIN)
	for key: String in ["bark_depart_ok", "bark_depart_denied", "bark_depart_detained", "tag_departing"]:
		assert_true(UiText.has(key), key)


func test_visor_question_only_when_face_covered() -> void:
	_present_case()
	assert_false(ui.available_topics().has(InterrogationTopics.REMOVE_VISOR))
	case.passenger_presented.appearance.traits[PassengerAppearance.SLOT_HEADWEAR] = PassengerAppearance.VISOR_DOWN
	assert_true(ui.available_topics().has(InterrogationTopics.REMOVE_VISOR))


# ---------------------------------------------------------------------------
# Tampons : verrouillage et maintien 0,4 s
# ---------------------------------------------------------------------------

func test_stamps_locked_outside_inspecting() -> void:
	assert_true(ui.stamps_locked(), "guichet vide")
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	assert_true(ui.get_stamp_button(VerdictKind.Kind.APPROVE).locked, "ARRIVING")
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	assert_true(ui.get_stamp_button(VerdictKind.Kind.APPROVE).locked, "INSPECTING sans documents")
	watch_signals(EventBus)
	var deny: StampButton = ui.get_stamp_button(VerdictKind.Kind.DENY)
	deny.begin_hold()
	deny.advance(1.0)
	assert_signal_not_emitted(EventBus, "verdict_stamped", "aucun verdict verrouillé")
	EventBus.documents_presented.emit(case.case_id)
	assert_false(ui.get_stamp_button(VerdictKind.Kind.APPROVE).locked, "INSPECTING + documents")
	assert_false(deny.locked)
	EventBus.day_phase_changed.emit(DayPhase.Kind.DEPARTING, case.case_id)
	assert_true(ui.get_stamp_button(VerdictKind.Kind.APPROVE).locked, "DEPARTING")
	assert_true(deny.locked)


func test_stamp_requires_hold_of_0_4_seconds() -> void:
	assert_almost_eq(DS.STAMP_HOLD, 0.4, 0.0001)
	var expiry: FieldRef = _expire_permit()
	_present_case()
	ui.set_inspection_active(true)
	ui.pick(expiry)
	ui.pick(FieldRef.today())
	EventBus.discrepancy_checked.emit(DiscrepancyChecker.check(case, expiry, FieldRef.today(),
			CaseFactory.context(day.rule_set, day.game_date)))
	ui.ask(&"about_expired:entry_permit")
	watch_signals(EventBus)
	var deny: StampButton = ui.get_stamp_button(VerdictKind.Kind.DENY)
	deny.begin_hold()
	assert_false(deny.advance(0.3), "0,3 s : pas encore")
	assert_signal_not_emitted(EventBus, "verdict_stamped")
	assert_gt(deny.hold_progress, 0.7)
	assert_true(deny.advance(0.11), "0,41 s : tampon posé")
	assert_signal_emit_count(EventBus, "verdict_stamped", 1)
	var verdict: Verdict = get_signal_parameters(EventBus, "verdict_stamped")[0]
	assert_eq(verdict.case_id, case.case_id)
	assert_eq(verdict.kind, VerdictKind.Kind.DENY)
	assert_eq(verdict.flagged.size(), 1, "discordance épinglée transmise")
	assert_true(verdict.questions_asked.has(&"about_expired:entry_permit"))
	assert_true(ui.stamps_locked(), "un seul verdict par cas")
	assert_false(ui.inspection_active)


func test_releasing_early_cancels_the_stamp() -> void:
	_present_case()
	watch_signals(EventBus)
	var approve: StampButton = ui.get_stamp_button(VerdictKind.Kind.APPROVE)
	approve.begin_hold()
	approve.advance(0.3)
	approve.end_hold()
	assert_eq(approve.hold_progress, 0.0)
	approve.advance(0.3)
	assert_signal_not_emitted(EventBus, "verdict_stamped")


func test_detain_stamp_only_when_day_allows_it() -> void:
	assert_false(ui.detain_available, "J3 : pas de DÉTENTION")
	assert_false(ui.get_stamp_button(VerdictKind.Kind.DETAIN).visible)
	# M7 (D-055) : une règle de sévérité 3 ne suffit pas, le jour doit l'autoriser.
	var rs: RuleSet = RuleSet.new()
	var severe: Rule = CaseFactory.rule(&"r_portrait_match").duplicate() as Rule
	severe.severity = RuleEngine.DETAIN_SEVERITY
	rs.rules.append(severe)
	var detain_day: DayDef = day.duplicate() as DayDef
	detain_day.rule_set = rs
	EventBus.day_started.emit(detain_day, rs.build_rulebook())
	assert_false(ui.detain_available, "detain_enabled faux : verrouillé")
	detain_day.detain_enabled = true
	EventBus.day_started.emit(detain_day, rs.build_rulebook())
	assert_true(ui.detain_available)
	assert_true(ui.get_stamp_button(VerdictKind.Kind.DETAIN).visible)


func test_next_case_only_when_waiting_and_debounced() -> void:
	watch_signals(EventBus)
	ui.request_next_case()
	ui.request_next_case()
	assert_signal_emit_count(EventBus, "next_case_requested", 1, "anti-rebond")
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, &"x")
	ui._next_cooldown = 0.0
	ui.request_next_case()
	assert_signal_emit_count(EventBus, "next_case_requested", 1, "ignoré hors WAITING_CASE")


# ---------------------------------------------------------------------------
# Sélection pure, textes, thème
# ---------------------------------------------------------------------------

func test_inspection_selection_pure_logic() -> void:
	var selection: InspectionSelection = InspectionSelection.new()
	var a: FieldRef = FieldRef.new(&"id_card", &"family_name")
	var b: FieldRef = FieldRef.new(&"entry_permit", &"family_name")
	assert_eq(selection.select(a), InspectionSelection.Action.IGNORED, "mode inactif")
	selection.set_active(true)
	assert_eq(selection.select(a), InspectionSelection.Action.SELECTED_A)
	assert_eq(selection.select(b), InspectionSelection.Action.REQUESTED)
	var incomparable: Discrepancy = Discrepancy.new(b, a).set_result(Discrepancy.Result.INCOMPARABLE, Discrepancy.REASON_INCOMPARABLE)
	assert_true(selection.receive(incomparable))
	assert_false(selection.is_requested(a, b), "une paire incomparable peut être retentée")
	assert_false(selection.receive(Discrepancy.new(a, FieldRef.today())), "résultat non demandé")
	assert_eq(InspectionSelection.pair_key(a, b), InspectionSelection.pair_key(b, a))


func test_french_translation_is_loaded() -> void:
	assert_eq(UiText.t("doc_id_card_title"), "Carte d'identité")
	assert_eq(UiText.t("field_family_name"), "Nom")
	assert_eq(UiText.t("clé_absente", "repli"), "repli")
	assert_eq(UiText.t("clé_absente"), "clé_absente", "sans repli : la clé")


func test_every_data_key_has_a_translation() -> void:
	var missing: PackedStringArray = []
	var catalog: DataCatalog = CaseFactory.catalog()
	for def: DocumentTypeDef in catalog.documents.values():
		if not UiText.has(def.title_key):
			missing.append(def.title_key)
		for field: FieldDef in def.fields:
			if not UiText.has(field.label_key):
				missing.append(field.label_key)
	for rule: Rule in catalog.rules.values():
		for key: String in [rule.title_key, rule.rulebook_text_key]:
			if not UiText.has(key):
				missing.append(key)
	for reason: String in [Discrepancy.REASON_EXPIRED, Discrepancy.REASON_MISMATCH, Discrepancy.REASON_FACE_MISMATCH,
			Discrepancy.REASON_FACE_MASKED, Discrepancy.REASON_RULE_VIOLATED, Discrepancy.REASON_INCOMPARABLE]:
		if not UiText.has(reason):
			missing.append(reason)
	assert_eq(missing, PackedStringArray(), "clés sans traduction FR")


func test_value_text_formats_by_kind() -> void:
	var def: DocumentTypeDef = CaseFactory.doc_def(CaseFactory.PERMIT)
	assert_eq(UiText.value_text(def.get_field(&"purpose"), &"work"), "TRAVAIL")
	assert_eq(UiText.value_text(def.get_field(&"expiry_date"), GameDate.from_ymd(2187, 3, 14)), "14.03.2187")
	assert_eq(UiText.value_text(def.get_field(&"stay_days"), 30), "30 JOURS")
	assert_eq(UiText.weekday(GameDate.from_ymd(2187, 3, 13)), 1, "13.03.2187 = mardi (LORE)")
	assert_eq(UiText.weekday(GameDate.from_ymd(2187, 3, 19)), 0, "19.03.2187 = lundi (LORE)")
	assert_eq(UiText.clock(UiText.shift_minutes(0.0, 600.0)), "18:00")
	assert_eq(UiText.clock(UiText.shift_minutes(600.0, 600.0)), "10:00")


func test_theme_scales_text_only() -> void:
	var base: Theme = ThemeBuilder.build(1.0)
	var large: Theme = ThemeBuilder.build(1.5)
	assert_eq(base.get_font_size(&"font_size", &"DocFieldValue"), DS.FS_DATA)
	assert_eq(large.get_font_size(&"font_size", &"DocFieldValue"), roundi(DS.FS_DATA * 1.5))
	assert_eq(large.default_font_size, roundi(DS.FS_BODY * 1.5))
	for variation: StringName in [&"DocTitle", &"DataSmall", &"TimerCompact", &"ToggleTab", &"ButtonTool", &"RuleCardNew", &"VeilPanel"]:
		assert_true(base.is_type_variation(variation, base.get_type_variation_base(variation)), "variation %s" % variation)
