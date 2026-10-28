## Avis de recherche du Rulebook (M7, R22, onglet « Avis de recherche ») :
## portrait officiel (`portrait_provider`, comme la photo d'un document), nom,
## motif, mention « MISE EN ATTENTE ». **Sélectionnable en Mode Inspection**
## comme un champ : `FieldRef.wanted(id)`, comparable au visage du passager ou
## au nom / aux prénoms d'un document (`DiscrepancyChecker`).
class_name WantedCardView
extends InspectableItem

const PORTRAIT_SIZE: Vector2 = Vector2(96, 120)

var notice: WantedNotice = null
var number: int = 0

var _name: Label = null
var _eyebrow: Label = null
var _portrait: PortraitView = null


func setup(p_notice: WantedNotice, p_number: int, portrait_provider: Callable = Callable()) -> void:
	notice = p_notice
	number = p_number
	ref = p_notice.get_ref()
	comparable = true
	display_label = UiText.tf("rb_wanted_display", [p_number, p_notice.full_name().to_upper()], "AVIS %02d · %s")
	tooltip_text = display_label
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", DS.SPACE_3)
	margin.add_theme_constant_override("margin_right", DS.SPACE_8)
	margin.add_theme_constant_override("margin_top", DS.SPACE_3)
	margin.add_theme_constant_override("margin_bottom", DS.SPACE_3)
	add_child(margin)
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	margin.add_child(row)
	_portrait = PortraitView.new()
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.appearance = p_notice.appearance
	if portrait_provider.is_valid() and p_notice.appearance != null:
		var provided: Variant = portrait_provider.call(p_notice.appearance)
		if provided is Texture2D:
			_portrait.texture = provided
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var column: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_eyebrow = ScreenBase.eyebrow(UiText.tf("rb_wanted_number", [p_number], "AVIS N° %02d · RECHERCHÉ·E"), DS.STATE_RED)
	column.add_child(_eyebrow)
	_name = ScreenBase.label(p_notice.full_name().to_upper(), &"DataTitle", DS.TEXT_PRIMARY)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size.x = 120.0
	column.add_child(_name)
	var reason: Label = ScreenBase.wrapped(UiText.t(p_notice.reason_key, ""), &"BodySmall", DS.TEXT_PRIMARY)
	column.add_child(reason)
	var chip: PanelContainer = ScreenBase.chip(UiText.t("rb_wanted_action", "MISE EN ATTENTE"), UiIcon.Kind.DETAIN, DS.ACCENT_YELLOW)
	column.add_child(chip)
	margin.minimum_size_changed.connect(_sync_min_size.bind(margin))
	_sync_min_size(margin)


func get_portrait() -> PortraitView:
	return _portrait


func _sync_min_size(margin: MarginContainer) -> void:
	custom_minimum_size.y = maxf(DS.HIT_TARGET_MIN, margin.get_combined_minimum_size().y)


func _refresh_content() -> void:
	if _name == null:
		return
	if is_flagged():
		_name.add_theme_color_override(&"font_color", DS.ACCENT_MAGENTA)
	elif selected:
		_name.add_theme_color_override(&"font_color", DS.ACCENT_CYAN)
	else:
		_name.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)


func _draw() -> void:
	# Fond de l'avis (bulletin officiel) : liseré rouge à gauche, fond red.12.
	if not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.RED_12)
		draw_rect(Rect2(Vector2.ZERO, Vector2(DS.BORDER_STRONG + 1, size.y)), DS.STATE_RED)
	super._draw()


## Pas de soulignement pointillé : cadre complet en inspection (comme une règle).
func _draw_underline(_rect: Rect2) -> void:
	if inspection_active and comparable and not is_flagged() and not selected:
		draw_rect(Rect2(Vector2.ZERO, size), DS.CYAN_24 if _hovered else DS.CYAN_08, false, 1.0)
