## Bilan de shift (UI_FLOW §8, GDD §3.2, §5) — après la sirène de 18:00.
##
## Tuiles : passagers traités / prévus, conformes (indice de conformité),
## citations (avertissements / amendes), salaire, amendes, net du jour.
## Registre du guichet : une ligne par passager (tampon, nom, verdict juste ou
## motif de l'erreur + règle **révélée** : violation non relevée ou refus non
## documenté — erreurs pédagogiques), puis les passagers non traités.
## Avis d'infraction du jour (tickets archivés, 40 %, 100 % au survol).
## M7 : lignes « Divers non déclaré » (enveloppes gardées, ambre) et « Prime de
## signalement » (objets remis à la Garde, jaune) avec le total versé ce soir ;
## décision sur l'objet glissé rappelée dans la ligne du registre.
## « RENTRER AU BLOC PÉTREL » → `finished(&"evening")`.
class_name ShiftSummaryScreen
extends ScreenBase

const LEFT_RATIO: float = 1.7
const TICKETS_WIDTH: float = 380.0

var summary: DaySummary = null
var day: DayDef = null
var continue_button: Button = null


func setup(p_summary: DaySummary, p_day: DayDef) -> void:
	summary = p_summary
	day = p_day


func _build() -> void:
	if summary == null:
		summary = DaySummary.new()
	var page: VBoxContainer = vbox(DS.SPACE_6)
	root_box().add_child(page)
	page.add_child(_header())
	page.add_child(_tiles())
	var columns: HBoxContainer = hbox(DS.SPACE_8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var ledger: Control = _ledger()
	ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger.size_flags_stretch_ratio = LEFT_RATIO
	columns.add_child(ledger)
	columns.add_child(_tickets())
	page.add_child(_footer())
	continue_button.grab_focus.call_deferred()


func _header() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	var top: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(top)
	top.add_child(UiIcon.make(UiIcon.Kind.INFO, DS.ACCENT_CYAN, DS.ICON_M))
	var org: VBoxContainer = vbox(0)
	top.add_child(org)
	var siren_key: String = "sum_siren_time" if summary.time_expired else "sum_siren_queue"
	org.add_child(eyebrow(UiText.t(siren_key, "FIN DE SHIFT · 18:00 · SIRÈNE DU HALL"), DS.ACCENT_CYAN))
	org.add_child(label(UiText.t("sum_location", "Halcyon Gate · Guichet 04 · rapport transmis aux Inspecteurs"), &"CaptionLabel"))
	top.add_child(spacer())
	if day != null:
		var date: Label = label(UiText.date_with_weekday(day.game_date), &"DataTitle")
		date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(date)
	box.add_child(rule_line(DS.CYAN_24))
	box.add_child(label(UiText.tf("sum_title", [summary.day_number], "BILAN DU SHIFT — JOUR %02d"), &"DisplayLabel"))
	return box


func _tiles() -> Control:
	var row: HBoxContainer = hbox(DS.SPACE_3)
	var processed: int = summary.get_processed_count()
	var unprocessed: int = summary.get_unprocessed_count()
	var processed_detail: String = UiText.plural("sum_unprocessed", unprocessed, "%d non traité · manque à gagner", "%d non traités · manque à gagner") \
			if unprocessed > 0 else UiText.t("sum_queue_empty", "File vidée avant la sirène")
	row.add_child(stat_tile(UiText.t("sum_processed", "TRAITÉS"), "%d / %d" % [processed, summary.planned_cases], processed_detail,
			DS.TEXT_PRIMARY, UiIcon.Kind.DIAMOND))
	var compliance: int = roundi(summary.get_compliance() * 100.0)
	row.add_child(stat_tile(UiText.t("sum_correct", "CONFORMES"), str(summary.get_correct_count()),
			UiText.tf("sum_compliance", [compliance], "Conformité %d %%"), DS.ACCENT_CYAN, UiIcon.Kind.CHECK))
	var citations: int = summary.get_citation_count()
	var warnings: int = summary.get_warning_count()
	row.add_child(stat_tile(UiText.t("sum_citations", "CITATIONS"), str(citations),
			UiText.tf("sum_citation_detail", [warnings, citations - warnings], "%d avert. · %d amende(s)"),
			DS.STATE_AMBER if citations > 0 else DS.TEXT_PRIMARY, UiIcon.Kind.WARNING))
	row.add_child(stat_tile(UiText.t("sum_wage", "SALAIRE"), credits(summary.get_wage_total(), true),
			UiText.tf("sum_wage_detail", [day.credit_per_correct if day != null else 5], "%d ₵ par dossier conforme"), DS.TEXT_PRIMARY))
	row.add_child(stat_tile(UiText.t("sum_fines", "AMENDES"), credits(-summary.get_fine_total()),
			UiText.t("sum_fines_detail", "Retenues sur salaire"), DS.STATE_RED if summary.get_fine_total() > 0 else DS.TEXT_SECONDARY,
			UiIcon.Kind.DENIED))
	var net: int = summary.get_net()
	var bribes: int = summary.get_bribe_total()
	var reports: int = summary.get_report_total()
	if bribes > 0:
		var tile: PanelContainer = stat_tile(UiText.t("sum_bribes", "DIVERS NON DÉCLARÉ"), credits(bribes, true),
				UiText.t("sum_bribes_detail", "Enveloppes gardées · hors salaire"), DS.STATE_AMBER, UiIcon.Kind.WARNING)
		tile.name = "BribeTile"
		row.add_child(tile)
	if reports > 0:
		var report_tile: PanelContainer = stat_tile(UiText.t("sum_reports", "PRIME DE SIGNALEMENT"), credits(reports, true),
				UiText.t("sum_reports_detail", "Objets remis à la Garde"), DS.ACCENT_YELLOW, UiIcon.Kind.LOGO)
		report_tile.name = "ReportTile"
		row.add_child(report_tile)
	var total_detail: String = UiText.t("sum_net_detail", "Versé ce soir par la Banque Aurel")
	if bribes > 0 or reports > 0:
		total_detail = UiText.tf("sum_total_detail", [credits(summary.get_total_income(), true)], "Ce soir au total : %s")
	row.add_child(stat_tile(UiText.t("sum_net", "NET DU JOUR"), credits(net, true), total_detail, DS.ACCENT_YELLOW, UiIcon.Kind.LOGO))
	return row


func _ledger() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.add_child(section(UiText.t("sum_ledger", "REGISTRE DU GUICHET"), UiIcon.Kind.DIAMOND, DS.TEXT_SECONDARY,
			UiText.plural("sum_errors", summary.get_error_count(), "%d ERREUR", "%d ERREURS")))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list: VBoxContainer = vbox(DS.SPACE_1)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for result: CaseResult in summary.results:
		list.add_child(_ledger_row(result))
	var unprocessed: int = summary.get_unprocessed_count()
	if unprocessed > 0:
		var row: PanelContainer = panel(&"ElevatedCard")
		row.modulate.a = 0.7
		var line: HBoxContainer = hbox(DS.SPACE_3)
		row.add_child(line)
		line.add_child(UiIcon.make(UiIcon.Kind.LOCK, DS.TEXT_MUTED, DS.ICON_S))
		line.add_child(label(UiText.plural("sum_unprocessed_row", unprocessed, "%d passager encore dans la file à la sirène — 0 ₵",
				"%d passagers encore dans la file à la sirène — 0 ₵"), &"BodySmall"))
		list.add_child(row)
	return box


func _ledger_row(result: CaseResult) -> Control:
	var row: PanelContainer = panel(&"ElevatedCard")
	if not result.correct:
		row.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.BG_ELEVATED, DS.STATE_RED if result.fine > 0 or not result.verdict_correct else DS.STATE_AMBER))
	var col: VBoxContainer = vbox(DS.SPACE_1)
	row.add_child(col)
	var line: HBoxContainer = hbox(DS.SPACE_3)
	col.add_child(line)
	line.add_child(label("%02d" % (result.case_index + 1), &"DataSmall", DS.TEXT_MUTED))
	var stamp_color: Color = _stamp_color(result.verdict_kind)
	line.add_child(UiIcon.make(_stamp_icon(result.verdict_kind), stamp_color, DS.ICON_S))
	var stamp: Label = label(StampMark.label_of(result.verdict_kind), &"DocFieldLabel", stamp_color)
	stamp.custom_minimum_size.x = 104.0
	line.add_child(stamp)
	var who: Label = label(result.passenger_label, &"DocFieldValue")
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	line.add_child(who)
	var status_color: Color = DS.ACCENT_CYAN if result.correct else (DS.STATE_AMBER if result.verdict_correct else DS.STATE_RED)
	var status_text: String = UiText.t("sum_ok", "Conforme") if result.correct else UiText.t(result.citation_reason_key, result.citation_reason_key)
	line.add_child(chip(status_text, UiIcon.Kind.CHECK if result.correct else UiIcon.Kind.WARNING, status_color))
	if result.bribe_credits > 0:
		line.add_child(chip(UiText.tf("sum_item_bribe", [credits(result.bribe_credits, true)], "ENVELOPPE %s"), UiIcon.Kind.WARNING, DS.STATE_AMBER))
	if result.report_credits > 0:
		line.add_child(chip(UiText.tf("sum_item_report", [credits(result.report_credits, true)], "SIGNALÉ %s"), UiIcon.Kind.LOGO, DS.ACCENT_YELLOW))
	var money: Label = label(credits(result.credits_delta, true), &"DocFieldValue",
			DS.TEXT_PRIMARY if result.credits_delta > 0 else (DS.STATE_RED if result.credits_delta < 0 else DS.TEXT_MUTED))
	money.custom_minimum_size.x = 72.0
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(money)
	if not result.correct:
		var detail: String = _error_detail(result)
		if not detail.is_empty():
			var note: Label = wrapped(detail, &"BodySmall")
			var indent: MarginContainer = MarginContainer.new()
			indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			indent.add_theme_constant_override("margin_left", DS.SPACE_10 + DS.SPACE_6)
			indent.add_child(note)
			col.add_child(indent)
	return row


