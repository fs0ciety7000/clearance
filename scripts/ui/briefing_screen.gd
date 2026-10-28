## Briefing du jour (UI_FLOW §7, §8 ; remplace le `DayBriefing` provisoire M4).
##
## Bulletin du Bureau de Continuité : date, directive de délégation du jour
## (D-028, LORE §3), règles en vigueur avec badge NOUVEAU (même vocabulaire que
## le Rulebook), slogan ; messages personnels (Okonkwo au J1 : tutoriel
## diégétique court ; Ilan ; brèves du hall qui font écho aux choix de la
## veille) ; état du foyer et solde. Lecture au rythme du joueur (l'horloge ne
## tourne pas) ; « PRENDRE SON POSTE » (Entrée / Ⓐ) émet `closed` puis `finished`.
class_name BriefingScreen
extends ScreenBase

## Compatibilité M4 (`DayScene` branche `closed` sur `close_intro()`).
signal closed()

const LEFT_RATIO: float = 1.45
## Pas de défilement au clavier / à la manette (px logiques).
const SCROLL_STEP: float = 120.0
## Commandes rappelées au J1 (tutoriel diégétique court, UI_FLOW §7) :
## [touches, clé du libellé].
const CONTROLS: Array[Array] = [
	["N · Ⓐ", "br_ctrl_next"], ["ESPACE · LT", "br_ctrl_inspect"], ["Q · Ⓨ", "br_ctrl_ask"],
	["V · RT", "br_ctrl_approve"], ["X · Ⓧ", "br_ctrl_deny"], ["TAB · R", "br_ctrl_rulebook"],
]

var content: BriefingContent = null
var household: Household = null
var credits_balance: int = 0
var day: DayDef = null
var start_button: Button = null
## Contenu défilant (directive, règles, messages, foyer) entre l'en-tête et la
## barre d'action fixe (QA-001 : 22 règles au J10, plancher de texte au Deck).
var scroll: ScrollContainer = null
## « Suite du bulletin » : visible tant que du contenu reste sous le pli.
var scroll_hint: Label = null


func setup(p_content: BriefingContent, p_household: Household, p_credits: int, p_day: DayDef = null) -> void:
	content = p_content
	household = p_household
	credits_balance = p_credits
	day = p_day


func close(choice: StringName = &"start") -> void:
	if is_closing():
		return
	closed.emit()
	super.close(choice)


func _build() -> void:
	if content == null:
		content = BriefingContent.new()
	var page: VBoxContainer = vbox(DS.SPACE_4)
	root_box().add_child(page)
	page.add_child(_header())
	scroll = ScrollContainer.new()
	scroll.name = "BriefingScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Place de la barre réservée : pas de boucle « barre visible → texte replié
	# → barre masquée » (cf. `EndScreen`).
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.follow_focus = false
	page.add_child(scroll)
	var inner: MarginContainer = MarginContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_right", DS.SPACE_4)
	inner.add_theme_constant_override("margin_bottom", DS.SPACE_2)
	scroll.add_child(inner)
	var columns: HBoxContainer = hbox(DS.SPACE_8)
	inner.add_child(columns)
	var left: VBoxContainer = vbox(DS.SPACE_5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = LEFT_RATIO
	columns.add_child(left)
	left.add_child(_directive())
	if day != null:
		left.add_child(_shift_tiles())
	left.add_child(_rules())
	if content.day_number == 1:
		left.add_child(_controls())
	if content.advance_credits > 0:
		left.add_child(_advance_notice())
	var right: VBoxContainer = vbox(DS.SPACE_5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(_messages())
	right.add_child(_household())
	page.add_child(rule_line())
	page.add_child(_footer())
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	bar.changed.connect(_refresh_scroll_hint)
	bar.value_changed.connect(func(_v: float) -> void: _refresh_scroll_hint())
	_refresh_scroll_hint.call_deferred()
	start_button.grab_focus.call_deferred()


## Vrai si une partie du bulletin est encore sous le pli.
func has_more_below() -> bool:
	if scroll == null:
		return false
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	return bar.max_value - bar.page - bar.value > 1.0


func _refresh_scroll_hint() -> void:
	if scroll_hint != null:
		scroll_hint.modulate.a = 1.0 if has_more_below() else 0.0


## Défilement au clavier / à la manette (haut/bas, pages) : le bouton d'action
## garde le focus, la souris défile à la molette ou par la barre.
func _input(event: InputEvent) -> void:
	if scroll == null or is_closing() or not is_visible_in_tree() or not event.is_pressed():
		return
	var step: float = 0.0
	if event.is_action(&"ui_down"):
		step = SCROLL_STEP
	elif event.is_action(&"ui_up"):
		step = -SCROLL_STEP
	elif event.is_action(&"ui_page_down"):
		step = scroll.size.y * 0.8
	elif event.is_action(&"ui_page_up"):
		step = -scroll.size.y * 0.8
	if step == 0.0:
		return
	scroll.scroll_vertical = roundi(scroll.scroll_vertical + step)
	get_viewport().set_input_as_handled()


func _header() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	var top: HBoxContainer = hbox(DS.SPACE_3)
	box.add_child(top)
	top.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.ACCENT_YELLOW, DS.ICON_M))
	var org: VBoxContainer = vbox(0)
	top.add_child(org)
	org.add_child(eyebrow(UiText.t("br_org", "CONSORTIUM · BUREAU DE CONTINUITÉ"), DS.ACCENT_YELLOW))
	org.add_child(label(UiText.t("br_bulletin", "Bulletin quotidien · Halcyon Gate — Guichet 04"), &"CaptionLabel"))
	top.add_child(spacer())
	var when: VBoxContainer = vbox(0)
	top.add_child(when)
	var date_label: Label = label(UiText.date_with_weekday(content.game_date), &"DataTitle")
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	when.add_child(date_label)
	var shift: Label = label(UiText.t("br_shift_hours", "SHIFT 10:00 — 18:00"), &"DataSmall")
	shift.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	when.add_child(shift)
	box.add_child(rule_line(DS.YELLOW_24))
	var title_row: HBoxContainer = hbox(DS.SPACE_6)
	box.add_child(title_row)
	title_row.add_child(label(UiText.tf("br_day", [content.day_number], "JOUR %02d"), &"DisplayLabel", DS.ACCENT_YELLOW))
	var directive_title: Label = label(UiText.t(content.directive_title_key, ""), &"TitleLabel", DS.TEXT_PRIMARY)
	directive_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(directive_title)
	return box


