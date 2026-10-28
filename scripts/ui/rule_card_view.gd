## RuleCard (DS §7.5) : n° de règle, badge NOUVEAU (ambre + triangle), texte de
## la règle. Champ comparable en Mode Inspection (`FieldRef.rulebook_rule`).
## Acte III (M1, I21) : règle **retirée** (`RulebookEntry.retired`) affichée
## barrée, atténuée, avec son motif (`note_key` : « REPRIS PAR LES QUAIS ») et
## jamais comparable ; note du jour sous une règle active (« SUSPENDU
## PENDANT L'ENQUÊTE » sous R23).
class_name RuleCardView
extends InspectableItem

var entry: RulebookEntry = null
var number: int = 0

var _text: Label = null
var _number: Label = null
## Acte III : note affichée sous le texte (motif de retrait, quota suspendu).
var note_text: String = ""


## Texte d'une règle ; R23 (« %d entrées par jour ») reçoit le quota du jour.
static func rule_text(p_entry: RulebookEntry, quota: int = 0) -> String:
	var text: String = UiText.t(p_entry.text_key, UiText.t(p_entry.title_key, String(p_entry.rule_id)))
	if text.contains("%d"):
		return text.replace("%d", str(quota) if quota > 0 else "—")
	return text


## `extra_note` : note du jour imposée par l'UI (quota suspendu par le climat).
func setup(p_entry: RulebookEntry, p_number: int, quota: int = 0, extra_note: String = "") -> void:
	entry = p_entry
	number = p_number
	ref = p_entry.ref if p_entry.ref != null else FieldRef.rulebook_rule(p_entry.rule_id)
	comparable = not p_entry.retired
	if not p_entry.note_key.is_empty():
		note_text = UiText.t(p_entry.note_key, "")
	elif not extra_note.is_empty():
		note_text = extra_note
	var title: String = UiText.t(p_entry.title_key, String(p_entry.rule_id))
	display_label = "%02d · %s" % [p_number, title] if not p_entry.retired else title
	tooltip_text = title
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", DS.SPACE_3)
	margin.add_theme_constant_override("margin_right", DS.SPACE_8)
	margin.add_theme_constant_override("margin_top", DS.SPACE_2)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_2)
	add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", DS.SPACE_3)
	margin.add_child(row)
	_number = Label.new()
	_number.theme_type_variation = &"DataSmall"
	_number.text = "%02d" % p_number if not p_entry.retired else "—"
	_number.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_number)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", DS.SPACE_1)
	row.add_child(column)
	if p_entry.is_new:
		var badge_row: HBoxContainer = HBoxContainer.new()
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(badge_row)
		badge_row.add_child(make_new_badge(UiText.t("badge_new", "NOUVEAU")))
	_text = Label.new()
	_text.theme_type_variation = &"BodySmall"
	_text.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.text = rule_text(p_entry, quota)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size.x = 120.0
	column.add_child(_text)
	if p_entry.retired:
		# Retrait (M1) : texte atténué, barré ligne à ligne, motif en puce.
		_text.add_theme_color_override(&"font_color", DS.TEXT_MUTED)
		_text.draw.connect(_draw_strike)
		tooltip_text = "%s — %s" % [title, note_text] if not note_text.is_empty() else title
	if not note_text.is_empty():
		var chip_color: Color = DS.TEXT_SECONDARY if p_entry.retired else DS.STATE_AMBER
		var note: PanelContainer = ScreenBase.chip(note_text, UiIcon.Kind.STRIKE if p_entry.retired else UiIcon.Kind.LOCK, chip_color)
		note.name = "Note"
		note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(note)
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_sync_min_size(margin)


## Badge « NOUVEAU » : ambre plein, texte #07080C, triangle (DS §7.5).
static func make_new_badge(text: String) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.theme_type_variation = &"BadgeNew"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", DS.SPACE_1)
	badge.add_child(row)
	row.add_child(UiIcon.make(UiIcon.Kind.WARNING, DS.TEXT_ON_ACCENT, DS.ICON_S - 4))
	var label: Label = Label.new()
	label.theme_type_variation = &"BadgeLabel"
	label.text = text
	label.uppercase = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return badge


## Vrai pour une règle retirée ce jour (ligne barrée, jamais évaluée).
func is_retired() -> bool:
	return entry != null and entry.retired


## Trait horizontal au milieu de chaque ligne du texte d'une règle retirée
## (la dernière ligne n'est barrée que sur la longueur de son texte).
func _draw_strike() -> void:
	var lines: int = _text.get_line_count()
	if lines <= 0:
		return
	var font: Font = _text.get_theme_font(&"font")
	var font_size: int = _text.get_theme_font_size(&"font_size")
	var line_h: float = _text.size.y / float(lines)
	var full: float = font.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	for i: int in lines:
		var width: float = _text.size.x
		if i == lines - 1:
			width = clampf(full - _text.size.x * i, DS.SPACE_8, _text.size.x)
		var y: float = line_h * (i + 0.55)
		_text.draw_line(Vector2(0.0, y), Vector2(width, y), DS.TEXT_SECONDARY, DS.BORDER_HAIRLINE)


func _sync_min_size(margin: MarginContainer) -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, margin.get_combined_minimum_size().y)


func _refresh_content() -> void:
	if _number == null:
		return
	if is_flagged():
		_number.add_theme_color_override(&"font_color", DS.ACCENT_MAGENTA)
	elif selected:
		_number.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	else:
		_number.remove_theme_color_override(&"font_color")


func _draw() -> void:
	if is_retired():
		draw_rect(Rect2(Vector2.ZERO, size), DS.BG_PANEL)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), DS.TEXT_MUTED)
	elif entry != null and entry.is_new and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.AMBER_12)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), DS.STATE_AMBER)
	super._draw()


## Pas de soulignement pointillé sur une carte de règle (lisibilité du texte).
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
