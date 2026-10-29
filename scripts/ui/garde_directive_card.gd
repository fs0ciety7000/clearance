## Carte « DIRECTIVE DE GARDE N° n » (M12 lot C, I31 ; M12 §2.2) : posée sur le
## plan de travail après le passager qui déclenche la directive, avant le
## suivant. Titre de l'unité, texte de chaque règle (neutre, `r_*_text`),
## action (NOUVEAU · REPRIS PAR LES QUAIS · RÉTABLIE : icône + texte),
## documents et onglets ajoutés ; « Effet au prochain passager ». Au plus
## `DS.DIRECTIVE_HOLD`, puis fondu ; passable (COMPRIS / Ⓐ / clic / Échap).
## Le focus va à COMPRIS pendant l'affichage (Ⓐ ferme la carte avant
## d'appeler le passager, D-114) ; `GardeHud` le rend au guichet ensuite.
class_name GardeDirectiveCard
extends Control

signal dismissed()

const WIDTH: float = 720.0

var number: int = 0
var unit: GardeUnitDef = null
var action: StringName = GardeService.ACTION_ADD
var ok_button: Button = null
var panel: PanelContainer = null
var _done: bool = false
var _hold_left: float = DS.DIRECTIVE_HOLD


static func make(p_number: int, p_unit: GardeUnitDef, p_action: StringName) -> GardeDirectiveCard:
	var card: GardeDirectiveCard = GardeDirectiveCard.new()
	card.name = "GardeDirectiveCard"
	card.number = p_number
	card.unit = p_unit
	card.action = p_action
	return card


func _init() -> void:
	# Zone du plan de travail (UI_FLOW §2) : entre la vitre et la barre d'outils,
	# à gauche du Rulebook.
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_top = ComparisonUI.BAND_BOTTOM
	offset_right = -ComparisonUI.WORKBENCH_RIGHT_GAP
	offset_bottom = -ComparisonUI.TOOLBAR_H
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Couleur de l'action (ambre : nouveau ; gris : retrait ; cyan : rétablie).
static func action_color(p_action: StringName) -> Color:
	match p_action:
		GardeService.ACTION_RETIRE:
			return Palette.TEXT_SECONDARY
		GardeService.ACTION_RESTORE:
			return DS.ACCENT_CYAN
	return Palette.STATE_AMBER


static func action_text(p_action: StringName) -> String:
	match p_action:
		GardeService.ACTION_RETIRE:
			return UiText.t("garde_dir_retire", "REPRIS PAR LES QUAIS")
		GardeService.ACTION_RESTORE:
			return UiText.t("garde_dir_restore", "RÉTABLIE")
	return UiText.t("badge_new", "NOUVEAU")


static func action_icon(p_action: StringName) -> UiIcon.Kind:
	match p_action:
		GardeService.ACTION_RETIRE:
			return UiIcon.Kind.STRIKE
		GardeService.ACTION_RESTORE:
			return UiIcon.Kind.CHECK
	return UiIcon.Kind.WARNING


func _ready() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var accent: Color = action_color(action)
	panel = PanelContainer.new()
	panel.name = "Card"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size.x = WIDTH
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(DS.BG_PANEL, accent, DS.BORDER_STRONG, DS.CHAMFER_L, DS.SPACE_6)
	box.shadow_color = Color(accent, 0.24)
	box.shadow_size = DS.GLOW_2
	panel.add_theme_stylebox_override(&"panel", box)
	panel.gui_input.connect(_on_panel_input)
	center.add_child(panel)
	var col: VBoxContainer = ScreenBase.vbox(DS.SPACE_3)
	panel.add_child(col)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	col.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.LOGO, DS.ACCENT_YELLOW, DS.ICON_M))
	var eyebrow: Label = ScreenBase.eyebrow(UiText.tf("garde_dir_title", [number], "DIRECTIVE DE GARDE N° %d"), DS.ACCENT_YELLOW)
	eyebrow.name = "Number"
	eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(eyebrow)
	head.add_child(ScreenBase.spacer())
	var badge: PanelContainer = ScreenBase.chip(action_text(action), action_icon(action), accent)
	badge.name = "Action"
	head.add_child(badge)
	var title: Label = ScreenBase.wrapped(UiText.t(unit.title_key, String(unit.id)) if unit != null else "", &"TitleLabel", DS.TEXT_PRIMARY)
	title.name = "UnitTitle"
	col.add_child(title)
	if unit != null:
		for rule: Rule in unit.rules:
			if rule == null:
				continue
			var entry: RulebookEntry = rule.get_rulebook_entry()
			var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
			col.add_child(row)
			var mark: ColorRect = ColorRect.new()
			mark.color = accent
			mark.custom_minimum_size = Vector2(DS.BORDER_STRONG, DS.SPACE_5)
			mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(mark)
			var text: VBoxContainer = ScreenBase.vbox(0)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			var rule_title: String = UiText.t(entry.title_key, String(entry.rule_id))
			if rule_title != title.text:
				text.add_child(ScreenBase.label(rule_title, &"BodyStrong", DS.TEXT_PRIMARY))
			var body: Label = ScreenBase.wrapped(RuleCardView.rule_text(entry), &"BodySmall",
					DS.TEXT_MUTED if action == GardeService.ACTION_RETIRE else Palette.TEXT_SECONDARY)
			text.add_child(body)
		var extras: PackedStringArray = []
		for doc_id: StringName in unit.document_ids:
			extras.append(UiText.t("doc_%s_title" % doc_id, String(doc_id)))
		for tab: String in unit.rulebook_tabs:
			extras.append(RulebookReference.tab_title(StringName(tab)))
		if not extras.is_empty() and action != GardeService.ACTION_RETIRE:
			col.add_child(ScreenBase.wrapped(UiText.tf("garde_dir_adds", [" · ".join(extras)], "Ajoute : %s"), &"CaptionLabel"))
	col.add_child(ScreenBase.rule_line())
	var foot: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	col.add_child(foot)
	var hint: Label = ScreenBase.wrapped(UiText.t("garde_dir_effect", "Effet au prochain passager · Rulebook › Règles."), &"CaptionLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	foot.add_child(PromptGlyph.make(&"ui_accept"))
	ok_button = ScreenBase.button(UiText.t("garde_dir_ok", "COMPRIS"), &"ButtonTool")
	ok_button.name = "Ok"
	ok_button.custom_minimum_size.x = 160.0
	ok_button.pressed.connect(dismiss)
	foot.add_child(ok_button)
	if not (Settings.reduce_motion or Settings.fx_intensity <= 0.0):
		panel.modulate.a = 0.0
		panel.create_tween().tween_property(panel, "modulate:a", 1.0, DS.DUR_BASE)
	ok_button.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if _done:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		dismiss()


## Captures : la carte reste affichée (pas de fondu après `DS.DIRECTIVE_HOLD`).
func hold() -> void:
	_hold_left = INF


func is_dismissed() -> bool:
	return _done


## Ferme la carte (fondu court, immédiat si les animations sont réduites).
func dismiss() -> void:
	if _done:
		return
	_done = true
	dismissed.emit()
	if Settings.reduce_motion or not is_inside_tree() or panel == null:
		queue_free()
		return
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, DS.DUR_FAST)
	tween.tween_callback(queue_free)


func _on_panel_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		dismiss()
		accept_event()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		dismiss()
		get_viewport().set_input_as_handled()
