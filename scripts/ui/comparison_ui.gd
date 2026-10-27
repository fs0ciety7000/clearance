## Interface de comparaison (jalon M4, UI_FLOW §2–§4) — surcouche 2D plein
## écran 1920×1080 au-dessus de la vue 3D du guichet.
##
## Contrat d'intégration :
## - la bande B (y 56 → 432) reste **transparente et `MOUSE_FILTER_IGNORE`** :
##   l'intégrateur y place le SubViewport 3D en dessous ; seuls la bulle
##   passager (gauche), les compteurs (droite), les sous-titres (bas de la
##   bande), les toasts et le cadre « VISAGE » y sont dessinés ;
## - l'UI ne connaît que l'`EventBus` et `Case` / `DocumentInstance` /
##   `FieldRef` / `Discrepancy` / `RulebookEntry` (jamais `CaseKey`) ;
## - `portrait_provider(appearance: PassengerAppearance) -> Texture2D` (photo
##   des documents, placeholder vectoriel si invalide ou null) et
##   `face_rect_provider() -> Rect2` (rectangle global du visage dans la bande B,
##   pour le cadre « VISAGE » et l'ancrage des liens) sont renseignés par
##   l'intégrateur.
class_name ComparisonUI
extends Control

# --- Zones (UI_FLOW §2.2, px @1080p) -------------------------------------------
const BAND_TOP: float = 56.0
const BAND_BOTTOM: float = 432.0
const TOOLBAR_H: float = 96.0
const WORKBENCH_RIGHT_GAP: float = 464.0 # 1920 − 1456
const RULEBOOK_WIDTH: float = 440.0
const SIDE_PANEL_WIDTH: float = 456.0
const QUEUE_PANEL_WIDTH: float = 440.0
## Visage par défaut (centre de la vitre) tant que l'intégrateur n'a rien fourni.
const DEFAULT_FACE_RECT: Rect2 = Rect2(880, 112, 160, 196)

## Photo des documents : `func(appearance: PassengerAppearance) -> Texture2D`.
var portrait_provider: Callable = Callable()
## Visage du passager : `func() -> Rect2` (coordonnées globales).
var face_rect_provider: Callable = Callable()

# --- État -------------------------------------------------------------------------
var day: DayDef = null
var rulebook_entries: Array[RulebookEntry] = []
var current_case: Case = null
var phase: DayPhase.Kind = DayPhase.Kind.INTRO
var documents_shown: bool = false
var verdict_sent: bool = false
var inspection_active: bool = false
var question_menu_open: bool = false
var processed: int = 0
var remaining_sec: float = 0.0
var elapsed_sec: float = 0.0
var selection: InspectionSelection = InspectionSelection.new()
## Discordances confirmées dans l'ordre (numéro = index + 1).
var discrepancies: Array[Discrepancy] = []
var unlocked_topics: Array[StringName] = []
var asked_topics: Array[StringName] = []
var detain_available: bool = false
var fx_intensity: float = 1.0
var reduce_motion: bool = false

# --- Nœuds ------------------------------------------------------------------------
var top_bar: TopBar = null
var workbench: Workbench = null
var rulebook: RulebookPanel = null
var tool_bar: ToolBar = null
var passenger_panel: PassengerPanel = null
var queue_panel: QueuePanel = null
var subtitles: SubtitleBar = null
var toasts: ToastStack = null
var links: LinkLayer = null
var _veil: ColorRect = null
var _next_cooldown: float = 0.0
var _menu_items: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_settings()
	theme = ThemeBuilder.build(_text_scale())
	_build()
	_connect_bus()
	_refresh_all()


func _read_settings() -> void:
	fx_intensity = Settings.fx_intensity
	reduce_motion = Settings.reduce_motion


