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
## M9 (Acte III, ARCHITECTURE §7.3) : **carte « FIN DE L'ACTE II »** plein cadre
## à l'ouverture de la soirée pivot du J20 (événement `d20_card_<climat>` :
## titre de la fin de l'Acte II + 2 lignes, ≈ 3 s, passable), « Embarquer »
## confirmé comme au J10 ; panneaux de l'**Enquête** (questions de Ravel J22,
## J26, J28 : voix ambre, balance) ; **Déposition** du J29 mise en scène — le
## verdict reste « en délibéré » tant que la déposition n'est pas choisie, puis
## il est recalculé avec le choix (`audit_preview`) et révélé (arrestation,
## blâme, rien à retenir) ; aides du soir versées par lettre (rappel des
## salaires, caisse des vitres) comptées dans les revenus.
## M13 (lot C, I38) : **Économat du Hall** (`ShopView`) sous les dépenses à
## partir du soir du J5 : offres (`ExpenseLine.upgrade_id`), jamais cochées,
## un achat par soir, sans crédit, effet et prix narratif écrits, solde après
## achat ; améliorations acquises rappelées ; la nuit nomme l'achat
## (`EveningReport.upgrades_bought`, effet dès le shift suivant).
class_name EveningScreen
extends ScreenBase

signal confirmed(lines: Array[ExpenseLine])
signal luciole_decided(report_it: bool)
## M7 : un choix d'événement vient d'être fait (son « ui.* », tests).
signal event_choice_made(event_id: StringName, option_id: StringName)

const LEFT_RATIO: float = 1.25
const REPORT_WIDTH: float = 760.0
## Couleur de liseré par événement (DS §7.10 : Lucioles magenta, Brûlants rouge).
const EVENT_ACCENTS: Dictionary[StringName, StringName] = {
	&"d05_heat": &"ACCENT_MAGENTA", &"d07_tag": &"ACCENT_MAGENTA", &"d08_package": &"STATE_RED",
	&"d09_ilan": &"ACCENT_MAGENTA",
	# Acte II : la Nuit des vannes (J10) et la Commission.
	&"d10_vannes_opened": &"ACCENT_MAGENTA", &"d10_vannes_aborted": &"ACCENT_MAGENTA", &"d10_vannes_failed": &"ACCENT_MAGENTA",
	&"d10_double": &"STATE_AMBER", &"d10_promo": &"ACCENT_YELLOW", &"d10_drift": &"ACCENT_CYAN",
	&"d11_levy": &"VOICE_COMMISSION", &"d14_lease": &"VOICE_COMMISSION", &"d17_review": &"VOICE_COMMISSION",
	&"d17_list": &"VOICE_COMMISSION", &"d13_scanner": &"ACCENT_MAGENTA", &"d16_unplug": &"ACCENT_MAGENTA",
	&"d19_registre": &"ACCENT_MAGENTA",
	# Acte III : l'Enquête (Ravel, voix INSPECTION ambre), l'Arbitre (registre).
	&"d22_q1": &"STATE_AMBER", &"d26_q2": &"STATE_AMBER", &"d28_q3": &"STATE_AMBER",
	&"d29_deposition": &"STATE_AMBER", &"d29_verdict": &"STATE_AMBER", &"d20_double": &"STATE_AMBER",
	&"d20_flat": &"ACCENT_YELLOW", &"d20_drift": &"ACCENT_CYAN", &"d20_drift_refused": &"ACCENT_CYAN",
	&"d21_loan": &"VOICE_COMMISSION", &"d27_loan": &"VOICE_COMMISSION", &"d25_levy": &"VOICE_COMMISSION",
}
## Acte III : carte de fin d'acte (J20, panneau 0) — préfixe des événements,
## durée de lecture avant de passer seule (ACT3 §1.2 : « 3 s, passable »).
const ACT_CARD_PREFIX: String = "d20_card_"
const ACT_CARD_HOLD_SEC: float = DS.DUR_DRAMATIC * 5.0
## Climat de la carte → fin de l'Acte II correspondante (couleur, icône).
const ACT_CARD_ENDINGS: Dictionary[String, StringName] = {
	"vanne": EndingService.F5_AIR, "brulants": EndingService.F5_AIR, "vitres": EndingService.F9_STRIKE,
	"registre": EndingService.F8_REGISTRE, "promu": EndingService.F4_GLORY, "statu_quo": EndingService.F7_REOPENS,
}
## Acte III : panneaux de l'Enquête (locuteur « ENQUÊTE · C. RAVEL »).
const ENQUETE_EVENTS: Array[StringName] = [&"d22_q1", &"d26_q2", &"d28_q3", &"d29_deposition", &"d29_verdict"]
## Acte III : aides versées par lettre → libellé de revenu.
const LETTER_INCOME_KEYS: Dictionary[StringName, String] = {&"d21_recall": "inc_recall", &"d23_fund": "inc_vitres_fund"}
## M13 (QA-069, M13 §3.5) : messages remis au rapport de la nuit / à l'audit,
## signés (locuteur, voix du briefing) : `{clé du texte: [locuteur, voix]}`.
const SIGNED_MESSAGES: Dictionary[String, Array] = {
	"msg_okonkwo_drawer_found": ["spk_okonkwo", BriefingContent.Voice.MENTOR],
}
## Hauteur d'une ligne de dépense (rations : plus compactes, groupées).
## Compactes (QA-034) : libellé et note sur une ligne quand la largeur le
## permet (repli sinon) ; foyer complet + 4 rations tiennent sans défiler en
## 1080p ; la ligne grandit avec son contenu (texte 1,5). ≥ `HIT_TARGET_MIN`.
const ROW_H: float = 44.0
const RATION_ROW_H: float = 40.0

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
## Liste des dépenses (défile au-delà de sa hauteur) et indice « plus bas ».
var _lines_scroll: ScrollContainer = null
var _more_hint: Label = null
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
## M13 : Économat (null sans offre ni amélioration acquise) et ses données.
var shop: ShopView = null
var economy: EconomyDef = null
var shop_flags: Dictionary[StringName, Variant] = {}
## Acte II : revenus du soir (salaire d'Ilan), crédités avec la soirée.
var incomes: Array[ExpenseLine] = []
## Acte II : boîte de confirmation d'une option qui termine la campagne.
var confirm_layer: Control = null
var _pending_final: Array[StringName] = []
## Acte III : carte « FIN DE L'ACTE II » affichée (null sinon) ; elle passe
## seule après `ACT_CARD_HOLD_SEC` sauf si `act_card_auto_close` est faux.
var act_card_layer: Control = null
var act_card_auto_close: bool = true
var _act_card_button: Button = null
## Acte III : recalcule les audits qui dépendent des choix du soir (Déposition) :
## `func(choices: Dictionary[StringName, StringName]) -> void` (la scène passe
## par `Campaign.preview_evening`, qui met `EveningEvent.audit` à jour).
var audit_preview: Callable = Callable()


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