func _directive() -> Control:
	var card: PanelContainer = panel(&"VeilPanel")
	card.add_theme_stylebox_override(&"panel", _bar_box(DS.BG_ELEVATED, DS.ACCENT_YELLOW))
	var box: VBoxContainer = vbox(DS.SPACE_2)
	card.add_child(box)
	box.add_child(eyebrow(UiText.t("br_directive", "DIRECTIVE DU JOUR · AUTORITÉ DE TRANSIT"), DS.ACCENT_YELLOW))
	box.add_child(wrapped(UiText.t(content.directive_key, ""), &"BodyLabel"))
	return card


func _rules() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	var new_count: int = content.get_new_entries().size()
	var side: String = UiText.plural("br_new_count", new_count, "%d NOUVELLE", "%d NOUVELLES")
	box.add_child(section(UiText.t("br_rules", "RÈGLES EN VIGUEUR"), UiIcon.Kind.WARNING, DS.STATE_AMBER, side))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", DS.SPACE_3)
	grid.add_theme_constant_override("v_separation", DS.SPACE_3)
	box.add_child(grid)
	var number: int = 0
	for entry: RulebookEntry in content.rulebook:
		number += 1
		grid.add_child(_rule_card(entry, number))
	return box


func _shift_tiles() -> Control:
	var row: HBoxContainer = hbox(DS.SPACE_3)
	row.add_child(stat_tile(UiText.t("br_expected", "PASSAGERS ATTENDUS"), str(day.passenger_count),
			UiText.t("br_expected_detail", "La file ne se vide jamais tout à fait."), DS.TEXT_PRIMARY, UiIcon.Kind.DIAMOND))
	@warning_ignore("integer_division")
	var minutes: int = roundi(day.duration_sec) / 60
	row.add_child(stat_tile(UiText.t("br_duration", "DURÉE DU SHIFT"), "8 h",
			UiText.tf("br_duration_detail", [minutes], "≈ %d min réelles · l'horloge tourne pendant la marche"), DS.TEXT_PRIMARY, UiIcon.Kind.INFO))
	row.add_child(stat_tile(UiText.t("br_pay", "RÉMUNÉRATION"), credits(day.credit_per_correct),
			UiText.tf("br_pay_detail", [day.free_citations_per_day], "par dossier conforme · %d avertissements tolérés"), DS.ACCENT_YELLOW, UiIcon.Kind.LOGO))
	return row


