## Soirée au Bloc Pétrel (UI_FLOW §8 « Foyer », GDD §5.3, §5.4).
##
## Budget : solde du matin (+ avance du Consortium au J1, D-047) + net du
## shift = disponible ; postes cochables
## (loyer, nourriture, chauffage, oxygène de Dora les soirs pairs, médicaments
## par proche malade) — la taxe d'air est prélevée d'office ; un poste
## facultatif ne se coche que si le solde reste ≥ 0 (« fonds insuffisants »).
## Foyer : état de chaque proche (icône + couleur + texte). Message narratif :
## le mot des Lucioles (SC-05) à « SIGNALER » ou « BRÛLER » (GDD §4.7).
## « VALIDER ET DORMIR » émet `confirmed(lines)` : la scène calcule et
## enregistre la soirée puis appelle `show_report()` (conséquences de la nuit),
## dont le bouton émet `finished(&"next" | fin)`.
## M7 (NARRATIVE §5, I9) : **événements du soir** (`set_events`) présentés en
## panneaux successifs (J9 : audit → aveu d'Ilan → déposition → laissez-passer) :
## lettre, audit (résultat imposé, retenue), choix (options exclusives, coût /
## gain, option grisée avec sa raison si les fonds manquent). Les choix
## modifient les postes (`line_costs` : chauffage offert…) et le solde ; un
## audit qui arrête l'agent·e (F1) clôt la séquence. « VALIDER ET DORMIR »
## attend que chaque choix soit fait (sinon `confirm()` complète par les choix
## par défaut, D-058 : tests, joueur pressé).
## M8 (Acte II, ARCHITECTURE §7.2) : textes à valeurs formatés (`text_args`,
## `%d` : prélèvement, pages du registre), section **Revenus** (salaire d'Ilan,
## `set_income`), **rations d'air** groupées (« qui respire ce soir ? », proches
## absents grisés), postes défilants, **confirmation** avant une option qui
## termine la campagne (« Embarquer », F6 au J10) ; soirée pivot du J10
## (panneaux des vannes, d'Ilan, du double jeu, de la promotion, du quai 6).
class_name EveningScreen
extends ScreenBase

signal confirmed(lines: Array[ExpenseLine])
signal luciole_decided(report_it: bool)
## M7 : un choix d'événement vient d'être fait (son « ui.* », tests).
signal event_choice_made(event_id: StringName, option_id: StringName)

const LEFT_RATIO: float = 1.25
const REPORT_WIDTH: float = 760.0
## Couleur de liseré par événement (DS §7.10 : Lucioles magenta, Brûlants rouge).
const EVENT_ACCENTS: Dictionary[StringName, Color] = {
	&"d05_heat": DS.ACCENT_MAGENTA, &"d07_tag": DS.ACCENT_MAGENTA, &"d08_package": DS.STATE_RED,
	&"d09_ilan": DS.ACCENT_MAGENTA,
	# Acte II : la Nuit des vannes (J10) et la Commission.
	&"d10_vannes_opened": DS.ACCENT_MAGENTA, &"d10_vannes_aborted": DS.ACCENT_MAGENTA, &"d10_vannes_failed": DS.ACCENT_MAGENTA,
	&"d10_double": DS.STATE_AMBER, &"d10_promo": DS.ACCENT_YELLOW, &"d10_drift": DS.ACCENT_CYAN,
	&"d11_levy": DS.VOICE_COMMISSION, &"d14_lease": DS.VOICE_COMMISSION, &"d17_review": DS.VOICE_COMMISSION,
	&"d17_list": DS.VOICE_COMMISSION, &"d13_scanner": DS.ACCENT_MAGENTA, &"d16_unplug": DS.ACCENT_MAGENTA,
	&"d19_registre": DS.ACCENT_MAGENTA,
}
## Hauteur d'une ligne de dépense (rations : plus compactes, groupées).
const ROW_H: float = 56.0
const RATION_ROW_H: float = 48.0

var day_number: int = 1
var game_date: int = 0
## Solde avant la soirée (crédits du shift déjà inclus).
var balance: int = 0
## Net du shift (affichage du détail du solde).
var shift_net: int = 0
## Avance du Consortium déjà comprise dans `balance` (J1 ; 0 sinon).
var consortium_advance: int = 0
var lines: Array[ExpenseLine] = []
var household: Household = null
var luciole_pending: bool = false
## Prime de signalement reçue ce soir (mot des Lucioles signalé) : déjà
## créditée sur le compte par `Campaign.decide_luciole_note`, ajoutée ici au
## solde disponible pour les postes (QA-008).
var report_bonus: int = 0
var confirm_button: Button = null
## M7 : événements du soir (ordre d'affichage) et choix du joueur.
var events: Array[EveningEvent] = []
var choices: Dictionary[StringName, StringName] = {}
## Panneau d'événement affiché (index dans `events`).
var step: int = 0
## Boutons d'options du panneau courant (`option_id` → bouton).
var option_buttons: Dictionary[StringName, Button] = {}
var next_button: Button = null
var prev_button: Button = null

var _rows: Array[Button] = []
var _spent_label: Label = null
var _available_label: Label = null
var _bonus_row: HBoxContainer = null
var _after_label: Label = null
var _after_hint: Label = null
var _note_card: PanelContainer = null
var _right: VBoxContainer = null
var _report_layer: Control = null
var _report_button: Button = null
var _events_box: VBoxContainer = null
var _event_card: PanelContainer = null
var _events_label: Label = null
var _events_row: HBoxContainer = null
var _confirm_hint: Label = null
var _base_costs: Dictionary[StringName, int] = {}
## Acte II : revenus du soir (salaire d'Ilan), crédités avec la soirée.
var incomes: Array[ExpenseLine] = []
## Acte II : boîte de confirmation d'une option qui termine la campagne.
var confirm_layer: Control = null
var _pending_final: Array[StringName] = []


