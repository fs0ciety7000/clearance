## Construit le `Theme` CLEARANCE à partir des tokens `DS` (DESIGN_SYSTEM §10).
##
## Alternative au `clearance_theme.tres` écrit à la main (proposition D-025) :
## une seule source de vérité (`tokens.gd`), aucune désynchronisation possible,
## diffable et relisible sans éditeur. Le `.tres` pourra être généré plus tard
## depuis cette classe par un script d'outil si besoin.
##
## Polices : chargées depuis `res://assets/fonts/` si présentes ; sinon repli
## silencieux sur la police par défaut du moteur (tailles et couleurs restent
## appliquées).
class_name ThemeBuilder
extends RefCounted

## Graisses OpenType des polices variables / statiques (DS §3).
const WEIGHT_REGULAR: int = 400
const WEIGHT_MEDIUM: int = 500
const WEIGHT_SEMIBOLD: int = 600
const WEIGHT_BOLD: int = 700


## Construit un nouveau Theme complet.
static func build() -> Theme:
	var theme: Theme = Theme.new()
	var fonts: Dictionary[StringName, Font] = _load_fonts()

	# --- Défauts globaux : Inter 400, 16 px, text.primary (DS §10.2) -------
	if fonts.has(&"ui"):
		theme.default_font = fonts[&"ui"]
	theme.default_font_size = DS.FS_BODY

	_build_label(theme)
	_build_panels(theme)
	_build_buttons(theme, fonts)
	_build_variations(theme, fonts)
	return theme


# ---------------------------------------------------------------------------
# Polices
# ---------------------------------------------------------------------------

static func _load_fonts() -> Dictionary[StringName, Font]:
	var fonts: Dictionary[StringName, Font] = {}
	var ui: Font = _font_variant(DS.FONT_UI_PATH, WEIGHT_REGULAR, 0.0)
	if ui != null:
		fonts[&"ui"] = ui
	var ui_semibold: Font = _font_variant(DS.FONT_UI_PATH, WEIGHT_SEMIBOLD, 0.0)
	if ui_semibold != null:
		fonts[&"ui_semibold"] = ui_semibold
	# Labels en capitales : tracking +8 % de 12 px ≈ 1 px.
	var ui_label: Font = _font_variant(DS.FONT_UI_PATH, WEIGHT_SEMIBOLD, DS.TRACKING_LABEL * DS.FS_LABEL)
	if ui_label != null:
		fonts[&"ui_label"] = ui_label
	var ui_medium: Font = _font_variant(DS.FONT_UI_PATH, WEIGHT_MEDIUM, 0.0)
	if ui_medium != null:
		fonts[&"ui_medium"] = ui_medium
	var display: Font = _font_variant(DS.FONT_DISPLAY_PATH, 0, 0.0)
	if display != null:
		fonts[&"display"] = display
	var display_bold: Font = _font_variant(DS.FONT_DISPLAY_BOLD_PATH, 0, 0.0)
	if display_bold != null:
		fonts[&"display_bold"] = display_bold
	var mono: Font = _font_variant(DS.FONT_MONO_PATH, WEIGHT_MEDIUM, 0.0)
	if mono != null:
		fonts[&"mono"] = mono
	return fonts


## `FontVariation` sur la police `path` (graisse `weight` si > 0, tracking en
## px). `null` si le fichier n'existe pas encore.
static func _font_variant(path: String, weight: int, spacing_px: float) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var base: Font = load(path) as Font
	if base == null:
		return null
	var variant: FontVariation = FontVariation.new()
	variant.base_font = base
	if weight > 0:
		variant.variation_opentype = {"wght": weight}
	if spacing_px != 0.0:
		variant.spacing_glyph = roundi(spacing_px)
	return variant


static func _set_font_if(theme: Theme, type_name: StringName, fonts: Dictionary[StringName, Font], key: StringName) -> void:
	if fonts.has(key):
		theme.set_font(&"font", type_name, fonts[key])


# ---------------------------------------------------------------------------
# StyleBoxes
# ---------------------------------------------------------------------------

## StyleBox chanfreinée. `all_corners = false` : signature « ticket »
## (haut-gauche et bas-droit seulement, DS §4.2).
static func chamfer_box(bg: Color, border: Color, border_width: int, chamfer: int, margin: int, all_corners: bool = false) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.corner_detail = DS.CORNER_DETAIL_CHAMFER
	box.corner_radius_top_left = chamfer
	box.corner_radius_bottom_right = chamfer
	if all_corners:
		box.corner_radius_top_right = chamfer
		box.corner_radius_bottom_left = chamfer
	box.set_content_margin_all(margin)
	box.anti_aliasing = true
	return box


