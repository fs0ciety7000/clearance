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
class_name EveningScreen
extends ScreenBase

signal confirmed(lines: Array[ExpenseLine])
signal luciole_decided(report_it: bool)

const LEFT_RATIO: float = 1.25
const REPORT_WIDTH: float = 760.0

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
var confirm_button: Button = null

var _rows: Array[Button] = []
var _spent_label: Label = null
var _after_label: Label = null
var _after_hint: Label = null
var _note_card: PanelContainer = null
var _right: VBoxContainer = null
var _report_layer: Control = null
var _report_button: Button = null


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


func _build() -> void:
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
	head_box.add_child(rule_line())
	head_box.add_child(_money_row(UiText.t("ev_available", "Disponible ce soir"), credits(balance), DS.ACCENT_YELLOW, &"DataTitle"))
	box.add_child(eyebrow(UiText.t("ev_lines", "DÉPENSES DU SOIR — COCHEZ CE QUE VOUS PAYEZ")))
	for line: ExpenseLine in lines:
		var row: Button = _expense_row(line)
		_rows.append(row)
		box.add_child(row)
	box.add_child(spacer(false, true))
	var totals: PanelContainer = panel(&"ElevatedCard")
	box.add_child(totals)
	var totals_box: VBoxContainer = vbox(DS.SPACE_1)
	totals.add_child(totals_box)
	var spent_row: HBoxContainer = _money_row(UiText.t("ev_spent", "Dépenses"), "", DS.TEXT_PRIMARY)
	_spent_label = spent_row.get_child(spent_row.get_child_count() - 1)
	totals_box.add_child(spent_row)
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


## Ligne de dépense : case à cocher DS + libellé + note + coût (bouton bascule).
func _expense_row(line: ExpenseLine) -> Button:
	var row: Button = Button.new()
	row.toggle_mode = true
	row.theme_type_variation = &"ButtonQuestion"
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(0, 60)
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
	if pressed and not EveningService.can_toggle_on(lines, balance, line):
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
	var after: int = balance - spent
	for row: Button in _rows:
		var line: ExpenseLine = row.get_meta(&"line")
		var affordable: bool = EveningService.can_toggle_on(lines, balance, line)
		var check: CheckMark = row.find_child("Check", true, false)
		check.checked = line.paid
		check.locked = line.mandatory
		var cost: Label = row.find_child("Cost", true, false)
		cost.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY if line.paid else (DS.TEXT_SECONDARY if affordable else DS.TEXT_MUTED))
		var note: Label = row.find_child("Note", true, false)
		if not line.paid and not affordable:
			note.text = UiText.t("ev_insufficient", "Fonds insuffisants")
			note.add_theme_color_override(&"font_color", DS.STATE_AMBER)
		else:
			note.text = UiText.t(line.note_key, "")
			note.remove_theme_color_override(&"font_color")
	_spent_label.text = credits(-spent)
	_after_label.text = credits(after)
	_after_label.add_theme_color_override(&"font_color", DS.STATE_RED if after < 0 else DS.ACCENT_YELLOW)
	_after_hint.text = UiText.t("ev_debt_hint", "Dette : trois soirs de suite et l'Autorité de Transit vous réaffecte.") if after < 0 else ""
	_after_hint.visible = after < 0


func _family() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.add_child(section(UiText.t("ev_family", "LE FOYER"), UiIcon.Kind.INFO, DS.TEXT_SECONDARY))
	for member: Household.Member in household.members:
		box.add_child(HouseholdView.member_card(member, HouseholdView.member_note(member)))
	return box


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
	var report_button: Button = button(UiText.t("ev_note_report", "SIGNALER AU CONSORTIUM"))
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
	if _note_card != null:
		_note_card.queue_free()
		_note_card = null
		_right.add_child(wrapped(UiText.t("ev_note_reported" if report_it else "ev_note_burned", ""), &"BodySmall", DS.TEXT_SECONDARY))
	confirm_button.grab_focus()


func _footer() -> Control:
	var row: HBoxContainer = hbox(DS.SPACE_4)
	var hint: Label = label(UiText.t("ev_hint", "Ce qui n'est pas payé a des conséquences dès cette nuit."), &"CaptionLabel")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