func setup(p_day: DayDef, p_balance: int, p_shift_net: int, p_lines: Array[ExpenseLine], p_household: Household,
		p_luciole_pending: bool, p_advance: int = 0) -> void:
	day_number = p_day.day_number if p_day != null else 1
	game_date = p_day.game_date if p_day != null else 0
	balance = p_balance
	shift_net = p_shift_net
	lines = p_lines
	household = p_household if p_household != null else Household.new()
	luciole_pending = p_luciole_pending
	consortium_advance = maxi(p_advance, 0)
	_base_costs.clear()
	for line: ExpenseLine in lines:
		_base_costs[line.id] = line.cost


## Acte II : revenus du soir (`EveningService.income_lines`), avant l'entrée dans l'arbre.
func set_income(p_lines: Array[ExpenseLine]) -> void:
	incomes = p_lines.duplicate()


func income_total() -> int:
	var total: int = 0
	for line: ExpenseLine in incomes:
		total += line.cost
	return total


## M7 : événements du soir (`Campaign.prepare_events`), avant l'entrée dans l'arbre.
func set_events(p_events: Array[EveningEvent]) -> void:
	events = p_events.duplicate()
	choices.clear()
	step = 0


func _build() -> void:
	if not events.is_empty():
		# Présélection en tenant compte des événements imposés (retenue d'audit…).
		EveningService.default_selection(lines, effective_balance())
	var page: VBoxContainer = vbox(DS.SPACE_6)
	root_box().add_child(page)
	page.add_child(_header())
	var columns: HBoxContainer = hbox(DS.SPACE_8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var left: VBoxContainer = _budget()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = LEFT_RATIO
	columns.add_child(left)
	_right = vbox(DS.SPACE_5)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_right)
	_right.add_child(_family())
	if not events.is_empty():
		_events_box = vbox(DS.SPACE_3)
		_events_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_right.add_child(_events_box)
		_show_step(0)
	if luciole_pending:
		_note_card = _luciole_note()
		_right.add_child(_note_card)
	page.add_child(_footer())
	_refresh()
	confirm_button.grab_focus.call_deferred()


func _header() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	var top: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(top)
	top.add_child(UiIcon.make(UiIcon.Kind.INFO, DS.TEXT_SECONDARY, DS.ICON_M))
	var org: VBoxContainer = vbox(0)
	top.add_child(org)
	org.add_child(eyebrow(UiText.t("ev_location", "BLOC PÉTREL · ANNEAU C · CABINE 9 m²")))
	org.add_child(label(UiText.t("ev_subtitle", "Couchette triple, réchaud, recycleur d'air bruyant ; dehors, les Anneaux illuminés."), &"CaptionLabel"))
	top.add_child(spacer())
	var time: Label = label(UiText.t("ev_time", "19:40"), &"DataTitle", DS.TEXT_SECONDARY)
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(time)
	box.add_child(rule_line())
	box.add_child(label(UiText.tf("ev_title", [UiText.date_with_weekday(game_date)], "SOIRÉE — %s"), &"DisplayLabel"))
	return box


func _budget() -> VBoxContainer:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.add_child(section(UiText.t("ev_budget", "BUDGET DU FOYER"), UiIcon.Kind.LOGO, DS.ACCENT_YELLOW,
			UiText.t("ev_bank", "BANQUE AUREL")))
	var head: PanelContainer = panel(&"ElevatedCard")
	box.add_child(head)
	var head_box: VBoxContainer = vbox(DS.SPACE_1)
	head.add_child(head_box)
	var morning: int = balance - shift_net - consortium_advance
	if consortium_advance == 0 or morning != 0:
		head_box.add_child(_money_row(UiText.t("ev_morning", "Solde du matin"), credits(morning), DS.TEXT_SECONDARY))
	if consortium_advance > 0:
		head_box.add_child(_money_row(UiText.t("ev_advance", "Avance du Consortium (prise de poste)"),
				credits(consortium_advance, true), DS.ACCENT_YELLOW))
	head_box.add_child(_money_row(UiText.t("ev_shift_net", "Net du shift (salaire − amendes)"), credits(shift_net, true), DS.TEXT_SECONDARY))
	if not incomes.is_empty():
		var income_head: Label = eyebrow(UiText.t("ev_incomes", "REVENUS DU FOYER"), DS.STATE_GREEN)
		income_head.name = "Incomes"
		head_box.add_child(income_head)
		for income: ExpenseLine in incomes:
			head_box.add_child(_money_row(UiText.t(income.label_key, String(income.id)), credits(income.cost, true), DS.STATE_GREEN))
	_bonus_row = _money_row(UiText.t("ev_report_bonus", "Prime de signalement (Consortium)"), "", DS.ACCENT_YELLOW)
	_bonus_row.visible = false
	head_box.add_child(_bonus_row)
	head_box.add_child(rule_line())
	var available_row: HBoxContainer = _money_row(UiText.t("ev_available", "Disponible ce soir"), credits(balance), DS.ACCENT_YELLOW, &"DataTitle")
	_available_label = available_row.get_child(available_row.get_child_count() - 1)
	head_box.add_child(available_row)
	box.add_child(eyebrow(UiText.t("ev_lines", "DÉPENSES DU SOIR — COCHEZ CE QUE VOUS PAYEZ")))
	# Acte II : jusqu'à 12 postes — la liste défile, les totaux restent visibles.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Lines"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list: VBoxContainer = vbox(DS.SPACE_2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rations: Array[ExpenseLine] = []
	for line: ExpenseLine in lines:
		if is_ration(line):
			rations.append(line)
			continue
		var row: Button = _expense_row(line)
		_rows.append(row)
		list.add_child(row)
	if not rations.is_empty():
		list.add_child(_rations_group(rations))
	var totals: PanelContainer = panel(&"ElevatedCard")
	box.add_child(totals)
	var totals_box: VBoxContainer = vbox(DS.SPACE_1)
	totals.add_child(totals_box)
	var spent_row: HBoxContainer = _money_row(UiText.t("ev_spent", "Dépenses"), "", DS.TEXT_PRIMARY)
	_spent_label = spent_row.get_child(spent_row.get_child_count() - 1)
	totals_box.add_child(spent_row)
	_events_row = _money_row(UiText.t("ev_events_total", "Événements du soir"), "", DS.TEXT_PRIMARY)
	_events_label = _events_row.get_child(_events_row.get_child_count() - 1)
	_events_row.visible = not events.is_empty()
	totals_box.add_child(_events_row)
	var after_row: HBoxContainer = _money_row(UiText.t("ev_after", "Solde après la soirée"), "", DS.TEXT_PRIMARY, &"DataTitle")
	_after_label = after_row.get_child(after_row.get_child_count() - 1)
	totals_box.add_child(after_row)
	_after_hint = label("", &"CaptionLabel", DS.STATE_RED)
	_after_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	totals_box.add_child(_after_hint)
	return box