## Anneau de focus : sans fond, bordure cyan 2 px, décalé de 2 px (DS §10.2).
static func focus_box(chamfer: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = chamfer_box(Color(0, 0, 0, 0), DS.ACCENT_CYAN, DS.FOCUS_RING_WIDTH, chamfer + DS.FOCUS_RING_OFFSET, 0)
	box.draw_center = false
	box.set_expand_margin_all(DS.FOCUS_RING_OFFSET)
	return box


static func _with_glow(box: StyleBoxFlat, color: Color, size: int) -> StyleBoxFlat:
	box.shadow_color = color
	box.shadow_size = size
	box.shadow_offset = Vector2.ZERO
	return box


# ---------------------------------------------------------------------------
# Types de base
# ---------------------------------------------------------------------------

static func _build_label(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", DS.TEXT_PRIMARY)
	theme.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))
	theme.set_color(&"default_color", &"RichTextLabel", DS.TEXT_PRIMARY)


static func _build_panels(theme: Theme) -> void:
	# PanelContainer / Panel par défaut = SystemPanel (non diégétique, DS §10.3).
	var system: StyleBoxFlat = chamfer_box(DS.BG_PANEL, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_M, DS.SPACE_4, true)
	theme.set_stylebox(&"panel", &"PanelContainer", system)
	theme.set_stylebox(&"panel", &"Panel", system)


