## RuleCard (DS §7.5) : n° de règle, badge NOUVEAU (ambre + triangle), texte de
## la règle. Champ comparable en Mode Inspection (`FieldRef.rulebook_rule`).
class_name RuleCardView
extends InspectableItem

var entry: RulebookEntry = null
var number: int = 0

var _text: Label = null
var _number: Label = null


func setup(p_entry: RulebookEntry, p_number: int) -> void:
	entry = p_entry
	number = p_number
	ref = p_entry.ref if p_entry.ref != null else FieldRef.rulebook_rule(p_entry.rule_id)
	comparable = true
	var title: String = UiText.t(p_entry.title_key, String(p_entry.rule_id))
	display_label = "%02d · %s" % [p_number, title]
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
	_number.text = "%02d" % p_number
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
	_text.text = UiText.t(p_entry.text_key, title)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size.x = 120.0
	column.add_child(_text)
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
	if entry != null and entry.is_new and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.AMBER_12)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), DS.STATE_AMBER)
	super._draw()


## Pas de soulignement pointillé sur une carte de règle (lisibilité du texte).
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