func _money_row(caption: String, value: String, color: Color, value_variation: StringName = &"DocFieldValue") -> HBoxContainer:
	var row: HBoxContainer = hbox(DS.SPACE_3)
	var text: Label = label(caption, &"BodySmall")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	row.add_child(label(value, value_variation, color))
	return row


## Ration d'air (Acte II, M2) : la vôtre ou celle d'un proche.
static func is_ration(line: ExpenseLine) -> bool:
	return line.ration_of != &"" or line.id == EveningService.LINE_RATION_SELF


## Rations groupées : « qui respire ce soir ? », la vôtre prélevée d'office,
## une case par proche présent ; les proches absents ou en attente sont
## rappelés grisés (pas de ration, ACT2 §2.5 M2).
func _rations_group(rations: Array[ExpenseLine]) -> Control:
	var group: PanelContainer = panel()
	group.name = "Rations"
	group.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.BG_PANEL, DS.STATE_AMBER))
	var box: VBoxContainer = vbox(DS.SPACE_2)
	group.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.BREATH, DS.STATE_AMBER, DS.ICON_S))
	head.add_child(eyebrow(UiText.t("ev_rations", "RATIONS D'AIR · QUI RESPIRE CE SOIR ?"), DS.STATE_AMBER))
	for line: ExpenseLine in rations:
		var row: Button = _expense_row(line, RATION_ROW_H)
		_rows.append(row)
		box.add_child(row)
	for member: Household.Member in household.members:
		if member.is_alive() and not member.is_present():
			var absent: HBoxContainer = hbox(DS.SPACE_3)
			absent.name = "Absent_%s" % member.id
			absent.modulate.a = 0.6
			absent.add_child(UiIcon.make(HouseholdView.state_icon(member), DS.TEXT_MUTED, DS.ICON_S))
			var text: Label = label(UiText.tf("ev_ration_absent", [HouseholdView.member_name(member.id), HouseholdView.state_text(member)],
					"%s · %s — pas de ration ce soir"), &"CaptionLabel", DS.TEXT_SECONDARY)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			absent.add_child(text)
			box.add_child(absent)
	return group


## Ligne de dépense : case à cocher DS + libellé + note + coût (bouton bascule).
func _expense_row(line: ExpenseLine, height: float = ROW_H) -> Button:
	var row: Button = Button.new()
	row.name = "Line_%s" % line.id
	row.toggle_mode = true
	row.theme_type_variation = &"ButtonQuestion"
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(0, height)
	row.button_pressed = line.paid
	row.disabled = line.mandatory
	row.set_meta(&"line", line)
	# Cochée = liseré cyan discret (la case porte l'état) ; survol / focus du thème.
	var checked_box: StyleBoxFlat = ThemeBuilder.chamfer_box(DS.BG_ELEVATED.blend(DS.CYAN_08), DS.CYAN_40, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0)
	row.add_theme_stylebox_override(&"pressed", checked_box)
	row.add_theme_stylebox_override(&"disabled", ThemeBuilder.chamfer_box(DS.BG_PANEL, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, DS.SPACE_4)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DS.SPACE_2)
	row.add_child(margin)
	var content: HBoxContainer = hbox(DS.SPACE_4)
	margin.add_child(content)
	var check: CheckMark = CheckMark.new()
	check.name = "Check"
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(check)
	var texts: VBoxContainer = vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(texts)
	var title: String = UiText.t(line.label_key, String(line.id))
	if line.member_id != &"":
		title = title % HouseholdView.member_name(line.member_id) if title.contains("%s") else title
	texts.add_child(label(title, &"BodyStrong"))
	var note: Label = label(UiText.t(line.note_key, ""), &"CaptionLabel")
	note.name = "Note"
	texts.add_child(note)
	if line.mandatory:
		var lock: PanelContainer = chip(UiText.t("ev_mandatory", "PRÉLEVÉE D'OFFICE"), UiIcon.Kind.LOCK, DS.TEXT_SECONDARY)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(lock)
	var cost: Label = label(credits(line.cost), &"DataTitle")
	cost.name = "Cost"
	cost.custom_minimum_size.x = 80.0
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(cost)
	row.toggled.connect(_on_row_toggled.bind(row))
	return row


