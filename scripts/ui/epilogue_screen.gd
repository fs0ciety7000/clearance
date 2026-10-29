## Épilogue J31 « Un an plus tard » (M12 lot C, I30 ; M12 §1.9, §1.10 ;
## D-122 → D-125) — deux écrans plein cadre, sobres :
## - **carte d'ouverture** (`setup_intro`) : « UN AN PLUS TARD », Vendredi
##   11.04.2188, surtitre du monde (`epi_eyebrow_<monde>`) ; sur le modèle de la
##   carte de fin d'acte (D-096) : révélation lente, passable, « CONTINUER » ;
## - **carte de conclusion** (`setup_conclusion`, `Campaign.close_epilogue`) :
##   surtitre, titre, nom du monde (`dos_world_<monde>`), ligne de bilan
##   (`epi_tally`, avertissements), lignes de conclusion (ouverture → SC-90 →
##   lignes de monde → foyer → clôture) révélées une à une (passable : TOUT
##   AFFICHER, Entrée, clic), réplique Tessar de la figure si approuvée, puis
##   « RETOUR AU TITRE » (`finished(&"title")`).
## Texte large et lisible (colonne ≤ `COLUMN_WIDTH`, `TitleLabel`), défilant au
## texte 1,5 (QA-058) : les lignes occupent toute la hauteur libre, défilent au
## stick droit (Pg↑ / Pg↓, molette) et à la croix ↑ ↓ depuis les boutons, et
## un repère « suite » (glyphe + texte) dit qu'il reste du texte plus bas ;
## jamais la couleur seule (icône du monde + texte).
class_name EpilogueScreen
extends ScreenBase

enum Mode { INTRO, CONCLUSION }

const COLUMN_WIDTH: float = 980.0
## Rythme de lecture (comme l'écran de fin, une ligne toutes les ~1,9 s).
const LINE_REVEAL_SEC: float = DS.DUR_DRAMATIC * 3.0
## Icône par monde (forme, pas seulement couleur).
const WORLD_ICONS: Dictionary[String, UiIcon.Kind] = {
	"a": UiIcon.Kind.LOGO, "b": UiIcon.Kind.BREATH, "c": UiIcon.Kind.REGISTER, "d": UiIcon.Kind.AWAY,
}

var mode: Mode = Mode.CONCLUSION
var world: String = ""
## Carte de conclusion (`EpilogueService.conclusion`).
var card: Dictionary = {}
var continue_button: Button = null
var skip_button: Button = null
var line_labels: Array[Label] = []
var revealed: int = 0
var _farewell: Control = null
var _scroll: ScrollContainer = null
## Repère « suite » sous les lignes (visible tant qu'il reste du texte plus bas).
var more_hint: Control = null
var _reveal_left: float = 0.0
var _done: bool = false


func _ready() -> void:
	super._ready()
	focus_guard.scroll_target = func() -> ScrollContainer: return _scroll


func setup_intro(epi: Dictionary) -> void:
	mode = Mode.INTRO
	world = str(epi.get("world", ""))


func setup_conclusion(p_card: Dictionary) -> void:
	mode = Mode.CONCLUSION
	card = p_card
	world = str(p_card.get("world", ""))


## Couleur d'un monde (DS : A jaune Consortium, B vert de l'air, C cyan des
## témoins, D ambre du sas) — toujours avec son icône et son nom.
static func world_color(p_world: String) -> Color:
	match p_world:
		"a":
			return DS.ACCENT_YELLOW
		"b":
			return Palette.STATE_GREEN
		"c":
			return DS.ACCENT_CYAN
		"d":
			return Palette.STATE_AMBER
	return Palette.TEXT_SECONDARY


## Lignes de conclusion en texte (clés traduites, `%d` des `args`).
static func conclusion_lines(p_card: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var keys: PackedStringArray = p_card.get("lines", PackedStringArray())
	var args: Dictionary = p_card.get("args", {}) if p_card.get("args") is Dictionary else {}
	for key: String in keys:
		var text: String = UiText.t(key, key)
		if args.has(key) and text.contains("%"):
			var values: Array = args[key]
			text = text % values
		lines.append(ComparisonUI.lumika_text(text, true))
	return lines


func default_focus() -> Control:
	if skip_button != null and skip_button.is_visible_in_tree():
		return skip_button
	return continue_button


func _build() -> void:
	if mode == Mode.INTRO:
		_build_intro()
	else:
		_build_conclusion()


func _head(box: VBoxContainer, tint: Color, eyebrow_key: String) -> void:
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiIcon.make(WORLD_ICONS.get(world, UiIcon.Kind.DIAMOND), tint, DS.ICON_M))
	var brow: Label = ScreenBase.eyebrow(UiText.t(eyebrow_key, "HALCYON GATE · GUICHET 04"), tint)
	brow.name = "WorldEyebrow"
	row.add_child(brow)
	box.add_child(row)


