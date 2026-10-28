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
## M8 (Acte II, ARCHITECTURE §7.2) : compteur QUOTA de la barre d'état
## (`quota_changed`, sélectionnable), onglets Employeurs / Vaisseaux /
## Révocations du Rulebook (`revocations_published`), liens suggérés du scanner
## partiel (`scanner_suggested`, pointillés de la source, à confirmer d'un
## clic : `confirm_suggestion`), répliques lues par `Case.scripted_key`
## (variantes conditionnelles), étiquettes d'ambiance des accessoires
## (`companion_child`, `prop_*`) et figure finale du J20 (SC-50).
class_name ComparisonUI
extends Control

# --- Signaux publics (retours sonores, docs/AUDIO.md §4) ----------------------
## Survol (souris ou focus) d'un bouton actif de l'UI (`ui.hover`).
signal hovered(control: Control)
## Un toast vient d'apparaître (`ui.toast_*`).
signal toast_shown(kind: ToastStack.Kind)
## Réplique de départ du passager sous-titrée (`passenger.bark_depart`) :
## `bark_depart_ok` / `_denied` / `_detained` (ou réplique scénarisée).
signal departure_line_shown(line_key: String, text: String)
## M7 : réplique scénarisée hors interrogatoire sous-titrée (pot-de-vin, phrase
## de passe, réaction à l'enveloppe) — même chemin audio que le départ.
signal passenger_line_shown(line_key: String, text: String)

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
## M7 — codes Lucioles (LORE §7) et *lumika* (NARRATIVE B16).
const FLAG_LUMIKA: StringName = &"lumika_learned"
const LUMIKA_WORD: String = "lumika"
const UNKNOWN_WORD_FALLBACK: String = "[mot inconnu]"
## Présentation « trois tapes sur la vitre » (code 5).
const PRESENTATION_KNOCK: StringName = &"knock_three"
## Annonce du haut-parleur du Hall : durée minimale d'affichage.
const PA_MIN_HOLD: float = 6.0
## Acte II : étiquettes d'ambiance des accessoires (`Case.dialogue_tags`) →
## didascalie sous-titrée à l'arrivée (à la place des « pas mouillés »).
const PROP_TAGS: Dictionary[StringName, String] = {
	&"companion_child": "tag_companion_child",
	&"prop_cat_crate": "tag_prop_cat_crate",
	&"prop_drone": "tag_prop_drone",
	&"prop_shunt_led": "tag_prop_shunt_led",
}
## Acte II : figure finale du J20 (SC-50, D-079) — dialogue → voix (couleur).
const FINAL_FIGURES: Dictionary[StringName, String] = {&"sc50_ilan": "ilan", &"sc50_mira": "mira"}
## Grève du J20 : voile de la vue 3D et luminosité des panneaux.
const LIGHTS_OUT_BAND: float = 0.82
const LIGHTS_OUT_PANELS: float = 0.38
## Couleurs des sources du scanner partiel (ARCHITECTURE §7.2 : ambre / magenta).
const SCANNER_ACV: StringName = &"acv"
const SCANNER_LUCIOLE: StringName = &"luciole"

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
## M7 : objets glissés du cas courant (reçus par `item_slipped`).
var slipped_items: Array[SlippedItem] = []
## M7 : avis de recherche du jour (`wanted_notices_published`).
var wanted_notices: Array[WantedNotice] = []
## M7 : dernière annonce du Hall affichée (texte), vide sinon.
var announcement_text: String = ""
## Acte II : compteur du quota (`quota_changed`), révocations du jour.
var quota_used: int = 0
var quota_max: int = 0
var revocations: Array[RevokedEntry] = []
## Acte II : liens suggérés par le scanner partiel pour le cas courant
## (non encore confirmés) et leur source (`acv`, `luciole`).
var suggestions: Array[Discrepancy] = []
var scanner_source: StringName = &""
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
## M7 : bandeau discret du haut-parleur du Hall (haut de la bande B).
var pa_strip: PanelContainer = null
var _pa_label: Label = null
var _pa_serial: int = 0
## Acte II : pastilles « CONFIRMER » posées au milieu des liens suggérés.
var _suggestion_layer: Control = null
var _suggestion_buttons: Array[Button] = []
## Acte II : grève du J20, les vitres s'éteignent (voile sur la vue 3D, panneaux
## assombris ; seuls le haut-parleur et les sous-titres restent lisibles).
var lights_out: bool = false
var _lights_veil: ColorRect = null
var _veil: ColorRect = null
var _next_cooldown: float = 0.0
var _menu_items: Array[Dictionary] = []
var _applied_min_px: int = 0
## Dernier résultat reçu (`case_resolved`) : détail du ticket de citation.
var _last_result: CaseResult = null
## Réponse d'interrogatoire de cette image : la réaction émise juste après
## (NERVOUS / ANGRY) ne remplace pas la réplique, elle n'ajoute que l'étiquette.
var _answer_frame: int = -1
var _answer_text: String = ""
## Passager qui quitte le guichet (réplique de départ), null sinon.
var _departing_case: Case = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_read_settings()
	theme = ThemeBuilder.build(_text_scale(), _min_text_px())
	_applied_min_px = _min_text_px()
	_build()
	_connect_bus()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_wire_hover(self)
	get_tree().node_added.connect(_on_node_added)
	_refresh_all()


## Boutons créés plus tard (menu de questions, onglets…) : même branchement.
func _on_node_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node):
		_wire_button(node as BaseButton)


func _wire_hover(node: Node) -> void:
	if node is BaseButton:
		_wire_button(node as BaseButton)
	for child: Node in node.get_children():
		_wire_hover(child)