func _on_row_toggled(pressed: bool, row: Button) -> void:
	var line: ExpenseLine = row.get_meta(&"line")
	if line.mandatory:
		row.set_pressed_no_signal(true)
		return
	if pressed and not EveningService.can_toggle_on(lines, effective_balance(), line):
		row.set_pressed_no_signal(false)
		return
	line.paid = pressed
	_refresh()


## Coche une ligne par son identifiant (tests, raccourcis).
func set_line_paid(id: StringName, paid: bool) -> bool:
	for row: Button in _rows:
		var line: ExpenseLine = row.get_meta(&"line")
		if line.id == id:
			row.button_pressed = paid
			return line.paid == paid
	return false


func _refresh() -> void:
	var spent: int = EveningService.total_spent(lines)
	var delta: int = event_balance_delta()
	var after: int = funds() - spent + delta
	if _available_label != null:
		_available_label.text = credits(funds())
	if _bonus_row != null:
		_bonus_row.visible = report_bonus != 0
		(_bonus_row.get_child(_bonus_row.get_child_count() - 1) as Label).text = credits(report_bonus, true)
	for row: Button in _rows:
		var line: ExpenseLine = row.get_meta(&"line")
		var affordable: bool = EveningService.can_toggle_on(lines, effective_balance(), line)
		var check: CheckMark = row.find_child("Check", true, false)
		check.checked = line.paid
		check.locked = line.mandatory
		var cost: Label = row.find_child("Cost", true, false)
		cost.text = credits(line.cost)
		cost.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY if line.paid else (DS.TEXT_SECONDARY if affordable else DS.TEXT_MUTED))
		var note: Label = row.find_child("Note", true, false)
		if not line.paid and not affordable:
			note.text = UiText.t("ev_insufficient", "Fonds insuffisants")
			note.add_theme_color_override(&"font_color", DS.STATE_AMBER)
		else:
			note.text = UiText.t(line.note_key, "")
			note.remove_theme_color_override(&"font_color")
	_spent_label.text = credits(-spent)
	if _events_label != null:
		_events_label.text = credits(delta, true)
		_events_label.add_theme_color_override(&"font_color", DS.STATE_RED if delta < 0 else (DS.ACCENT_YELLOW if delta > 0 else DS.TEXT_SECONDARY))
	_after_label.text = credits(after)
	_after_label.add_theme_color_override(&"font_color", DS.STATE_RED if after < 0 else DS.ACCENT_YELLOW)
	_after_hint.text = UiText.t("ev_debt_hint", "Dette : trois soirs de suite et l'Autorité de Transit vous réaffecte.") if after < 0 else ""
	_after_hint.visible = after < 0
	_refresh_options()
	_refresh_confirm()


func _family() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.add_child(section(UiText.t("ev_family", "LE FOYER"), UiIcon.Kind.INFO, DS.TEXT_SECONDARY))
	var compact: bool = not events.is_empty()
	for member: Household.Member in household.members:
		box.add_child(HouseholdView.member_card(member, "" if compact else HouseholdView.member_note(member), compact))
	return box


# ---------------------------------------------------------------------------
# M7 : événements du soir
# ---------------------------------------------------------------------------

## Solde disponible pour les postes, événements compris.
func effective_balance() -> int:
	return funds() + event_balance_delta()


## Fonds de la soirée avant dépenses et événements : solde du shift + prime de
## signalement éventuelle + revenus du foyer (Acte II : salaire d'Ilan).
func funds() -> int:
	return balance + report_bonus + income_total()


## Effet net des événements (retenue d'audit, coûts et gains des options).
func event_balance_delta(except_event: StringName = &"") -> int:
	var delta: int = 0
	for event: EveningEvent in events:
		if event.id == except_event or is_skipped(event):
			continue
		if event.kind == EveningEventDef.Kind.AUDIT:
			delta -= SaveService.as_int(event.audit.get("cost", 0))
			continue
		var chosen: StringName = choices.get(event.id, &"")
		var option: EveningOptionDef = event.get_option(chosen)
		if option != null:
			delta += option.gain - option.cost
	return delta


## Fonds disponibles pour une option de `event` (les autres choix comptés).
func available_for(event: EveningEvent) -> int:
	return funds() - EveningService.total_spent(lines) + event_balance_delta(event.id)


## Un audit qui arrête l'agent·e (F1) clôt la soirée : les panneaux suivants sautent.
func is_skipped(event: EveningEvent) -> bool:
	var index: int = events.find(event)
	for i: int in index:
		if events[i].kind == EveningEventDef.Kind.AUDIT and events[i].audit.get("ending", &"") != &"":
			return true
	return false


## Choix encore à faire (événements à choix non tranchés, non sautés).
func pending_choice_count() -> int:
	var count: int = 0
	for event: EveningEvent in events:
		if event.is_choice() and not is_skipped(event) and not choices.has(event.id):
			count += 1
	return count


## Choisit une option ; faux si elle n'existe pas ou n'est pas finançable.
func choose(event_id: StringName, option_id: StringName) -> bool:
	var event: EveningEvent = get_event(event_id)
	if event == null or not event.is_choice() or is_skipped(event) or _report_layer != null:
		return false
	var option: EveningOptionDef = event.get_option(option_id)
	if option == null or not can_afford(event, option):
		return false
	choices[event_id] = option_id
	_apply_choice_costs()
	event_choice_made.emit(event_id, option_id)
	_refresh()
	return true


