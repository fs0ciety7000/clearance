## Écran de fin (UI_FLOW §1 « Écran de fin », GDD §11.2, NARRATIVE §6, I10) :
## fin de la démo, fins anticipées F2 / F3, fins de campagne F1–F7.
##
## M7 : **épilogue lu lentement** — titre de la fin (couleur sémantique), puis
## les lignes de l'épilogue apparaissent une à une (fondu + montée,
## `LINE_REVEAL_SEC`, *skippable* : clic, Entrée, « TOUT AFFICHER ») dans une
## colonne qui défile seule ; variante F5 Veilleurs / Brûlants signalée par une
## puce. Ensuite seulement : traces des choix (décisions marquantes, dans
## l'ordre de la campagne), récapitulatif des shifts, conformité, solde, foyer.
## « RETOUR AU TITRE » (CTA jaune). Aucune sauvegarde ne survit à une fin
## (D-041 : effacée par `Campaign` et `DayScene.show_end`).
## M8 (Acte II) : surtitres et titres F8 « LE REGISTRE » (cyan : la vérité
## lue au Hall) et F9 « LES VITRES ÉTEINTES » (gris : les guichets éteints),
## épilogues `end2_*`, puce « ACTE II », traces des choix J11–J20, tableau des
## 20 shifts défilant.
class_name EndScreen
extends ScreenBase

const COLUMNS: Array[String] = ["end_col_day", "end_col_processed", "end_col_correct", "end_col_citations",
		"end_col_wage", "end_col_fines", "end_col_spent", "end_col_balance"]
## Drapeaux dont la trace est rappelée, dans l'ordre de la campagne (J1 → J10).
const NARRATIVE_FLAGS: Array[StringName] = [&"sc02_mercy", &"sc02_turned_away", &"sc03_passed", &"met_mira",
		&"sc05_helped", &"lucioles_reported", &"lucioles_note_burned",
		&"sc06_reunited", &"sc07_bribe_kept", &"sc07_bribe_returned", &"noa_birthday_gift", &"lucioles_heating_accepted",
		&"inspector_bribe_taken", &"inspector_test_passed", &"inspector_test_failed", &"sc11_veteran_passed",
		&"sc13_detained", &"sc13_passed", &"sc14_bribe_kept", &"sc16_hana_passed", &"sc16_family_split",
		&"sc17_detained", &"sc17_passed", &"neighbor_denounced", &"neighbor_helped", &"brulants_package",
		&"sc18_note_reported", &"sc18_note_kept", &"audit_retention", &"audit_clean",
		&"ilan_supported", &"ilan_forbidden", &"ilan_denounced", &"okonkwo_denounced", &"okonkwo_warned",
		&"drift_passes_bought", &"sc20_detained", &"sc20_passed", &"sc21_bribe_kept",
		&"final_detained", &"final_passed", &"final_denied", &"final_unprocessed",
		# Acte II (J10 → J20).
		&"vannes_opened", &"drift_stayed", &"sc25_elena_turned_away", &"quota_overrun", &"sc28_tariq_refused",
		&"sc35_okonkwo_detained", &"sc35_okonkwo_helped", &"colleagues_listed", &"sc41_sato_spared", &"sc43_mateus_detained",
		&"beaumont_defied", &"sc45_ravel_spared", &"ilan_joined_soute", &"dora_departed", &"registre_sent", &"strike_joined"]
## Au plus autant de traces affichées (les plus récentes l'emportent).
const MAX_TRACES: int = 9
## Rythme de lecture de l'épilogue (une ligne toutes les ~1,9 s).
const LINE_REVEAL_SEC: float = DS.DUR_DRAMATIC * 3.0
const EPILOGUE_WIDTH: float = 820.0
## Définitions des jours (date du dernier jour joué, QA-010).
const DAY_PATH: String = "res://data/days/day_%02d.tres"

var ending: StringName = &"demo_complete"
var history: Array[Dictionary] = []
var household: Household = null
var final_credits: int = 0
var flags: Dictionary[StringName, Variant] = {}
var compliance: float = 0.0
var title_button: Button = null
var skip_button: Button = null
## M7 : épilogue (`Campaign.epilogue` : `title_key`, `eyebrow_key`, `lines`,
## `variant`) ; vide = texte de fin historique (`end_text_<fin>`).
var epilogue: Dictionary = {}
## Lignes de l'épilogue affichées (Label), révélées une à une.
var epilogue_labels: Array[Label] = []
## Nombre de lignes déjà révélées.
var revealed: int = 0