## Manette / clavier (M11) : carte de fin d'acte, rapport, puis bouton de
## validation de la soirée.
func default_focus() -> Control:
	for candidate: Button in [_act_card_button, _report_button, confirm_button, next_button]:
		if candidate != null and is_instance_valid(candidate) and candidate.is_visible_in_tree() and not candidate.disabled:
			return candidate
	return null


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
	# Colonne de droite défilante (QA-034) : au texte 1,5 en 1080p, foyer +
	# Déposition dépassent la hauteur ; la page (et VALIDER ET DORMIR) reste à l'écran.
	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.name = "RightColumn"
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.follow_focus = true
	columns.add_child(right_scroll)
	_right = vbox(DS.SPACE_5)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_right)
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
	var card: EveningEvent = act_card_event()
	if card != null:
		_open_act_card(card)


func _header() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	var top: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(top)
	top.add_child(UiIcon.make(UiIcon.Kind.INFO, Palette.TEXT_SECONDARY, DS.ICON_M))
	var org: VBoxContainer = vbox(0)
	top.add_child(org)
	org.add_child(eyebrow(UiText.t("ev_location", "BLOC PÉTREL · ANNEAU C · CABINE 9 m²")))
	org.add_child(label(UiText.t("ev_subtitle", "Couchette triple, réchaud, recycleur d'air bruyant ; dehors, les Anneaux illuminés."), &"CaptionLabel"))
	top.add_child(spacer())
	var time: Label = label(UiText.t("ev_time", "19:40"), &"DataTitle", Palette.TEXT_SECONDARY)
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
		head_box.add_child(_money_row(UiText.t("ev_morning", "Solde du matin"), credits(morning), Palette.TEXT_SECONDARY))
	if consortium_advance > 0:
		head_box.add_child(_money_row(UiText.t("ev_advance", "Avance du Consortium (prise de poste)"),
				credits(consortium_advance, true), DS.ACCENT_YELLOW))
	head_box.add_child(_money_row(UiText.t("ev_shift_net", "Net du shift (salaire − amendes)"), credits(shift_net, true), Palette.TEXT_SECONDARY))
	var letter_incomes: Array[EveningEvent] = []
	for event: EveningEvent in events:
		if letter_gain(event) > 0:
			letter_incomes.append(event)
	if not incomes.is_empty() or not letter_incomes.is_empty():
		var income_head: Label = eyebrow(UiText.t("ev_incomes", "REVENUS DU FOYER"), Palette.STATE_GREEN)
		income_head.name = "Incomes"
		head_box.add_child(income_head)
		for income: ExpenseLine in incomes:
			var income_row: HBoxContainer = _money_row(UiText.t(income.label_key, String(income.id)), credits(income.cost, true),
					Palette.STATE_GREEN)
			income_row.name = "Income_%s" % income.id
			head_box.add_child(income_row)
		# Acte III : aides versées par une lettre du soir (rappel, caisse des vitres).
		for event: EveningEvent in letter_incomes:
			var key: String = LETTER_INCOME_KEYS.get(event.id, event.title_key)
			var gain_row: HBoxContainer = _money_row(UiText.t(key, String(event.id)), credits(letter_gain(event), true), Palette.STATE_GREEN)
			gain_row.name = "Income_%s" % event.id
			head_box.add_child(gain_row)
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
	_lines_scroll = scroll
	# Indice visible quand des postes sont sous le bord (QA-034) : un poste non
	# vu (la ration d'un proche) ne passe jamais pour absent.
	_more_hint = label("", &"CaptionLabel", Palette.STATE_AMBER)
	_more_hint.name = "MoreLines"
	_more_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more_hint.visible = false
	box.add_child(_more_hint)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _update_more_hint())
	scroll.resized.connect(_update_more_hint.call_deferred)
	list.resized.connect(_update_more_hint.call_deferred)
	var rations: Array[ExpenseLine] = []
	for line: ExpenseLine in lines:
		if is_ration(line):
			rations.append(line)
			continue
		if line.upgrade_id != &"":
			continue
		var row: Button = _expense_row(line)
		_rows.append(row)
		list.add_child(row)
	if not rations.is_empty():
		list.add_child(_rations_group(rations))
	_build_shop(list)
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
	_after_hint = label("", &"CaptionLabel", Palette.STATE_RED)
	_after_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	totals_box.add_child(_after_hint)
	return box