## Commandes du poste (J1) : touches clavier · manette.
func _controls() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.add_child(section(UiText.t("br_controls", "COMMANDES DU POSTE"), UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", DS.SPACE_6)
	grid.add_theme_constant_override("v_separation", DS.SPACE_2)
	box.add_child(grid)
	for control: Array in CONTROLS:
		var keys: String = control[0]
		var caption_key: String = control[1]
		var row: HBoxContainer = hbox(DS.SPACE_2)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap: PanelContainer = panel(&"KeyCap")
		cap.custom_minimum_size.x = 112.0
		var cap_label: Label = label(keys, &"KeyCapLabel", DS.TEXT_PRIMARY)
		cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(cap_label)
		row.add_child(cap)
		var text: Label = wrapped(UiText.t(caption_key, caption_key), &"BodySmall")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		grid.add_child(row)
	return box


func _rule_card(entry: RulebookEntry, number: int) -> Control:
	var card: PanelContainer = panel(&"RuleCardNew" if entry.is_new else &"ElevatedCard")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 300.0
	var row: HBoxContainer = hbox(DS.SPACE_3)
	card.add_child(row)
	var num: Label = label("%02d" % number, &"DataTitle", DS.STATE_AMBER if entry.is_new else DS.TEXT_MUTED)
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(num)
	var col: VBoxContainer = vbox(DS.SPACE_1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title_row: HBoxContainer = hbox(DS.SPACE_2)
	col.add_child(title_row)
	var title: Label = label(UiText.t(entry.title_key, String(entry.rule_id)), &"BodyStrong", DS.TEXT_PRIMARY if entry.is_new else DS.TEXT_SECONDARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(title)
	if entry.is_new:
		title_row.add_child(RuleCardView.make_new_badge(UiText.t("badge_new", "NOUVEAU")))
	col.add_child(wrapped(RuleCardView.rule_text(entry, day.air_quota if day != null else 0), &"BodySmall"))
	return card


func _messages() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	box.add_child(section(UiText.t("br_messages", "MESSAGES"), UiIcon.Kind.CHAT, DS.ACCENT_CYAN,
			UiText.plural("br_msg_count", content.messages.size(), "%d REÇU", "%d REÇUS")))
	for message: Dictionary in content.messages:
		var voice: BriefingContent.Voice = message["voice"]
		var speaker: String = message["speaker"]
		var text: String = message["text"]
		var args: Array = message.get("args", [])
		box.add_child(_message_card(speaker, text, voice, args))
	return box


func _message_card(speaker_key: String, text_key: String, voice: BriefingContent.Voice, args: Array = []) -> Control:
	var accent: Color = voice_color(voice)
	var bg: Color = DS.BG_ELEVATED
	match voice:
		BriefingContent.Voice.LUCIOLES:
			bg = DS.BG_ELEVATED.blend(DS.MAGENTA_12) # encre magenta, sans signature
		BriefingContent.Voice.INSPECTION:
			bg = DS.BG_ELEVATED.blend(DS.YELLOW_12)
		BriefingContent.Voice.COMMISSION:
			bg = DS.BG_ELEVATED.blend(DS.VOICE_COMMISSION_12) # registre administratif, froid
		BriefingContent.Voice.BRULANTS:
			bg = DS.BG_VOID # encre noire : la carte est plus sombre que les autres
	var card: PanelContainer = panel()
	card.name = "Message_%s" % speaker_key
	card.add_theme_stylebox_override(&"panel", _bar_box(bg, accent))
	var box: VBoxContainer = vbox(DS.SPACE_1)
	card.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(voice_icon(voice), accent, DS.ICON_S))
	head.add_child(eyebrow(UiText.t(speaker_key, speaker_key), accent))
	box.add_child(wrapped(UiText.tf(text_key, args), &"BodyLabel"))
	return card


## Couleur d'un locuteur (DS §7.10) : Consortium jaune, mentor cyan, famille
## gris, Lucioles magenta (contenu rebelle), Inspection des agents ambre
## (avertissement : l'Inspecteur Ravel surveille l'agent·e). Acte II
## (DS §7.10) : Commission de Rééquilibrage en bleu de registre, Brûlants en
## braise éteinte — deux teintes hors des familles sémantiques.
static func voice_color(voice: BriefingContent.Voice) -> Color:
	match voice:
		BriefingContent.Voice.CONSORTIUM:
			return DS.ACCENT_YELLOW
		BriefingContent.Voice.FAMILY:
			return DS.TEXT_SECONDARY
		BriefingContent.Voice.LUCIOLES:
			return DS.ACCENT_MAGENTA
		BriefingContent.Voice.INSPECTION:
			return DS.STATE_AMBER
		BriefingContent.Voice.COMMISSION:
			return DS.VOICE_COMMISSION
		BriefingContent.Voice.BRULANTS:
			return DS.VOICE_BRULANTS
	return DS.ACCENT_CYAN


static func voice_icon(voice: BriefingContent.Voice) -> UiIcon.Kind:
	match voice:
		BriefingContent.Voice.CONSORTIUM:
			return UiIcon.Kind.LOGO
		BriefingContent.Voice.FAMILY:
			return UiIcon.Kind.INFO
		BriefingContent.Voice.LUCIOLES:
			return UiIcon.Kind.DISCORDANCE
		BriefingContent.Voice.INSPECTION:
			return UiIcon.Kind.WARNING
		BriefingContent.Voice.COMMISSION:
			return UiIcon.Kind.REGISTER
		BriefingContent.Voice.BRULANTS:
			return UiIcon.Kind.FLAME
	return UiIcon.Kind.CHAT


## Avis de versement de la Trésorerie (J1, D-047) : avance du Consortium.
func _advance_notice() -> Control:
	var card: PanelContainer = panel()
	card.add_theme_stylebox_override(&"panel", _bar_box(DS.BG_ELEVATED, DS.ACCENT_YELLOW))
	var row: HBoxContainer = hbox(DS.SPACE_6)
	card.add_child(row)
	var texts: VBoxContainer = vbox(DS.SPACE_1)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(eyebrow(UiText.t(BriefingContent.SPEAKER_TREASURY, "CONSORTIUM · TRÉSORERIE DU PERSONNEL"), DS.ACCENT_YELLOW))
	texts.add_child(wrapped(UiText.tf(BriefingContent.MSG_ADVANCE, [content.advance_credits]), &"BodySmall"))
	var amount: VBoxContainer = vbox(0)
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(amount)
	var value: Label = label(ScreenBase.credits(content.advance_credits, true), &"DataTitle", DS.ACCENT_YELLOW)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_child(value)
	var caption: Label = label(UiText.t("br_advance_line", "CRÉDITÉE"), &"DataSmall")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_child(caption)
	return card


func _household() -> Control:
	var box: VBoxContainer = vbox(DS.SPACE_3)
	var balance_text: String = UiText.tf("br_balance", [ScreenBase.credits(credits_balance)], "SOLDE %s")
	if content.advance_credits > 0:
		balance_text = UiText.tf("br_balance_advance", [ScreenBase.credits(credits_balance)], "SOLDE %s · AVANCE INCLUSE")
	box.add_child(section(UiText.t("br_household", "FOYER · BLOC PÉTREL"), UiIcon.Kind.INFO, DS.TEXT_SECONDARY, balance_text))
	var home: Household = household if household != null else Household.new()
	for member: Household.Member in home.members:
		box.add_child(HouseholdView.member_card(member, HouseholdView.member_note(member)))
	return box


func _slogan() -> Control:
	var slogan_row: HBoxContainer = hbox(DS.SPACE_2)
	slogan_row.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.YELLOW_60, DS.ICON_S))
	var slogan: Label = wrapped("« %s »" % UiText.t(content.slogan_key, ""), &"BodySmall", DS.ACCENT_YELLOW)
	slogan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slogan_row.add_child(slogan)
	return slogan_row


func _footer() -> Control:
	var row: HBoxContainer = hbox(DS.SPACE_4)
	var texts: VBoxContainer = vbox(DS.SPACE_1)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	scroll_hint = label(UiText.t("br_scroll_hint", "▼ SUITE DU BULLETIN · MOLETTE OU ↑ ↓"), &"DataSmall", DS.ACCENT_CYAN)
	scroll_hint.modulate.a = 0.0
	texts.add_child(scroll_hint)
	texts.add_child(_slogan())
	texts.add_child(wrapped(UiText.t("br_hint", "Lecture libre : l'horloge du shift démarre à la prise de poste."), &"CaptionLabel"))
	start_button = button(UiText.t("br_start", "PRENDRE SON POSTE"), &"ButtonPrimary")
	start_button.custom_minimum_size.x = 320.0
	start_button.pressed.connect(close.bind(&"start"))
	row.add_child(start_button)
	return row


## Carte à liseré gauche (couleur du locuteur, DS §7.8 / §7.10).
static func _bar_box(bg: Color, bar: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(bg, bar, 0, DS.CHAMFER_M, DS.SPACE_4)
	box.border_width_left = DS.BORDER_STRONG + 1
	box.border_color = bar
	return box
