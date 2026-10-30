## Objet révélé par le portique (M13 lot C, I36 ; M13 §2.2 point 5) : icône
## **neutre** (elle ne dit jamais si l'objet est interdit), nom, ligne de
## description où les états « scellé / sans scellé », « étiqueté / sans
## étiquette » sont écrits en toutes lettres, zone. Sélectionnable en Mode
## Inspection comme un champ (`FieldRef.scan(zone, n)`) : objet ↔ R45 / R46,
## ↔ entrée de l'onglet Contrebande, implant ↔ « Implants déclarés » de la
## carte, imprimé ↔ bulletin des symboles.
class_name SearchItemView
extends InspectableItem

var item: SearchItem = null

var _name: Label = null
var _desc: Label = null
var _margin: MarginContainer = null


func setup(p_item: SearchItem) -> void:
	item = p_item
	ref = p_item.get_ref() if p_item != null else null
	comparable = p_item != null
	name = "Item_%s" % String(p_item.id).replace(":", "_") if p_item != null else "Item"
	display_label = item_name(p_item)
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", DS.SPACE_2)
	_margin.add_theme_constant_override("margin_right", DS.SPACE_8)
	_margin.add_theme_constant_override("margin_top", DS.SPACE_1)
	_margin.add_theme_constant_override("margin_bottom", DS.SPACE_1)
	add_child(_margin)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	_margin.add_child(row)
	var icon: UiIcon = UiIcon.make(UiIcon.Kind.DIAMOND if p_item != null and p_item.is_implant() else UiIcon.Kind.ITEM,
			Palette.TEXT_SECONDARY, DS.ICON_S)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var column: VBoxContainer = ScreenBase.vbox(0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name = ScreenBase.label(display_label, &"BodyStrong", DS.TEXT_PRIMARY)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = 120.0
	column.add_child(_name)
	_desc = ScreenBase.wrapped(item_detail(p_item), &"CaptionLabel", Palette.TEXT_SECONDARY)
	_desc.name = "Detail"
	column.add_child(_desc)
	_margin.minimum_size_changed.connect(_sync_min_size)
	_sync_min_size()


## Nom affiché (`item_<id>_name`).
static func item_name(p_item: SearchItem) -> String:
	if p_item == null:
		return ""
	return UiText.t(p_item.name_key, String(p_item.item_id))


## Ligne de description : « 6 · sans scellé », implant « NX-12 · sous la peau »,
## attributs écrits en clair, contenu illisible d'une cache blindée (DER-19).
static func item_detail(p_item: SearchItem) -> String:
	if p_item == null:
		return ""
	if p_item.unreadable:
		return UiText.t("line_scan_unreadable", "CONTENU NON LISIBLE · BLINDAGE")
	var args: Array = p_item.args.duplicate()
	if args.is_empty() and not p_item.implant_code.is_empty():
		args.append(p_item.implant_code)
	var text: String = UiText.t(p_item.desc_key, "")
	if not args.is_empty():
		text = Statement.format_fragment(text, args)
	var parts: PackedStringArray = []
	if not text.is_empty():
		parts.append(text)
	for key: String in p_item.attribute_keys:
		var attribute: String = UiText.t(key, key)
		if not text.contains(attribute):
			parts.append(attribute)
	return " · ".join(parts)


func get_detail_text() -> String:
	return _desc.text if _desc != null else ""


func _sync_min_size() -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, _margin.get_combined_minimum_size().y)


func _refresh_content() -> void:
	if _name == null:
		return
	if is_flagged():
		_name.add_theme_color_override(&"font_color", Palette.ACCENT_MAGENTA)
	elif selected:
		_name.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	else:
		_name.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)


## Cadre complet en inspection (comme une carte du Rulebook).
func _draw_underline(rect: Rect2) -> void:
	if is_flagged() or selected:
		return
	if inspection_active and comparable:
		draw_rect(rect, DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
	else:
		var y: float = rect.end.y - 0.5
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Palette.LINE_SUBTLE, 1.0)