## M13 : Économat du Hall sous les dépenses du foyer (même liste défilante).
func _build_shop(list: VBoxContainer) -> void:
	if economy == null:
		economy = DataCatalog.load_economy()
	if shop_flags.is_empty():
		shop_flags = GameState.narrative_flags
	var offers: Array[ExpenseLine] = []
	for line: ExpenseLine in lines:
		if line.upgrade_id != &"":
			line.paid = false # jamais présélectionnée (D-150)
			offers.append(line)
	if not ShopView.has_content(offers, economy, shop_flags, day_number):
		return
	shop = ShopView.new()
	shop.setup(offers, economy, shop_flags, day_number)
	shop.line_toggled.connect(_on_shop_toggled)
	list.add_child(shop)


## Achats possibles ce soir (`EconomyDef.upgrades_per_evening`, 1 par défaut).
func max_upgrades() -> int:
	return economy.upgrades_per_evening if economy != null else 1


func _on_shop_toggled(line: ExpenseLine, pressed: bool) -> void:
	if pressed and not EveningService.can_toggle_on(lines, effective_balance(), line, max_upgrades()):
		_refresh()
		return
	line.paid = pressed
	_refresh()


func _money_row(caption: String, value: String, color: Color, value_variation: StringName = &"DocFieldValue") -> HBoxContainer:
	var row: HBoxContainer = hbox(DS.SPACE_3)
	var text: Label = label(caption, &"BodySmall")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	row.add_child(label(value, value_variation, color))
	return row


## « ▼ n postes plus bas » sous la liste tant que des postes sont sous le bord.
func _update_more_hint() -> void:
	if _lines_scroll == null or _more_hint == null or not is_instance_valid(_lines_scroll):
		return
	var view: Rect2 = _lines_scroll.get_global_rect().grow(1.0)
	var below: int = 0
	var all_rows: Array[Button] = _rows.duplicate()
	if shop != null and is_instance_valid(shop):
		all_rows.append_array(shop.rows)
	for row: Button in all_rows:
		if is_instance_valid(row) and row.get_global_rect().end.y > view.end.y:
			below += 1
	_more_hint.text = UiText.plural("ev_more_lines", below, "▼ %d poste plus bas — faites défiler",
			"▼ %d postes plus bas — faites défiler")
	_more_hint.visible = below > 0


## Ration d'air (Acte II, M2) : la vôtre ou celle d'un proche.
static func is_ration(line: ExpenseLine) -> bool:
	return line.ration_of != &"" or line.id == EveningService.LINE_RATION_SELF


## Rations groupées : « qui respire ce soir ? », la vôtre prélevée d'office,
## une case par proche présent ; les proches absents ou en attente sont
## rappelés grisés (pas de ration, ACT2 §2.5 M2).
func _rations_group(rations: Array[ExpenseLine]) -> Control:
	var group: PanelContainer = panel()
	group.name = "Rations"
	group.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(DS.BG_PANEL, Palette.STATE_AMBER))
	var box: VBoxContainer = vbox(DS.SPACE_1)
	group.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.BREATH, Palette.STATE_AMBER, DS.ICON_S))
	head.add_child(eyebrow(UiText.t("ev_rations", "RATIONS D'AIR · QUI RESPIRE CE SOIR ?"), Palette.STATE_AMBER))
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
					"%s · %s — pas de ration ce soir"), &"CaptionLabel", Palette.TEXT_SECONDARY)
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
	row.add_theme_stylebox_override(&"disabled", ThemeBuilder.chamfer_box(DS.BG_PANEL, Palette.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0))
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, DS.SPACE_4)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DS.SPACE_1)
	row.add_child(margin)
	# Un Button ne grandit pas avec ses enfants : la ligne suit son contenu
	# (sous-titre de poste au texte 1,5, QA-034).
	margin.minimum_size_changed.connect(func() -> void:
		row.custom_minimum_size.y = maxf(height, margin.get_combined_minimum_size().y))
	var content: HBoxContainer = hbox(DS.SPACE_4)
	margin.add_child(content)
	var check: CheckMark = CheckMark.new()
	check.name = "Check"
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(check)
	# Libellé · note sur une ligne si la place le permet, repliés sinon (QA-034).
	var texts: HFlowContainer = HFlowContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("h_separation", DS.SPACE_3)
	texts.add_theme_constant_override("v_separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(texts)
	var title: String = UiText.t(line.label_key, String(line.id))
	if line.member_id != &"":
		title = title % HouseholdView.member_name(line.member_id) if title.contains("%s") else title
	var title_label: Label = label(title, &"BodyStrong")
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(title_label)
	var note: Label = label(UiText.t(line.note_key, ""), &"CaptionLabel")
	note.name = "Note"
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(note)
	if line.mandatory:
		var lock: PanelContainer = chip(UiText.t("ev_mandatory", "PRÉLEVÉE D'OFFICE"), UiIcon.Kind.LOCK, Palette.TEXT_SECONDARY)
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
	var all_rows: Array[Button] = _rows.duplicate()
	if shop != null:
		all_rows.append_array(shop.rows)
	for row: Button in all_rows:
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
		cost.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY if line.paid else (Palette.TEXT_SECONDARY if affordable else DS.TEXT_MUTED))
		var note: Label = row.find_child("Note", true, false)
		if not line.paid and not affordable:
			note.text = UiText.t("ev_insufficient", "Fonds insuffisants")
			note.add_theme_color_override(&"font_color", Palette.STATE_AMBER)
		else:
			note.text = UiText.t(line.note_key, "")
			note.remove_theme_color_override(&"font_color")
	_spent_label.text = credits(-spent)
	if _events_label != null:
		_events_label.text = credits(delta, true)
		_events_label.add_theme_color_override(&"font_color", Palette.STATE_RED if delta < 0 else (DS.ACCENT_YELLOW if delta > 0 else Palette.TEXT_SECONDARY))
	_after_label.text = credits(after)
	_after_label.add_theme_color_override(&"font_color", Palette.STATE_RED if after < 0 else DS.ACCENT_YELLOW)
	_after_hint.text = UiText.t("ev_debt_hint", "Dette : trois soirs de suite et l'Autorité de Transit vous réaffecte.") if after < 0 else ""
	_after_hint.visible = after < 0
	if shop != null and is_instance_valid(shop):
		shop.refresh(func(line: ExpenseLine) -> bool:
			return EveningService.can_toggle_on(lines, effective_balance(), line, max_upgrades()), after)
	_refresh_options()
	_refresh_confirm()