## Option finançable : gratuite, ou couverte par les fonds restants
## (`EveningService.can_choose`) — une option sans coût reste toujours possible,
## même à découvert.
func can_afford(event: EveningEvent, option: EveningOptionDef) -> bool:
	return option != null and (option.cost <= 0 or EveningService.can_choose(option, available_for(event)))


func get_event(event_id: StringName) -> EveningEvent:
	for event: EveningEvent in events:
		if event.id == event_id:
			return event
	return null


## Choix du joueur, complétés par les choix par défaut (D-058) pour ceux
## qui restent (validation sans tout trancher).
func get_choices() -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = choices.duplicate()
	if pending_choice_count() == 0:
		return result
	var undecided: Array[EveningEvent] = []
	for event: EveningEvent in events:
		if event.is_choice() and not result.has(event.id) and not is_skipped(event):
			undecided.append(event)
	var defaults: Dictionary[StringName, StringName] = EveningService.default_choices(undecided,
			funds() - EveningService.total_spent(lines) + event_balance_delta())
	for id: StringName in defaults:
		result[id] = defaults[id]
	return result


## Coûts des postes : base du soir puis effets des choix (chauffage offert…).
func _apply_choice_costs() -> void:
	for line: ExpenseLine in lines:
		if _base_costs.has(line.id):
			line.cost = _base_costs[line.id]
	EveningService.apply_line_costs(lines, events, choices)
	for line: ExpenseLine in lines:
		if line.cost == 0 and not line.paid:
			line.paid = true # offert : coché d'office


func _event_accent(event: EveningEvent) -> Color:
	if EVENT_ACCENTS.has(event.id):
		return EVENT_ACCENTS[event.id]
	match event.kind:
		EveningEventDef.Kind.AUDIT:
			return DS.ACCENT_YELLOW
		EveningEventDef.Kind.LETTER:
			return DS.TEXT_SECONDARY
	return DS.ACCENT_CYAN


## Texte d'un événement, valeurs (`text_args`) substituées aux `%d` dans
## l'ordre ; jamais de `%d` brut à l'écran (valeur manquante : « — »).
static func event_text(event: EveningEvent) -> String:
	return format_args(UiText.t(event.text_key, ""), event.text_args)


## Substitue `%d` / `%s` dans l'ordre (sans erreur si le nombre diffère).
static func format_args(text: String, args: Array) -> String:
	var result: String = ""
	var index: int = 0
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		if c == "%" and i + 1 < text.length():
			var spec: String = text[i + 1]
			if spec == "d" or spec == "s":
				result += str(args[index]) if index < args.size() else "—"
				index += 1
				i += 2
				continue
			if spec == "%":
				result += "%"
				i += 2
				continue
		result += c
		i += 1
	return result


func show_step(index: int) -> void:
	_show_step(index)


## Panneau de l'événement `index` (séquence, J9 : audit → aveu → déposition → départ).
func _show_step(index: int) -> void:
	if _events_box == null or events.is_empty():
		return
	step = clampi(index, 0, events.size() - 1)
	for child: Node in _events_box.get_children():
		child.queue_free()
	option_buttons.clear()
	var event: EveningEvent = events[step]
	var accent: Color = _event_accent(event)
	_events_box.add_child(section(UiText.t("ev_events", "CE SOIR"), UiIcon.Kind.CHAT, accent,
			UiText.tf("ev_event_step", [step + 1, events.size()], "%d / %d")))
	_event_card = panel()
	_event_card.name = "EventCard"
	_event_card.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.BG_ELEVATED, accent))
	_event_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_events_box.add_child(_event_card)
	var box: VBoxContainer = vbox(DS.SPACE_3)
	_event_card.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(_step_dots(accent))
	head.add_child(spacer())
	var kind_key: String = ["ev_kind_letter", "ev_kind_choice", "ev_kind_audit"][event.kind]
	head.add_child(eyebrow(UiText.t(kind_key, "LETTRE"), accent))
	if not event.title_key.is_empty():
		var title: Label = label(UiText.t(event.title_key, String(event.id)), &"PanelTitle", DS.TEXT_PRIMARY)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.x = 120.0
		box.add_child(title)
	if not event.text_key.is_empty():
		var body: Label = wrapped(event_text(event), &"BodyLabel", DS.TEXT_PRIMARY)
		body.name = "EventText"
		box.add_child(body)
	for key: String in event.extra_keys:
		box.add_child(wrapped(UiText.t(key, ""), &"BodySmall"))
	if is_skipped(event):
		box.add_child(wrapped(UiText.t("ev_event_skipped", "Cette nuit-là, vous ne rentrez pas au Bloc Pétrel."), &"BodySmall", DS.STATE_RED))
	elif event.kind == EveningEventDef.Kind.AUDIT:
		box.add_child(_audit_result(event))
	elif event.is_choice():
		var options: VBoxContainer = vbox(DS.SPACE_2)
		box.add_child(options)
		var group: ButtonGroup = ButtonGroup.new()
		for option: EveningOptionDef in event.options:
			var option_row: Button = _option_row(event, option, group)
			option_buttons[option.id] = option_row
			options.add_child(option_row)
	box.add_child(spacer(false, true))
	var nav: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(nav)
	prev_button = button(UiText.t("ev_event_prev", "◀ PRÉCÉDENT"), &"ButtonGhost")
	prev_button.visible = step > 0
	prev_button.pressed.connect(func() -> void: _show_step(step - 1))
	nav.add_child(prev_button)
	nav.add_child(spacer())
	next_button = button(UiText.t("ev_event_next", "SUIVANT ▶"), &"ButtonTool")
	next_button.visible = step < events.size() - 1
	next_button.pressed.connect(func() -> void: _show_step(step + 1))
	nav.add_child(next_button)
	_refresh_options()
	_refresh_confirm()