func _text_scale() -> float:
	return Settings.text_scale


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	# Voile de la vue 3D en Mode Inspection (bg.void 8 %, UI_FLOW §3.4).
	_veil = ColorRect.new()
	_veil.name = "InspectionVeil"
	_veil.color = DS.INSPECTION_VEIL
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.anchor_right = 1.0
	_veil.offset_top = BAND_TOP
	_veil.offset_bottom = BAND_BOTTOM
	_veil.visible = false
	add_child(_veil)

	workbench = Workbench.new()
	workbench.name = "Workbench"
	workbench.anchor_right = 1.0
	workbench.anchor_bottom = 1.0
	workbench.offset_top = BAND_BOTTOM
	workbench.offset_right = -WORKBENCH_RIGHT_GAP
	workbench.offset_bottom = -TOOLBAR_H
	workbench.reduce_motion = reduce_motion
	workbench.fx_intensity = fx_intensity
	add_child(workbench)
	workbench.field_picked.connect(_on_item_picked)
	workbench.document_focused.connect(_on_document_focused)
	workbench.background_clicked.connect(_on_background_clicked)

	rulebook = RulebookPanel.new()
	rulebook.name = "Rulebook"
	rulebook.anchor_left = 1.0
	rulebook.anchor_right = 1.0
	rulebook.anchor_bottom = 1.0
	rulebook.offset_left = -(RULEBOOK_WIDTH + DS.SPACE_4)
	rulebook.offset_right = -DS.SPACE_4
	rulebook.offset_top = BAND_BOTTOM + DS.SPACE_2
	rulebook.offset_bottom = -(TOOLBAR_H + DS.SPACE_2)
	add_child(rulebook)
	rulebook.item_picked.connect(_on_item_picked)
	rulebook.collapse_changed.connect(_on_rulebook_collapsed)

	top_bar = TopBar.new()
	top_bar.name = "TopBar"
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = BAND_TOP
	add_child(top_bar)

	passenger_panel = PassengerPanel.new()
	passenger_panel.name = "PassengerPanel"
	passenger_panel.position = Vector2(DS.SPACE_8, BAND_TOP + DS.SPACE_6)
	passenger_panel.custom_minimum_size.x = SIDE_PANEL_WIDTH
	passenger_panel.size.x = SIDE_PANEL_WIDTH
	add_child(passenger_panel)
	passenger_panel.question_chosen.connect(ask)

	queue_panel = QueuePanel.new()
	queue_panel.name = "QueuePanel"
	queue_panel.anchor_left = 1.0
	queue_panel.anchor_right = 1.0
	queue_panel.offset_left = -(QUEUE_PANEL_WIDTH + DS.SPACE_8)
	queue_panel.offset_right = -DS.SPACE_8
	queue_panel.offset_top = BAND_TOP + DS.SPACE_6
	add_child(queue_panel)

	subtitles = SubtitleBar.new()
	subtitles.name = "Subtitles"
	subtitles.anchor_left = 0.5
	subtitles.anchor_right = 0.5
	subtitles.grow_horizontal = Control.GROW_DIRECTION_BOTH
	subtitles.grow_vertical = Control.GROW_DIRECTION_BEGIN
	subtitles.offset_top = BAND_BOTTOM - DS.SPACE_10
	subtitles.offset_bottom = BAND_BOTTOM - DS.SPACE_10
	subtitles.enabled = Settings.subtitles
	add_child(subtitles)

	tool_bar = ToolBar.new()
	tool_bar.name = "ToolBar"
	tool_bar.anchor_top = 1.0
	tool_bar.anchor_right = 1.0
	tool_bar.anchor_bottom = 1.0
	tool_bar.offset_top = -TOOLBAR_H
	add_child(tool_bar)
	tool_bar.inspection_toggled.connect(set_inspection_active)
	tool_bar.interrogate_pressed.connect(toggle_question_menu)
	tool_bar.next_pressed.connect(request_next_case)
	tool_bar.stamped.connect(_on_stamped)
	tool_bar.set_fx_intensity(fx_intensity)

	links = LinkLayer.new()
	links.name = "Links"
	links.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	links.rect_provider = _rect_of
	links.fx_intensity = fx_intensity
	links.reduce_motion = reduce_motion
	links.face_label = UiText.t("face_label", "VISAGE")
	add_child(links)

	toasts = ToastStack.new()
	toasts.name = "Toasts"
	toasts.anchor_left = 1.0
	toasts.anchor_right = 1.0
	toasts.offset_left = -(QUEUE_PANEL_WIDTH + DS.SPACE_8)
	toasts.offset_right = -DS.SPACE_8
	toasts.offset_top = BAND_TOP + DS.SPACE_6 + 132.0
	add_child(toasts)


func _connect_bus() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.day_clock_ticked.connect(_on_day_clock_ticked)
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.discrepancy_checked.connect(_on_discrepancy_checked)
	EventBus.interrogation_answered.connect(_on_interrogation_answered)
	EventBus.case_resolved.connect(_on_case_resolved)
	EventBus.citation_issued.connect(_on_citation_issued)
	EventBus.passenger_reaction_triggered.connect(_on_reaction)
	EventBus.inspection_target_picked.connect(_on_inspection_target_picked)
	EventBus.credits_changed.connect(_on_credits_changed)
	EventBus.settings_changed.connect(_on_settings_changed)


# ---------------------------------------------------------------------------
# Signaux de la logique
# ---------------------------------------------------------------------------

func _on_day_started(p_day: DayDef, p_rulebook: Array[RulebookEntry]) -> void:
	day = p_day
	rulebook_entries = p_rulebook.duplicate()
	processed = 0
	remaining_sec = p_day.duration_sec
	detain_available = false
	if p_day.rule_set != null:
		for rule: Rule in p_day.rule_set.rules:
			detain_available = detain_available or (rule != null and rule.severity >= RuleEngine.DETAIN_SEVERITY)
	rulebook.set_rulebook(rulebook_entries, p_day.game_date, p_day.day_number)
	top_bar.set_day(p_day.day_number, p_day.game_date)
	top_bar.set_clock(remaining_sec, p_day.duration_sec)
	top_bar.set_processed(processed)
	top_bar.set_credits(GameState.credits)
	tool_bar.set_detain_available(detain_available)
	_refresh_all()