func _family() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.add_child(section(UiText.t("ev_family", "LE FOYER"), UiIcon.Kind.INFO, Palette.TEXT_SECONDARY))
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
			if not is_audit_pending(event):
				delta -= SaveService.as_int(event.audit.get("cost", 0))
			continue
		delta += letter_gain(event)
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
		if events[i].kind == EveningEventDef.Kind.AUDIT and not is_audit_pending(events[i]) \
				and events[i].audit.get("ending", &"") != &"":
			return true
	return false


## Acte III : audit qui dépend d'un choix du soir encore en suspens (la
## Déposition du J29 : verdict « en délibéré » tant qu'elle n'est pas choisie).
func is_audit_pending(event: EveningEvent) -> bool:
	if event == null or event.kind != EveningEventDef.Kind.AUDIT or event.def == null \
			or event.def.audit_id != EndingService.AUDIT_DEPOSITION:
		return false
	for other: EveningEvent in events:
		if other == event:
			break
		if other.is_choice() and not choices.has(other.id):
			return true
	return false


## Acte III : gain versé par une lettre du soir (aide fixe `gain`, ou jauge
## `gain_gauge` lue dans les valeurs du texte, ex. rappel des salaires).
static func letter_gain(event: EveningEvent) -> int:
	if event == null or event.def == null or event.kind != EveningEventDef.Kind.LETTER:
		return 0
	var gain: int = event.def.gain
	if event.def.gain_gauge != &"":
		var index: int = event.def.text_gauges.find(String(event.def.gain_gauge))
		if index >= 0 and index < event.text_args.size():
			gain += SaveService.as_int(event.text_args[index])
	return gain


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
	_refresh_audits()
	_apply_choice_costs()
	event_choice_made.emit(event_id, option_id)
	_refresh()
	# Déposition (J29) : le choix fait, le verdict de l'Enquête est révélé.
	var verdict: EveningEvent = _dependent_audit(event)
	if verdict != null and is_inside_tree() and _events_box != null and events[step] == event:
		_show_step(events.find(verdict))
	return true


## Audit recalculé par un choix (Déposition) qui suit `event`, null sinon.
func _dependent_audit(event: EveningEvent) -> EveningEvent:
	var index: int = events.find(event)
	for i: int in range(index + 1, events.size()):
		var other: EveningEvent = events[i]
		if other.kind == EveningEventDef.Kind.AUDIT and other.def != null and other.def.audit_id == EndingService.AUDIT_DEPOSITION:
			return other if not is_audit_pending(other) else null
	return null


## Recalcule les audits qui dépendent des choix (Déposition), une fois tous
## les choix qui les précèdent faits.
func _refresh_audits() -> void:
	if not audit_preview.is_valid():
		return
	for event: EveningEvent in events:
		if event.kind == EveningEventDef.Kind.AUDIT and event.def != null and event.def.audit_id == EndingService.AUDIT_DEPOSITION \
				and not is_audit_pending(event):
			audit_preview.call(get_choices())
			return


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
	if is_act_card(event):
		return act_card_accent(event)
	if offer_upgrade(event) != null:
		return BriefingScreen.voice_color(offer_voice(event))
	if EVENT_ACCENTS.has(event.id):
		return Palette.token(EVENT_ACCENTS[event.id])
	match event.kind:
		EveningEventDef.Kind.AUDIT:
			return DS.ACCENT_YELLOW
		EveningEventDef.Kind.LETTER:
			return Palette.TEXT_SECONDARY
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
		# Retiré tout de suite : la nouvelle carte garde son nom (« EventCard »).
		_events_box.remove_child(child)
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
	var offer: UpgradeDef = offer_upgrade(event)
	if is_act_card(event):
		kind_key = "evt_d20_card_eyebrow"
	elif offer != null:
		kind_key = "ev_kind_offer"
	elif event.def != null and event.def.audit_id == EndingService.AUDIT_DEPOSITION:
		kind_key = "ev_kind_verdict"
	head.add_child(eyebrow(UiText.t(kind_key, "LETTRE"), accent))
	if ENQUETE_EVENTS.has(event.id):
		# Acte III : l'Enquête parle (Ravel), comme une voix de briefing.
		var speaker: HBoxContainer = hbox(DS.SPACE_2)
		speaker.name = "Speaker"
		speaker.add_child(UiIcon.make(UiIcon.Kind.SCALES, accent, DS.ICON_S))
		speaker.add_child(eyebrow(UiText.t("spk_enquete", "ENQUÊTE · C. RAVEL"), accent))
		box.add_child(speaker)
	if offer != null:
		_offer_letter(box, event, offer)
	elif not event.title_key.is_empty():
		var title: Label = label(UiText.t(event.title_key, String(event.id)), &"PanelTitle", accent if is_act_card(event) else DS.TEXT_PRIMARY)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.x = 120.0
		box.add_child(title)
	if offer == null and not event.text_key.is_empty():
		var body: Label = wrapped(event_text(event), &"BodyLabel", DS.TEXT_PRIMARY)
		body.name = "EventText"
		box.add_child(body)
	for key: String in event.extra_keys:
		box.add_child(wrapped(UiText.t(key, ""), &"BodySmall"))
	if is_skipped(event):
		box.add_child(wrapped(UiText.t("ev_event_skipped", "Cette nuit-là, vous ne rentrez pas au Bloc Pétrel."), &"BodySmall", Palette.STATE_RED))
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