func _wire_button(button: BaseButton) -> void:
	if not button.mouse_entered.is_connected(_on_button_hovered):
		button.mouse_entered.connect(_on_button_hovered.bind(button))
		button.focus_entered.connect(_on_button_hovered.bind(button))


func _on_button_hovered(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.disabled and button.is_visible_in_tree():
		hovered.emit(button)


func _read_settings() -> void:
	fx_intensity = Settings.fx_intensity
	reduce_motion = Settings.reduce_motion


func _text_scale() -> float:
	return Settings.text_scale


## Plancher de taille de texte selon le facteur d'étirement de la fenêtre
## (`canvas_items` : 1280×800 → ×0,67, le texte passe à ≥ 18 px logiques).
func _min_text_px() -> int:
	if not is_inside_tree():
		return 0
	return ThemeBuilder.min_px_for(get_viewport().get_final_transform().get_scale().x)


func _rebuild_theme(text_scale: float) -> void:
	theme = ThemeBuilder.build(text_scale, _min_text_px())
	if tool_bar != null:
		tool_bar.refresh_fonts()


func _on_viewport_resized() -> void:
	var min_px: int = _min_text_px()
	if min_px != _applied_min_px:
		_applied_min_px = min_px
		_rebuild_theme(_text_scale())


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
	workbench.scanner_confirm_pressed.connect(func() -> void: confirm_suggestion())

	rulebook = RulebookPanel.new()
	rulebook.name = "Rulebook"
	rulebook.anchor_left = 1.0
	rulebook.anchor_right = 1.0
	rulebook.anchor_bottom = 1.0
	rulebook.offset_left = -(RULEBOOK_WIDTH + DS.SPACE_4)
	rulebook.offset_right = -DS.SPACE_4
	rulebook.grow_horizontal = Control.GROW_DIRECTION_BEGIN # jamais hors du bord droit (QA-009)
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
	top_bar.quota_view.picked.connect(_on_item_picked)

	passenger_panel = PassengerPanel.new()
	passenger_panel.name = "PassengerPanel"
	passenger_panel.position = Vector2(DS.SPACE_8, BAND_TOP + DS.SPACE_6)
	passenger_panel.custom_minimum_size.x = SIDE_PANEL_WIDTH
	passenger_panel.size.x = SIDE_PANEL_WIDTH
	add_child(BlurBackdrop.create(passenger_panel))
	add_child(passenger_panel)
	passenger_panel.question_chosen.connect(ask)

	queue_panel = QueuePanel.new()
	queue_panel.name = "QueuePanel"
	queue_panel.anchor_left = 1.0
	queue_panel.anchor_right = 1.0
	queue_panel.offset_left = -(QUEUE_PANEL_WIDTH + DS.SPACE_8)
	queue_panel.offset_right = -DS.SPACE_8
	queue_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	queue_panel.offset_top = BAND_TOP + DS.SPACE_6
	add_child(BlurBackdrop.create(queue_panel))
	add_child(queue_panel)

	_lights_veil = ColorRect.new()
	_lights_veil.name = "LightsOutVeil"
	_lights_veil.color = Color(DS.BG_VOID, 0.0)
	_lights_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lights_veil.anchor_right = 1.0
	_lights_veil.offset_top = BAND_TOP
	_lights_veil.offset_bottom = BAND_BOTTOM
	_lights_veil.visible = false
	add_child(_lights_veil)
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
	_build_pa_strip()

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
	_suggestion_layer = Control.new()
	_suggestion_layer.name = "ScannerSuggestions"
	_suggestion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_suggestion_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_suggestion_layer)

	toasts = ToastStack.new()
	toasts.name = "Toasts"
	toasts.anchor_left = 1.0
	toasts.anchor_right = 1.0
	toasts.offset_left = -(QUEUE_PANEL_WIDTH + DS.SPACE_8)
	toasts.offset_right = -DS.SPACE_8
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toasts.offset_top = BAND_TOP + DS.SPACE_6 + 132.0
	add_child(toasts)
	toasts.toast_shown.connect(func(kind: ToastStack.Kind) -> void: toast_shown.emit(kind))


## Bandeau du haut-parleur du Hall (M7, NARRATIVE I6) : sous-titre discret
## en haut de la vitre, voix du Consortium (jaune), hors bulle passager.
func _build_pa_strip() -> void:
	pa_strip = PanelContainer.new()
	pa_strip.name = "HallAnnouncement"
	pa_strip.theme_type_variation = &"SubtitlePanel"
	pa_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pa_strip.anchor_left = 0.5
	pa_strip.anchor_right = 0.5
	pa_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pa_strip.offset_top = BAND_TOP + DS.SPACE_3
	pa_strip.visible = false
	add_child(pa_strip)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SPACE_3)
	pa_strip.add_child(row)
	row.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.ACCENT_YELLOW, DS.ICON_S))
	var speaker: Label = Label.new()
	speaker.theme_type_variation = &"DocIssuer"
	speaker.uppercase = true
	speaker.add_theme_color_override(&"font_color", DS.ACCENT_YELLOW)
	speaker.text = UiText.t("spk_pa", "HAUT-PARLEUR · HALL")
	speaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(speaker)
	_pa_label = Label.new()
	_pa_label.theme_type_variation = &"BodySmall"
	_pa_label.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)
	_pa_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_pa_label)


func _connect_bus() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.wanted_notices_published.connect(_on_wanted_notices_published)
	EventBus.item_slipped.connect(_on_item_slipped)
	EventBus.item_decided.connect(_on_item_decided)
	EventBus.hall_announced.connect(_on_hall_announced)
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
	EventBus.quota_changed.connect(_on_quota_changed)
	EventBus.revocations_published.connect(_on_revocations_published)
	EventBus.scanner_suggested.connect(_on_scanner_suggested)