func _on_day_phase_changed(p_phase: DayPhase.Kind, case_id: StringName) -> void:
	phase = p_phase
	if p_phase == DayPhase.Kind.WAITING_CASE:
		if current_case != null and (case_id == &"" or case_id != current_case.case_id or verdict_sent):
			_end_case(true)
	elif p_phase == DayPhase.Kind.DEPARTING and documents_shown:
		_return_documents()
	_refresh_all()


func _on_day_clock_ticked(p_remaining: float) -> void:
	remaining_sec = p_remaining
	if day != null:
		top_bar.set_clock(p_remaining, day.duration_sec)


func _on_case_presented(case: Case) -> void:
	_end_case(false)
	current_case = case
	documents_shown = false
	verdict_sent = false
	elapsed_sec = 0.0
	var bark: String = UiText.t("bark_arrival", "Bonsoir… J'arrive, j'arrive.")
	passenger_panel.set_line(bark)
	subtitles.show_line(UiText.passenger_number(case), bark, UiText.t("tag_footsteps", "[pas mouillés]"))
	workbench.set_empty_state(UiText.t("wb_empty_title", "EN ATTENTE DES DOCUMENTS"),
			UiText.t("wb_empty_arriving", "Ils glisseront par la fente de la vitre à l'arrivée du passager. En attendant : Tab · Rulebook."))
	_refresh_all()


func _on_documents_presented(case_id: StringName) -> void:
	if current_case == null or case_id != current_case.case_id or documents_shown:
		return
	documents_shown = true
	elapsed_sec = 0.0
	workbench.present(current_case.documents, portrait_provider)
	var line: String = UiText.t("bark_present", "Voici mes papiers…")
	passenger_panel.set_line(line)
	passenger_panel.set_hint("")
	subtitles.show_line(_speaker_name(), line)
	_refresh_all()


func _on_discrepancy_checked(result: Discrepancy) -> void:
	if not selection.receive(result):
		return
	var item_a: InspectableItem = _find_item(result.a)
	var item_b: InspectableItem = _find_item(result.b)
	match result.result:
		Discrepancy.Result.DISCORDANT:
			discrepancies.append(result)
			var number: int = discrepancies.size()
			links.resolve(result, number)
			for item: InspectableItem in [item_a, item_b]:
				if item != null:
					item.add_flag(number)
					_pulse_item(item)
			_flag_face(result)
			_refresh_doc_flags()
			var topic: StringName = InterrogationTopics.topic_for(result)
			if topic != &"" and not unlocked_topics.has(topic) and not asked_topics.has(topic):
				unlocked_topics.append(topic)
			workbench.show_banner(Workbench.BannerKind.DISCORDANT,
					UiText.tf("res_discordance", [number], "DISCORDANCE %d"), describe(result))
		Discrepancy.Result.CONCORDANT:
			links.resolve(result, 0)
			for item: InspectableItem in [item_a, item_b]:
				if item != null:
					item.set_concordant(true)
					get_tree().create_timer(DS.CONCORDANT_HOLD + DS.DUR_BASE).timeout.connect(_unmark_concordant.bind(item))
			workbench.show_banner(Workbench.BannerKind.CONCORDANT, UiText.t("res_concordant", "CONCORDANT"), describe(result), DS.CONCORDANT_HOLD)
		_:
			links.resolve(result, 0)
			# A est conservé (UI_FLOW §3.2 « Incomparable → ChampA »).
			if inspection_active and selection.last_a != null and selection.last_a.equals(result.a):
				_select_a(result.a)
			workbench.show_banner(Workbench.BannerKind.INCOMPARABLE, UiText.t("res_incomparable", "INCOMPARABLE"), describe(result),
					DS.INCOMPARABLE_HOLD + DS.SUBTITLE_MIN_HOLD)
	_refresh_all()


func _on_interrogation_answered(topic: StringName, line_key: String) -> void:
	var text: String = UiText.t(line_key, line_key)
	passenger_panel.set_line(text)
	subtitles.show_line(_speaker_name(), text)
	if topic == InterrogationTopics.REMOVE_VISOR:
		_refresh_face()
	_refresh_all()


func _on_reaction(reaction: PassengerReaction.Kind) -> void:
	var name_key: String = str(PassengerReaction.Kind.find_key(reaction)).to_lower()
	var feminine: bool = current_case != null and current_case.passenger_presented != null \
			and current_case.passenger_presented.sex == Passenger.SEX_F
	var tag: String = UiText.t("tag_%s%s" % [name_key, "_f" if feminine else ""], UiText.t("tag_" + name_key, "[%s]" % name_key))
	var line: String = UiText.t("react_" + name_key, "")
	if not line.is_empty():
		subtitles.show_line(_speaker_name(), line, tag)
		passenger_panel.set_line(line)
	passenger_panel.set_hint(tag)


func _on_inspection_target_picked(ref: FieldRef) -> void:
	if not _inspection_allowed():
		return
	if not inspection_active:
		set_inspection_active(true)
	pick(ref)


