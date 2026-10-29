## Entrée de l'onglet « Main courante » du Rulebook (Acte III, R34, J24+ ;
## ARCHITECTURE §7.3, ACT3 §2.5 M2) : un passager **admis aujourd'hui à cette
## vitre** et admissible comme répondant. N° ID en mono (la donnée à comparer),
## nom, classe et origine. **Sélectionnable en Mode Inspection** comme un champ
## (`FieldRef.ledger(id)`) : la paire « Répondant (permis) ↔ entrée » est
## CONCORDANTE quand le N° ID est le même (`disc_sponsor_match`).
## La dernière entrée inscrite est surlignée brièvement (`highlight()`), la
## liste s'allonge pendant le shift (`ledger_changed`).
class_name LedgerCardView
extends InspectableItem

var entry: LedgerEntry = null
var number: int = 0
## Surlignage « dernière entrée » (1 → 0), animé par `highlight()`.
var glow: float = 0.0:
	set(value):
		glow = value
		queue_redraw()

var _id_label: Label = null


func setup(p_entry: LedgerEntry, p_number: int) -> void:
	entry = p_entry
	number = p_number
	ref = p_entry.get_ref()
	comparable = true
	display_label = UiText.tf("rb_ledger_display", [p_number, p_entry.citizen_id], "MAIN COURANTE %02d · %s")
	tooltip_text = display_label
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", DS.SPACE_4)
	margin.add_theme_constant_override("margin_right", DS.SPACE_8)
	margin.add_theme_constant_override("margin_top", DS.SPACE_2)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_2)
	add_child(margin)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	margin.add_child(row)
	var index: Label = ScreenBase.label("%02d" % p_number, &"DataSmall", Palette.TEXT_SECONDARY)
	index.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(index)
	var column: VBoxContainer = ScreenBase.vbox(0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_id_label = ScreenBase.label(p_entry.citizen_id, &"DataTitle", DS.TEXT_PRIMARY)
	column.add_child(_id_label)
	# Nom puis statut (classe, « ADMIS·E ») ; repli sur deux lignes au Deck.
	var detail_row: HFlowContainer = HFlowContainer.new()
	detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_row.add_theme_constant_override("h_separation", DS.SPACE_3)
	column.add_child(detail_row)
	detail_row.add_child(ScreenBase.label(p_entry.full_name().strip_edges().to_upper(), &"BodySmall"))
	var status: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(UiIcon.make(UiIcon.Kind.APPROVED, Palette.STATE_GREEN, DS.ICON_S))
	var klass: String = String(p_entry.citizen_class)
	status.add_child(ScreenBase.label(UiText.tf("rb_ledger_admitted", [klass], "ADMIS·E · %s"), &"DocFieldLabel", Palette.STATE_GREEN))
	detail_row.add_child(status)
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_sync_min_size(margin)


## Dernière entrée inscrite : surlignage qui s'éteint (immédiat sans animation).
func highlight(reduce_motion: bool = false) -> void:
	glow = 1.0
	if reduce_motion:
		return
	var tween: Tween = create_tween()
	tween.tween_interval(DS.DUR_DRAMATIC * 2.0)
	tween.tween_property(self, "glow", 0.0, DS.DUR_DRAMATIC * 2.0).set_trans(Tween.TRANS_SINE)


func _sync_min_size(margin: MarginContainer) -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, margin.get_combined_minimum_size().y)


func _refresh_content() -> void:
	if _id_label == null:
		return
	if is_flagged():
		_id_label.add_theme_color_override(&"font_color", Palette.ACCENT_MAGENTA)
	elif selected:
		_id_label.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	else:
		_id_label.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)


func _draw() -> void:
	# Registre du guichet : fond élevé, liseré vert des admissions ; la
	# dernière entrée garde un fond vert 12 % le temps du surlignage.
	if not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.BG_ELEVATED)
		if glow > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.GREEN_12, Palette.GREEN_12.a * glow * 2.0))
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), Palette.STATE_GREEN)
	super._draw()


## Cadre complet en inspection (comme une règle).
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
