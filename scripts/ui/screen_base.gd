## Base des écrans plein cadre du jour (UI_FLOW §8) : briefing, bilan de
## shift, soirée, fin — et du menu pause.
##
## - Couvre tout l'écran au-dessus de la scène (voile `DS.BG_VOID` opaque ou
##   `DS.SCRIM`), capte la souris, porte son propre thème DS reconstruit quand
##   `Settings.text_scale` change (et selon le plancher Steam Deck, D-023).
## - Entrée en fondu + légère montée (`DS.DUR_SLOW`, `ease.out`) ; fondu simple
##   court si « réduire les animations » (DS §8.3) — l'input n'est jamais bloqué.
## - Petits constructeurs DS (`label`, `eyebrow`, `section`, `rule_line`,
##   `stat_tile`, `button`…) partagés par les écrans.
## - Fond : grille fine `line.subtle` et équerres d'angle (décor, jamais cyan).
class_name ScreenBase
extends Control

## Émis quand l'écran est fermé (bouton principal) ; `choice` dépend de l'écran.
signal finished(choice: StringName)

## Marges d'écran (DS §4.1 : 48 px de sécurité à 1080p).
const SCREEN_MARGIN_X: int = 96
const SCREEN_MARGIN_Y: int = 64
## Pas de la grille de fond (multiple de 4).
const GRID_STEP: float = 48.0
## Longueur des équerres d'angle.
const BRACKET: float = 28.0

## Opaque (écrans de jour) ou voile 72 % (pause, par-dessus le guichet).
var opaque: bool = true
var _root_margin: MarginContainer = null
var _applied_min_px: int = -1
## Focus d'appoint et défilement à la manette (M11).
var focus_guard: FocusGuard = null
var _closing: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	_apply_theme()
	EventBus.settings_changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	InputPrompts.ensure(get_tree())
	_build()
	# Manette / clavier : une direction sans focus le rend au contrôle par
	# défaut de l'écran ; stick droit / Pg↑ Pg↓ font défiler (UI_FLOW §9).
	focus_guard = FocusGuard.attach(self, default_focus)
	_appear()


## À surcharger : contrôle qui reçoit le focus par défaut (manette, clavier).
## Null : premier contrôle focalisable de l'écran.
func default_focus() -> Control:
	return null


## À surcharger : construit le contenu (appelé une fois, dans `_ready`).
func _build() -> void:
	pass


## Conteneur racine avec les marges d'écran.
func root_box() -> MarginContainer:
	if _root_margin == null:
		_root_margin = MarginContainer.new()
		_root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root_margin.add_theme_constant_override("margin_left", SCREEN_MARGIN_X)
		_root_margin.add_theme_constant_override("margin_right", SCREEN_MARGIN_X)
		_root_margin.add_theme_constant_override("margin_top", SCREEN_MARGIN_Y)
		_root_margin.add_theme_constant_override("margin_bottom", SCREEN_MARGIN_Y)
		add_child(_root_margin)
	return _root_margin


func close(choice: StringName = &"") -> void:
	if _closing:
		return
	_closing = true
	finished.emit(choice)
	queue_free()


func is_closing() -> bool:
	return _closing


# ---------------------------------------------------------------------------
# Thème, apparition
# ---------------------------------------------------------------------------

func _min_text_px() -> int:
	if not is_inside_tree():
		return 0
	return ThemeBuilder.min_px_for(get_viewport().get_final_transform().get_scale().x)


func _apply_theme() -> void:
	_applied_min_px = _min_text_px()
	theme = ThemeBuilder.build(Settings.text_scale, _applied_min_px)


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == Settings.KEY_TEXT_SCALE:
		_apply_theme()
	elif key == Settings.KEY_COLOR_VISION:
		# Palette changée (DESIGN_SYSTEM §2.5) : thème reconstruit, tracés redessinés.
		_apply_theme()
		propagate_call(&"queue_redraw")


func _on_viewport_resized() -> void:
	if _min_text_px() != _applied_min_px:
		_apply_theme()