func _on_case_resolved(case_id: StringName, result: CaseResult) -> void:
	if current_case == null or case_id != current_case.case_id:
		return
	processed += 1
	top_bar.set_processed(processed)
	_show_result(result)
	_return_documents()
	_refresh_all()


func _on_citation_issued(reason_key: String) -> void:
	var reason: String = UiText.t(reason_key, reason_key)
	toasts.push_citation(reason, UiText.t("cit_warning", "AVERTISSEMENT"), true)


func _on_credits_changed(credits: int, _delta: int) -> void:
	top_bar.set_credits(credits)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	match key:
		Settings.KEY_TEXT_SCALE:
			var text_scale: float = value
			theme = ThemeBuilder.build(text_scale)
		Settings.KEY_FX_INTENSITY:
			fx_intensity = value
			workbench.set_fx_intensity(fx_intensity)
			links.fx_intensity = fx_intensity
			tool_bar.set_fx_intensity(fx_intensity)
		Settings.KEY_REDUCE_MOTION:
			reduce_motion = value
			workbench.reduce_motion = reduce_motion
			links.reduce_motion = reduce_motion
		Settings.KEY_SUBTITLES:
			subtitles.enabled = value


# ---------------------------------------------------------------------------
# Actions du joueur (API publique : boutons, raccourcis, démo, tests)
# ---------------------------------------------------------------------------

## Vrai si le Mode Inspection peut être activé (documents posés, cas ouvert).
func _inspection_allowed() -> bool:
	return documents_shown and phase == DayPhase.Kind.INSPECTING and not verdict_sent


func stamps_locked() -> bool:
	return not _inspection_allowed()


func set_inspection_active(enabled: bool) -> void:
	enabled = enabled and _inspection_allowed()
	if enabled == inspection_active:
		tool_bar.set_inspection_pressed(enabled)
		return
	inspection_active = enabled
	selection.set_active(enabled)
	_clear_selected_marks()
	workbench.set_inspection_active(enabled)
	rulebook.set_inspection_active(enabled)
	if enabled and rulebook.collapsed:
		rulebook.set_collapsed(false)
	links.inspection_active = enabled
	links.pending_a = null
	_veil.visible = enabled
	tool_bar.set_inspection_pressed(enabled)
	EventBus.inspection_mode_changed.emit(enabled)
	_refresh_face()
	_refresh_all()


func toggle_inspection() -> void:
	set_inspection_active(not inspection_active)


## Sélectionne `ref` comme champ A ou B (clic, Entrée, visage 3D).
func pick(ref: FieldRef) -> InspectionSelection.Action:
	if current_case == null:
		return InspectionSelection.Action.IGNORED
	var previous_a: FieldRef = selection.a
	var action: InspectionSelection.Action = selection.select(ref)
	match action:
		InspectionSelection.Action.SELECTED_A, InspectionSelection.Action.REPLACED_A:
			_clear_selected_marks()
			_select_a(ref)
		InspectionSelection.Action.DESELECTED:
			_clear_selected_marks()
		InspectionSelection.Action.REQUESTED:
			_clear_selected_marks()
			links.add_evaluating(previous_a, ref)
			EventBus.discrepancy_check_requested.emit(previous_a, ref)
		InspectionSelection.Action.ALREADY_DONE:
			_clear_selected_marks()
			links.pulse_link(previous_a, ref)
			for item: InspectableItem in [_find_item(previous_a), _find_item(ref)]:
				if item != null:
					_pulse_item(item)
	links.pending_a = selection.a
	_refresh_face()
	return action


## Échap / Ⓑ / clic droit : annule A, sinon ferme le menu, sinon quitte le mode.
func cancel() -> void:
	if question_menu_open:
		close_question_menu()
	elif selection.cancel():
		_clear_selected_marks()
		links.pending_a = null
		_refresh_face()
	elif inspection_active:
		set_inspection_active(false)


func request_next_case() -> void:
	if phase != DayPhase.Kind.WAITING_CASE or _next_cooldown > 0.0:
		return
	_next_cooldown = DS.NEXT_DEBOUNCE
	EventBus.next_case_requested.emit()


## Sujets proposés au menu d'interrogatoire, dans l'ordre d'affichage.
func available_topics() -> Array[StringName]:
	var topics: Array[StringName] = []
	if current_case == null or not documents_shown:
		return topics
	for topic: StringName in unlocked_topics:
		topics.append(topic)
	if _face_covered() and not asked_topics.has(InterrogationTopics.REMOVE_VISOR):
		topics.append(InterrogationTopics.REMOVE_VISOR)
	for topic: StringName in InterrogationTopics.BASE:
		topics.append(topic)
	return topics


func toggle_question_menu() -> void:
	if question_menu_open:
		close_question_menu()
	else:
		open_question_menu()


func open_question_menu() -> void:
	if not _inspection_allowed():
		return
	question_menu_open = true
	_menu_items.clear()
	for topic: StringName in available_topics():
		_menu_items.append({
			"topic": topic,
			"text": InterrogationTopics.question_text(topic, current_case),
			"unlocked": unlocked_topics.has(topic),
			"asked": asked_topics.has(topic),
		})
	passenger_panel.show_menu(_menu_items)


