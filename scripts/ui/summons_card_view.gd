## Entrée de l'onglet « Convocations » du Rulebook (Acte III, R36, J26+ ;
## ARCHITECTURE §7.3) : N° `ENQ-NNNN` en mono (la donnée à comparer), nom du
## convoqué, motif facultatif. **Sélectionnable en Mode Inspection**
## (`FieldRef.summons(id)`) : paire « Convocation (permis) ↔ entrée » —
## même N° et même nom : CONCORDANT ; même N°, autre nom : DISCORDANT.
## Couleur : ambre de l'Enquête (voix INSPECTION, D-061), icône balance.
class_name SummonsCardView
extends InspectableItem

var entry: SummonsEntry = null
var number: int = 0

var _id_label: Label = null


func setup(p_entry: SummonsEntry, p_number: int) -> void:
	entry = p_entry
	number = p_number
	ref = p_entry.get_ref()
	comparable = true
	display_label = UiText.tf("rb_summons_display", [p_entry.number, p_entry.full_name().strip_edges().to_upper()],
			"CONVOCATION %s · %s")
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
	var icon: UiIcon = UiIcon.make(UiIcon.Kind.SCALES, Palette.STATE_AMBER, DS.ICON_M)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var column: VBoxContainer = ScreenBase.vbox(0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_id_label = ScreenBase.label(p_entry.number, &"DataTitle", DS.TEXT_PRIMARY)
	column.add_child(_id_label)
	var who: String = p_entry.full_name().strip_edges().to_upper()
	column.add_child(ScreenBase.label(who, &"BodySmall"))
	if not p_entry.reason_key.is_empty():
		var reason: Label = ScreenBase.wrapped(UiText.t(p_entry.reason_key, ""), &"CaptionLabel")
		reason.name = "Reason"
		column.add_child(reason)
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_sync_min_size(margin)


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
	# Pièce de l'Enquête : fond élevé, liseré ambre.
	if not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.BG_ELEVATED)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), Palette.STATE_AMBER)
	super._draw()


## Cadre complet en inspection (comme une règle).
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
