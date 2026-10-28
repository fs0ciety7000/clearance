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


## Échelle du texte de la construction en cours (`Settings.text_scale`).
static var _scale: float = 1.0
## Plancher de taille (px logiques) : garantit ≥ 12 px **effectifs** quand la
## fenêtre est plus petite que 1920×1080 (Steam Deck 1280×800, D-023).
static var _min_px: int = 0
const MIN_PX_MAX_SCALE: float = 1.5


## Construit un nouveau Theme complet. `text_scale` (0,9–1,5, UI_FLOW §6)
## multiplie toutes les tailles de police ; espacements et formes sont fixes.
static func build(text_scale: float = 1.0, min_px: int = 0) -> Theme:
	_scale = clampf(text_scale, 0.5, 2.0)
	_min_px = maxi(min_px, 0)
	var theme: Theme = Theme.new()
	var fonts: Dictionary[StringName, Font] = _load_fonts()

	# --- Défauts globaux : Inter 400, 16 px, text.primary (DS §10.2) -------
	if fonts.has(&"ui"):
		theme.default_font = fonts[&"ui"]
	theme.default_font_size = fs(DS.FS_BODY)

	_build_label(theme)
	_build_panels(theme)
	_build_buttons(theme, fonts)
	_build_variations(theme, fonts)
	_build_m4_variations(theme, fonts)
	_scale = 1.0
	_min_px = 0
	return theme


## Taille de police mise à l'échelle de la construction en cours.
static func fs(size: int) -> int:
	return maxi(maxi(roundi(size * _scale), _min_px), 1)


## Plancher de taille pour un facteur d'affichage `screen_scale` (taille de
## la fenêtre / taille de référence) : `DS.FS_CAPTION` px effectifs minimum.
static func min_px_for(screen_scale: float) -> int:
	if screen_scale >= 1.0 or screen_scale <= 0.0:
		return 0
	# Plafonné à l'échelle UI maximale (150 %, DS §1.7) : au-delà, la mise en
	# page ne tient plus (fenêtres minuscules, headless).
	return mini(ceili(DS.FS_CAPTION / screen_scale), ceili(DS.FS_CAPTION * MIN_PX_MAX_SCALE))


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
	var mono_regular: Font = _font_variant(DS.FONT_MONO_PATH, WEIGHT_REGULAR, 0.0)
	if mono_regular != null:
		fonts[&"mono_regular"] = mono_regular
	var mono_bold: Font = _font_variant(DS.FONT_MONO_PATH, WEIGHT_BOLD, 0.0)
	if mono_bold != null:
		fonts[&"mono_bold"] = mono_bold
	# Display en capitales (titres de documents, Rulebook) : tracking +2 %… +4 %.
	var display_caps: Font = _font_variant(DS.FONT_DISPLAY_PATH, 0, DS.TRACKING_DISPLAY * 2.0 * DS.FS_TITLE)
	if display_caps != null:
		fonts[&"display_caps"] = display_caps
	var display_bold_caps: Font = _font_variant(DS.FONT_DISPLAY_BOLD_PATH, 0, DS.TRACKING_DISPLAY * 2.0 * DS.FS_TITLE)
	if display_bold_caps != null:
		fonts[&"display_bold_caps"] = display_bold_caps
	var ui_button: Font = _font_variant(DS.FONT_UI_PATH, WEIGHT_SEMIBOLD, DS.TRACKING_LABEL * 0.5 * DS.FS_BODY)
	if ui_button != null:
		fonts[&"ui_button"] = ui_button
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
	theme.set_font_size(&"font_size", &"Button", fs(DS.FS_BODY))
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
	theme.set_font_size(&"font_size", &"DocFieldLabel", fs(DS.FS_LABEL))
	theme.set_color(&"font_color", &"DocFieldLabel", DS.TEXT_SECONDARY)

	# DocFieldValue : JetBrains Mono 500, 16 px, text.primary.
	theme.set_type_variation(&"DocFieldValue", &"Label")
	_set_font_if(theme, &"DocFieldValue", fonts, &"mono")
	theme.set_font_size(&"font_size", &"DocFieldValue", fs(DS.FS_DATA))
	theme.set_color(&"font_color", &"DocFieldValue", DS.TEXT_PRIMARY)

	# DisplayLabel : Chakra Petch 700, 40 px.
	theme.set_type_variation(&"DisplayLabel", &"Label")
	_set_font_if(theme, &"DisplayLabel", fonts, &"display_bold")
	theme.set_font_size(&"font_size", &"DisplayLabel", fs(DS.FS_DISPLAY_L))
	theme.set_color(&"font_color", &"DisplayLabel", DS.TEXT_PRIMARY)

	# TitleLabel : Chakra Petch 600, 20 px.
	theme.set_type_variation(&"TitleLabel", &"Label")
	_set_font_if(theme, &"TitleLabel", fonts, &"display")
	theme.set_font_size(&"font_size", &"TitleLabel", fs(DS.FS_TITLE))
	theme.set_color(&"font_color", &"TitleLabel", DS.TEXT_PRIMARY)

	# CaptionLabel : Inter 500, 12 px, text.secondary.
	theme.set_type_variation(&"CaptionLabel", &"Label")
	_set_font_if(theme, &"CaptionLabel", fonts, &"ui_medium")
	theme.set_font_size(&"font_size", &"CaptionLabel", fs(DS.FS_CAPTION))
	theme.set_color(&"font_color", &"CaptionLabel", DS.TEXT_SECONDARY)

	# ButtonPrimary : jaune plein, texte #07080C, chamfer.m.
	_build_filled_button(theme, &"ButtonPrimary", DS.ACCENT_YELLOW, DS.YELLOW_60)
	# ButtonDanger : rouge plein, texte #07080C.
	_build_filled_button(theme, &"ButtonDanger", DS.STATE_RED, DS.RED_60)


