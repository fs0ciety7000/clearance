## Écran de fin (UI_FLOW §1 « Écran de fin », GDD §11.2) : fin de la démo
## après le J3, ou fin anticipée F2 (réaffectation) / F3 (famille perdue).
##
## Récapitulatif jour par jour (traités, conformes, citations, salaire,
## amendes, dépenses, solde), indice de conformité cumulé, état final du
## foyer et traces des choix narratifs (drapeaux). « RETOUR AU TITRE ».
class_name EndScreen
extends ScreenBase

const COLUMNS: Array[String] = ["end_col_day", "end_col_processed", "end_col_correct", "end_col_citations",
		"end_col_wage", "end_col_fines", "end_col_spent", "end_col_balance"]
## Drapeaux dont la trace est rappelée (dans cet ordre).
const NARRATIVE_FLAGS: Array[StringName] = [&"sc02_mercy", &"sc02_turned_away", &"sc03_passed", &"met_mira",
		&"sc05_helped", &"lucioles_reported", &"lucioles_note_burned"]

var ending: StringName = &"demo_complete"
var history: Array[Dictionary] = []
var household: Household = null
var final_credits: int = 0
var flags: Dictionary[StringName, Variant] = {}
var compliance: float = 0.0
var title_button: Button = null
## M7 : épilogue (`Campaign.epilogue` : `title_key`, `lines`) ; vide = texte
## de fin historique (`end_text_<fin>`). Affichage minimal en attendant
## l'écran de fin dédié (UI/UX, contrat ARCHITECTURE §7.1).
var epilogue: Dictionary = {}


func setup(p_ending: StringName, p_history: Array[Dictionary], p_household: Household, p_credits: int,
		p_flags: Dictionary[StringName, Variant], p_compliance: float) -> void:
	ending = p_ending
	history = p_history
	household = p_household if p_household != null else Household.new()
	final_credits = p_credits
	flags = p_flags
	compliance = p_compliance


func _build() -> void:
	var page: VBoxContainer = vbox(DS.SPACE_6)
	root_box().add_child(page)
	var demo: bool = ending == &"demo_complete"
	var accent: Color = DS.ACCENT_YELLOW if demo else DS.STATE_RED
	var top: HBoxContainer = hbox(DS.SPACE_3)
	page.add_child(top)
	top.add_child(UiIcon.make(UiIcon.Kind.LOGO if demo else UiIcon.Kind.DENIED, accent, DS.ICON_M))
	top.add_child(eyebrow(UiText.t("end_eyebrow_%s" % ending, "CLEARANCE · VERTICAL SLICE"), accent))
	page.add_child(rule_line(DS.YELLOW_24 if demo else DS.RED_24))
	var title_key: String = str(epilogue.get("title_key", "end_title_%s" % ending))
	page.add_child(label(UiText.t(title_key, String(ending).to_upper()), &"DisplayLabel", accent))
	var body: String = UiText.t("end_text_%s" % ending, "")
	var lines: PackedStringArray = epilogue.get("lines", PackedStringArray())
	if not lines.is_empty():
		var texts: PackedStringArray = []
		for key: String in lines:
			texts.append(UiText.t(key, key))
		body = "\n".join(texts)
	var text: Label = wrapped(body, &"BodyLabel")
	text.custom_minimum_size.x = 960.0
	text.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(text)
	var columns: HBoxContainer = hbox(DS.SPACE_8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var left: VBoxContainer = vbox(DS.SPACE_4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	columns.add_child(left)
	left.add_child(section(UiText.t("end_recap", "RÉCAPITULATIF DES SHIFTS"), UiIcon.Kind.DIAMOND, DS.TEXT_SECONDARY))
	left.add_child(_table())
	var tiles: HBoxContainer = hbox(DS.SPACE_3)
	left.add_child(tiles)
	tiles.add_child(stat_tile(UiText.t("end_compliance", "INDICE DE CONFORMITÉ"), "%d %%" % roundi(compliance * 100.0),
			UiText.t("end_compliance_detail", "Cas corrects / cas traités"), DS.ACCENT_CYAN, UiIcon.Kind.CHECK))
	tiles.add_child(stat_tile(UiText.t("end_balance", "SOLDE FINAL"), credits(final_credits),
			UiText.t("end_balance_detail", "Banque Aurel"), DS.STATE_RED if final_credits < 0 else DS.ACCENT_YELLOW, UiIcon.Kind.LOGO))
	var right: VBoxContainer = vbox(DS.SPACE_4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(section(UiText.t("end_family", "LE FOYER"), UiIcon.Kind.INFO, DS.TEXT_SECONDARY))
	for member: Household.Member in household.members:
		right.add_child(HouseholdView.member_card(member, HouseholdView.member_note(member)))
	var traces: Array[String] = []
	for flag: StringName in NARRATIVE_FLAGS:
		var value: Variant = flags.get(flag, false)
		if (value is bool and value) or ((value is int or value is float) and value != 0):
			traces.append(UiText.t("end_trace_%s" % flag, String(flag)))
	if not traces.is_empty():
		right.add_child(section(UiText.t("end_traces", "CE QUE VOUS AVEZ CHOISI"), UiIcon.Kind.DISCORDANCE, DS.ACCENT_MAGENTA))
		for trace: String in traces:
			var row: HBoxContainer = hbox(DS.SPACE_2)
			row.add_child(UiIcon.make(UiIcon.Kind.DIAMOND, DS.TEXT_SECONDARY, DS.ICON_S))
			var trace_label: Label = wrapped(trace, &"BodyLabel")
			trace_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(trace_label)
			right.add_child(row)
	var footer: HBoxContainer = hbox(DS.SPACE_4)
	page.add_child(footer)
	footer.add_child(label(UiText.t("end_hint", "« Gloire au Consortium. » — Vesh ota lumi."), &"CaptionLabel"))
	footer.add_child(spacer())
	title_button = button(UiText.t("end_to_title", "RETOUR AU TITRE"), &"ButtonPrimary")
	title_button.custom_minimum_size.x = 280.0
	title_button.pressed.connect(close.bind(&"title"))
	footer.add_child(title_button)
	title_button.grab_focus.call_deferred()


func _table() -> Control:
	var card: PanelContainer = panel(&"ElevatedCard")
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", DS.SPACE_6)
	grid.add_theme_constant_override("v_separation", DS.SPACE_2)
	card.add_child(grid)
	for key: String in COLUMNS:
		grid.add_child(eyebrow(UiText.t(key, key)))
	for entry: Dictionary in history:
		var balance: int = _n(entry, "balance")
		var cells: Array[String] = [
			"J%02d" % _n(entry, "day"),
			"%d / %d" % [_n(entry, "processed"), _n(entry, "planned")],
			str(_n(entry, "correct")),
			str(_n(entry, "citations")),
			credits(_n(entry, "wage"), true),
			credits(-_n(entry, "fines")),
			credits(-_n(entry, "spent")),
			credits(balance),
		]
		for i: int in cells.size():
			var color: Color = DS.TEXT_PRIMARY
			if i == cells.size() - 1 and balance < 0:
				color = DS.STATE_RED
			grid.add_child(label(cells[i], &"DocFieldValue", color))
	return card


static func _n(entry: Dictionary, key: String) -> int:
	return SaveService.as_int(entry.get(key, 0))