# ---------------------------------------------------------------------------
# Signaux de la logique
# ---------------------------------------------------------------------------

func _on_day_started(p_day: DayDef, p_rulebook: Array[RulebookEntry]) -> void:
	day = p_day
	rulebook_entries = p_rulebook.duplicate()
	processed = 0
	remaining_sec = p_day.duration_sec
	# DÉTENTION (« mise en attente ») seulement si le jour l'autorise (J7+, D-055).
	detain_available = p_day.detain_enabled
	wanted_notices.clear()
	revocations.clear()
	rulebook.quota_max = p_day.air_quota
	rulebook.set_rulebook(rulebook_entries, p_day.game_date, p_day.day_number, p_day.rulebook_tabs)
	top_bar.set_day(p_day.day_number, p_day.game_date)
	top_bar.set_clock(remaining_sec, p_day.duration_sec)
	top_bar.set_processed(processed)
	top_bar.set_credits(GameState.credits)
	tool_bar.set_detain_available(detain_available)
	_refresh_all()


func _on_day_phase_changed(p_phase: DayPhase.Kind, case_id: StringName) -> void:
	var previous: DayPhase.Kind = phase
	phase = p_phase
	if p_phase == DayPhase.Kind.INSPECTING and previous == DayPhase.Kind.ARRIVING and current_case != null \
			and case_id == current_case.case_id and current_case.presentation == PRESENTATION_KNOCK:
		# Code 5 : trois tapes sur la vitre avant les papiers (didascalie seule).
		subtitles.show_tag(UiText.passenger_number(current_case), UiText.t("tag_knock_three", "[trois tapes sur la vitre]"))
		passenger_panel.set_hint(UiText.t("tag_knock_three", "[trois tapes sur la vitre]"))
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
	_departing_case = null
	current_case = case
	documents_shown = false
	verdict_sent = false
	elapsed_sec = 0.0
	slipped_items.clear()
	suggestions.clear()
	_refresh_suggestion_buttons()
	var bark: String = arrival_text(case)
	passenger_panel.set_line(bark)
	passenger_panel.set_accent(final_figure_color(case))
	subtitles.show_line(UiText.passenger_number(case), bark, arrival_tag(case))
	workbench.set_empty_state(UiText.t("wb_empty_title", "EN ATTENTE DES DOCUMENTS"),
			UiText.t("wb_empty_arriving", "Ils glisseront par la fente de la vitre à l'arrivée du passager. En attendant : Tab · Rulebook."))
	_refresh_all()


func _on_documents_presented(case_id: StringName) -> void:
	if current_case == null or case_id != current_case.case_id or documents_shown:
		return
	documents_shown = true
	elapsed_sec = 0.0
	workbench.present(current_case.documents, portrait_provider)
	for item: SlippedItem in slipped_items:
		_show_slipped(item)
	_show_suggestions()
	var line: String = passenger_text(UiText.t(scripted_key(current_case, "present", "bark_present"), "Voici mes papiers…"))
	passenger_panel.set_line(line)
	# Mot glissé entre les documents (passager scénarisé, ex. SC-05 Lucioles).
	var note_key: String = scripted_key(current_case, "note", "")
	if not note_key.is_empty():
		toasts.push(ToastStack.Kind.NARRATIVE, UiText.t("note_title", "UN MOT GLISSÉ ENTRE LES PAPIERS"), UiText.t(note_key, ""))
	passenger_panel.set_hint("")
	subtitles.show_line(_speaker_name(), line)
	# Code 4 : phrase de passe dite spontanément, après les papiers.
	if current_case.dialogue_tags.has(CaseBuilder.TAG_LUCIOLE_PASSWORD):
		var password_key: String = scripted_key(current_case, "password", "line_password_generic")
		get_tree().create_timer(UiText.subtitle_hold(line)).timeout.connect(say_passenger_line.bind(current_case.case_id, password_key))
	_refresh_all()


# ---------------------------------------------------------------------------
# M7 : objets glissés, annonces, avis de recherche
# ---------------------------------------------------------------------------

func _on_item_slipped(item: SlippedItem) -> void:
	if item == null or current_case == null or item.case_id != current_case.case_id:
		return
	for known: SlippedItem in slipped_items:
		if known.id == item.id:
			return
	slipped_items.append(item)
	# Les documents peuvent être posés juste après (ordre des écouteurs) :
	# l'objet suit alors les documents (`_on_documents_presented`).
	if documents_shown:
		_show_slipped(item)


func _show_slipped(item: SlippedItem) -> void:
	if workbench.get_slipped_view(item.id) != null:
		return
	var view: SlippedItemView = SlippedItemView.create(item)
	view.name = "Slipped_%s" % item.id
	view.decision_requested.connect(request_item_decision)
	workbench.add_slipped_item(view)
	if item.kind == SlippedItem.Kind.ENVELOPE:
		var key: String = scripted_key(current_case, "bribe", "line_bribe_generic")
		get_tree().create_timer(DS.DUR_SLOW + DS.DOC_STAGGER * 3.0).timeout.connect(say_passenger_line.bind(item.case_id, key))
	_refresh_all()


## Intention du joueur sur un objet glissé (bouton GARDER / RENDRE / REMETTRE) :
## `item_decision_requested` ; ignoré hors inspection (verdict transmis).
func request_item_decision(item_id: StringName, decision: SlippedItem.Decision) -> bool:
	if not _inspection_allowed() or current_case == null:
		return false
	var item: SlippedItem = current_case.get_item(item_id)
	if item == null or not item.is_allowed(decision):
		return false
	EventBus.item_decision_requested.emit(item_id, decision)
	return true