## Ce qui a manqué, avec la règle du jour (n° + titre) — erreurs pédagogiques.
func _error_detail(result: CaseResult) -> String:
	var rules: PackedStringArray = []
	var source: Array[Violation] = result.missed_violations if not result.missed_violations.is_empty() else result.expected_violations
	for violation: Violation in source:
		var text: String = _rule_label(violation.rule_id)
		if not rules.has(text):
			rules.append(text)
	match result.citation_reason_key:
		ScoringService.CIT_IRREGULAR_ENTRY:
			return UiText.tf("sum_detail_missed", [" · ".join(rules)], "Non relevé : %s")
		ScoringService.CIT_UNDOCUMENTED_DENIAL, ScoringService.CIT_UNDOCUMENTED_DETENTION:
			return UiText.tf("sum_detail_undocumented", [" · ".join(rules)], "Aucune discordance épinglée pour : %s")
		ScoringService.CIT_UNJUSTIFIED_DENIAL:
			return UiText.t("sum_detail_innocent", "Dossier en règle : aucune violation à relever.")
		ScoringService.CIT_FACE_UNCHECKED, ScoringService.CIT_INTERVIEW_SKIPPED:
			return UiText.tf("sum_detail_procedure", [_rule_label(result.citation_rule_id)], "Procédure : %s")
	return ""


