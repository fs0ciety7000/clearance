## M15 (lot U) — passe de débordement **en anglais** au Steam Deck (fenêtre
## 1280×800 → vue logique 1920×1200, plancher de texte ; texte 1,0 et 1,5),
## sur les points relevés aux captures `docs/mockups/m15_en_*` :
## - en-tête des documents : l'émetteur n'est plus coupé par le n° de série
##   (deux lignes au plus, jamais d'ellipse sur les vrais émetteurs) ;
## - Rulebook : aucun onglet dessiné à moitié au bord de la rangée ;
## - bilan : colonne des avis d'infraction élargie avec le texte (en-tête du
##   ticket sur deux lignes au plus) ;
## - soirée : « One purchase per evening. No credit. » entier à côté de
##   « HALL COMMISSARY » ; « One per evening: untick the other first. » ;
## - guillemets de la langue (« … » / "…") pour les répliques et devises.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DECK_SCALE: float = 1280.0 / 1920.0
const DECK_LOGICAL: Vector2i = Vector2i(1920, 1200)

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)


func after_each() -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	Settings.clear_session_value(Settings.KEY_TEXT_SCALE)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


func _viewport() -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = DECK_LOGICAL
	vp.disable_3d = true
	add_child_autofree(vp)
	return vp


## Guichet au Deck (J8), cas valide posé (carte, permis, bio-scan).
func _booth(text_scale: float) -> ComparisonUI:
	Settings.set_session_value(Settings.KEY_TEXT_SCALE, text_scale)
	var vp: SubViewport = _viewport()
	var ui: ComparisonUI = (load("res://scenes/ui/comparison_ui.tscn") as PackedScene).instantiate() as ComparisonUI
	vp.add_child(ui)
	var session: InspectionSession = InspectionSession.new()
	add_child_autofree(session)
	session.set_process(false)
	var day: DayDef = data.get_day(8)
	var ctx: RuleContext = CaseFactory.context(day.rule_set.make_shift_copy())
	ui.rule_context_provider = func() -> RuleContext: return ctx
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	ui.emulate_screen_scale(DECK_SCALE)
	await wait_process_frames(2)
	var c: Case = CaseFactory.valid_case()
	c.index = 0
	session.begin(c, ctx)
	session.configure(InterrogationTiming.new(), {} as Dictionary[StringName, Variant])
	EventBus.case_presented.emit(c)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, c.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, c.case_id)
	EventBus.documents_presented.emit(c.case_id)
	await wait_process_frames(4)
	return ui