func _on_item_decided(item: SlippedItem, decision: SlippedItem.Decision) -> void:
	if item == null:
		return
	var view: SlippedItemView = workbench.get_slipped_view(item.id)
	if view != null:
		view.set_decision(decision, verdict_sent)
	if verdict_sent or current_case == null or item.case_id != current_case.case_id:
		return
	if item.kind == SlippedItem.Kind.ENVELOPE:
		var suffix: String = "bribe_kept" if decision == SlippedItem.Decision.KEEP else "bribe_returned"
		say_passenger_line(item.case_id, scripted_key(current_case, suffix, "line_%s_generic" % suffix))
	if decision == SlippedItem.Decision.REPORT:
		toasts.push(ToastStack.Kind.INFO, UiText.t("wb_item_report_toast", "Objet remis à la Garde"),
				SlippedItemView.item_label(item), ScreenBase.credits(item.report_bonus, true) if item.report_bonus > 0 else "")
	_refresh_all()


## Réplique hors interrogatoire du passager courant (sous-titre + bulle) ;
## ignorée si le cas a changé entre-temps.
func say_passenger_line(case_id: StringName, key: String) -> void:
	if current_case == null or current_case.case_id != case_id or key.is_empty() or not UiText.has(key):
		return
	if verdict_sent and not key.contains("bribe_"):
		return # réplique différée devenue caduque (verdict posé entre-temps)
	var text: String = passenger_text(UiText.t(key, ""))
	if text.is_empty():
		return
	subtitles.show_line(_speaker_name(), text)
	passenger_panel.set_line(text)
	passenger_line_shown.emit(key, text)


func _on_hall_announced(text_key: String) -> void:
	show_announcement(UiText.t(text_key, text_key))


## Annonce du haut-parleur du Hall (sous-titre discret ; toast si les
## sous-titres sont désactivés : aucune information par le son seul).
func show_announcement(text: String) -> void:
	if text.is_empty():
		return
	announcement_text = text
	if not subtitles.enabled:
		toasts.push(ToastStack.Kind.INFO, UiText.t("spk_pa", "HAUT-PARLEUR · HALL"), text)
		return
	_pa_serial += 1
	var serial: int = _pa_serial
	_pa_label.text = text
	pa_strip.visible = true
	pa_strip.reset_size()
	pa_strip.modulate.a = 0.0
	var tween: Tween = pa_strip.create_tween()
	tween.tween_property(pa_strip, "modulate:a", 1.0, DS.DUR_BASE)
	get_tree().create_timer(maxf(PA_MIN_HOLD, UiText.subtitle_hold(text))).timeout.connect(_hide_announcement.bind(serial))


func _hide_announcement(serial: int) -> void:
	if serial != _pa_serial or not is_instance_valid(pa_strip):
		return
	var out: Tween = pa_strip.create_tween()
	out.tween_property(pa_strip, "modulate:a", 0.0, DS.DUR_SLOW)
	out.tween_callback(pa_strip.hide)


func _on_wanted_notices_published(notices: Array[WantedNotice]) -> void:
	wanted_notices = notices.duplicate()
	rulebook.set_wanted(wanted_notices, portrait_provider)


## Avis de recherche par identifiant (null si inconnu).
func find_notice(notice_id: StringName) -> WantedNotice:
	for notice: WantedNotice in wanted_notices:
		if notice.id == notice_id:
			return notice
	return null


# ---------------------------------------------------------------------------
# Acte II : quota, révocations, scanner partiel, accessoires, figure finale
# ---------------------------------------------------------------------------

## Les vitres s'éteignent (grève du J20, `DayScene.lights_out`) : la vue 3D
## passe sous un voile presque noir, les panneaux s'assombrissent ; le bandeau
## du haut-parleur et les sous-titres restent pleinement lisibles.
func set_lights_out(duration: float = DS.DUR_DRAMATIC) -> void:
	if lights_out:
		return
	lights_out = true
	_lights_veil.visible = true
	# La dernière annonce (« les vitres s'éteignent ») reste affichée dans le noir.
	if pa_strip.visible:
		_pa_serial += 1
	# Le fondu continue même si l'UI est désactivée par un écran plein cadre.
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_lights_veil, "color:a", LIGHTS_OUT_BAND, duration)
	for panel: Control in [workbench, rulebook, top_bar, tool_bar, passenger_panel, queue_panel, links, _suggestion_layer]:
		tween.tween_property(panel, "modulate", Color(LIGHTS_OUT_PANELS, LIGHTS_OUT_PANELS, LIGHTS_OUT_PANELS, 1.0), duration)


func _on_quota_changed(used: int, maximum: int) -> void:
	quota_used = used
	quota_max = maximum
	top_bar.set_quota(used, maximum)
	if rulebook.quota_max != maximum and maximum > 0:
		rulebook.quota_max = maximum
		rulebook.refresh_cards()


func _on_revocations_published(entries: Array[RevokedEntry]) -> void:
	revocations = entries.duplicate()
	rulebook.set_revoked(revocations)


## Révocation par identifiant (null si inconnue).
func find_revocation(entry_id: StringName) -> RevokedEntry:
	for entry: RevokedEntry in revocations:
		if entry.id == entry_id:
			return entry
	return null


## Couleur d'une source du scanner (ACV-2 ambre, boîtier des Lucioles magenta).
static func scanner_color(source: StringName) -> Color:
	return DS.ACCENT_MAGENTA if source == SCANNER_LUCIOLE else DS.STATE_AMBER