func close_question_menu() -> void:
	question_menu_open = false
	_refresh_questions()


## Pose une question : `interrogation_requested(topic)`.
func ask(topic: StringName) -> void:
	if not _inspection_allowed() or topic == &"":
		return
	EventBus.interrogation_requested.emit(topic)
	if not asked_topics.has(topic):
		asked_topics.append(topic)
	unlocked_topics.erase(topic)
	var question: String = InterrogationTopics.question_text(topic, current_case)
	subtitles.show_line(UiText.t("speaker_agent", "AGENT"), question)
	passenger_panel.set_hint(UiText.t("speaker_agent", "AGENT") + " : « " + question + " »")
	question_menu_open = false
	_refresh_all()


func get_stamp_button(kind: VerdictKind.Kind) -> StampButton:
	return tool_bar.stamps.get(kind, null)


# ---------------------------------------------------------------------------
# Verdict, fin de cas
# ---------------------------------------------------------------------------

func _on_stamped(kind: VerdictKind.Kind) -> void:
	if stamps_locked() or current_case == null:
		return
	if kind == VerdictKind.Kind.DETAIN and not detain_available:
		return
	var verdict: Verdict = Verdict.new(current_case.case_id, kind)
	verdict.flagged = discrepancies.duplicate()
	verdict.questions_asked = asked_topics.duplicate()
	verdict.elapsed_sec = elapsed_sec
	verdict_sent = true
	set_inspection_active(false)
	close_question_menu()
	var caption: String = UiText.tf("stamp_caption", [day.day_number if day != null else 0], "CONSORTIUM · G04 · J%02d")
	workbench.show_stamp(kind, caption, current_case.case_seed)
	EventBus.verdict_stamped.emit(verdict)
	_refresh_all()


## Retour de verdict (toast). L'avis d'infraction vient de `citation_issued`.
func _show_result(result: CaseResult) -> void:
	if result == null:
		return
	var verdict_name: String = StampMark.label_of(result.verdict_kind)
	var side: String = ("+%d ₵" if result.credits_delta >= 0 else "%d ₵") % result.credits_delta
	var message: String = UiText.tf("res_case_detail", [verdict_name], "Tampon %s")
	if not result.correct and not result.missed_violations.is_empty():
		message += " · " + UiText.tf("res_missed", [result.missed_violations.size()], "%d infraction(s) non relevée(s)")
	if result.correct:
		toasts.push(ToastStack.Kind.SUCCESS, UiText.t("res_case_ok", "Dossier conforme"), message, side)
	else:
		toasts.push(ToastStack.Kind.ERROR, UiText.t("res_case_error", "Erreur de contrôle"), message, side)


## Documents rendus par la fente (DEPARTING / `case_resolved`).
func _return_documents() -> void:
	if not documents_shown:
		return
	documents_shown = false
	workbench.clear(true)
	workbench.set_empty_state(UiText.t("wb_returned_title", "DOCUMENTS RENDUS"),
			UiText.t("wb_returned_text", "Le passager quitte le guichet. « Suivant » se réactive à son départ."))
	links.clear()
	_clear_rulebook_marks()
	set_inspection_active(false)
	_refresh_all()


func _clear_rulebook_marks() -> void:
	for item: InspectableItem in rulebook.get_items():
		item.clear_marks()


## Oublie le cas courant (nouveau cas, ou retour au guichet vide).
func _end_case(animated: bool) -> void:
	if documents_shown:
		workbench.clear(animated)
	documents_shown = false
	selection.reset()
	discrepancies.clear()
	unlocked_topics.clear()
	asked_topics.clear()
	question_menu_open = false
	links.clear()
	links.face_state = 0
	_clear_rulebook_marks()
	if inspection_active:
		set_inspection_active(false)
	if phase == DayPhase.Kind.WAITING_CASE:
		current_case = null
		passenger_panel.set_line("")
		workbench.set_empty_state(UiText.t("wb_empty_title", "EN ATTENTE DES DOCUMENTS"),
				UiText.t("wb_empty_waiting", "Appelez le passager suivant à l'intercom."))


# ---------------------------------------------------------------------------
# Rafraîchissements
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	if tool_bar == null:
		return
	var allowed: bool = _inspection_allowed()
	tool_bar.set_stamps_locked(not allowed)
	tool_bar.set_inspection_available(allowed)
	tool_bar.set_interrogate_available(allowed)
	tool_bar.set_unlocked_count(unlocked_topics.size() + (1 if allowed and _face_covered() and not asked_topics.has(InterrogationTopics.REMOVE_VISOR) else 0))
	workbench.set_inspection_available(allowed, UiText.t("wb_mode_verdict", "VERDICT TRANSMIS") if verdict_sent else "")
	match phase:
		DayPhase.Kind.WAITING_CASE:
			tool_bar.set_next_mode(&"ready")
		DayPhase.Kind.ARRIVING:
			tool_bar.set_next_mode(&"approaching")
		DayPhase.Kind.INSPECTING:
			tool_bar.set_next_mode(&"hidden" if documents_shown else &"approaching")
		DayPhase.Kind.RESOLVING, DayPhase.Kind.DEPARTING:
			tool_bar.set_next_mode(&"departing")
		_:
			tool_bar.set_next_mode(&"hidden")
	tool_bar.set_status(_status_text())
	_refresh_speaker()
	_refresh_queue()
	if not question_menu_open:
		_refresh_questions()