static func _build_buttons(theme: Theme, fonts: Dictionary[StringName, Font]) -> void:
	# Bouton par défaut = ButtonSecondary (bordure text.secondary, hover cyan.12).
	_set_font_if(theme, &"Button", fonts, &"ui_semibold")
	theme.set_font_size(&"font_size", &"Button", DS.FS_BODY)
	_set_button_colors(theme, &"Button", DS.TEXT_PRIMARY, DS.TEXT_PRIMARY)
	var margin_h: int = DS.SPACE_4
	var margin_v: int = DS.SPACE_3
	var normal: StyleBoxFlat = chamfer_box(Color(0, 0, 0, 0), DS.TEXT_SECONDARY, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	var hover: StyleBoxFlat = _with_glow(chamfer_box(DS.CYAN_12, DS.ACCENT_CYAN, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0), DS.CYAN_24, DS.GLOW_1)
	var pressed: StyleBoxFlat = chamfer_box(DS.CYAN_24, DS.ACCENT_CYAN, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	var disabled: StyleBoxFlat = chamfer_box(DS.DISABLED_BG, DS.LINE_SUBTLE, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		_set_button_margins(box, margin_h, margin_v)
	theme.set_stylebox(&"normal", &"Button", normal)
	theme.set_stylebox(&"hover", &"Button", hover)
	theme.set_stylebox(&"pressed", &"Button", pressed)
	theme.set_stylebox(&"hover_pressed", &"Button", pressed)
	theme.set_stylebox(&"disabled", &"Button", disabled)
	theme.set_stylebox(&"focus", &"Button", focus_box(DS.CHAMFER_M))
	theme.set_constant(&"h_separation", &"Button", DS.SPACE_2)


static func _set_button_margins(box: StyleBoxFlat, h: int, v: int) -> void:
	box.content_margin_left = h
	box.content_margin_right = h
	box.content_margin_top = v
	box.content_margin_bottom = v


static func _set_button_colors(theme: Theme, type_name: StringName, fg: Color, fg_hover: Color) -> void:
	theme.set_color(&"font_color", type_name, fg)
	theme.set_color(&"font_hover_color", type_name, fg_hover)
	theme.set_color(&"font_pressed_color", type_name, fg_hover)
	theme.set_color(&"font_hover_pressed_color", type_name, fg_hover)
	theme.set_color(&"font_focus_color", type_name, fg)
	theme.set_color(&"font_disabled_color", type_name, DS.DISABLED_FG)
	theme.set_color(&"icon_normal_color", type_name, fg)
	theme.set_color(&"icon_hover_color", type_name, fg_hover)
	theme.set_color(&"icon_pressed_color", type_name, fg_hover)
	theme.set_color(&"icon_focus_color", type_name, fg)
	theme.set_color(&"icon_disabled_color", type_name, DS.DISABLED_FG)


## Bouton plein (Primary / Danger) : fond `fill`, texte `TEXT_ON_ACCENT`.
static func _build_filled_button(theme: Theme, type_name: StringName, fill: Color, glow: Color) -> void:
	theme.set_type_variation(type_name, &"Button")
	_set_button_colors(theme, type_name, DS.TEXT_ON_ACCENT, DS.TEXT_ON_ACCENT)
	var normal: StyleBoxFlat = chamfer_box(fill, fill, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	var hover: StyleBoxFlat = _with_glow(chamfer_box(fill.lightened(0.12), fill, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0), glow, DS.GLOW_1)
	var pressed: StyleBoxFlat = chamfer_box(fill.darkened(0.12), fill, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	var disabled: StyleBoxFlat = chamfer_box(DS.DISABLED_BG, DS.LINE_SUBTLE, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		_set_button_margins(box, DS.SPACE_6, DS.SPACE_3)
	theme.set_stylebox(&"normal", type_name, normal)
	theme.set_stylebox(&"hover", type_name, hover)
	theme.set_stylebox(&"pressed", type_name, pressed)
	theme.set_stylebox(&"hover_pressed", type_name, pressed)
	theme.set_stylebox(&"disabled", type_name, disabled)


# ---------------------------------------------------------------------------
# Type variations (DS §10.3)
# ---------------------------------------------------------------------------

static func _build_variations(theme: Theme, fonts: Dictionary[StringName, Font]) -> void:
	# HoloPanel : bg.panel voilé cyan.08, bordure cyan.40, chamfer.l, marge 24.
	theme.set_type_variation(&"HoloPanel", &"PanelContainer")
	var holo_bg: Color = DS.BG_PANEL.blend(DS.CYAN_08)
	theme.set_stylebox(&"panel", &"HoloPanel", chamfer_box(holo_bg, DS.CYAN_40, DS.BORDER_HAIRLINE, DS.CHAMFER_L, DS.SPACE_6))

	# HoloPanelActive : idem + glow cyan.60 / 8 px.
	theme.set_type_variation(&"HoloPanelActive", &"PanelContainer")
	theme.set_stylebox(&"panel", &"HoloPanelActive", _with_glow(chamfer_box(holo_bg, DS.CYAN_40, DS.BORDER_HAIRLINE, DS.CHAMFER_L, DS.SPACE_6), DS.CYAN_60, DS.GLOW_2))

	# SystemPanel : explicite (identique au PanelContainer par défaut).
	theme.set_type_variation(&"SystemPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SystemPanel", chamfer_box(DS.BG_PANEL, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_M, DS.SPACE_4, true))

	# DocFieldLabel : Inter 600, 12 px, text.secondary, tracking +1 px
	# (`uppercase = true` à poser sur le Label : ce n'est pas une propriété de thème).
	theme.set_type_variation(&"DocFieldLabel", &"Label")
	_set_font_if(theme, &"DocFieldLabel", fonts, &"ui_label")
	theme.set_font_size(&"font_size", &"DocFieldLabel", DS.FS_LABEL)
	theme.set_color(&"font_color", &"DocFieldLabel", DS.TEXT_SECONDARY)

	# DocFieldValue : JetBrains Mono 500, 16 px, text.primary.
	theme.set_type_variation(&"DocFieldValue", &"Label")
	_set_font_if(theme, &"DocFieldValue", fonts, &"mono")
	theme.set_font_size(&"font_size", &"DocFieldValue", DS.FS_DATA)
	theme.set_color(&"font_color", &"DocFieldValue", DS.TEXT_PRIMARY)

	# DisplayLabel : Chakra Petch 700, 40 px.
	theme.set_type_variation(&"DisplayLabel", &"Label")
	_set_font_if(theme, &"DisplayLabel", fonts, &"display_bold")
	theme.set_font_size(&"font_size", &"DisplayLabel", DS.FS_DISPLAY_L)
	theme.set_color(&"font_color", &"DisplayLabel", DS.TEXT_PRIMARY)

	# TitleLabel : Chakra Petch 600, 20 px.
	theme.set_type_variation(&"TitleLabel", &"Label")
	_set_font_if(theme, &"TitleLabel", fonts, &"display")
	theme.set_font_size(&"font_size", &"TitleLabel", DS.FS_TITLE)
	theme.set_color(&"font_color", &"TitleLabel", DS.TEXT_PRIMARY)

	# CaptionLabel : Inter 500, 12 px, text.secondary.
	theme.set_type_variation(&"CaptionLabel", &"Label")
	_set_font_if(theme, &"CaptionLabel", fonts, &"ui_medium")
	theme.set_font_size(&"font_size", &"CaptionLabel", DS.FS_CAPTION)
	theme.set_color(&"font_color", &"CaptionLabel", DS.TEXT_SECONDARY)

	# ButtonPrimary : jaune plein, texte #07080C, chamfer.m.
	_build_filled_button(theme, &"ButtonPrimary", DS.ACCENT_YELLOW, DS.YELLOW_60)
	# ButtonDanger : rouge plein, texte #07080C.
	_build_filled_button(theme, &"ButtonDanger", DS.STATE_RED, DS.RED_60)