func _on_scanner_suggested(case_id: StringName, p_links: Array[Discrepancy], source: StringName) -> void:
	if current_case == null or case_id != current_case.case_id:
		return
	scanner_source = source
	suggestions.clear()
	for link: Discrepancy in p_links:
		if link != null and link.a != null and link.b != null:
			suggestions.append(link)
	# Les documents peuvent être posés juste après (ordre des écouteurs).
	if documents_shown:
		_show_suggestions()


## Trace les liens suggérés (pointillés) et la pastille de source du plan.
func _show_suggestions() -> void:
	if scanner_source == &"":
		workbench.set_scanner("", DS.TEXT_SECONDARY, 0)
		return
	var tint: Color = scanner_color(scanner_source)
	for link: Discrepancy in suggestions:
		if not selection.is_requested(link.a, link.b):
			links.add_suggested(link.a, link.b, tint)
	var label: String = UiText.t("wb_scanner_src_luciole", "BOÎTIER MAGENTA") if scanner_source == SCANNER_LUCIOLE \
			else UiText.t("wb_scanner_src_acv", "ACV-2 · CONSORTIUM")
	workbench.set_scanner(label, tint, pending_suggestion_count())
	_refresh_suggestion_buttons()


## Liens suggérés encore à confirmer.
func pending_suggestion_count() -> int:
	var count: int = 0
	for link: Discrepancy in suggestions:
		if not selection.is_requested(link.a, link.b):
			count += 1
	return count


## Confirme le lien suggéré `index` (clic sur sa pastille, ou le premier en
## attente si −1) : la paire est évaluée comme une sélection A → B
## (`discrepancy_check_requested`) et devient une discordance épinglée.
func confirm_suggestion(index: int = -1) -> bool:
	if not _inspection_allowed() or suggestions.is_empty():
		return false
	var target: Discrepancy = null
	if index >= 0 and index < suggestions.size():
		target = suggestions[index]
	else:
		for link: Discrepancy in suggestions:
			if not selection.is_requested(link.a, link.b):
				target = link
				break
	if target == null or not selection.request_pair(target.a, target.b):
		return false
	links.add_evaluating(target.a, target.b)
	EventBus.discrepancy_check_requested.emit(target.a, target.b)
	workbench.set_scanner_count(pending_suggestion_count())
	_refresh_suggestion_buttons()
	_refresh_all()
	return true


func _refresh_suggestion_buttons() -> void:
	for button: Button in _suggestion_buttons:
		button.queue_free()
	_suggestion_buttons.clear()
	if _suggestion_layer == null or not documents_shown or verdict_sent:
		return
	var tint: Color = scanner_color(scanner_source)
	for i: int in suggestions.size():
		var link: Discrepancy = suggestions[i]
		if selection.is_requested(link.a, link.b):
			continue
		# Pastille compacte (coche dans un carré chanfreiné) : ne masque aucune valeur.
		var button: Button = Button.new()
		button.name = "Confirm_%d" % i
		button.theme_type_variation = &"ButtonGhost"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(DS.ICON_L, DS.ICON_L)
		button.add_theme_stylebox_override(&"normal", ThemeBuilder.chamfer_box(DS.BG_VOID, tint, DS.BORDER_STRONG, DS.CHAMFER_S, 0))
		button.add_theme_stylebox_override(&"hover", ThemeBuilder.chamfer_box(DS.BG_ELEVATED.blend(Color(tint, 0.24)), tint,
				DS.BORDER_STRONG, DS.CHAMFER_S, 0))
		button.add_theme_stylebox_override(&"pressed", ThemeBuilder.chamfer_box(Color(tint, 0.4), tint, DS.BORDER_STRONG, DS.CHAMFER_S, 0))
		var check: UiIcon = UiIcon.make(UiIcon.Kind.CHECK, tint, DS.ICON_M)
		check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		check.offset_left = DS.SPACE_1
		check.offset_top = DS.SPACE_1
		check.offset_right = -DS.SPACE_1
		check.offset_bottom = -DS.SPACE_1
		button.add_child(check)
		button.tooltip_text = "%s — %s" % [UiText.t("wb_scanner_confirm", "CONFIRMER"), describe(link)]
		button.visible = false
		button.pressed.connect(confirm_suggestion.bind(i))
		_suggestion_layer.add_child(button)
		_suggestion_buttons.append(button)
	_place_suggestion_buttons()


## Pastilles au milieu de leur lien (suivent les documents déplacés).
func _place_suggestion_buttons() -> void:
	if _suggestion_buttons.is_empty():
		return
	var shown: Array[LinkLayer.Link] = links.suggested_links()
	var inv: Transform2D = get_global_transform().affine_inverse()
	for button: Button in _suggestion_buttons:
		var index: int = button.name.trim_prefix("Confirm_").to_int()
		var mid: Vector2 = Vector2.INF
		if index < suggestions.size():
			for link: LinkLayer.Link in shown:
				if InspectionSelection.pair_key(link.a, link.b) == InspectionSelection.pair_key(suggestions[index].a, suggestions[index].b):
					mid = links.link_midpoint(link)
		button.visible = mid != Vector2.INF
		if button.visible:
			button.reset_size()
			button.position = (inv * mid - button.size * 0.5).round()


## Didascalie d'arrivée : accessoire d'ambiance (enfant, caisse, drone, LED),
## sinon les pas mouillés.
static func arrival_tag(case: Case) -> String:
	if case != null:
		for tag: StringName in PROP_TAGS:
			if case.dialogue_tags.has(tag):
				return UiText.t(PROP_TAGS[tag], "[%s]" % tag)
	return UiText.t("tag_footsteps", "[pas mouillés]")