func _appear() -> void:
	if Settings.reduce_motion or Settings.fx_intensity <= 0.0:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, DS.DUR_FAST)
		return
	modulate.a = 0.0
	var content: Control = _root_margin
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, DS.DUR_SLOW)
	if content != null:
		content.position.y = DS.SPACE_2
		tween.tween_property(content, "position:y", 0.0, DS.DUR_SLOW)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DS.BG_VOID if opaque else DS.SCRIM)
	if not opaque:
		return
	var grid: Color = Palette.LINE_SUBTLE
	grid.a = 0.35
	var x: float = GRID_STEP
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid, 1.0)
		x += GRID_STEP
	var y: float = GRID_STEP
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), grid, 1.0)
		y += GRID_STEP
	# Équerres d'angle (cadre de « terminal » Consortium).
	var inset: Vector2 = Vector2(SCREEN_MARGIN_X * 0.5, SCREEN_MARGIN_Y * 0.5)
	var corners: Array[Vector2] = [inset, Vector2(size.x - inset.x, inset.y),
			Vector2(inset.x, size.y - inset.y), size - inset]
	for i: int in corners.size():
		var c: Vector2 = corners[i]
		var sx: float = 1.0 if i % 2 == 0 else -1.0
		var sy: float = 1.0 if i < 2 else -1.0
		draw_line(c, c + Vector2(BRACKET * sx, 0.0), DS.TEXT_MUTED, 1.0)
		draw_line(c, c + Vector2(0.0, BRACKET * sy), DS.TEXT_MUTED, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# ---------------------------------------------------------------------------
# Constructeurs DS
# ---------------------------------------------------------------------------

static func label(text: String, variation: StringName = &"BodyLabel", color: Variant = null) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color is Color:
		var c: Color = color
		l.add_theme_color_override(&"font_color", c)
	return l


static func wrapped(text: String, variation: StringName = &"BodyLabel", color: Variant = null) -> Label:
	var l: Label = label(text, variation, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120.0
	return l


## Sur-titre en capitales (label DS, tracking).
static func eyebrow(text: String, color: Color = Palette.TEXT_SECONDARY) -> Label:
	var l: Label = label(text, &"DocFieldLabel", color)
	l.uppercase = true
	return l


static func vbox(separation: int = DS.SPACE_4) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int = DS.SPACE_4) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box


static func panel(variation: StringName = &"ElevatedCard") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func spacer(expand_h: bool = true, expand_v: bool = false) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand_v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Filet horizontal `line.subtle` (ou couleur donnée).
static func rule_line(color: Color = Palette.LINE_SUBTLE, thickness: int = DS.BORDER_HAIRLINE) -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, thickness)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## En-tête de section : icône + titre en capitales + filet qui remplit la ligne
## + compteur optionnel.
static func section(title: String, icon: UiIcon.Kind = UiIcon.Kind.DIAMOND, color: Color = Palette.TEXT_SECONDARY,
		side: String = "") -> HBoxContainer:
	var row: HBoxContainer = hbox(DS.SPACE_2)
	row.add_child(UiIcon.make(icon, color, DS.ICON_S))
	row.add_child(label(title, &"PanelTitle", DS.TEXT_PRIMARY))
	var line: ColorRect = rule_line()
	line.custom_minimum_size = Vector2(DS.SPACE_2, DS.BORDER_HAIRLINE)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	if not side.is_empty():
		row.add_child(SideLabel.make(side, &"DataSmall", color))
	return row


## Tuile de statistique : libellé, valeur mono, détail.
static func stat_tile(caption: String, value: String, detail: String = "", accent: Color = DS.TEXT_PRIMARY,
		icon: Variant = null) -> PanelContainer:
	var tile: PanelContainer = panel(&"ElevatedCard")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = vbox(DS.SPACE_1)
	tile.add_child(box)
	var head: HBoxContainer = hbox(DS.SPACE_2)
	box.add_child(head)
	if icon is int:
		var kind: UiIcon.Kind = icon
		head.add_child(UiIcon.make(kind, accent, DS.ICON_S))
	head.add_child(eyebrow(caption))
	var value_label: Label = label(value, &"TimerCompact", accent)
	box.add_child(value_label)
	if not detail.is_empty():
		# Replié plutôt qu'élargi : trois tuiles côte à côte tiennent au Deck
		# (plancher de texte 18 px, QA-001).
		box.add_child(wrapped(detail, &"CaptionLabel"))
	return tile