func _refresh_speaker() -> void:
	if current_case == null:
		passenger_panel.set_speaker(UiText.t("pp_idle", "GUICHET OUVERT · FILE D'ATTENTE"), false)
		passenger_panel.set_hint(UiText.t("pp_idle_hint", "Appuyez sur l'intercom (N) pour faire avancer le passager suivant."))
		return
	if documents_shown or verdict_sent:
		passenger_panel.set_speaker("%s · %s" % [UiText.passenger_number(current_case).get_slice(" ", 0), UiText.passenger_name(current_case)], true)
	else:
		passenger_panel.set_speaker("%s · %s" % [UiText.passenger_number(current_case), UiText.t("pp_unverified", "IDENTITÉ NON VÉRIFIÉE")], false)
		passenger_panel.set_hint(UiText.t("pp_arriving_hint", "Le passager s'approche du guichet. Ses documents glisseront par la fente de la vitre à son arrivée."))


func _refresh_queue() -> void:
	var total: int = day.passenger_count if day != null else 0
	queue_panel.set_queue(current_case.index + 1 if current_case != null else 0, total)
	if current_case == null:
		queue_panel.set_status(QueuePanel.Status.IDLE, 0)
	elif not documents_shown and not verdict_sent:
		queue_panel.set_status(QueuePanel.Status.APPROACHING, 0)
	else:
		queue_panel.set_status(QueuePanel.Status.INSPECTING, discrepancies.size())


func _refresh_questions() -> void:
	if passenger_panel == null:
		return
	var cards: Array[Dictionary] = []
	for d: Discrepancy in discrepancies:
		var topic: StringName = InterrogationTopics.topic_for(d)
		if unlocked_topics.has(topic):
			cards.append({"number": discrepancies.find(d) + 1, "text": InterrogationTopics.question_text(topic, current_case)})
	passenger_panel.show_unlocked(cards.slice(maxi(cards.size() - 2, 0)))
	if documents_shown and cards.is_empty() and _face_covered() and not asked_topics.has(InterrogationTopics.REMOVE_VISOR):
		passenger_panel.set_hint(UiText.t("pp_visor_hint", "Visage masqué : demandez le retrait de la visière (Q)."))


func _status_text() -> String:
	if current_case == null:
		return UiText.t("st_idle", "Guichet ouvert — appelez le passager suivant à l'intercom.")
	if verdict_sent:
		return UiText.t("st_verdict", "Verdict transmis — documents rendus par la fente.")
	if not documents_shown:
		return _bb(UiText.t("st_arriving_title", "◆ Passager en approche"), DS.STATE_AMBER) \
				+ UiText.t("st_arriving", " — lisez le Rulebook en attendant.\nTampons verrouillés jusqu'à la présentation des documents.")
	var count: int = discrepancies.size()
	if count > 0:
		var last: Discrepancy = discrepancies.back()
		var rule_part: String = ""
		var rule_number: int = _rule_number_of(last)
		if rule_number > 0:
			rule_part = UiText.tf("st_rule", [rule_number], " · règle %02d")
		if count == 1:
			return _bb(UiText.t("st_discordance_one_title", "⚠ 1 discordance"), DS.ACCENT_MAGENTA) \
					+ UiText.tf("st_discordance_one", [rule_part], " documentée%s · question débloquée.")
		return _bb(UiText.tf("st_discordances_title", [count], "⚠ %d discordances"), DS.ACCENT_MAGENTA) \
				+ UiText.tf("st_discordances", [rule_part], " documentées%s · questions débloquées.")
	if inspection_active:
		if selection.has_a():
			return UiText.t("st_pick_b", "Champ A sélectionné — choisissez le champ B (document, règle, date du jour ou visage). Échap : annuler.")
		return UiText.t("st_pick_a", "Mode Inspection — cliquez un premier champ à comparer.")
	return UiText.t("st_inspect", "Documents posés — Espace : Mode Inspection · maintenez V / X pour tamponner.")


func _describe_concordant(result: Discrepancy) -> String:
	if result.a.is_today() or result.b.is_today():
		var dated: FieldRef = result.b if result.a.is_today() else result.a
		var value: Variant = current_case.get_value(dated)
		var valid_text: String = "—"
		if value is int:
			var valid_days: int = value
			valid_text = UiText.date(valid_days)
		return UiText.tf("conc_valid_detail", [valid_text, UiText.date(day.game_date) if day != null else "—"],
				"Valide jusqu'au %s ≥ date du jour %s")
	if result.a.is_passenger_face() or result.b.is_passenger_face() or not result.a.is_document_field():
		return UiText.t("conc_generic", "Aucune discordance constatée.")
	var field: FieldDef = current_case.get_field_def(result.a)
	var shown: String = UiText.value_text(field, current_case.get_value(result.a))
	return UiText.tf("conc_detail", [UiText.field_label(field), shown, shown], "%s : %s = %s")