func _build_intro() -> void:
	var tint: Color = world_color(world)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box().add_child(center)
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_5)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size.x = COLUMN_WIDTH
	center.add_child(box)
	_head(box, tint, "epi_eyebrow_%s" % world)
	var title: Label = ScreenBase.label(UiText.t("epi_title", "UN AN PLUS TARD"), &"DisplayLabel", DS.TEXT_PRIMARY)
	title.name = "EpilogueTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", roundi(DS.FS_DISPLAY_XL * Settings.text_scale))
	box.add_child(title)
	var date: Label = ScreenBase.label(UiText.t("epi_card_date", "Vendredi 11.04.2188"), &"DataTitle", Palette.TEXT_SECONDARY)
	date.name = "EpilogueDate"
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(date)
	var line: ColorRect = ScreenBase.rule_line(Color(tint, 0.4))
	line.custom_minimum_size = Vector2(480.0, DS.BORDER_HAIRLINE)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(line)
	var recall: Label = ScreenBase.wrapped(UiText.t("epi_card_recall", "Il y a un an, la dernière Transit-7 de Tycho s'arrimait à 14:00."),
			&"TitleLabel", DS.TEXT_PRIMARY)
	recall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(recall)
	continue_button = ScreenBase.button(UiText.t("epi_card_continue", "CONTINUER"), &"ButtonPrimary")
	continue_button.name = "Continue"
	continue_button.custom_minimum_size.x = 360.0
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(close.bind(&"next"))
	box.add_child(continue_button)
	var note: Label = ScreenBase.label(UiText.t("epi_card_note", "Épilogue · la partie terminée n'est pas modifiée"), &"CaptionLabel")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_done = true
	continue_button.grab_focus.call_deferred()


func _build_conclusion() -> void:
	var tint: Color = world_color(world)
	var page: VBoxContainer = ScreenBase.vbox(DS.SPACE_4)
	root_box().add_child(page)
	# QA-058 : la colonne prend toute la hauteur libre (pas de CenterContainer,
	# qui la réduisait à sa hauteur minimale et tronquait les lignes).
	var column: VBoxContainer = ScreenBase.vbox(DS.SPACE_4)
	column.name = "Column"
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(column)
	_head(column, tint, str(card.get("eyebrow_key", "epi_eyebrow_%s" % world)))
	var title: Label = ScreenBase.label(UiText.t(str(card.get("title_key", "epi_title")), "UN AN PLUS TARD"), &"DisplayLabel", DS.TEXT_PRIMARY)
	title.name = "EpilogueTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	sub.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(sub)
	var world_name: Label = ScreenBase.label(UiText.t(str(card.get("name_key", "dos_world_%s" % world)), ""), &"TitleLabel", tint)
	world_name.name = "WorldName"
	sub.add_child(world_name)
	var tally_args: Array = card.get("tally_args", [0]) if card.get("tally_args") is Array else [0]
	var tally: Label = ScreenBase.label(UiText.tf(str(card.get("tally_key", "epi_tally")), tally_args, "7 passagers · %d avertissement(s)"),
			&"DataSmall", Palette.TEXT_SECONDARY)
	tally.name = "Tally"
	tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub.add_child(tally)
	column.add_child(ScreenBase.rule_line(Color(tint, 0.3)))
	_scroll = ScrollContainer.new()
	_scroll.name = "Lines"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	var lines_box: VBoxContainer = ScreenBase.vbox(DS.SPACE_5)
	lines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(lines_box)
	for text: String in conclusion_lines(card):
		var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
		var mark: ColorRect = ColorRect.new()
		mark.color = Color(tint, 0.6)
		mark.custom_minimum_size = Vector2(DS.BORDER_STRONG, DS.SPACE_6)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		var label_node: Label = ScreenBase.wrapped(text, &"TitleLabel", DS.TEXT_PRIMARY)
		label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label_node)
		row.modulate.a = 0.0
		lines_box.add_child(row)
		line_labels.append(label_node)
	var farewell_key: String = str(card.get("farewell_key", ""))
	if not farewell_key.is_empty():
		var farewell: Label = ScreenBase.wrapped(ComparisonUI.lumika_text(UiText.t(farewell_key, ""), true), &"BodyStrong", Palette.ACCENT_MAGENTA)
		farewell.name = "Farewell"
		farewell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		farewell.modulate.a = 0.0
		lines_box.add_child(farewell)
		_farewell = farewell
	more_hint = _more_hint()
	column.add_child(more_hint)
	_scroll.get_v_scroll_bar().changed.connect(update_more_hint)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: update_more_hint())
	_scroll.resized.connect(update_more_hint)
	page.add_child(ScreenBase.rule_line())
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	page.add_child(foot)
	var hint: Label = ScreenBase.label(UiText.t("epi_end_hint", "Le Dossier de l'agent garde cette conclusion."), &"CaptionLabel")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	foot.add_child(ScreenBase.spacer())
	skip_button = ScreenBase.button(UiText.t("end_skip", "TOUT AFFICHER"), &"ButtonGhost")
	skip_button.name = "Skip"
	skip_button.pressed.connect(reveal_all)
	foot.add_child(skip_button)
	continue_button = ScreenBase.button(UiText.t("end_to_title", "RETOUR AU TITRE"), &"ButtonPrimary")
	continue_button.name = "Title"
	continue_button.custom_minimum_size.x = 280.0
	continue_button.pressed.connect(close.bind(&"title"))
	foot.add_child(continue_button)
	_start_reveal()
	(skip_button if not _done else continue_button).grab_focus.call_deferred()