static func button(text: String, variation: StringName = &"ButtonTool") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, DS.HIT_TARGET_MIN + DS.SPACE_1)
	b.focus_mode = Control.FOCUS_ALL
	return b


## Puce d'état : icône + texte en capitales sur fond teinté (couleur sémantique).
static func chip(text: String, icon: UiIcon.Kind, color: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: Color = color
	bg.a = 0.12
	p.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(bg, color, DS.BORDER_HAIRLINE, DS.CHAMFER_S, DS.SPACE_1))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row: HBoxContainer = hbox(DS.SPACE_1)
	p.add_child(row)
	row.add_child(UiIcon.make(icon, color, DS.ICON_S))
	var l: Label = label(text, &"DocFieldLabel", color)
	l.uppercase = true
	row.add_child(l)
	return p


## « 42 ₵ », « −5 ₵ », « +5 ₵ » (signe forcé si `signed`) ; M15 : selon la
## langue (« ₵42 » en anglais, séparateur de milliers, `Localization.credits`).
static func credits(amount: int, signed: bool = false) -> String:
	return UiText.remember_call(Localization.credits(amount, signed), Localization.credits.bind(amount, signed))


## M15 : texte d'appoint au bout d'une rangée (côté d'un en-tête de section) :
## jamais plus large que la place laissée par ses voisins — tronqué « … »
## (texte complet en infobulle) au lieu d'élargir l'écran (anglais,
## pseudo-localisation, texte 150 %).
class SideLabel extends Label:
	static func make(p_text: String, variation: StringName, color: Color) -> SideLabel:
		var l: SideLabel = SideLabel.new()
		l.theme_type_variation = variation
		l.text = p_text
		l.add_theme_color_override(&"font_color", color)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return l

	func _ready() -> void:
		var parent: Control = get_parent() as Control
		if parent != null:
			parent.resized.connect(_fit)
		refit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_THEME_CHANGED:
			refit()

	## Contrat `Localization` : texte retraduit → largeur recalculée.
	func on_language_changed() -> void:
		refit()

	## Recalcule maintenant puis après la mise en page du parent (sa largeur
	## n'est connue qu'après le tri de son conteneur).
	func refit() -> void:
		if not is_inside_tree():
			return
		_fit()
		await get_tree().process_frame
		if is_inside_tree():
			_fit()

	## Vrai si un conteneur impose sa largeur à `row` (colonne qui remplit, ou
	## case qui s'étend dans une rangée).
	static func _width_bounded(row: Control) -> bool:
		var holder: Node = row.get_parent()
		if holder is VBoxContainer or holder is MarginContainer or holder is PanelContainer or holder is ScrollContainer:
			return (row.size_flags_horizontal & Control.SIZE_FILL) != 0
		if holder is HBoxContainer or holder is GridContainer:
			return (row.size_flags_horizontal & Control.SIZE_EXPAND) != 0
		return false

	## Largeur minimale = place laissée par les voisins (jamais plus que le
	## texte entier) ; la largeur du parent ne dépend donc jamais de ce texte.
	func _fit() -> void:
		var font: Font = get_theme_font(&"font")
		if font == null:
			return
		var full: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size(&"font_size")).x
		var parent: BoxContainer = get_parent() as BoxContainer
		var room: float = full
		# Rangée à la taille de son contenu (aucun conteneur ne borne sa
		# largeur) : texte entier, comme avant M15.
		var content_sized: bool = parent != null and not _width_bounded(parent)
		if parent != null and parent.size.x > 0.0 and not content_sized:
			var used: float = 0.0
			var count: int = 0
			for child: Node in parent.get_children():
				var c: Control = child as Control
				if c == null or not c.visible or c == self:
					continue
				used += c.get_combined_minimum_size().x
				count += 1
			used += parent.get_theme_constant(&"separation") * count
			room = parent.size.x - used
		elif parent != null and parent.size.x <= 0.0:
			room = minf(full, DS.SPACE_16) # premier passage : pas encore de largeur
		var width: float = clampf(room, minf(full, DS.SPACE_8), ceilf(full))
		tooltip_text = text if width + 0.5 < full else ""
		if not is_equal_approx(custom_minimum_size.x, width):
			custom_minimum_size.x = width