# ---------------------------------------------------------------------------
# Variations M4 — interface de comparaison (DS §7, §10.3 ; UI_FLOW §2–§4)
# ---------------------------------------------------------------------------

static func _label_variation(theme: Theme, type_name: StringName, fonts: Dictionary[StringName, Font],
		font_key: StringName, size: int, color: Color) -> void:
	theme.set_type_variation(type_name, &"Label")
	_set_font_if(theme, type_name, fonts, font_key)
	theme.set_font_size(&"font_size", type_name, fs(size))
	theme.set_color(&"font_color", type_name, color)


static func _panel_variation(theme: Theme, type_name: StringName, box: StyleBox) -> void:
	theme.set_type_variation(type_name, &"PanelContainer")
	theme.set_stylebox(&"panel", type_name, box)


static func _build_m4_variations(theme: Theme, fonts: Dictionary[StringName, Font]) -> void:
	# --- Libellés -------------------------------------------------------------
	_label_variation(theme, &"DocTitle", fonts, &"display_caps", DS.FS_TITLE, DS.TEXT_PRIMARY)
	_label_variation(theme, &"DocIssuer", fonts, &"ui_label", DS.FS_LABEL, DS.ACCENT_CYAN)
	_label_variation(theme, &"DataSmall", fonts, &"mono_regular", DS.FS_DATA_S, DS.TEXT_SECONDARY)
	_label_variation(theme, &"DataTitle", fonts, &"mono", DS.FS_TITLE, DS.TEXT_PRIMARY)
	_label_variation(theme, &"TimerLabel", fonts, &"mono_bold", DS.FS_TIMER, DS.TEXT_PRIMARY)
	_label_variation(theme, &"TimerCompact", fonts, &"mono_bold", DS.FS_TIMER_COMPACT, DS.TEXT_PRIMARY)
	_label_variation(theme, &"BodyLabel", fonts, &"ui", DS.FS_BODY, DS.TEXT_PRIMARY)
	_label_variation(theme, &"BodyStrong", fonts, &"ui_semibold", DS.FS_BODY, DS.TEXT_PRIMARY)
	_label_variation(theme, &"BodySmall", fonts, &"ui", DS.FS_BODY_S, DS.TEXT_SECONDARY)
	_label_variation(theme, &"SubtitleText", fonts, &"ui_medium", DS.FS_SUBTITLE, DS.TEXT_PRIMARY)
	_label_variation(theme, &"PanelTitle", fonts, &"display_bold_caps", DS.FS_TITLE, DS.TEXT_PRIMARY)
	_label_variation(theme, &"StampLabel", fonts, &"display_bold_caps", DS.FS_TITLE, DS.TEXT_PRIMARY)
	_label_variation(theme, &"BrandLabel", fonts, &"display_bold_caps", DS.FS_TITLE, DS.TEXT_PRIMARY)
	_label_variation(theme, &"KeyCapLabel", fonts, &"mono", DS.FS_CAPTION, DS.TEXT_SECONDARY)
	_label_variation(theme, &"BadgeLabel", fonts, &"ui_label", DS.FS_LABEL, DS.TEXT_ON_ACCENT)
	theme.set_constant(&"line_spacing", &"BodyLabel", roundi(DS.FS_BODY * (DS.LINE_HEIGHT_READ - 1.2)))
	theme.set_constant(&"line_spacing", &"BodySmall", roundi(DS.FS_BODY_S * (DS.LINE_HEIGHT_READ - 1.2)))
	theme.set_constant(&"line_spacing", &"SubtitleText", roundi(DS.FS_SUBTITLE * (DS.LINE_HEIGHT_UI - 1.2)))

	# --- Panneaux -------------------------------------------------------------
	_panel_variation(theme, &"ElevatedCard", chamfer_box(DS.BG_ELEVATED, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_M, DS.SPACE_4))
	# Panneaux posés sur la vitre : voile ≥ 85 % (DS §5 règle 5).
	_panel_variation(theme, &"VeilPanel", chamfer_box(DS.PANEL_VEIL, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_M, DS.SPACE_5))
	_panel_variation(theme, &"BarPanel", _flat_box(DS.BG_PANEL, DS.LINE_SUBTLE, 0, DS.BORDER_HAIRLINE))
	_panel_variation(theme, &"ToolbarPanel", _flat_box(DS.BG_VOID, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, 0))
	_panel_variation(theme, &"SubtitlePanel", chamfer_box(DS.SUBTITLE_BG, Color(0, 0, 0, 0), 0, DS.CHAMFER_S, DS.SPACE_3, true))
	_panel_variation(theme, &"KeyCap", _keycap_box())
	_panel_variation(theme, &"BadgeNew", chamfer_box(DS.STATE_AMBER, DS.STATE_AMBER, 0, DS.CHAMFER_S, DS.SPACE_1))
	_panel_variation(theme, &"BadgeMagenta", chamfer_box(DS.ACCENT_MAGENTA, DS.ACCENT_MAGENTA, 0, DS.CHAMFER_S, DS.SPACE_1))
	_panel_variation(theme, &"RuleCard", _rule_card_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	_panel_variation(theme, &"RuleCardNew", _rule_card_box(DS.AMBER_12, DS.STATE_AMBER))
	_panel_variation(theme, &"DialogueQuestion", _left_bar_box(DS.MAGENTA_12, DS.ACCENT_MAGENTA))
	for pair: Array in [[&"ToastInfo", DS.ACCENT_CYAN], [&"ToastSuccess", DS.STATE_GREEN], [&"ToastWarning", DS.STATE_AMBER],
			[&"ToastError", DS.STATE_RED], [&"ToastNarrative", DS.ACCENT_MAGENTA]]:
		var toast_name: StringName = pair[0]
		var toast_color: Color = pair[1]
		_panel_variation(theme, toast_name, _left_bar_box(DS.BG_ELEVATED, toast_color, 3))
	_panel_variation(theme, &"CitationTicket", chamfer_box(DS.BG_ELEVATED, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_M, 0))

	# --- Boutons --------------------------------------------------------------
	# ButtonGhost : texte seul (DS §7.7).
	theme.set_type_variation(&"ButtonGhost", &"Button")
	_set_button_colors(theme, &"ButtonGhost", DS.TEXT_SECONDARY, DS.TEXT_PRIMARY)
	theme.set_color(&"font_pressed_color", &"ButtonGhost", DS.ACCENT_CYAN)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.set_content_margin_all(DS.SPACE_2)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		theme.set_stylebox(state, &"ButtonGhost", empty)
	# ToggleTab : sélectionné = cyan.12 + barre basse 2 px (DS §7.7).
	theme.set_type_variation(&"ToggleTab", &"Button")
	_set_font_if(theme, &"ToggleTab", fonts, &"ui_semibold")
	theme.set_font_size(&"font_size", &"ToggleTab", fs(DS.FS_BODY_S))
	_set_button_colors(theme, &"ToggleTab", DS.TEXT_SECONDARY, DS.TEXT_PRIMARY)
	theme.set_color(&"font_pressed_color", &"ToggleTab", DS.TEXT_PRIMARY)
	var tab_normal: StyleBoxFlat = _flat_box(Color(0, 0, 0, 0), DS.LINE_SUBTLE, 0, DS.BORDER_HAIRLINE)
	var tab_hover: StyleBoxFlat = _flat_box(DS.CYAN_08, DS.LINE_SUBTLE, 0, DS.BORDER_HAIRLINE)
	var tab_pressed: StyleBoxFlat = _flat_box(DS.CYAN_12, DS.ACCENT_CYAN, 0, DS.BORDER_STRONG)
	for box: StyleBoxFlat in [tab_normal, tab_hover, tab_pressed]:
		_set_button_margins(box, DS.SPACE_3, DS.SPACE_2)
	theme.set_stylebox(&"normal", &"ToggleTab", tab_normal)
	theme.set_stylebox(&"hover", &"ToggleTab", tab_hover)
	theme.set_stylebox(&"pressed", &"ToggleTab", tab_pressed)
	theme.set_stylebox(&"hover_pressed", &"ToggleTab", tab_pressed)
	theme.set_stylebox(&"disabled", &"ToggleTab", tab_normal)
	theme.set_stylebox(&"focus", &"ToggleTab", focus_box(0))
	# ButtonTool : bouton secondaire haut de la barre d'outils (capitales, tracking).
	theme.set_type_variation(&"ButtonTool", &"Button")
	_set_font_if(theme, &"ButtonTool", fonts, &"ui_button")
	theme.set_font_size(&"font_size", &"ButtonTool", fs(DS.FS_BODY))
	_set_button_colors(theme, &"ButtonTool", DS.TEXT_PRIMARY, DS.TEXT_PRIMARY)
	theme.set_color(&"font_pressed_color", &"ButtonTool", DS.ACCENT_CYAN)
	theme.set_color(&"font_hover_pressed_color", &"ButtonTool", DS.ACCENT_CYAN)
	var tool_normal: StyleBoxFlat = chamfer_box(DS.BG_PANEL, DS.TEXT_MUTED, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	var tool_hover: StyleBoxFlat = _with_glow(chamfer_box(DS.CYAN_12, DS.ACCENT_CYAN, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0), DS.CYAN_24, DS.GLOW_1)
	var tool_pressed: StyleBoxFlat = chamfer_box(DS.BG_PANEL.blend(DS.CYAN_12), DS.ACCENT_CYAN, DS.BORDER_STRONG, DS.CHAMFER_M, 0)
	var tool_disabled: StyleBoxFlat = chamfer_box(DS.DISABLED_BG, DS.LINE_SUBTLE, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	for box: StyleBoxFlat in [tool_normal, tool_hover, tool_pressed, tool_disabled]:
		_set_button_margins(box, DS.SPACE_5, DS.SPACE_3)
	theme.set_stylebox(&"normal", &"ButtonTool", tool_normal)
	theme.set_stylebox(&"hover", &"ButtonTool", tool_hover)
	theme.set_stylebox(&"pressed", &"ButtonTool", tool_pressed)
	theme.set_stylebox(&"hover_pressed", &"ButtonTool", tool_pressed)
	theme.set_stylebox(&"disabled", &"ButtonTool", tool_disabled)
	theme.set_stylebox(&"focus", &"ButtonTool", focus_box(DS.CHAMFER_M))
	theme.set_constant(&"h_separation", &"ButtonTool", DS.SPACE_3)
	# ButtonQuestion : option de réponse/question numérotée (DS §7.10).
	theme.set_type_variation(&"ButtonQuestion", &"Button")
	_set_font_if(theme, &"ButtonQuestion", fonts, &"ui")
	theme.set_font_size(&"font_size", &"ButtonQuestion", fs(DS.FS_BODY_S))
	_set_button_colors(theme, &"ButtonQuestion", DS.TEXT_PRIMARY, DS.TEXT_PRIMARY)
	var q_normal: StyleBoxFlat = chamfer_box(DS.BG_ELEVATED, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0)
	var q_hover: StyleBoxFlat = chamfer_box(DS.BG_ELEVATED.blend(DS.CYAN_12), DS.ACCENT_CYAN, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0)
	var q_disabled: StyleBoxFlat = chamfer_box(DS.DISABLED_BG, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0)
	for box: StyleBoxFlat in [q_normal, q_hover, q_disabled]:
		_set_button_margins(box, DS.SPACE_3, DS.SPACE_2)
	theme.set_stylebox(&"normal", &"ButtonQuestion", q_normal)
	theme.set_stylebox(&"hover", &"ButtonQuestion", q_hover)
	theme.set_stylebox(&"pressed", &"ButtonQuestion", q_hover)
	theme.set_stylebox(&"hover_pressed", &"ButtonQuestion", q_hover)
	theme.set_stylebox(&"disabled", &"ButtonQuestion", q_disabled)
	theme.set_stylebox(&"focus", &"ButtonQuestion", focus_box(DS.CHAMFER_S))

	# --- Défilement discret (Rulebook) ------------------------------------------
	var grabber: StyleBoxFlat = _flat_box(DS.LINE_SUBTLE, DS.LINE_SUBTLE, 0, 0)
	var grabber_hot: StyleBoxFlat = _flat_box(DS.CYAN_40, DS.CYAN_40, 0, 0)
	var track: StyleBoxFlat = _flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	track.content_margin_left = DS.SPACE_1
	theme.set_stylebox(&"grabber", &"VScrollBar", grabber)
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", grabber_hot)
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", grabber_hot)
	theme.set_stylebox(&"scroll", &"VScrollBar", track)
	theme.set_stylebox(&"scroll_focus", &"VScrollBar", track)
	theme.set_color(&"font_color", &"TooltipLabel", DS.TEXT_PRIMARY)
	theme.set_stylebox(&"panel", &"TooltipPanel", chamfer_box(DS.BG_ELEVATED, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, DS.SPACE_2, true))


## Boîte rectangulaire (pas de chanfrein) avec bordure haute/basse optionnelle.
static func _flat_box(bg: Color, border: Color, top: int, bottom: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_top = top
	box.border_width_bottom = bottom
	return box


static func _keycap_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = chamfer_box(DS.BG_VOID, DS.LINE_SUBTLE, DS.BORDER_HAIRLINE, DS.CHAMFER_S, 0, true)
	box.content_margin_left = DS.SPACE_2
	box.content_margin_right = DS.SPACE_2
	box.content_margin_top = DS.SPACE_1
	box.content_margin_bottom = DS.SPACE_1
	return box


## Carte avec liseré gauche (RuleCard « NOUVEAU », toasts, questions).
static func _left_bar_box(bg: Color, bar: Color, width: int = DS.BORDER_STRONG) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = bar
	box.border_width_left = width
	box.content_margin_left = DS.SPACE_4
	box.content_margin_right = DS.SPACE_4
	box.content_margin_top = DS.SPACE_3
	box.content_margin_bottom = DS.SPACE_3
	return box


static func _rule_card_box(bg: Color, bar: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = _left_bar_box(bg, bar, DS.BORDER_STRONG if bar.a > 0.0 else 0)
	box.content_margin_left = DS.SPACE_3
	box.content_margin_right = DS.SPACE_3
	box.content_margin_top = DS.SPACE_2
	box.content_margin_bottom = DS.SPACE_2
	return box