## M13 (QA-069) : amélioration dont `event` est la lettre d'offre
## (`EveningEvent.upgrade_id`, lettres `offer_<id>` d'`EveningService`), null
## sinon. Lecture défensive : un événement sans ce champ n'est pas une offre.
func offer_upgrade(event: EveningEvent) -> UpgradeDef:
	if event == null:
		return null
	var id: Variant = event.get(&"upgrade_id")
	if not (id is StringName or id is String) or String(id).is_empty():
		return null
	if economy == null:
		economy = DataCatalog.load_economy()
	return economy.get_upgrade(StringName(id)) if economy != null else null


## Voix du message d'offre (`EveningEvent.voice`, sinon `UpgradeDef.offer_voice`).
func offer_voice(event: EveningEvent) -> BriefingContent.Voice:
	var voice: Variant = event.get(&"voice") if event != null else null
	if not voice is int or int(voice) < 0:
		var upgrade: UpgradeDef = offer_upgrade(event)
		voice = upgrade.offer_voice if upgrade != null else 0
	var value: int = clampi(int(voice), 0, BriefingContent.Voice.size() - 1)
	var result: BriefingContent.Voice = value as BriefingContent.Voice
	return result


## Lettre d'offre (QA-069, M13 §3.3 / §3.5) : signée comme un message du
## briefing (icône et nom du locuteur, jamais la couleur seule), le nom de
## l'amélioration, le message, puis le renvoi à l'Économat (prix) et, si la
## ligne y est, « VOIR L'OFFRE » (souris, clavier, manette : le focus va à la
## ligne de l'Économat).
func _offer_letter(box: VBoxContainer, event: EveningEvent, upgrade: UpgradeDef) -> void:
	var speaker_key: String = str(event.get(&"speaker_key")) if event.get(&"speaker_key") != null else ""
	if speaker_key.is_empty():
		speaker_key = upgrade.offer_speaker_key if not upgrade.offer_speaker_key.is_empty() else event.title_key
	var voice: BriefingContent.Voice = offer_voice(event)
	if not speaker_key.is_empty():
		var speaker: Control = _speaker_row(speaker_key, voice)
		box.add_child(speaker)
	var title: Label = label(UiText.t(upgrade.name_key, String(upgrade.id)), &"PanelTitle", DS.TEXT_PRIMARY)
	title.name = "OfferTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 120.0
	box.add_child(title)
	var body: Label = wrapped(event_text(event), &"BodyLabel", DS.TEXT_PRIMARY)
	body.name = "EventText"
	box.add_child(body)
	var row: HBoxContainer = hbox(DS.SPACE_3)
	row.name = "OfferShop"
	box.add_child(row)
	var where: PanelContainer = chip(UiText.tf("ev_offer_at_shop", [credits(upgrade.price)], "À L'ÉCONOMAT CE SOIR · %s"),
			UiIcon.Kind.TOOL, DS.ACCENT_YELLOW)
	where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(where)
	if shop != null and is_instance_valid(shop) and shop.get_row(upgrade.id) != null:
		var go: Button = button(UiText.t("ev_offer_goto", "VOIR L'OFFRE"), &"ButtonGhost")
		go.name = "OfferGoto"
		go.tooltip_text = UiText.t(upgrade.name_key, String(upgrade.id))
		go.pressed.connect(focus_offer.bind(upgrade.id))
		row.add_child(go)


## Focus sur la ligne de l'Économat d'une offre (lettre « VOIR L'OFFRE »).
func focus_offer(upgrade_id: StringName) -> bool:
	if shop == null or not is_instance_valid(shop):
		return false
	var row: Button = shop.get_row(upgrade_id)
	if row == null or not row.is_visible_in_tree():
		return false
	row.grab_focus()
	var node: Node = row.get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	if node != null:
		(node as ScrollContainer).ensure_control_visible(row)
	return true


