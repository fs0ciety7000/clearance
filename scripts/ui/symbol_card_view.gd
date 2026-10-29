## Entrée du bulletin « Symboles subversifs » du Rulebook (M7, J7+, NARRATIVE
## §4.9) : glyphe, nom, description, consigne « À SIGNALER ».
## **Sélectionnable en Mode Inspection** : `FieldRef.symbol(id)`, comparable à
## la marque au coin d'un document (`DocMarkView`, `FieldRef.mark`) — la paire
## épinglée documente le signalement d'un porteur du code 1 (D-062).
class_name SymbolCardView
extends InspectableItem

const GLYPH_SIZE: Vector2 = Vector2(64, 64)

var symbol_id: StringName = &""

var _title: Label = null


func setup(p_symbol_id: StringName) -> void:
	symbol_id = p_symbol_id
	ref = FieldRef.symbol(p_symbol_id)
	comparable = true
	var key: String = "rb_symbol_%s" % p_symbol_id
	display_label = UiText.t(key + "_title", String(p_symbol_id))
	tooltip_text = display_label
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", DS.SPACE_4)
	margin.add_theme_constant_override("margin_right", DS.SPACE_8)
	margin.add_theme_constant_override("margin_top", DS.SPACE_3)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_3)
	add_child(margin)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	margin.add_child(row)
	var glyph: Control = Control.new()
	glyph.name = "Glyph"
	glyph.custom_minimum_size = GLYPH_SIZE
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	glyph.draw.connect(_draw_glyph.bind(glyph))
	row.add_child(glyph)
	var column: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_title = ScreenBase.label(display_label, &"BodyStrong", DS.TEXT_PRIMARY)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 120.0
	column.add_child(_title)
	column.add_child(ScreenBase.wrapped(UiText.t(key + "_text", ""), &"BodySmall"))
	column.add_child(ScreenBase.chip(UiText.t(key + "_action", "À SIGNALER"), UiIcon.Kind.WARNING, Palette.STATE_AMBER))
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_sync_min_size(margin)


func _sync_min_size(margin: MarginContainer) -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, margin.get_combined_minimum_size().y)


func _draw_glyph(glyph: Control) -> void:
	glyph.draw_rect(Rect2(Vector2.ZERO, glyph.size), DS.BG_PANEL)
	glyph.draw_rect(Rect2(Vector2.ZERO, glyph.size), Palette.MAGENTA_24, false, 1.0)
	SlippedItemView.draw_luciole(glyph, glyph.size * 0.5 + Vector2(0, DS.SPACE_1), DS.SPACE_4, Palette.ACCENT_MAGENTA)


func _refresh_content() -> void:
	if _title == null:
		return
	if is_flagged():
		_title.add_theme_color_override(&"font_color", Palette.ACCENT_MAGENTA)
	elif selected:
		_title.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	else:
		_title.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)


func _draw() -> void:
	# Fond du bulletin : liseré magenta à gauche (comme les autres références).
	if not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.BG_ELEVATED)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), Palette.ACCENT_MAGENTA)
	super._draw()


## Cadre complet en inspection (comme une règle ou un avis de recherche).
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