## Figure finale du J20 (SC-50) : Ilan (voix de la famille) ou Mira (Lucioles),
## couleur transparente sinon.
static func final_figure_color(case: Case) -> Color:
	if case != null:
		for tag: StringName in FINAL_FIGURES:
			if case.dialogue_tags.has(tag):
				return DS.TEXT_SECONDARY if FINAL_FIGURES[tag] == "ilan" else DS.ACCENT_MAGENTA
	return Color.TRANSPARENT


## Réplique d'arrivée (`<dialogue>_arrival`, sinon générique) ; un porteur du
## code 7 glisse *lumika* dans sa phrase.
static func arrival_text(case: Case) -> String:
	var text: String = UiText.t(scripted_key(case, "arrival", "bark_arrival"), "Bonsoir… J'arrive, j'arrive.")
	if case != null and case.dialogue_tags.has(CaseBuilder.TAG_LUMIKA) and not text.to_lower().contains(LUMIKA_WORD) \
			and not text.contains(_unknown_word()):
		text += " ‹" + LUMIKA_WORD.capitalize() + ".›" # mot en Tessar entre chevrons (D-062)
	return passenger_text(text)


## Sous-titre d'un passager : *lumika* reste « [mot inconnu] » tant que le mot
## n'est pas appris (`lumika_learned`, NARRATIVE B16), puis s'affiche.
static func passenger_text(text: String) -> String:
	if text.is_empty():
		return text
	var learned: bool = GameState.get_flag(FLAG_LUMIKA, false) == true
	return lumika_text(text, learned)


static func lumika_text(text: String, learned: bool) -> String:
	var unknown: String = _unknown_word()
	if learned:
		return text.replace(unknown, LUMIKA_WORD)
	var regex: RegEx = RegEx.create_from_string("(?i)\\blumika\\b")
	return regex.sub(text, unknown, true)


static func _unknown_word() -> String:
	return UiText.t("tag_unknown_word", UNKNOWN_WORD_FALLBACK)


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
	var text: String = passenger_text(UiText.t(line_key, line_key))
	passenger_panel.set_line(text)
	subtitles.show_line(_speaker_name(), text)
	_answer_frame = Engine.get_process_frames()
	_answer_text = text
	if topic == InterrogationTopics.REMOVE_VISOR:
		_refresh_face()
	_refresh_all()


func _on_reaction(reaction: PassengerReaction.Kind) -> void:
	var name_key: String = str(PassengerReaction.Kind.find_key(reaction)).to_lower()
	var feminine: bool = current_case != null and current_case.passenger_presented != null \
			and current_case.passenger_presented.sex == Passenger.SEX_F
	var tag: String = UiText.t("tag_%s%s" % [name_key, "_f" if feminine else ""], UiText.t("tag_" + name_key, "[%s]" % name_key))
	if is_answer_reaction():
		# Réaction qui accompagne une réponse : la réplique reste, l'étiquette s'ajoute.
		subtitles.show_line(_speaker_name(), _answer_text, tag)
		_answer_text = ""
		passenger_panel.set_hint(tag)
		return
	var line: String = passenger_text(UiText.t("react_" + name_key, ""))
	if not line.is_empty():
		subtitles.show_line(_speaker_name(), line, tag)
		passenger_panel.set_line(line)
	passenger_panel.set_hint(tag)


## Vrai si une réponse d'interrogatoire vient d'être affichée (même image) et
## qu'aucune réaction ne l'a encore accompagnée.
func is_answer_reaction() -> bool:
	return not _answer_text.is_empty() and _answer_frame == Engine.get_process_frames()


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
	_last_result = result
	top_bar.set_processed(processed)
	_show_result(result)
	_return_documents()
	_refresh_all()
	# Réplique de départ, après la réaction au tampon (lisible à son tour).
	_departing_case = current_case
	var kind: VerdictKind.Kind = result.verdict_kind if result != null else VerdictKind.Kind.DENY
	get_tree().create_timer(DS.SUBTITLE_MIN_HOLD).timeout.connect(show_departure_line.bind(case_id, kind))


## Sous-titre de départ du passager (`bark_depart_*`, AUDIO.md §5.2) ; ignoré
## si un autre passager est déjà appelé.
func show_departure_line(case_id: StringName, kind: VerdictKind.Kind) -> void:
	var leaving: Case = _departing_case
	if leaving == null or leaving.case_id != case_id or (current_case != null and current_case != leaving):
		return
	_departing_case = null
	var key: String = departure_key(leaving, kind)
	var text: String = passenger_text(UiText.t(key, ""))
	if text.is_empty():
		return
	subtitles.show_line(UiText.passenger_name(leaving), text, UiText.t("tag_departing", "[en partant]"))
	if current_case == leaving:
		passenger_panel.set_line(text)
	departure_line_shown.emit(key, text)


static func departure_key(case: Case, kind: VerdictKind.Kind) -> String:
	# M7 : dernière réplique scénarisée (`_exit_<verdict>`, détention générique).
	var exit_key: String = InspectionSession.exit_line_key(case, kind)
	if not exit_key.is_empty():
		return exit_key
	match kind:
		VerdictKind.Kind.APPROVE:
			return scripted_key(case, "depart_ok", "bark_depart_ok")
		VerdictKind.Kind.DETAIN:
			return scripted_key(case, "depart_detained", "bark_depart_detained")
	return scripted_key(case, "depart_denied", "bark_depart_denied")