## Locuteur d'un message (icône et nom, couleur de sa voix, DS §7.10).
func _speaker_row(speaker_key: String, voice: BriefingContent.Voice) -> HBoxContainer:
	var accent: Color = BriefingScreen.voice_color(voice)
	var speaker: HBoxContainer = hbox(DS.SPACE_2)
	speaker.name = "Speaker"
	speaker.add_child(UiIcon.make(BriefingScreen.voice_icon(voice), accent, DS.ICON_S))
	speaker.add_child(eyebrow(UiText.t(speaker_key, speaker_key), accent))
	return speaker


## Message signé (QA-069 : Okonkwo après la confiscation du tiroir) ; null si
## `key` n'est pas un message signé (`SIGNED_MESSAGES`).
func _signed_message(key: String) -> Control:
	if not SIGNED_MESSAGES.has(key):
		return null
	var spec: Array = SIGNED_MESSAGES[key]
	var voice: BriefingContent.Voice = spec[1]
	var box: VBoxContainer = vbox(DS.SPACE_1)
	box.name = "Signed_%s" % key
	box.add_child(_speaker_row(str(spec[0]), voice))
	box.add_child(wrapped(UiText.t(key, key), &"BodyLabel", DS.TEXT_PRIMARY))
	return box


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
	if is_audit_pending(event):
		# Déposition (J29) : rien n'est jugé avant votre déposition.
		var waiting: PanelContainer = panel()
		waiting.name = "VerdictPending"
		waiting.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.BG_PANEL, Palette.LINE_SUBTLE, DS.BORDER_HAIRLINE,
				DS.CHAMFER_S, DS.SPACE_3))
		var wait_row: HBoxContainer = hbox(DS.SPACE_3)
		waiting.add_child(wait_row)
		wait_row.add_child(UiIcon.make(UiIcon.Kind.SCALES, Palette.TEXT_SECONDARY, DS.ICON_M))
		var wait_text: Label = wrapped(UiText.t("ev_deposition_pending", "Le greffe délibère. Votre déposition d'abord."), &"BodyLabel",
				Palette.TEXT_SECONDARY)
		wait_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wait_row.add_child(wait_text)
		return waiting
	if event.def != null and event.def.audit_id == EndingService.AUDIT_DEPOSITION:
		return _deposition_verdict(event)
	var outcome: Dictionary = event.audit
	var ending: StringName = outcome.get("ending", &"")
	var cost: int = SaveService.as_int(outcome.get("cost", 0))
	var color: Color = Palette.STATE_RED if ending != &"" else (Palette.STATE_AMBER if cost > 0 else DS.ACCENT_CYAN)
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
	# QA-069 (M13 §3.5) : tiroir confisqué — le mot d'Okonkwo suit le constat.
	var drawer_key: String = str(outcome.get("drawer_message_key", "")) if bool(outcome.get("drawer_found", false)) else ""
	var signed: Control = _signed_message(drawer_key) if not drawer_key.is_empty() else null
	if signed == null:
		return card
	var stack: VBoxContainer = vbox(DS.SPACE_3)
	stack.add_child(card)
	stack.add_child(signed)
	return stack


## Déposition (J29) : verdict de l'Enquête et sa conséquence (arrestation →
## fin de la campagne, blâme → retenue, rien à retenir), révélé en fondu.
func _deposition_verdict(event: EveningEvent) -> Control:
	var outcome: Dictionary = event.audit
	var ending: StringName = outcome.get("ending", &"")
	var cost: int = SaveService.as_int(outcome.get("cost", 0))
	var color: Color = Palette.STATE_RED if ending != &"" else (Palette.STATE_AMBER if cost > 0 else DS.ACCENT_CYAN)
	var card: PanelContainer = panel()
	card.name = "Verdict"
	card.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(Color(color, 0.12), color, DS.BORDER_STRONG, DS.CHAMFER_S, DS.SPACE_4))
	var box: VBoxContainer = vbox(DS.SPACE_3)
	card.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	var icon: UiIcon.Kind = UiIcon.Kind.DETAIN if ending != &"" else (UiIcon.Kind.WARNING if cost > 0 else UiIcon.Kind.CHECK)
	head.add_child(UiIcon.make(icon, color, DS.ICON_M))
	var chip_key: String = "ev_dep_arrest" if ending != &"" else ("ev_dep_blame" if cost > 0 else "ev_dep_clean")
	var chip_fallback: String = "MISE EN ATTENTE · FIN DE LA CAMPAGNE" if ending != &"" else ("BLÂME · RETENUE" if cost > 0 else "RIEN À RETENIR")
	var consequence: Label = label(UiText.t(chip_key, chip_fallback), &"PanelTitle", color)
	consequence.name = "Consequence"
	consequence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence.custom_minimum_size.x = 120.0
	head.add_child(consequence)
	if cost > 0:
		var amount: Label = label(credits(-cost), &"DataTitle", color)
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(amount)
	box.add_child(wrapped(UiText.t(str(outcome.get("result_key", "")), ""), &"BodyLabel", DS.TEXT_PRIMARY))
	# Rappel de ce que vous avez dit (le choix qui précède le verdict).
	for i: int in range(events.find(event) - 1, -1, -1):
		var said_id: StringName = choices.get(events[i].id, &"")
		var said: EveningOptionDef = events[i].get_option(said_id)
		if events[i].is_choice() and said != null:
			var quote: Label = label("« %s »" % UiText.t(said.label_key, String(said.id)), &"CaptionLabel", Palette.TEXT_SECONDARY)
			quote.name = "Said"
			box.add_child(quote)
			break
	if not Settings.reduce_motion:
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, DS.DUR_DRAMATIC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	var reason: Label = label("", &"CaptionLabel", Palette.STATE_AMBER)
	reason.name = "Reason"
	reason.visible = false
	texts.add_child(reason)
	if option.ends_campaign != &"":
		var final_chip: PanelContainer = chip(UiText.t("ev_option_final", "FIN DE LA CAMPAGNE"), UiIcon.Kind.WARNING, Palette.STATE_AMBER)
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
	head.add_child(UiIcon.make(UiIcon.Kind.WARNING, Palette.STATE_AMBER, DS.ICON_M))
	head.add_child(eyebrow(UiText.t("ev_final_eyebrow", "DÉCISION DÉFINITIVE"), Palette.STATE_AMBER))
	var title: Label = label(UiText.t("ev_final_title", "QUITTER HALCYON ?"), &"DisplayLabel", DS.TEXT_PRIMARY)
	title.name = "FinalTitle"
	box.add_child(title)
	var choice: Label = wrapped("« %s »" % UiText.t(option.label_key, String(option.id)), &"BodyStrong", Palette.STATE_AMBER)
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
	# Boîte modale au clavier / à la manette (QA-021) : le focus tourne entre
	# ses deux boutons, jamais vers les postes derrière le voile.
	_trap_focus(cancel, accept)
	_trap_focus(accept, cancel)
	cancel.grab_focus.call_deferred()