## « SUITE · défiler » : glyphe du stick droit + texte, centré sous les lignes.
func _more_hint() -> Control:
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	row.name = "MoreHint"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(PromptGlyph.make(&"scroll_down"))
	var label_node: Label = ScreenBase.label(UiText.t("epi_scroll_more", "SUITE · défiler"), &"CaptionLabel", Palette.TEXT_SECONDARY)
	label_node.name = "MoreLabel"
	row.add_child(label_node)
	row.modulate.a = 0.0
	return row


## Zone défilante des lignes de conclusion (null sur la carte d'ouverture).
func lines_scroll() -> ScrollContainer:
	return _scroll


## Vrai s'il reste du texte sous la zone visible des lignes.
func has_more_below() -> bool:
	if _scroll == null:
		return false
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	return bar.max_value - bar.page > 1.0 and bar.value < bar.max_value - bar.page - 1.0


## Le repère garde sa place (pas de saut de mise en page) : seule son opacité change.
func update_more_hint() -> void:
	if more_hint != null:
		more_hint.modulate.a = 1.0 if has_more_below() else 0.0


## Croix / flèches ↑ ↓ depuis les boutons du pied : défile les lignes d'une
## demi-page (rien d'autre n'est focalisable au-dessus). Vrai si consommé.
func scroll_lines(direction: int) -> bool:
	if _scroll == null:
		return false
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	if bar.max_value - bar.page <= 1.0:
		return false
	var before: int = _scroll.scroll_vertical
	_scroll.scroll_vertical = before + direction * roundi(maxf(_scroll.size.y * 0.5, 1.0))
	return _scroll.scroll_vertical != before


func _start_reveal() -> void:
	revealed = 0
	_done = false
	if Settings.reduce_motion or line_labels.is_empty():
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


func reveal_next() -> void:
	if revealed >= line_labels.size():
		_finish_reveal()
		return
	var row: Control = line_labels[revealed].get_parent() as Control
	revealed += 1
	row.create_tween().tween_property(row, "modulate:a", 1.0, DS.DUR_DRAMATIC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _scroll != null:
		_scroll.ensure_control_visible.call_deferred(row)
	if revealed >= line_labels.size():
		get_tree().create_timer(DS.DUR_DRAMATIC).timeout.connect(_finish_reveal)


func reveal_all() -> void:
	for label_node: Label in line_labels:
		(label_node.get_parent() as Control).modulate.a = 1.0
	revealed = line_labels.size()
	_finish_reveal()


func is_reveal_done() -> bool:
	return _done


func _finish_reveal() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	if _farewell != null:
		_farewell.modulate.a = 1.0
	if skip_button != null:
		skip_button.visible = false
	if continue_button != null and is_inside_tree():
		continue_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.CONCLUSION or _done:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept"):
		reveal_all()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if is_closing() or not is_visible_in_tree():
		return
	if mode == Mode.CONCLUSION and (event.is_action_pressed(&"ui_up", false, true) or event.is_action_pressed(&"ui_down", false, true)):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null and (focused == continue_button or focused == skip_button) \
				and scroll_lines(-1 if event.is_action_pressed(&"ui_up", false, true) else 1):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		# Ⓑ : conclusion — tout afficher d'abord, puis retour au titre ; carte
		# d'ouverture — retour au titre (rien n'est écrit pendant le J31).
		if not _done:
			reveal_all()
		else:
			close(&"title")
		get_viewport().set_input_as_handled()