## Avis d'infraction imprimé (DS §7.9) : détail tiré du `CaseResult` du cas
## (rang, amende, règle citée) reçu juste avant par `case_resolved`.
func _on_citation_issued(reason_key: String) -> void:
	show_citation(_last_result if _last_result != null and _last_result.citation_reason_key == reason_key else null, reason_key)


func show_citation(result: CaseResult, reason_key: String = "") -> CitationTicket:
	if result == null:
		result = CaseResult.new()
		result.citation_reason_key = reason_key
		result.citation_number = 1
	var number: int = 0
	var title: String = ""
	for i: int in rulebook_entries.size():
		if rulebook_entries[i].rule_id == result.citation_rule_id:
			number = i + 1
			title = UiText.t(rulebook_entries[i].title_key, String(result.citation_rule_id))
	var free: int = day.free_citations_per_day if day != null else 2
	var ticket: CitationTicket = CitationTicket.make(result, day.day_number if day != null else 0, number, title, free)
	toasts.push_node(ticket, 120)
	ticket.play_print.call_deferred()
	return ticket


## Message d'intercom (Okonkwo, tutoriel diégétique du J1 — UI_FLOW §7) :
## sous-titre au bas de la vitre ; toast si les sous-titres sont désactivés
## (aucune information par le son seul, UI_FLOW §6).
func say_intercom(speaker: String, text: String) -> void:
	if subtitles.enabled:
		subtitles.show_line(speaker, text, UiText.t("tag_intercom", "[intercom]"))
	else:
		toasts.push(ToastStack.Kind.INFO, speaker, text)


## Clé de réplique dédiée d'un passager scénarisé : variante conditionnelle
## (`Case.line_overrides`), sinon `<dialogue_id>_<suffixe>` traduite, sinon
## `fallback` — `Case.scripted_key` (M8, ARCHITECTURE §7.2).
static func scripted_key(case: Case, suffix: String, fallback: String) -> String:
	if case == null:
		return fallback
	return case.scripted_key(suffix, fallback, UiText.has)


func _on_credits_changed(credits: int, _delta: int) -> void:
	top_bar.set_credits(credits)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	match key:
		Settings.KEY_TEXT_SCALE:
			var text_scale: float = value
			_rebuild_theme(text_scale)
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
	top_bar.quota_view.set_inspection_active(enabled)
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
## Renvoie `false` s'il n'y avait rien à annuler : Échap ouvre alors la pause
## (M5, UI_FLOW §3.5 « Pause : Échap (hors sélection) »).
func cancel() -> bool:
	if question_menu_open:
		close_question_menu()
	elif selection.cancel():
		_clear_selected_marks()
		links.pending_a = null
		_refresh_face()
	elif inspection_active:
		set_inspection_active(false)
	else:
		return false
	return true


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
	if luciole_reply_available():
		topics.append(InterrogationTopics.LUCIOLE_REPLY)
	if current_case.has_envelope() and not asked_topics.has(InterrogationTopics.ABOUT_ENVELOPE):
		topics.append(InterrogationTopics.ABOUT_ENVELOPE)
	for topic: StringName in unlocked_topics:
		topics.append(topic)
	if _face_covered() and not asked_topics.has(InterrogationTopics.REMOVE_VISOR):
		topics.append(InterrogationTopics.REMOVE_VISOR)
	for topic: StringName in InterrogationTopics.BASE:
		topics.append(topic)
	return topics


## Réponse à la phrase de passe proposée (code 4) : étiquette du cas et
## `lucioles_trust ≥ 2` (même condition que le DayController, GDD §4.7).
func luciole_reply_available() -> bool:
	if current_case == null or asked_topics.has(InterrogationTopics.LUCIOLE_REPLY):
		return false
	if not current_case.dialogue_tags.has(CaseBuilder.TAG_LUCIOLE_PASSWORD):
		return false
	return FlagCondition.gauge_value(GameState.narrative_flags, CaseConsequences.FLAG_TRUST) >= CaseConsequences.PASSWORD_TRUST


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
			"unlocked": unlocked_topics.has(topic) or topic == InterrogationTopics.ABOUT_ENVELOPE,
			"luciole": topic == InterrogationTopics.LUCIOLE_REPLY,
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
	for view: SlippedItemView in workbench.items:
		if is_instance_valid(view):
			view.lock()
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
	var side: String = ScreenBase.credits(result.wage, true)
	var message: String = UiText.tf("res_case_detail", [verdict_name], "Tampon %s")
	if result.citation_reason_key == ScoringService.CIT_IRREGULAR_ENTRY:
		message += " · " + UiText.plural("res_missed", result.missed_violations.size(), "%d infraction non relevée", "%d infractions non relevées")
	elif result.has_citation():
		message += " · " + UiText.t(result.citation_reason_key, result.citation_reason_key).to_lower()
	if result.correct:
		toasts.push(ToastStack.Kind.SUCCESS, UiText.t("res_case_ok", "Dossier conforme"), message, side)
	elif not result.has_citation():
		# Une erreur citée est annoncée par le ticket d'infraction (`citation_issued`).
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
	_refresh_suggestion_buttons()
	workbench.set_scanner("", DS.TEXT_SECONDARY, 0)
	_refresh_all()


func _clear_rulebook_marks() -> void:
	rulebook.clear_item_marks()
	top_bar.quota_view.clear_marks()