func _step_dots(accent: Color) -> Control:
	var dots: Control = Control.new()
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.custom_minimum_size = Vector2(events.size() * DS.SPACE_4, DS.SPACE_3)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.draw.connect(func() -> void:
		for i: int in events.size():
			var c: Vector2 = Vector2(DS.SPACE_2 + DS.SPACE_4 * i, dots.size.y * 0.5)
			var done: bool = not events[i].is_choice() or choices.has(events[i].id)
			var diamond: PackedVector2Array = [c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]
			if i == step:
				dots.draw_colored_polygon(diamond, accent)
			else:
				diamond.append(diamond[0])
				dots.draw_polyline(diamond, accent if done else DS.TEXT_MUTED, 1.5))
	return dots


func _audit_result(event: EveningEvent) -> Control:
	var outcome: Dictionary = event.audit
	var ending: StringName = outcome.get("ending", &"")
	var cost: int = SaveService.as_int(outcome.get("cost", 0))
	var color: Color = DS.STATE_RED if ending != &"" else (DS.STATE_AMBER if cost > 0 else DS.ACCENT_CYAN)
	var card: PanelContainer = panel()
	card.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(Color(color, 0.12), color, DS.BORDER_HAIRLINE, DS.CHAMFER_S, DS.SPACE_3))
	var row: HBoxContainer = hbox(DS.SPACE_3)
	card.add_child(row)
	row.add_child(UiIcon.make(UiIcon.Kind.DENIED if ending != &"" else (UiIcon.Kind.WARNING if cost > 0 else UiIcon.Kind.CHECK), color, DS.ICON_M))
	var text: Label = wrapped(UiText.t(str(outcome.get("result_key", "")), ""), &"BodyLabel", DS.TEXT_PRIMARY)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if cost > 0:
		var amount: Label = label(credits(-cost), &"DataTitle", color)
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(amount)
	return card


## Option d'un choix : bouton exclusif, libellé, coût ou gain, raison si grisée.
func _option_row(event: EveningEvent, option: EveningOptionDef, group: ButtonGroup) -> Button:
	var row: Button = Button.new()
	row.name = "Option_%s" % option.id
	row.toggle_mode = true
	row.button_group = group
	row.theme_type_variation = &"ButtonQuestion"
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(0, 52)
	row.set_meta(&"option", option)
	row.set_meta(&"event", event.id)
	row.add_theme_stylebox_override(&"pressed", ThemeBuilder.chamfer_box(DS.BG_ELEVATED.blend(DS.CYAN_12), DS.ACCENT_CYAN,
			DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", DS.SPACE_4)
	margin.add_theme_constant_override("margin_right", DS.SPACE_4)
	margin.add_theme_constant_override("margin_top", DS.SPACE_1)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_1)
	row.add_child(margin)
	var content: HBoxContainer = hbox(DS.SPACE_3)
	margin.add_child(content)
	var check: CheckMark = CheckMark.new()
	check.name = "Check"
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(check)
	var texts: VBoxContainer = vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(texts)
	var title: Label = label(UiText.t(option.label_key, String(option.id)), &"BodyStrong")
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 120.0
	texts.add_child(title)
	var reason: Label = label("", &"CaptionLabel", DS.STATE_AMBER)
	reason.name = "Reason"
	reason.visible = false
	texts.add_child(reason)
	if option.ends_campaign != &"":
		var final_chip: PanelContainer = chip(UiText.t("ev_option_final", "FIN DE LA CAMPAGNE"), UiIcon.Kind.WARNING, DS.STATE_AMBER)
		final_chip.name = "FinalChip"
		final_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(final_chip)
	if option.cost != 0 or option.gain != 0:
		var amount: Label = label(credits(option.gain - option.cost, true), &"DataTitle")
		amount.name = "Amount"
		amount.custom_minimum_size.x = 72.0
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(amount)
	row.pressed.connect(func() -> void:
		if not request_choice(event.id, option.id):
			_refresh_options())
	return row


## Choix du joueur (bouton) : une option qui termine la campagne demande
## d'abord une confirmation explicite (« Embarquer », F6 au J10) ; les autres
## sont appliquées tout de suite (`choose`).
func request_choice(event_id: StringName, option_id: StringName) -> bool:
	var event: EveningEvent = get_event(event_id)
	var option: EveningOptionDef = event.get_option(option_id) if event != null else null
	if option == null:
		return false
	if option.ends_campaign != &"" and choices.get(event_id, &"") != option_id:
		if event.is_choice() and can_afford(event, option) and not is_skipped(event) and _report_layer == null:
			_open_final_confirm(event, option)
		return false
	return choose(event_id, option_id)


## Boîte « Quitter Halcyon ? » : CONFIRMER applique le choix, ANNULER le laisse en suspens.
func _open_final_confirm(event: EveningEvent, option: EveningOptionDef) -> void:
	close_final_confirm()
	_pending_final = [event.id, option.id]
	confirm_layer = Control.new()
	confirm_layer.name = "FinalConfirm"
	confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm_layer)
	var scrim: ColorRect = ColorRect.new()
	scrim.color = DS.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)
	var card: PanelContainer = panel(&"HoloPanel")
	card.custom_minimum_size.x = 640.0
	center.add_child(card)
	var box: VBoxContainer = vbox(DS.SPACE_4)
	card.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.WARNING, DS.STATE_AMBER, DS.ICON_M))
	head.add_child(eyebrow(UiText.t("ev_final_eyebrow", "DÉCISION DÉFINITIVE"), DS.STATE_AMBER))
	var title: Label = label(UiText.t("ev_final_title", "QUITTER HALCYON ?"), &"DisplayLabel", DS.TEXT_PRIMARY)
	title.name = "FinalTitle"
	box.add_child(title)
	var choice: Label = wrapped("« %s »" % UiText.t(option.label_key, String(option.id)), &"BodyStrong", DS.STATE_AMBER)
	choice.custom_minimum_size.x = 400.0
	box.add_child(choice)
	box.add_child(wrapped(UiText.t("ev_final_text", "La partie s'arrête ce soir : vous quittez Halcyon, et le Guichet 04 ne rouvrira pas pour vous."),
			&"BodyLabel", DS.TEXT_PRIMARY))
	var buttons: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(buttons)
	buttons.add_child(spacer())
	var cancel: Button = button(UiText.t("ev_final_cancel", "RESTER ENCORE UN PEU"), &"ButtonGhost")
	cancel.name = "Cancel"
	cancel.pressed.connect(close_final_confirm)
	buttons.add_child(cancel)
	var accept: Button = button(UiText.t("ev_final_accept", "CONFIRMER LE DÉPART"), &"ButtonDanger")
	accept.name = "Accept"
	accept.pressed.connect(accept_final_confirm)
	buttons.add_child(accept)
	cancel.grab_focus.call_deferred()