## Tab, Maj+Tab et les quatre directions de `from` mènent à `other` ou à lui-même.
static func _trap_focus(from: Button, other: Button) -> void:
	var to: NodePath = from.get_path_to(other)
	var me: NodePath = NodePath(".")
	from.focus_next = to
	from.focus_previous = to
	from.focus_neighbor_left = to
	from.focus_neighbor_right = to
	from.focus_neighbor_top = me
	from.focus_neighbor_bottom = me


# ---------------------------------------------------------------------------
# Acte III : carte « FIN DE L'ACTE II » (soirée pivot du J20)
# ---------------------------------------------------------------------------

static func is_act_card(event: EveningEvent) -> bool:
	return event != null and String(event.id).begins_with(ACT_CARD_PREFIX)


## Événement « carte de fin d'acte » du soir (un seul climat), null sinon.
func act_card_event() -> EveningEvent:
	for event: EveningEvent in events:
		if is_act_card(event):
			return event
	return null


## Climat de la carte (`vanne`, `brulants`, `vitres`…).
static func act_card_climate(event: EveningEvent) -> String:
	return String(event.id).trim_prefix(ACT_CARD_PREFIX) if event != null else ""


## Couleur de la fin de l'Acte II que la carte rappelle (DS, comme l'écran de fin).
static func act_card_accent(event: EveningEvent) -> Color:
	var climate: String = act_card_climate(event)
	return EndScreen.accent_of(act_card_ending(event), "brulants" if climate == "brulants" else "")


## Fin de l'Acte II que la carte rappelle (F7 par défaut).
static func act_card_ending(event: EveningEvent) -> StringName:
	var ending: StringName = ACT_CARD_ENDINGS.get(act_card_climate(event), EndingService.F7_REOPENS)
	return ending