## « PERMIS D'ENTRÉE » → « Permis d'entrée ».
static func _sentence_case(text: String) -> String:
	var lower: String = text.to_lower()
	return lower.left(1).to_upper() + lower.substr(1)


## Texte BBCode gras dans une couleur sémantique `DS` (pas de hex en dur).
static func _bb(text: String, color: Color) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [color.to_html(false), text]


## Numéro (1-based) de la règle citée par une discordance, ou 0.
func _rule_number_of(result: Discrepancy) -> int:
	for ref: FieldRef in [result.a, result.b]:
		if ref != null and ref.is_rule():
			for i: int in rulebook_entries.size():
				if rulebook_entries[i].rule_id == ref.field_id:
					return i + 1
	return 0


func _speaker_name() -> String:
	if current_case == null:
		return ""
	if documents_shown or verdict_sent:
		return UiText.passenger_name(current_case)
	return UiText.passenger_number(current_case)


func _face_covered() -> bool:
	return current_case != null and current_case.passenger_presented != null \
			and current_case.passenger_presented.appearance != null \
			and current_case.passenger_presented.appearance.is_face_covered()


func _refresh_face() -> void:
	links.face_rect = _face_rect() if current_case != null and documents_shown else Rect2()
	links.face_masked = _face_covered()
	var flagged: bool = false
	for d: Discrepancy in discrepancies:
		flagged = flagged or (d.a != null and d.a.is_passenger_face()) or (d.b != null and d.b.is_passenger_face())
	if flagged:
		links.face_state = 2
	elif selection.a != null and selection.a.is_passenger_face():
		links.face_state = 1
	else:
		links.face_state = 0


func _flag_face(result: Discrepancy) -> void:
	if (result.a != null and result.a.is_passenger_face()) or (result.b != null and result.b.is_passenger_face()):
		links.face_state = 2


func _face_rect() -> Rect2:
	if face_rect_provider.is_valid():
		var provided: Variant = face_rect_provider.call()
		if provided is Rect2:
			return provided
	var xform: Transform2D = get_global_transform()
	return Rect2(xform * DEFAULT_FACE_RECT.position, DEFAULT_FACE_RECT.size * xform.get_scale())


func _refresh_doc_flags() -> void:
	for view: DocumentView in workbench.views:
		var count: int = 0
		for d: Discrepancy in discrepancies:
			if (d.a != null and d.a.document_id == view.get_document_id()) or (d.b != null and d.b.document_id == view.get_document_id()):
				count += 1
		view.flag_count = count


# ---------------------------------------------------------------------------
# Éléments sélectionnables
# ---------------------------------------------------------------------------

func _find_item(ref: FieldRef) -> InspectableItem:
	if ref == null or ref.is_passenger_face():
		return null
	if ref.document_id == FieldRef.RULEBOOK_DOCUMENT_ID:
		return rulebook.find_item(ref, true)
	return workbench.find_item(ref)


## Rectangle global d'une cible (liens) ; vide si invisible.
func _rect_of(ref: FieldRef) -> Rect2:
	if ref == null:
		return Rect2()
	if ref.is_passenger_face():
		return _face_rect()
	var item: InspectableItem = _find_item(ref)
	if item == null or not item.is_visible_in_tree():
		return Rect2()
	var rect: Rect2 = item.get_global_rect()
	if ref.document_id == FieldRef.RULEBOOK_DOCUMENT_ID and rulebook.collapsed:
		return Rect2()
	return rect


func _on_item_picked(item: InspectableItem) -> void:
	pick(item.ref)


func _on_background_clicked() -> void:
	if selection.cancel():
		_clear_selected_marks()
		links.pending_a = null
		_refresh_face()
		_refresh_all()


func _on_document_focused(doc: DocumentInstance) -> void:
	EventBus.document_focused.emit(doc)


func _on_rulebook_collapsed(collapsed: bool) -> void:
	var width: float = RulebookPanel.COLLAPSED_WIDTH if collapsed else RULEBOOK_WIDTH
	rulebook.offset_left = -(width + DS.SPACE_4)
	workbench.offset_right = -(width + DS.SPACE_4 * 2.0) if collapsed else -WORKBENCH_RIGHT_GAP


func _select_a(ref: FieldRef) -> void:
	var item: InspectableItem = _find_item(ref)
	if item != null:
		item.set_selected(true)
	selection.a = ref
	links.pending_a = ref
	_refresh_face()
	_refresh_all()


func _clear_selected_marks() -> void:
	for item: InspectableItem in workbench.get_items() + rulebook.get_items():
		if item.selected:
			item.set_selected(false)


func _unmark_concordant(item: InspectableItem) -> void:
	if is_instance_valid(item):
		item.set_concordant(false)


