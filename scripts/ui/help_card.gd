## Carte d'aide M13 (lot C ; M13 §6.5, ARCHITECTURE §12.10) : au premier jour
## où R43 (déclarations, J4) ou R44 (portique, J8) est en vigueur — partie
## neuve ou reprise d'une 0.12 —, une carte posée sur le plan de travail
## explique le geste (texte + invites qui suivent le périphérique). Passable
## (COMPRIS / Ⓐ / clic / Échap / Ⓑ) ; à la fermeture, le réglage
## correspondant passe à faux (`Settings.KEY_TUTORIAL_M13_*`, comme
## `tutorial_j1`) : elle ne revient pas. Plusieurs cartes dues : l'une après
## l'autre (« 1 / 2 »). Le focus va à COMPRIS (Ⓐ ferme la carte avant
## d'appeler le passager, D-114).
class_name HelpCard
extends Control

signal dismissed(key: StringName)
## Toutes les cartes ont été lues.
signal finished()

var keys: Array[StringName] = []
## Faux (captures) : le réglage n'est changé que pour la session.
var persist: bool = true
var index: int = 0
var ok_button: Button = null
var panel: PanelContainer = null
var _done: bool = false
var _center: CenterContainer = null


static func make(p_keys: Array[StringName]) -> HelpCard:
	var card: HelpCard = HelpCard.new()
	card.name = "HelpCard"
	card.keys = p_keys.duplicate()
	return card


func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_top = ComparisonUI.BAND_BOTTOM
	offset_right = -ComparisonUI.WORKBENCH_RIGHT_GAP
	offset_bottom = -ComparisonUI.TOOLBAR_H
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_show(0)


## Carte en cours (`Settings.KEY_TUTORIAL_M13_*`), vide si tout est lu.
func current_key() -> StringName:
	return keys[index] if index < keys.size() else &""


static func title_of(key: StringName) -> String:
	if key == Settings.KEY_TUTORIAL_M13_SEARCH:
		return UiText.t("help_search_title", "PORTIQUE · FOUILLE SUR MOTIF")
	return UiText.t("help_statements_title", "DÉCLARATIONS · CE QU'ILS DISENT")


static func body_of(key: StringName) -> String:
	if key == Settings.KEY_TUTORIAL_M13_SEARCH:
		return UiText.t("help_search_text",
				"Interroger › « Placez-vous dans le portique ». Le MOTIF s'affiche avant la fouille : sans motif, fouiller un passager en règle est une faute (FOUILLE SANS MOTIF). Choisissez une zone, ou TOUT SCANNER, puis comparez les objets à l'onglet Contrebande.")
	return UiText.t("help_statements_text",
			"La réponse du passager s'inscrit au journal. Ses valeurs soulignées » se comparent comme des champs : choisissez-en une, puis le champ du permis. Une déclaration contradictoire documente un refus (R43).")


## Gestes (invites qui suivent le périphérique : clavier ou manette).
static func steps_of(key: StringName) -> PackedStringArray:
	var steps: PackedStringArray = []
	if key == Settings.KEY_TUTORIAL_M13_SEARCH:
		steps.append(UiText.tf("help_search_step_1", [InputPrompts.text_for(&"interrogate")], "%s : Interroger › Portique"))
		steps.append(UiText.tf("help_search_step_2", [InputPrompts.text_for(&"ui_accept")], "Croix + %s : scanner une zone"))
		steps.append(UiText.tf("help_search_step_3", [InputPrompts.text_for(&"cancel")], "%s : refermer le portique"))
		return steps
	steps.append(UiText.tf("help_statements_step_1", [InputPrompts.text_for(&"interrogate")], "%s : poser la question"))
	steps.append(UiText.tf("help_statements_step_2", [InputPrompts.text_for(&"inspect_toggle")], "%s : Mode Inspection"))
	steps.append(UiText.tf("help_statements_step_3", [InputPrompts.text_for(&"ui_accept")],
			"Croix ↑ vers le journal · %s : choisir la puce, puis le champ"))
	return steps


func _show(p_index: int) -> void:
	index = p_index
	if panel != null:
		panel.queue_free()
		panel = null
	var key: StringName = current_key()
	if key == &"":
		_finish()
		return
	var accent: Color = DS.ACCENT_CYAN
	panel = PanelContainer.new()
	panel.name = "Card"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size.x = DS.HELP_CARD_WIDTH
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(DS.BG_PANEL, accent, DS.BORDER_STRONG, DS.CHAMFER_L, DS.SPACE_6)
	box.shadow_color = Color(accent, 0.24)
	box.shadow_size = DS.GLOW_2
	panel.add_theme_stylebox_override(&"panel", box)
	panel.gui_input.connect(_on_panel_input)
	_center.add_child(panel)
	var col: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	panel.add_child(col)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	col.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.GATE if key == Settings.KEY_TUTORIAL_M13_SEARCH else UiIcon.Kind.QUOTE, accent, DS.ICON_M))
	var eyebrow: Label = ScreenBase.eyebrow(UiText.t("help_eyebrow", "AIDE · NOUVEAU AU GUICHET"), accent)
	eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(eyebrow)
	head.add_child(ScreenBase.spacer())
	if keys.size() > 1:
		var page: Label = ScreenBase.label("%d / %d" % [index + 1, keys.size()], &"DataSmall", Palette.TEXT_SECONDARY)
		page.name = "Page"
		page.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(page)
	var title: Label = ScreenBase.wrapped(title_of(key), &"TitleLabel", DS.TEXT_PRIMARY)
	title.name = "Title"
	col.add_child(title)
	var body: Label = ScreenBase.wrapped(body_of(key), &"BodyLabel", DS.TEXT_PRIMARY)
	body.name = "Body"
	col.add_child(body)
	for step: String in steps_of(key):
		var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		col.add_child(row)
		var mark: ColorRect = ColorRect.new()
		mark.color = accent
		mark.custom_minimum_size = Vector2(DS.BORDER_STRONG, DS.SPACE_4)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		var step_label: Label = ScreenBase.wrapped(step, &"BodySmall", Palette.TEXT_SECONDARY)
		step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(step_label)
	col.add_child(ScreenBase.rule_line())
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	col.add_child(foot)
	var hint: Label = ScreenBase.wrapped(UiText.t("help_hint", "Cette aide ne reviendra pas. Options › Partie pour la revoir."), &"CaptionLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	foot.add_child(PromptGlyph.make(&"ui_accept"))
	ok_button = ScreenBase.button(UiText.t("help_ok", "COMPRIS") if index == keys.size() - 1 else UiText.t("help_next", "SUIVANT"),
			&"ButtonTool")
	ok_button.name = "Ok"
	ok_button.custom_minimum_size.x = 160.0
	ok_button.pressed.connect(advance)
	foot.add_child(ok_button)
	if not (Settings.reduce_motion or Settings.fx_intensity <= 0.0):
		panel.modulate.a = 0.0
		panel.create_tween().tween_property(panel, "modulate:a", 1.0, DS.DUR_BASE)
	ok_button.grab_focus.call_deferred()


## Carte lue : réglage à faux, carte suivante ou fin.
func advance() -> void:
	if _done:
		return
	var key: StringName = current_key()
	if key != &"":
		if persist:
			Settings.set_value(key, false)
		else:
			Settings.set_session_value(key, false)
		dismissed.emit(key)
	_show(index + 1)


func is_dismissed() -> bool:
	return _done


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _on_panel_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		advance()
		get_viewport().set_input_as_handled()