func _rule_label(rule_id: StringName) -> String:
	if day != null and day.rule_set != null:
		for i: int in day.rule_set.rules.size():
			var rule: Rule = day.rule_set.rules[i]
			if rule != null and rule.id == rule_id:
				return UiText.tf("cit_rule", [i + 1, UiText.t(rule.title_key, String(rule_id))], "Règle %02d · %s")
	return String(rule_id)


func _tickets() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.custom_minimum_size.x = TICKETS_WIDTH
	var citations: Array[CaseResult] = summary.get_citations()
	box.add_child(section(UiText.t("sum_tickets", "AVIS D'INFRACTION"), UiIcon.Kind.LOGO, DS.ACCENT_YELLOW, str(citations.size())))
	if citations.is_empty():
		var empty: PanelContainer = panel(&"ElevatedCard")
		empty.add_child(wrapped(UiText.t("sum_no_ticket", "Aucune infraction aujourd'hui. Le Consortium prend note de votre exactitude."), &"BodySmall"))
		box.add_child(empty)
		return box
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list: VBoxContainer = vbox(DS.SPACE_3)
	scroll.add_child(list)
	for result: CaseResult in citations:
		var number: int = 0
		var title: String = ""
		if day != null and day.rule_set != null:
			for i: int in day.rule_set.rules.size():
				if day.rule_set.rules[i] != null and day.rule_set.rules[i].id == result.citation_rule_id:
					number = i + 1
					title = UiText.t(day.rule_set.rules[i].title_key, "")
		list.add_child(CitationTicket.make(result, summary.day_number, number, title,
				day.free_citations_per_day if day != null else 2, true))
	return box


func _footer() -> Control:
	var row: HBoxContainer = hbox(DS.SPACE_4)
	var hint: Label = label(UiText.t("sum_hint", "Chaque erreur rappelle la règle du Rulebook concernée."), &"CaptionLabel")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	row.add_child(spacer())
	continue_button = button(UiText.t("sum_continue", "RENTRER AU BLOC PÉTREL"), &"ButtonPrimary")
	continue_button.custom_minimum_size.x = 320.0
	continue_button.pressed.connect(close.bind(&"evening"))
	row.add_child(continue_button)
	return row


static func _stamp_color(kind: VerdictKind.Kind) -> Color:
	match kind:
		VerdictKind.Kind.APPROVE:
			return DS.STATE_GREEN
		VerdictKind.Kind.DETAIN:
			return DS.ACCENT_YELLOW
	return DS.STATE_RED


static func _stamp_icon(kind: VerdictKind.Kind) -> UiIcon.Kind:
	match kind:
		VerdictKind.Kind.APPROVE:
			return UiIcon.Kind.APPROVED
		VerdictKind.Kind.DETAIN:
			return UiIcon.Kind.DETAIN
	return UiIcon.Kind.DENIED