func _pulse_item(item: InspectableItem) -> void:
	if fx_intensity <= 0.0 or reduce_motion:
		return
	item.set_pulse(1.0)
	var tween: Tween = item.create_tween()
	tween.tween_method(item.set_pulse, 1.0, 0.0, DS.DUR_SLOW)


## Texte explicatif d'un résultat (« Permis d'entrée expiré : 14.03.2187 <
## date du jour 15.03.2187 »), construit à partir des seules valeurs visibles.
func describe(result: Discrepancy) -> String:
	if current_case == null:
		return UiText.t(result.reason_key, result.reason_key)
	if result.result == Discrepancy.Result.CONCORDANT:
		return _describe_concordant(result)
	match result.reason_key:
		Discrepancy.REASON_EXPIRED:
			var dated: FieldRef = result.b if result.a.is_today() else result.a
			var doc: DocumentInstance = current_case.get_document(dated.document_id)
			var expiry: Variant = current_case.get_value(dated)
			var today_text: String = UiText.date(day.game_date) if day != null else "—"
			var expiry_text: String = "—"
			if expiry is int:
				var expiry_days: int = expiry
				expiry_text = UiText.date(expiry_days)
			return UiText.tf("disc_expired_detail", [_sentence_case(UiText.document_title(doc.type_def)) if doc != null else "",
					expiry_text, today_text],
					"%s expiré : %s < date du jour %s")
		Discrepancy.REASON_MISMATCH:
			var field: FieldDef = current_case.get_field_def(result.a)
			var label: String = UiText.field_label(field)
			return UiText.tf("disc_mismatch_detail", [label, UiText.value_text(field, current_case.get_value(result.a)),
					UiText.value_text(current_case.get_field_def(result.b), current_case.get_value(result.b))], "%s : %s ≠ %s")
		Discrepancy.REASON_FACE_MISMATCH:
			var traits: PackedStringArray = []
			for slot: StringName in result.differing_traits:
				traits.append(UiText.t("trait_" + String(slot), String(slot)))
			return UiText.tf("disc_face_detail", [", ".join(traits)], "Visage ≠ photo : %s")
		Discrepancy.REASON_RULE_VIOLATED:
			var rule_ref: FieldRef = result.a if result.a.is_rule() else result.b
			var number: int = _rule_number_of(result)
			var title: String = String(rule_ref.field_id)
			for entry: RulebookEntry in rulebook_entries:
				if entry.rule_id == rule_ref.field_id:
					title = UiText.t(entry.title_key, title)
			return UiText.tf("disc_rule_detail", [number, title], "Règle %02d enfreinte — %s")
	return UiText.t(result.reason_key, result.reason_key)


# ---------------------------------------------------------------------------
# Entrées
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_next_cooldown = maxf(_next_cooldown - delta, 0.0)
	if documents_shown and not verdict_sent:
		elapsed_sec += delta


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"inspect_toggle", false, true):
		toggle_inspection()
		_handled()
	elif event.is_action_pressed(&"cancel", false, true):
		cancel()
		_handled()
	elif event.is_action_pressed(&"interrogate", false, true):
		toggle_question_menu()
		_handled()
	elif event.is_action_pressed(&"next_case", false, true) and phase == DayPhase.Kind.WAITING_CASE:
		request_next_case()
		_handled()
	elif event.is_action_pressed(&"rulebook_toggle", false, true) and not inspection_active:
		rulebook.set_collapsed(not rulebook.collapsed)
		_handled()
	elif event.is_action_pressed(&"inspect_face", false, true) and _inspection_allowed():
		_on_inspection_target_picked(FieldRef.passenger_face())
		_handled()
	elif event.is_action_pressed(&"rulebook_prev", false, true):
		rulebook.cycle_tab(-1)
		_handled()
	elif event.is_action_pressed(&"rulebook_next", false, true):
		rulebook.cycle_tab(1)
		_handled()
	else:
		_handle_stamp_input(event)
		_handle_question_keys(event)


func _handle_stamp_input(event: InputEvent) -> void:
	var actions: Dictionary[StringName, VerdictKind.Kind] = {
		&"stamp_approve": VerdictKind.Kind.APPROVE,
		&"stamp_deny": VerdictKind.Kind.DENY,
		&"stamp_detain": VerdictKind.Kind.DETAIN,
	}
	for action: StringName in actions:
		if not event.is_action(action, true) or event.is_echo():
			continue
		var button: StampButton = get_stamp_button(actions[action])
		if button == null or not button.visible:
			return
		if event.is_pressed():
			button.begin_hold()
		else:
			button.end_hold()
		_handled()
		return


func _handle_question_keys(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not question_menu_open or key == null or not key.pressed or key.echo:
		return
	var n: int = key.physical_keycode - KEY_0
	if n >= 1 and n <= PassengerPanel.MAX_QUESTIONS:
		var topic: StringName = passenger_panel.topic_at(n, _menu_items)
		if topic != &"":
			ask(topic)
			_handled()


func _handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()