func test_document_issuer_is_never_cut_by_the_serial_on_deck() -> void:
	for text_scale: float in [1.0, 1.5]:
		var ui: ComparisonUI = await _booth(text_scale)
		assert_gt(ui.workbench.views.size(), 0, "documents posés")
		for view: DocumentView in ui.workbench.views:
			var issuer: Label = view.find_child("Issuer", true, false) as Label
			assert_not_null(issuer, "émetteur de %s" % view.get_document_id())
			if issuer == null:
				continue
			var where: String = "%s texte %.1f « %s »" % [view.get_document_id(), text_scale, issuer.text]
			assert_lte(issuer.get_line_count(), DocumentView.ISSUER_MAX_LINES, "émetteur entier (≤ 2 lignes) : " + where)
			var words: PackedStringArray = issuer.text.to_upper().split(" ", false)
			var font: Font = issuer.get_theme_font(&"font")
			var px: int = issuer.get_theme_font_size(&"font_size")
			for word: String in words:
				var w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				assert_gte(issuer.size.x + 1.0, w, "aucun mot coupé (%s) : %s" % [word, where])
			# Texte entier : il tient dans les lignes affichées (sinon ellipse).
			var full: float = font.get_string_size(issuer.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			assert_lte(full, (issuer.size.x + px) * issuer.get_line_count(), "émetteur sans ellipse : " + where)
			assert_lte(issuer.get_line_count(), issuer.get_visible_line_count(), "toutes les lignes visibles : " + where)
			# Le bloc de droite (n° de série, sceau) ne recouvre pas l'émetteur.
			for label: Label in view.find_children("*", "Label", true, false):
				if label != issuer and label.text == view.instance.serial and label.is_visible_in_tree():
					assert_false(label.get_global_rect().intersects(issuer.get_global_rect()), "n° de série à côté : " + where)
		ui.get_parent().queue_free()
		await wait_process_frames(1)


func test_rulebook_tabs_are_never_drawn_half_cut_on_deck() -> void:
	var ui: ComparisonUI = await _booth(1.5)
	var rulebook: RulebookPanel = ui.rulebook
	var strip: ScrollContainer = rulebook.find_child("Tabs", true, false) as ScrollContainer
	assert_not_null(strip, "rangée d'onglets")
	var seen_hidden: bool = false
	for i: int in 14:
		await wait_process_frames(3)
		var view: Rect2 = strip.get_global_rect().grow(1.0)
		var shown: int = 0
		for button: Button in _row_buttons(rulebook, strip):
			if not rulebook.is_tab_whole(button):
				seen_hidden = true
				continue
			var rect: Rect2 = button.get_global_rect()
			if rect.end.x < view.position.x or rect.position.x > view.end.x:
				continue # hors de la rangée (dessiné mais découpé entièrement)
			shown += 1
			assert_true(view.encloses(rect), "onglet « %s » dessiné entier : %s dans %s" % [button.text, rect, view])
		assert_gt(shown, 0, "au moins l'onglet courant est visible")
		rulebook.cycle_tab(1)
	assert_true(seen_hidden, "témoin : en anglais au Deck 1,5, des onglets dépassent la rangée")


## Onglets de la rangée (catégories de règles et bulletins).
func _row_buttons(rulebook: RulebookPanel, strip: ScrollContainer) -> Array[Button]:
	var out: Array[Button] = []
	for node: Node in rulebook.find_children("*", "Button", true, false):
		if node.get_parent() != null and node.get_parent().get_parent() == strip:
			out.append(node as Button)
	return out


func test_summary_notices_column_grows_with_the_text_on_deck() -> void:
	Settings.set_session_value(Settings.KEY_TEXT_SCALE, 1.5)
	var n: int = 8
	var summary: DaySummary = DaySimulator.simulate(data, n, 99,
			func(_c: Case, key: CaseKey, i: int) -> VerdictKind.Kind:
				return VerdictKind.Kind.APPROVE if i % 2 == 0 else key.expected_verdict)
	assert_gt(summary.get_citations().size(), 0, "témoin : des avis d'infraction")
	var screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
	screen.setup(summary, data.get_day(n))
	var vp: SubViewport = _viewport()
	vp.add_child(screen)
	screen.theme = ThemeBuilder.build(Settings.text_scale, ThemeBuilder.min_px_for(DECK_SCALE))
	await wait_process_frames(4)
	var column: Control = screen.find_child("Tickets", true, false) as Control
	assert_not_null(column, "colonne des avis")
	assert_gte(column.size.x, ShiftSummaryScreen.TICKETS_WIDTH * 1.5 - 1.0, "colonne élargie avec le texte 1,5")
	assert_lte(column.size.x, (DECK_LOGICAL.x - 2 * ScreenBase.SCREEN_MARGIN_X) * ShiftSummaryScreen.TICKETS_MAX_SHARE + 1.0,
			"jamais plus de 40 % de la largeur utile")
	assert_true(_visible_in(screen.continue_button, vp), "bouton principal à l'écran")
	var header: String = UiText.t("cit_header").to_upper()
	var checked: int = 0
	for ticket: CitationTicket in column.find_children("*", "CitationTicket", true, false):
		for label: Label in ticket.find_children("*", "Label", true, false):
			if label.text.to_upper() == header and label.is_visible_in_tree():
				checked += 1
				assert_lte(label.get_line_count(), 2, "« %s » sur deux lignes au plus (%d)" % [header, label.get_line_count()])
	assert_gt(checked, 0, "en-têtes de ticket vérifiés")


func _visible_in(control: Control, vp: SubViewport) -> bool:
	return Rect2(Vector2.ZERO, Vector2(vp.size)).encloses(control.get_global_rect())


func test_commissary_side_text_is_whole_on_deck_at_text_150() -> void:
	Settings.set_session_value(Settings.KEY_TEXT_SCALE, 1.5)
	var day_number: int = 11
	var economy: EconomyDef = data.get_economy()
	var flags: Dictionary[StringName, Variant] = {}
	var home: Household = Household.new()
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, home, flags, 200)
	EveningService.default_selection(lines, 200)
	lines.append_array(EveningService.shop_lines(economy, day_number, flags))
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(data.get_day(day_number), 200, 20, lines, home, false)
	screen.shop_flags = flags
	var vp: SubViewport = _viewport()
	vp.add_child(screen)
	screen.theme = ThemeBuilder.build(Settings.text_scale, ThemeBuilder.min_px_for(DECK_SCALE))
	await wait_process_frames(5)
	assert_not_null(screen.shop, "Économat ouvert au J11")
	if screen.shop == null:
		return
	var side: Label = null
	for label: Label in screen.shop.find_children("*", "Label", true, false):
		if label.text == UiText.t("shop_one_per_evening"):
			side = label
	assert_not_null(side, "texte d'appoint de l'Économat")
	if side == null:
		return
	assert_eq(side.text, "One purchase per evening. No credit.")
	assert_eq(side.tooltip_text, "", "entier, sans ellipse : « %s »" % side.text)
	var font: Font = side.get_theme_font(&"font")
	var full: float = font.get_string_size(side.text, HORIZONTAL_ALIGNMENT_LEFT, -1, side.get_theme_font_size(&"font_size")).x
	assert_gte(side.size.x + 1.0, full, "largeur du texte entier")


## Guillemets de la langue courante (répliques, devises, Dossier).
func test_quotes_follow_the_language() -> void:
	assert_eq(UiText.quoted("Order is the air we breathe."), "\"Order is the air we breathe.\"")
	assert_eq(UiText.speaker_quoted("OFFICER", "Purpose of visit?"), "OFFICER: \"Purpose of visit?\"")
	var quoted: String = UiText.quoted(UiText.t("ui_discordance"))
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	assert_eq(UiText.quoted("L'ordre est l'air que nous respirons."), "« L'ordre est l'air que nous respirons. »")
	assert_eq(UiText.speaker_quoted("AGENT", "Motif ?"), "AGENT : « Motif ? »")
	assert_eq(UiText.remake(quoted), "« %s »" % UiText.t("ui_discordance"), "retraduction à chaud de la réplique citée")