var _scroll: ScrollContainer = null
var _recap: Control = null
var _reveal_left: float = 0.0
var _done: bool = false


func setup(p_ending: StringName, p_history: Array[Dictionary], p_household: Household, p_credits: int,
		p_flags: Dictionary[StringName, Variant], p_compliance: float) -> void:
	ending = p_ending
	history = p_history
	household = p_household if p_household != null else Household.new()
	final_credits = p_credits
	flags = p_flags
	compliance = p_compliance


## Date de la fin : celle du dernier jour joué (`history`), donc une fin
## anticipée (F2 au soir du J4…) n'est pas datée du J10 (QA-010). Repli sur la
## date fixe `end_date` si l'historique ou la définition du jour manque.
static func date_text(p_history: Array[Dictionary]) -> String:
	var last_day: int = 0
	for entry: Dictionary in p_history:
		last_day = maxi(last_day, SaveService.as_int(entry.get("day", 0)))
	var path: String = DAY_PATH % last_day
	if last_day > 0 and ResourceLoader.exists(path):
		var day_def: DayDef = load(path) as DayDef
		if day_def != null:
			return UiText.tf("end_date_day", [UiText.date_with_weekday(day_def.game_date)], "%s · GUICHET 04")
	return UiText.t("end_date", "JEUDI 22.03.2187 · GUICHET 04")


## Couleur sémantique d'une fin (DS §2.1).
static func accent_of(p_ending: StringName, variant: String = "") -> Color:
	match p_ending:
		EndingService.F1_ARRESTED:
			return DS.STATE_RED
		EndingService.F2_REASSIGNED:
			return DS.STATE_AMBER
		EndingService.F3_FAMILY_LOST:
			return DS.TEXT_SECONDARY
		EndingService.F4_GLORY:
			return DS.ACCENT_YELLOW
		EndingService.F5_AIR:
			return DS.STATE_RED if variant == "brulants" else DS.ACCENT_MAGENTA
		EndingService.F6_DRIFT:
			return DS.ACCENT_CYAN
		EndingService.F7_REOPENS:
			return DS.TEXT_PRIMARY
		EndingService.F8_REGISTRE:
			return DS.ACCENT_CYAN
		EndingService.F9_STRIKE:
			return DS.TEXT_SECONDARY
		Campaign.ENDING_DEMO_COMPLETE:
			return DS.ACCENT_YELLOW
	return DS.STATE_RED


static func icon_of(p_ending: StringName) -> UiIcon.Kind:
	match p_ending:
		EndingService.F1_ARRESTED:
			return UiIcon.Kind.DETAIN
		EndingService.F2_REASSIGNED, EndingService.F3_FAMILY_LOST:
			return UiIcon.Kind.DENIED
		EndingService.F4_GLORY, Campaign.ENDING_DEMO_COMPLETE:
			return UiIcon.Kind.LOGO
		EndingService.F5_AIR:
			return UiIcon.Kind.DISCORDANCE
		EndingService.F6_DRIFT:
			return UiIcon.Kind.DIAMOND
		EndingService.F8_REGISTRE:
			return UiIcon.Kind.REGISTER
		EndingService.F9_STRIKE:
			return UiIcon.Kind.LOCK
	return UiIcon.Kind.INFO


## Clés des traces des choix (drapeaux vrais ou jauges non nulles), au plus
## `MAX_TRACES`, dans l'ordre de la campagne.
static func trace_keys(p_flags: Dictionary[StringName, Variant]) -> PackedStringArray:
	var keys: PackedStringArray = []
	for flag: StringName in NARRATIVE_FLAGS:
		var value: Variant = p_flags.get(flag, false)
		if (value is bool and value) or ((value is int or value is float) and value != 0):
			keys.append("end_trace_%s" % flag)
	return keys.slice(maxi(keys.size() - MAX_TRACES, 0))


func epilogue_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var keys: PackedStringArray = epilogue.get("lines", PackedStringArray())
	for key: String in keys:
		lines.append(ComparisonUI.lumika_text(UiText.t(key, key), true))
	if lines.is_empty():
		var body: String = UiText.t("end_text_%s" % ending, "")
		if not body.is_empty():
			lines.append(body)
	return lines


