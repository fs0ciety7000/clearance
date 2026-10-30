## Entrée de l'onglet **Contrebande** du Rulebook (M13 lot C, I37 ; M13 §2.5,
## `rb_tab_contraband`, `rb_cb_01` → `rb_cb_08`) : catégorie, exemple et
## verdict (REFUS / MISE EN ATTENTE / signalement), icône + texte.
## Sélectionnable en Mode Inspection (`FieldRef.contraband_entry(catégorie)`)
## pour la paire objet du portique ↔ entrée ; l'entrée CB-08 (imprimés) n'est
## qu'un renvoi au bulletin des symboles (non sélectionnable).
class_name ContrabandEntryView
extends InspectableItem

## Catégories du catalogue de fouille (`SearchItemDef.category`) dans l'ordre
## CB-01 → CB-08 et texte de l'entrée.
const ENTRIES: Array[Array] = [
	[&"oxygen", "rb_cb_01"], [&"stimulant", "rb_cb_02"], [&"medicine", "rb_cb_03"], [&"data", "rb_cb_04"],
	[&"seeds", "rb_cb_05"], [&"blade", "rb_cb_06"], [&"jammer", "rb_cb_07"], [&"print", "rb_cb_08"],
]
const WEAPONS: Array[StringName] = [&"blade", &"jammer"]
const REFERENCE_ONLY: Array[StringName] = [&"print"]

var category: StringName = &""
var number: int = 0

var _title: Label = null
var _margin: MarginContainer = null


func setup(p_category: StringName, text_key: String, p_number: int) -> void:
	category = p_category
	number = p_number
	ref = FieldRef.contraband_entry(p_category)
	comparable = not REFERENCE_ONLY.has(p_category)
	name = "Contraband_%s" % p_category
	var text: String = UiText.t(text_key, String(p_category))
	display_label = text
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", DS.SPACE_4)
	_margin.add_theme_constant_override("margin_right", DS.SPACE_8)
	_margin.add_theme_constant_override("margin_top", DS.SPACE_2)
	_margin.add_theme_constant_override("margin_bottom", DS.SPACE_2)
	add_child(_margin)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	_margin.add_child(row)
	var code: Label = ScreenBase.label("CB-%02d" % p_number, &"DataSmall", Palette.TEXT_SECONDARY)
	code.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(code)
	var column: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_title = ScreenBase.wrapped(text, &"BodySmall", DS.TEXT_PRIMARY)
	_title.custom_minimum_size.x = 160.0
	column.add_child(_title)
	column.add_child(_verdict_chip())
	_margin.minimum_size_changed.connect(_sync_min_size)
	_sync_min_size()


## Verdict de l'entrée en icône + texte : REFUS (R45), MISE EN ATTENTE (R46),
## SIGNALEMENT (bulletin des symboles).
func _verdict_chip() -> PanelContainer:
	if REFERENCE_ONLY.has(category):
		return ScreenBase.chip(UiText.t("rb_cb_report", "SIGNALEMENT · BULLETIN"), UiIcon.Kind.WARNING, Palette.STATE_AMBER)
	if WEAPONS.has(category):
		return ScreenBase.chip(UiText.t("rb_cb_detain", "MISE EN ATTENTE · R46"), UiIcon.Kind.DETAIN, DS.ACCENT_YELLOW)
	return ScreenBase.chip(UiText.t("rb_cb_deny", "REFUS · R45"), UiIcon.Kind.DENIED, Palette.STATE_RED)


func _sync_min_size() -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, _margin.get_combined_minimum_size().y)


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
	if not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.BG_ELEVATED)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)),
				Palette.STATE_AMBER if not REFERENCE_ONLY.has(category) else Palette.LINE_SUBTLE)
	super._draw()


func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