## Oublie le cas courant (nouveau cas, ou retour au guichet vide).
func _end_case(animated: bool) -> void:
	if documents_shown:
		workbench.clear(animated)
	documents_shown = false
	selection.reset()
	discrepancies.clear()
	if phase == DayPhase.Kind.WAITING_CASE:
		slipped_items.clear()
	unlocked_topics.clear()
	asked_topics.clear()
	question_menu_open = false
	links.clear()
	links.face_state = 0
	_clear_rulebook_marks()
	suggestions.clear()
	scanner_source = &""
	workbench.set_scanner("", DS.TEXT_SECONDARY, 0)
	_refresh_suggestion_buttons()
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
	var extra: int = 1 if allowed and _face_covered() and not asked_topics.has(InterrogationTopics.REMOVE_VISOR) else 0
	if allowed and current_case != null and current_case.has_envelope() and not asked_topics.has(InterrogationTopics.ABOUT_ENVELOPE):
		extra += 1
	if allowed and luciole_reply_available():
		extra += 1
	tool_bar.set_unlocked_count(unlocked_topics.size() + extra)
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
				+ UiText.t("st_arriving", " — lisez le Rulebook en attendant.")
	var count: int = discrepancies.size()
	if count > 0:
		var last: Discrepancy = discrepancies.back()
		var rule_part: String = ""
		var rule_number: int = _rule_number_of(last)
		if rule_number > 0:
			rule_part = UiText.tf("st_rule", [rule_number], " · règle %02d")
		# §4.9 : la paire marque ↔ bulletin ne débloque pas de question, elle
		# documente un signalement (DÉTENTION).
		if last.reason_key == Discrepancy.REASON_SYMBOL_MATCH:
			var title: String = UiText.t("st_discordance_one_title", "⚠ 1 discordance") if count == 1 \
					else UiText.tf("st_discordances_title", [count], "⚠ %d discordances")
			return _bb(title, DS.ACCENT_MAGENTA) + UiText.t("st_symbol_report",
					" · marque luciole relevée : DÉTENTION = signalement documenté.")
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
	if result.a.is_passenger_face() or result.b.is_passenger_face():
		return UiText.t("conc_face", "Visage conforme à la photo.")
	if not result.a.is_document_field():
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
	links.band_rect = band_rect()
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


## Rectangle global du visage, **contraint à la bande B** (y 56 → 432) : le
## cadre « VISAGE » ne déborde jamais sur la barre d'état ni sur le plan.
func _face_rect() -> Rect2:
	var rect: Rect2 = Rect2()
	var provided: Variant = face_rect_provider.call() if face_rect_provider.is_valid() else null
	if provided is Rect2:
		rect = provided
	else:
		var xform: Transform2D = get_global_transform()
		rect = Rect2(xform * DEFAULT_FACE_RECT.position, DEFAULT_FACE_RECT.size * xform.get_scale())
	if rect.size == Vector2.ZERO:
		return rect
	var band: Rect2 = band_rect().grow(-DS.SPACE_2)
	return rect.intersection(band) if rect.intersects(band) else Rect2()


## Bande B (vue 3D) en coordonnées globales.
func band_rect() -> Rect2:
	var xform: Transform2D = get_global_transform()
	var top_left: Vector2 = xform * Vector2(0.0, BAND_TOP)
	var bottom_right: Vector2 = xform * Vector2(size.x, BAND_BOTTOM)
	return Rect2(top_left, bottom_right - top_left)


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
	if ref.is_quota_counter():
		return top_bar.quota_view
	if ref.document_id == FieldRef.RULEBOOK_DOCUMENT_ID or ref.is_wanted() or ref.is_symbol() or ref.is_revoked():
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
	if (ref.document_id == FieldRef.RULEBOOK_DOCUMENT_ID or ref.is_wanted() or ref.is_symbol() or ref.is_revoked()) \
			and rulebook.collapsed:
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
	var items: Array[InspectableItem] = workbench.get_items()
	items.append_array(rulebook.get_items())
	items.append(top_bar.quota_view)
	for item: InspectableItem in items:
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
			if (result.a.is_quota_counter() or result.b.is_quota_counter()) and quota_max > 0:
				return UiText.tf("disc_quota_detail", [number, quota_used, quota_max],
						"Règle %02d — quota atteint (%d / %d) : refus justifié.")
			return UiText.tf("disc_rule_detail", [number, title], "Règle %02d enfreinte — %s")
		"disc_wanted_match":
			var wanted_ref: FieldRef = result.a if result.a.is_wanted() else result.b
			var notice: WantedNotice = find_notice(wanted_ref.field_id) if wanted_ref != null else null
			if notice != null:
				var who: String = notice.full_name().strip_edges().to_upper()
				if who.is_empty():
					who = UiText.t("rb_wanted_face_only", "VISAGE SEUL")
				return UiText.tf("disc_wanted_detail", [who], "Avis de recherche : %s")
		Discrepancy.REASON_REVOKED_MATCH:
			var revoked_ref: FieldRef = result.a if result.a.is_revoked() else result.b
			var entry: RevokedEntry = find_revocation(revoked_ref.field_id) if revoked_ref != null else null
			if entry != null:
				return UiText.tf("disc_revoked_detail", [entry.citizen_id, entry.full_name().to_upper()],
						"N° ID %s révoqué — %s n'est plus citoyen·ne.")
	return UiText.t(result.reason_key, result.reason_key)


# ---------------------------------------------------------------------------
# Entrées
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_next_cooldown = maxf(_next_cooldown - delta, 0.0)
	_place_suggestion_buttons()
	if documents_shown and not verdict_sent:
		elapsed_sec += delta


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"inspect_toggle", false, true):
		toggle_inspection()
		_handled()
	elif event.is_action_pressed(&"cancel", false, true):
		# Rien à annuler : l'événement continue (menu pause, `_unhandled_input`).
		if cancel():
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
