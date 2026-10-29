## DocField (DS §7.2) : libellé (`DocFieldLabel`, capitales) + valeur
## (`DocFieldValue`, JetBrains Mono, jamais tronquée) — ou photo pour un champ
## `PORTRAIT`. Sert aussi pour la date du jour du Rulebook (`setup_custom`).
class_name DocFieldView
extends InspectableItem

## Photo de référence (px @1080p) : format 4:5 (UI_FLOW §4.9).
const PORTRAIT_SIZE: Vector2 = Vector2(128, 160)

var field: FieldDef = null
var value: Variant = null

var _label: Label = null
var _value: Label = null
var _portrait: PortraitView = null
var _large: bool = false


## Champ d'un document. `portrait_provider(appearance) -> Texture2D` optionnel ;
## `label_text` remplace le libellé du type (« TITULAIRE » d'un document de tiers).
func setup(document_id: StringName, p_field: FieldDef, p_value: Variant, portrait_provider: Callable = Callable(),
		label_text: String = "") -> void:
	field = p_field
	value = p_value
	ref = FieldRef.new(document_id, p_field.id)
	comparable = p_field.comparable
	display_label = label_text if not label_text.is_empty() else UiText.field_label(p_field)
	if p_field.kind == FieldDef.FieldKind.PORTRAIT:
		_build_portrait(p_value, portrait_provider)
	else:
		_build_text(display_label, UiText.value_text(p_field, p_value), false)
	tooltip_text = display_label


## Élément libre (date du jour du Rulebook) : grande valeur à droite.
func setup_custom(p_ref: FieldRef, label_text: String, value_text: String) -> void:
	ref = p_ref
	comparable = true
	display_label = label_text
	_build_text(label_text, value_text, true)


func get_value_text() -> String:
	return _value.text if _value != null else ""


func set_value_text(text: String) -> void:
	if _value != null:
		_value.text = text


## Taille de police (px logiques) de la valeur / du libellé (mesures D-085).
func value_font_px() -> int:
	return _value.get_theme_font_size(&"font_size") if _value != null else 0


func label_font_px() -> int:
	return _label.get_theme_font_size(&"font_size") if _label != null else 0


## Libellé masqué à l'écran (bande MRZ de la carte, M11) : il reste le nom
## lisible de l'élément (infobulle, messages, lecteur d'écran).
func hide_label() -> void:
	if _label != null:
		_label.visible = false


func is_portrait() -> bool:
	return _portrait != null


func _build_text(label_text: String, value_text: String, large: bool) -> void:
	_large = large
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", DS.SPACE_2 if not large else DS.SPACE_4)
	# Place réservée à l'icône « ≠ » d'un champ flagged (jamais sur la valeur).
	margin.add_theme_constant_override("margin_right", DS.SPACE_2 if not large else DS.SPACE_4 + DS.ICON_M)
	margin.add_theme_constant_override("margin_top", 2 if not large else DS.SPACE_2)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_1 if not large else DS.SPACE_2)
	add_child(margin)
	var box: BoxContainer = null
	if large:
		box = HBoxContainer.new()
	else:
		box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2 if not large else DS.SPACE_4)
	margin.add_child(box)
	_label = Label.new()
	_label.theme_type_variation = &"DocFieldLabel"
	_label.uppercase = true
	_label.text = label_text
	# Libellé jamais tronqué (« VALIDE JUS… » au Steam Deck, QA-029) : faute de
	# place il passe à la ligne, sans élargir le document.
	# Repli **entre les mots** seulement : la colonne ne descend jamais sous
	# le plus long mot du libellé (« FIRMWARE » d'une carte seule, QA-038).
	if not large:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.theme_changed.connect(_fit_label_words)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if large:
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_label)
	_value = Label.new()
	# Valeur d'un document : `DocValue` (18 px, plancher physique au Deck, D-085 rév.).
	_value.theme_type_variation = &"DataTitle" if large else &"DocValue"
	_value.text = value_text
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_value)
	custom_minimum_size.y = DS.HIT_TARGET_MIN
	_sync_min_size(margin)
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_refresh_content()


func _build_portrait(p_value: Variant, portrait_provider: Callable) -> void:
	_portrait = PortraitView.new()
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if p_value is PortraitValue:
		var portrait_value: PortraitValue = p_value
		_portrait.appearance = portrait_value.appearance
		if portrait_provider.is_valid() and portrait_value.appearance != null:
			var provided: Variant = portrait_provider.call(portrait_value.appearance)
			if provided is Texture2D:
				_portrait.texture = provided
	add_child(_portrait)
	custom_minimum_size = PORTRAIT_SIZE


## Largeur minimale du libellé replié : son plus long mot (police du thème,
## capitales), pour qu'il ne se coupe jamais lettre par lettre (QA-038).
func _fit_label_words() -> void:
	if _label == null or not _label.is_inside_tree():
		return
	var font: Font = _label.get_theme_font(&"font")
	var font_size: int = _label.get_theme_font_size(&"font_size")
	if font == null:
		return
	var widest: float = 0.0
	for word: String in _label.text.to_upper().split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	widest = ceilf(widest) + 1.0
	if not is_equal_approx(_label.custom_minimum_size.x, widest):
		_label.custom_minimum_size.x = widest


func _sync_min_size(margin: MarginContainer) -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, margin.get_combined_minimum_size().y)
	custom_minimum_size.x = margin.get_combined_minimum_size().x


func _refresh_content() -> void:
	if _label == null:
		return
	var disabled: bool = inspection_active and not comparable
	if is_flagged():
		_label.add_theme_color_override(&"font_color", Palette.ACCENT_MAGENTA)
		_label.text = display_label
	elif selected:
		_label.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	elif disabled:
		_label.add_theme_color_override(&"font_color", DS.TEXT_MUTED)
	else:
		_label.remove_theme_color_override(&"font_color")
	if disabled:
		_value.add_theme_color_override(&"font_color", Palette.TEXT_SECONDARY)
	else:
		_value.remove_theme_color_override(&"font_color")
	tooltip_text = display_label + (" — " + UiText.t("ui_discordance", "DISCORDANCE") if is_flagged() else "")