## Confirme l'option en attente (bouton CONFIRMER, tests).
func accept_final_confirm() -> bool:
	if _pending_final.size() != 2:
		return false
	var event_id: StringName = _pending_final[0]
	var option_id: StringName = _pending_final[1]
	close_final_confirm()
	return choose(event_id, option_id)


func close_final_confirm() -> void:
	_pending_final.clear()
	if confirm_layer != null:
		confirm_layer.queue_free()
		confirm_layer = null
	_refresh_options()


func _refresh_options() -> void:
	if events.is_empty() or option_buttons.is_empty():
		return
	var event: EveningEvent = events[step]
	var chosen: StringName = choices.get(event.id, &"")
	for id: StringName in option_buttons:
		var row: Button = option_buttons[id]
		if not is_instance_valid(row):
			continue
		var option: EveningOptionDef = row.get_meta(&"option")
		var affordable: bool = can_afford(event, option)
		row.set_pressed_no_signal(id == chosen)
		row.disabled = not affordable and id != chosen
		var check: CheckMark = row.find_child("Check", true, false)
		check.checked = id == chosen
		check.locked = row.disabled
		var title: Label = row.find_child("Title", true, false)
		title.add_theme_color_override(&"font_color", DS.TEXT_MUTED if row.disabled else (DS.ACCENT_CYAN if id == chosen else DS.TEXT_PRIMARY))
		var reason: Label = row.find_child("Reason", true, false)
		reason.visible = row.disabled
		reason.text = UiText.tf("ev_option_insufficient", [credits(option.cost)], "Fonds insuffisants : %s requis") if row.disabled else ""
		var amount: Label = row.find_child("Amount", true, false) as Label
		if amount != null:
			var net: int = option.gain - option.cost
			amount.add_theme_color_override(&"font_color", DS.TEXT_MUTED if row.disabled else (DS.ACCENT_YELLOW if net > 0 else DS.TEXT_PRIMARY))
	if next_button != null and is_instance_valid(next_button):
		next_button.disabled = event.is_choice() and not choices.has(event.id) and not is_skipped(event)


func _refresh_confirm() -> void:
	if confirm_button == null:
		return
	var pending: int = pending_choice_count()
	confirm_button.disabled = pending > 0 or _report_layer != null
	if _confirm_hint != null:
		_confirm_hint.text = UiText.plural("ev_events_pending", pending, "%d décision à prendre ce soir",
				"%d décisions à prendre ce soir") if pending > 0 else UiText.t("ev_hint", "Ce qui n'est pas payé a des conséquences dès cette nuit.")
		_confirm_hint.add_theme_color_override(&"font_color", DS.STATE_AMBER if pending > 0 else DS.TEXT_SECONDARY)


func _luciole_note() -> PanelContainer:
	var card: PanelContainer = panel()
	card.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.MAGENTA_12, DS.ACCENT_MAGENTA))
	var box: VBoxContainer = vbox(DS.SPACE_2)
	card.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.DISCORDANCE, DS.ACCENT_MAGENTA, DS.ICON_S))
	head.add_child(eyebrow(UiText.t("ev_note_title", "LE MOT GLISSÉ AU GUICHET"), DS.ACCENT_MAGENTA))
	box.add_child(wrapped(UiText.t("ev_note_text", ""), &"BodyLabel"))
	box.add_child(wrapped(UiText.t("ev_note_choice", ""), &"BodySmall"))
	var buttons: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(buttons)
	var report_button: Button = button(UiText.t("ev_note_report", "SIGNALER AU CONSORTIUM") + "  " +
			credits(DataCatalog.load_economy().report_bonus, true))
	report_button.pressed.connect(_decide_luciole.bind(true))
	buttons.add_child(report_button)
	var burn_button: Button = button(UiText.t("ev_note_burn", "BRÛLER LE MOT"))
	burn_button.pressed.connect(_decide_luciole.bind(false))
	buttons.add_child(burn_button)
	return card


