## Entrée de l'onglet « Révocations » du Rulebook (Acte II, R30, J17+) : N° ID
## révoqué en mono (la donnée à comparer), nom de l'ex-titulaire, motif
## facultatif. **Sélectionnable en Mode Inspection** comme un champ :
## `FieldRef.revoked(id)`, comparable au N° ID d'un document
## (`DiscrepancyChecker` : égalité = DISCORDANCE, le titulaire n'est plus citoyen).
## Acte III (R33) : colonne « RÉINTÉGRÉ·E LE » (date atteinte : statut vert,
## la révocation est levée ; date à venir : rappel de la date) et motif
## d'exclusion de la réintégration (`excluded_reason_key`, ambre).
class_name RevokedCardView
extends InspectableItem

var entry: RevokedEntry = null
var number: int = 0
## Acte III : la révocation est levée à la date du jour (R33).
var reinstated: bool = false

var _id_label: Label = null


## `today` (`GameDate`) : date du jour pour la colonne « RÉINTÉGRÉ·E LE » (0 : ignorée).
func setup(p_entry: RevokedEntry, p_number: int, today: int = 0) -> void:
	entry = p_entry
	number = p_number
	reinstated = today > 0 and p_entry.is_reinstated(today)
	ref = p_entry.get_ref()
	comparable = true
	display_label = UiText.tf("rb_revoked_display", [p_number, p_entry.citizen_id], "RÉVOCATION %02d · %s")
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
	var index: Label = ScreenBase.label("%02d" % p_number, &"DataSmall", DS.TEXT_SECONDARY)
	index.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(index)
	var column: VBoxContainer = ScreenBase.vbox(0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_id_label = ScreenBase.label(p_entry.citizen_id, &"DataTitle", DS.TEXT_PRIMARY)
	column.add_child(_id_label)
	var who: String = p_entry.full_name().strip_edges().to_upper()
	var detail: String = who
	if not p_entry.reason_key.is_empty():
		detail = "%s · %s" % [who, UiText.t(p_entry.reason_key, "")] if not who.is_empty() else UiText.t(p_entry.reason_key, "")
	# Nom puis statut ; repli sur deux lignes dans un Rulebook étroit (Steam Deck).
	var detail_row: HFlowContainer = HFlowContainer.new()
	detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_row.add_theme_constant_override("h_separation", DS.SPACE_3)
	column.add_child(detail_row)
	var detail_label: Label = ScreenBase.label(detail, &"BodySmall")
	detail_row.add_child(detail_label)
	var status: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	status.name = "Status"
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if reinstated:
		status.add_child(UiIcon.make(UiIcon.Kind.APPROVED, DS.STATE_GREEN, DS.ICON_S))
		status.add_child(ScreenBase.label(UiText.t("cmp_reinstated", "RÉINTÉGRÉ (R33)"), &"DocFieldLabel", DS.STATE_GREEN))
	else:
		status.add_child(UiIcon.make(UiIcon.Kind.DENIED, DS.STATE_RED, DS.ICON_S))
		status.add_child(ScreenBase.label(UiText.t("rb_revoked_action", "NON CITOYEN·NE"), &"DocFieldLabel", DS.STATE_RED))
	detail_row.add_child(status)
	# Acte III (R33) : colonne « RÉINTÉGRÉ·E LE » ou motif d'exclusion.
	if p_entry.reinstated_on > 0:
		var on: Label = ScreenBase.label("%s %s" % [UiText.t("rb_col_reinstated", "RÉINTÉGRÉ·E LE"), UiText.date(p_entry.reinstated_on)],
				&"DocFieldLabel", DS.STATE_GREEN if reinstated else DS.TEXT_SECONDARY)
		on.name = "ReinstatedOn"
		column.add_child(on)
	elif not p_entry.excluded_reason_key.is_empty():
		var excluded: Label = ScreenBase.wrapped(UiText.t(p_entry.excluded_reason_key, ""), &"CaptionLabel", DS.STATE_AMBER)
		excluded.name = "Excluded"
		column.add_child(excluded)
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_sync_min_size(margin)


func _sync_min_size(margin: MarginContainer) -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, margin.get_combined_minimum_size().y)


func _refresh_content() -> void:
	if _id_label == null:
		return
	if is_flagged():
		_id_label.add_theme_color_override(&"font_color", DS.ACCENT_MAGENTA)
	elif selected:
		_id_label.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	else:
		_id_label.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)


func _draw() -> void:
	# Registre de la Commission : fond élevé, liseré bleu de registre (vert :
	# réintégré·e, la révocation ne vaut plus).
	if not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.GREEN_12 if reinstated else DS.VOICE_COMMISSION_12)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), DS.STATE_GREEN if reinstated else DS.VOICE_COMMISSION)
	super._draw()


## Cadre complet en inspection (comme une règle).
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
