## Avis d'infraction du Consortium (DS §7.9) — ticket diégétique imprimé par
## la fente du poste.
##
## Anatomie : en-tête jaune (logo + « CONSORTIUM · AVIS D'INFRACTION ») et
## n° de citation (`G04-J01-03`, mono) · motif (`cit_*`) · règle enfreinte
## (n° + titre, rappel du Rulebook) · explication courte · sanction :
## avertissement en ambre + triangle (« AVERTISSEMENT 1/2 »), amende en rouge +
## octogone sur bandeau `red.12` · bord dentelé en bas.
## M11 (lot C, D-102) : en mode Récit (`story`), la citation reste numérotée
## et comptée mais sans amende : « AVERTISSEMENT · MODE RÉCIT », « sans
## amende en mode Récit » (jamais « AVERTISSEMENT 5/2 »).
## États : `archived` (récapitulatif de fin de journée) = opacité 40 %, 100 %
## au survol / focus. Impression : déroulé vertical depuis la fente (`ease.snap`),
## fondu simple si « réduire les animations ».
class_name CitationTicket
extends VBoxContainer

const WIDTH: float = 360.0
const TOOTH_W: float = 12.0
const TOOTH_H: float = 6.0
const ARCHIVED_ALPHA: float = 0.4

var result: CaseResult = null
var archived: bool = false
## Mode Récit : amende levée (libellé dédié).
var story: bool = false
var _paper: Color = DS.BG_ELEVATED


## `rule_number` / `rule_title` : règle citée telle qu'au Rulebook du jour (0 / "" si aucune).
static func make(p_result: CaseResult, day_number: int, rule_number: int, rule_title: String,
		free_citations: int = 2, p_archived: bool = false, p_story: bool = false) -> CitationTicket:
	var ticket: CitationTicket = CitationTicket.new()
	ticket.result = p_result
	ticket.archived = p_archived
	ticket.story = p_story
	ticket._build(day_number, rule_number, rule_title, free_citations)
	return ticket


func _build(day_number: int, rule_number: int, rule_title: String, free_citations: int) -> void:
	add_theme_constant_override("separation", 0)
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_PASS if archived else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if archived else Control.FOCUS_NONE
	var body_panel: PanelContainer = PanelContainer.new()
	body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_panel.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(_paper, Palette.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_M, 0))
	add_child(body_panel)
	var column: VBoxContainer = ScreenBase.vbox(0)
	body_panel.add_child(column)

	var header: PanelContainer = PanelContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.ACCENT_YELLOW, DS.ACCENT_YELLOW, 0, DS.CHAMFER_S, DS.SPACE_2))
	column.add_child(header)
	var header_row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	header.add_child(header_row)
	header_row.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.TEXT_ON_ACCENT, DS.ICON_S))
	# Libellés repliés : le ticket tient dans la colonne des toasts même avec
	# le plancher de texte du Steam Deck (QA-009).
	var title: Label = ScreenBase.wrapped(UiText.t("cit_header", "CONSORTIUM · AVIS D'INFRACTION"), &"BadgeLabel")
	title.uppercase = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	var number: int = result.citation_number if result != null else 0
	var serial: Label = ScreenBase.label(UiText.tf("cit_serial", [day_number, maxi(number, 1)], "G04-J%02d-%02d"), &"KeyCapLabel", DS.TEXT_ON_ACCENT)
	header_row.add_child(serial)

	var body: MarginContainer = MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, DS.SPACE_3)
	column.add_child(body)
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	body.add_child(box)
	var reason_key: String = result.citation_reason_key if result != null else ""
	box.add_child(ScreenBase.eyebrow(UiText.t("cit_motive", "MOTIF")))
	var reason: Label = ScreenBase.wrapped(UiText.t(reason_key, reason_key), &"BodyStrong")
	reason.uppercase = true
	box.add_child(reason)
	if rule_number > 0:
		box.add_child(ScreenBase.wrapped(UiText.tf("cit_rule", [rule_number, rule_title], "Règle %02d · %s"), &"DataSmall", DS.TEXT_PRIMARY))
	var desc_key: String = reason_key + "_desc"
	if UiText.has(desc_key):
		box.add_child(ScreenBase.wrapped(UiText.t(desc_key, ""), &"BodySmall"))

	var warning: bool = result != null and result.is_warning()
	var accent: Color = Palette.STATE_AMBER if warning else Palette.STATE_RED
	var sanction_panel: PanelContainer = PanelContainer.new()
	sanction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sanction_panel.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(Palette.AMBER_12 if warning else Palette.RED_12, accent, 0, 0, DS.SPACE_2))
	column.add_child(sanction_panel)
	var sanction_row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	sanction_panel.add_child(sanction_row)
	sanction_row.add_child(UiIcon.make(UiIcon.Kind.WARNING if warning else UiIcon.Kind.DENIED, accent, DS.ICON_S))
	var sanction_text: String
	if warning and story:
		sanction_text = UiText.t("cit_warning_story", "AVERTISSEMENT · MODE RÉCIT")
	elif warning:
		sanction_text = UiText.tf("cit_warning_n", [number, free_citations], "AVERTISSEMENT %d/%d")
	else:
		sanction_text = UiText.tf("cit_fine", [ScreenBase.credits(-result.fine)], "AMENDE %s")
	var sanction: Label = ScreenBase.wrapped(sanction_text, &"DocFieldValue", accent) if story else ScreenBase.label(sanction_text, &"DocFieldValue", accent)
	sanction.name = "Sanction"
	sanction.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sanction_row.add_child(sanction)
	var note_key: String = "cit_withheld" if not warning else ("cit_no_fine_story" if story else "cit_no_fine")
	var note: Label = ScreenBase.wrapped(UiText.t(note_key, ""), &"CaptionLabel")
	note.custom_minimum_size.x = 0.0
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sanction_row.add_child(note)

	var teeth: Control = Control.new()
	teeth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	teeth.custom_minimum_size = Vector2(0, TOOTH_H)
	teeth.draw.connect(_draw_teeth.bind(teeth))
	add_child(teeth)
	if archived:
		modulate.a = ARCHIVED_ALPHA
		mouse_entered.connect(_set_highlight.bind(true))
		mouse_exited.connect(_set_highlight.bind(false))
		focus_entered.connect(_set_highlight.bind(true))
		focus_exited.connect(_set_highlight.bind(false))


## Bord dentelé : dents vers le bas, couleur du papier.
func _draw_teeth(canvas: Control) -> void:
	var w: float = canvas.size.x
	var x: float = 0.0
	while x < w:
		var right: float = minf(x + TOOTH_W, w)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(right, 0.0),
				Vector2((x + right) * 0.5, TOOTH_H)]), _paper)
		x += TOOTH_W


func _set_highlight(on: bool) -> void:
	modulate.a = 1.0 if on else ARCHIVED_ALPHA


## Impression par la fente : déroulé vertical depuis le haut.
func play_print() -> void:
	if Settings.reduce_motion or Settings.fx_intensity <= 0.0:
		return
	pivot_offset = Vector2(size.x * 0.5, 0.0)
	scale = Vector2(1.0, 0.1)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, DS.DUR_SLOW)