func _decide_luciole(report_it: bool) -> void:
	if not luciole_pending:
		return
	luciole_pending = false
	luciole_decided.emit(report_it)
	if report_it:
		report_bonus += DataCatalog.load_economy().report_bonus
	if _note_card != null:
		_note_card.queue_free()
		_note_card = null
		_right.add_child(wrapped(UiText.t("ev_note_reported" if report_it else "ev_note_burned", ""), &"BodySmall", DS.TEXT_SECONDARY))
	if _spent_label != null:
		_refresh()
	confirm_button.grab_focus()


func _footer() -> Control:
	var row: HBoxContainer = hbox(DS.SPACE_4)
	var hint: Label = label(UiText.t("ev_hint", "Ce qui n'est pas payé a des conséquences dès cette nuit."), &"CaptionLabel")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_confirm_hint = hint
	row.add_child(hint)
	row.add_child(spacer())
	confirm_button = button(UiText.t("ev_confirm", "VALIDER ET DORMIR"), &"ButtonPrimary")
	confirm_button.custom_minimum_size.x = 320.0
	confirm_button.pressed.connect(confirm)
	row.add_child(confirm_button)
	return row


## Valide les dépenses (le mot non tranché est brûlé en silence).
func confirm() -> void:
	if _report_layer != null:
		return
	if luciole_pending:
		_decide_luciole(false)
	for row: Button in _rows:
		row.disabled = true
	confirm_button.disabled = true
	# Choix non tranchés : choix par défaut (refus / neutre, D-058).
	choices = get_choices()
	_apply_choice_costs()
	for button_row: Button in option_buttons.values():
		if is_instance_valid(button_row):
			button_row.disabled = true
	confirmed.emit(lines)


## Conséquences de la nuit ; `ending` vide → « JOUR SUIVANT ».
func show_report(report: EveningReport, ending: StringName) -> void:
	_report_layer = Control.new()
	_report_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_report_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_report_layer)
	var scrim: ColorRect = ColorRect.new()
	scrim.color = DS.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_report_layer.add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_report_layer.add_child(center)
	var card: PanelContainer = panel(&"HoloPanel")
	card.custom_minimum_size.x = REPORT_WIDTH
	center.add_child(card)
	var box: VBoxContainer = vbox(DS.SPACE_4)
	card.add_child(box)
	box.add_child(eyebrow(UiText.t("ev_night", "LA NUIT AU BLOC PÉTREL")))
	box.add_child(label(UiText.tf("ev_night_balance", [credits(report.balance_after)], "Solde : %s"), &"DataTitle",
			DS.STATE_RED if report.balance_after < 0 else DS.ACCENT_YELLOW))
	for event: Dictionary in report.events:
		box.add_child(_event_row(event))
	var members: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(members)
	for member: Household.Member in report.household.members:
		members.add_child(HouseholdView.member_card(member, "", true))
	var row: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(row)
	row.add_child(spacer())
	var key: String = "ev_next_day"
	if ending == Campaign.ENDING_DEMO_COMPLETE:
		key = "ev_to_demo_end"
	elif ending != EveningReport.ENDING_NONE:
		key = "ev_to_ending"
	_report_button = button(UiText.t(key, "JOUR SUIVANT"), &"ButtonPrimary")
	_report_button.custom_minimum_size.x = 280.0
	_report_button.pressed.connect(close.bind(ending if ending != EveningReport.ENDING_NONE else &"next"))
	row.add_child(_report_button)
	_report_button.grab_focus.call_deferred()


func get_report_button() -> Button:
	return _report_button


func _event_row(event: Dictionary) -> Control:
	var tone: EveningReport.Tone = event["tone"]
	var color: Color = DS.TEXT_SECONDARY
	var icon: UiIcon.Kind = UiIcon.Kind.INFO
	match tone:
		EveningReport.Tone.GOOD:
			color = DS.ACCENT_CYAN
			icon = UiIcon.Kind.CHECK
		EveningReport.Tone.WARNING:
			color = DS.STATE_AMBER
			icon = UiIcon.Kind.WARNING
		EveningReport.Tone.BAD:
			color = DS.STATE_RED
			icon = UiIcon.Kind.DENIED
	var row: HBoxContainer = hbox(DS.SPACE_3)
	row.add_child(UiIcon.make(icon, color, DS.ICON_S))
	var member: StringName = event["member"]
	var key: String = event["key"]
	var text: String = UiText.t(key, key)
	if text.contains("%s"):
		text = text % HouseholdView.member_name(member)
	row.add_child(wrapped(text, &"BodyLabel"))
	return row


## Case à cocher DS : carré chanfreiné, coche cyan, cadenas si verrouillée.
class CheckMark:
	extends Control

	const SIZE: float = 22.0

	var checked: bool = false:
		set(value):
			checked = value
			queue_redraw()
	var locked: bool = false:
		set(value):
			locked = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE, SIZE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
		var c: float = DS.CHAMFER_S
		var outline: PackedVector2Array = PackedVector2Array([Vector2(c, 0), Vector2(SIZE, 0), Vector2(SIZE, SIZE - c),
				Vector2(SIZE - c, SIZE), Vector2(0, SIZE), Vector2(0, c), Vector2(c, 0)])
		var color: Color = DS.ACCENT_CYAN if checked else DS.TEXT_SECONDARY
		if locked:
			color = DS.TEXT_SECONDARY
		if checked:
			var fill: Color = color
			fill.a = 0.24
			draw_colored_polygon(outline, fill)
		draw_polyline(outline, color, DS.ICON_STROKE)
		if checked:
			UiIcon.draw_icon(self, UiIcon.Kind.CHECK, r.grow(-3.0), color, 2.0)