## Plein cadre noir : « FIN DE L'ACTE II », titre de la fin (couleur de la
## fin), deux lignes ; passe seule après `ACT_CARD_HOLD_SEC` ou au clic, à
## Entrée, à « CONTINUER ». La soirée pivot est derrière.
func _open_act_card(event: EveningEvent) -> void:
	close_act_card()
	var accent: Color = act_card_accent(event)
	act_card_layer = Control.new()
	act_card_layer.name = "ActCard"
	act_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	act_card_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(act_card_layer)
	var fill: ColorRect = ColorRect.new()
	fill.color = DS.BG_VOID
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	act_card_layer.add_child(fill)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	act_card_layer.add_child(center)
	var box: VBoxContainer = vbox(DS.SPACE_5)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size.x = 960.0
	center.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_3)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UiIcon.make(EndScreen.icon_of(act_card_ending(event)), accent,
			DS.ICON_M))
	head.add_child(eyebrow(UiText.t("evt_d20_card_eyebrow", "FIN DE L'ACTE II"), accent))
	box.add_child(head)
	var title: Label = label(UiText.t(event.title_key, String(event.id)), &"DisplayLabel", accent)
	title.name = "CardTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 640.0
	box.add_child(title)
	var line: ColorRect = rule_line(Color(accent, 0.4))
	line.custom_minimum_size = Vector2(480.0, DS.BORDER_HAIRLINE)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(line)
	var keys: PackedStringArray = [event.text_key]
	keys.append_array(event.extra_keys)
	for key: String in keys:
		if key.is_empty():
			continue
		var text: Label = wrapped(UiText.t(key, ""), &"TitleLabel", DS.TEXT_PRIMARY)
		text.name = "CardLine_%d" % box.get_child_count()
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(text)
	var footer: VBoxContainer = vbox(DS.SPACE_2)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)
	_act_card_button = button(UiText.t("act_card_continue", "LA NUIT DU 1ᵉʳ AVRIL ▶"), &"ButtonGhost")
	_act_card_button.name = "Continue"
	_act_card_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_act_card_button.pressed.connect(close_act_card)
	footer.add_child(_act_card_button)
	_act_card_button.grab_focus.call_deferred()
	if Settings.reduce_motion:
		return
	box.modulate.a = 0.0
	var reveal: Tween = box.create_tween()
	reveal.tween_property(box, "modulate:a", 1.0, DS.DUR_DRAMATIC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if act_card_auto_close:
		get_tree().create_timer(ACT_CARD_HOLD_SEC).timeout.connect(_fade_act_card.bind(act_card_layer))


func _fade_act_card(layer: Control) -> void:
	if layer != act_card_layer or not is_instance_valid(layer) or not act_card_auto_close:
		return
	var fade: Tween = layer.create_tween()
	fade.tween_property(layer, "modulate:a", 0.0, DS.DUR_DRAMATIC)
	fade.tween_callback(close_act_card)


## Ferme la carte de fin d'acte (la soirée pivot reste affichée).
func close_act_card() -> void:
	if act_card_layer == null:
		return
	act_card_layer.queue_free()
	act_card_layer = null
	_act_card_button = null
	if confirm_button != null and is_inside_tree():
		confirm_button.grab_focus.call_deferred()


## Échap / B (`cancel`, `ui_cancel`) dans la boîte « QUITTER HALCYON ? » :
## annule (QA-021) ; le menu pause ne s'ouvre pas par-dessus. Carte de fin
## d'acte : clic, Entrée ou Échap la passent.
func _input(event: InputEvent) -> void:
	if act_card_layer != null and is_visible_in_tree():
		var click: InputEventMouseButton = event as InputEventMouseButton
		if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept", false, true) \
				or event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
			close_act_card()
			get_viewport().set_input_as_handled()
		return
	if confirm_layer == null or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		close_final_confirm()
		get_viewport().set_input_as_handled()


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
	var was_open: bool = confirm_layer != null
	if confirm_layer != null:
		confirm_layer.queue_free()
		confirm_layer = null
	_refresh_options()
	if was_open:
		_refocus_after_confirm()


## Focus rendu à l'option qui avait ouvert la boîte (sinon VALIDER).
func _refocus_after_confirm() -> void:
	for row: Button in option_buttons.values():
		if not is_instance_valid(row) or not row.is_visible_in_tree() or row.disabled:
			continue
		var option: EveningOptionDef = row.get_meta(&"option")
		if option != null and option.ends_campaign != &"":
			row.grab_focus.call_deferred()
			return
	if confirm_button != null and confirm_button.is_visible_in_tree():
		confirm_button.grab_focus.call_deferred()


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
		_confirm_hint.add_theme_color_override(&"font_color", Palette.STATE_AMBER if pending > 0 else Palette.TEXT_SECONDARY)


func _luciole_note() -> PanelContainer:
	var card: PanelContainer = panel()
	card.add_theme_stylebox_override(&"panel", BriefingScreen._bar_box(Palette.MAGENTA_12, Palette.ACCENT_MAGENTA))
	var box: VBoxContainer = vbox(DS.SPACE_2)
	card.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.DISCORDANCE, Palette.ACCENT_MAGENTA, DS.ICON_S))
	head.add_child(eyebrow(UiText.t("ev_note_title", "LE MOT GLISSÉ AU GUICHET"), Palette.ACCENT_MAGENTA))
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
		_right.add_child(wrapped(UiText.t("ev_note_reported" if report_it else "ev_note_burned", ""), &"BodySmall", Palette.TEXT_SECONDARY))
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
	# Boîte « QUITTER HALCYON ? » ouverte : elle seule répond (QA-021).
	if _report_layer != null or confirm_layer != null:
		return
	close_act_card()
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
			Palette.STATE_RED if report.balance_after < 0 else DS.ACCENT_YELLOW))
	for event: Dictionary in report.events:
		box.add_child(_event_row(event))
	# M13 : amélioration achetée ce soir — effet dès le shift suivant.
	for upgrade_id: StringName in report.upgrades_bought:
		var upgrade: UpgradeDef = economy.get_upgrade(upgrade_id) if economy != null else null
		var bought: PanelContainer = chip(UiText.tf("shop_bought", [UiText.t(upgrade.name_key, String(upgrade_id)) if upgrade != null
				else String(upgrade_id)], "ACQUIS · %s · effet dès demain"), UiIcon.Kind.TOOL, DS.ACCENT_YELLOW)
		bought.name = "Bought_%s" % upgrade_id
		box.add_child(bought)
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
	var color: Color = Palette.TEXT_SECONDARY
	var icon: UiIcon.Kind = UiIcon.Kind.INFO
	match tone:
		EveningReport.Tone.GOOD:
			color = DS.ACCENT_CYAN
			icon = UiIcon.Kind.CHECK
		EveningReport.Tone.WARNING:
			color = Palette.STATE_AMBER
			icon = UiIcon.Kind.WARNING
		EveningReport.Tone.BAD:
			color = Palette.STATE_RED
			icon = UiIcon.Kind.DENIED
	var row: HBoxContainer = hbox(DS.SPACE_3)
	row.add_child(UiIcon.make(icon, color, DS.ICON_S))
	var member: StringName = event["member"]
	var key: String = event["key"]
	var signed: Control = _signed_message(key)
	if signed != null:
		# QA-069 : message signé (locuteur nommé) dans le rapport de la nuit.
		signed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(signed)
		return row
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
		var color: Color = DS.ACCENT_CYAN if checked else Palette.TEXT_SECONDARY
		if locked:
			color = Palette.TEXT_SECONDARY
		if checked:
			var fill: Color = color
			fill.a = 0.24
			draw_colored_polygon(outline, fill)
		draw_polyline(outline, color, DS.ICON_STROKE)
		if checked:
			UiIcon.draw_icon(self, UiIcon.Kind.CHECK, r.grow(-3.0), color, 2.0)