func _build() -> void:
	var variant: String = str(epilogue.get("variant", ""))
	var accent: Color = accent_of(ending, variant)
	var page: VBoxContainer = vbox(DS.SPACE_5)
	root_box().add_child(page)
	var top: HBoxContainer = hbox(DS.SPACE_3)
	page.add_child(top)
	top.add_child(UiIcon.make(icon_of(ending), accent, DS.ICON_M))
	var eyebrow_key: String = str(epilogue.get("eyebrow_key", "end_eyebrow_%s" % ending))
	top.add_child(eyebrow(UiText.t(eyebrow_key, "CLEARANCE · HALCYON GATE"), accent))
	var act: Variant = epilogue.get("act", 1)
	if act is int and act == 2:
		var act_chip: PanelContainer = chip(UiText.t("end_act2_chip", "ACTE II"), UiIcon.Kind.REGISTER, DS.VOICE_COMMISSION)
		act_chip.name = "ActChip"
		top.add_child(act_chip)
	if ending == EndingService.F5_AIR:
		var variant_key: String = "end_variant_brulants" if variant == "brulants" else "end_variant_veilleurs"
		var chip_node: PanelContainer = chip(UiText.t(variant_key, "VARIANTE"), UiIcon.Kind.DISCORDANCE, accent)
		chip_node.name = "VariantChip"
		top.add_child(chip_node)
	top.add_child(spacer())
	var date_label: Label = label(date_text(history), &"DataSmall")
	date_label.name = "EndDate"
	top.add_child(date_label)
	page.add_child(rule_line(Color(accent, 0.24)))
	var title_key: String = str(epilogue.get("title_key", "end_title_%s" % ending))
	var title: Label = label(UiText.t(title_key, String(ending).to_upper()), &"DisplayLabel", accent)
	title.name = "EndingTitle"
	page.add_child(title)
	var columns: HBoxContainer = hbox(DS.SPACE_10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	columns.add_child(_epilogue_column(accent))
	_recap = _recap_column()
	_recap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_recap)
	page.add_child(_footer())
	_start_reveal()
	(skip_button if not _done else title_button).grab_focus.call_deferred()


func _epilogue_column(accent: Color) -> Control:
	var column: VBoxContainer = vbox(DS.SPACE_3)
	column.custom_minimum_size.x = EPILOGUE_WIDTH
	_scroll = ScrollContainer.new()
	_scroll.name = "Epilogue"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Défilement automatique (`ensure_control_visible`) ou molette : pas de barre
	# (une barre qui apparaît change la largeur, le texte se replie, la barre
	# disparaît… boucle de mise en page).
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	column.add_child(_scroll)
	var lines_box: VBoxContainer = vbox(DS.SPACE_5)
	lines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(lines_box)
	for text: String in epilogue_lines():
		var row: HBoxContainer = hbox(DS.SPACE_4)
		var mark: ColorRect = ColorRect.new()
		mark.color = Color(accent, 0.6)
		mark.custom_minimum_size = Vector2(DS.BORDER_STRONG, DS.SPACE_6)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		var line: Label = wrapped(text, &"TitleLabel", DS.TEXT_PRIMARY)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		row.modulate.a = 0.0
		lines_box.add_child(row)
		epilogue_labels.append(line)
	return column


func _recap_column() -> Control:
	var right: VBoxContainer = vbox(DS.SPACE_4)
	right.name = "Recap"
	right.modulate.a = 0.0
	var traces: PackedStringArray = trace_keys(flags)
	if not traces.is_empty():
		right.add_child(section(UiText.t("end_traces", "CE QUE VOUS AVEZ CHOISI"), UiIcon.Kind.DISCORDANCE, DS.ACCENT_MAGENTA,
				str(traces.size())))
		for key: String in traces:
			var row: HBoxContainer = hbox(DS.SPACE_2)
			row.add_child(UiIcon.make(UiIcon.Kind.DIAMOND, DS.TEXT_SECONDARY, DS.ICON_S))
			var trace_label: Label = wrapped(UiText.t(key, key.trim_prefix("end_trace_")), &"BodySmall", DS.TEXT_PRIMARY)
			trace_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(trace_label)
			right.add_child(row)
	right.add_child(section(UiText.t("end_recap", "RÉCAPITULATIF DES SHIFTS"), UiIcon.Kind.DIAMOND, DS.TEXT_SECONDARY))
	# Acte II : jusqu'à 20 lignes — le tableau défile, les tuiles restent visibles.
	var table_scroll: ScrollContainer = ScrollContainer.new()
	table_scroll.name = "RecapTable"
	table_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(table_scroll)
	var table: Control = _table()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.add_child(table)
	var tiles: HBoxContainer = hbox(DS.SPACE_3)
	right.add_child(tiles)
	tiles.add_child(stat_tile(UiText.t("end_compliance", "INDICE DE CONFORMITÉ"), "%d %%" % roundi(compliance * 100.0),
			UiText.t("end_compliance_detail", "Cas corrects / cas traités"), DS.ACCENT_CYAN, UiIcon.Kind.CHECK))
	tiles.add_child(stat_tile(UiText.t("end_balance", "SOLDE FINAL"), credits(final_credits),
			UiText.t("end_balance_detail", "Banque Aurel"), DS.STATE_RED if final_credits < 0 else DS.ACCENT_YELLOW, UiIcon.Kind.LOGO))
	var family: HBoxContainer = hbox(DS.SPACE_2)
	right.add_child(section(UiText.t("end_family", "LE FOYER"), UiIcon.Kind.INFO, DS.TEXT_SECONDARY))
	right.add_child(family)
	for member: Household.Member in household.members:
		var card: PanelContainer = HouseholdView.member_card(member, "", true)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		family.add_child(card)
	return right


func _footer() -> Control:
	var footer: HBoxContainer = hbox(DS.SPACE_4)
	var hint: Label = label(UiText.t("end_hint", "« Gloire au Consortium. » — Vesh ota lumi."), &"CaptionLabel")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(hint)
	footer.add_child(spacer())
	skip_button = button(UiText.t("end_skip", "TOUT AFFICHER"), &"ButtonGhost")
	skip_button.pressed.connect(reveal_all)
	footer.add_child(skip_button)
	title_button = button(UiText.t("end_to_title", "RETOUR AU TITRE"), &"ButtonPrimary")
	title_button.custom_minimum_size.x = 280.0
	title_button.pressed.connect(close.bind(&"title"))
	footer.add_child(title_button)
	return footer


# ---------------------------------------------------------------------------
# Défilement lent de l'épilogue
# ---------------------------------------------------------------------------

func _start_reveal() -> void:
	revealed = 0
	_done = false
	if Settings.reduce_motion or epilogue_labels.is_empty():
		reveal_all()
		return
	_reveal_left = DS.DUR_SLOW
	set_process(true)


func _process(delta: float) -> void:
	if _done:
		set_process(false)
		return
	_reveal_left -= delta
	if _reveal_left <= 0.0:
		reveal_next()
		_reveal_left = LINE_REVEAL_SEC


## Révèle la ligne suivante (fondu + montée) ; puis le récapitulatif.
func reveal_next() -> void:
	if revealed >= epilogue_labels.size():
		_finish_reveal()
		return
	var row: Control = epilogue_labels[revealed].get_parent() as Control
	revealed += 1
	var tween: Tween = row.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "modulate:a", 1.0, DS.DUR_DRAMATIC)
	if _scroll != null:
		_scroll.ensure_control_visible.call_deferred(row)
	if revealed >= epilogue_labels.size():
		_reveal_left = LINE_REVEAL_SEC
		get_tree().create_timer(DS.DUR_DRAMATIC).timeout.connect(_finish_reveal)


## Tout afficher d'un coup (bouton, Entrée, clic, effets réduits).
func reveal_all() -> void:
	for label_node: Label in epilogue_labels:
		(label_node.get_parent() as Control).modulate.a = 1.0
	revealed = epilogue_labels.size()
	_finish_reveal()


func is_reveal_done() -> bool:
	return _done


func _finish_reveal() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	if skip_button != null:
		skip_button.visible = false
	if _recap != null:
		if Settings.reduce_motion or not is_inside_tree():
			_recap.modulate.a = 1.0
		else:
			_recap.create_tween().tween_property(_recap, "modulate:a", 1.0, DS.DUR_DRAMATIC)
	if title_button != null and is_inside_tree():
		title_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept"):
		reveal_all()
		get_viewport().set_input_as_handled()


func _table() -> Control:
	var card: PanelContainer = panel(&"ElevatedCard")
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", DS.SPACE_4)
	grid.add_theme_constant_override("v_separation", DS.SPACE_1)
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
			grid.add_child(label(cells[i], &"DataSmall", color))
	return card


static func _n(entry: Dictionary, key: String) -> int:
	return SaveService.as_int(entry.get(key, 0))
