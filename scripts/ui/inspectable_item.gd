## Élément sélectionnable en Mode Inspection (DS §7.2, UI_FLOW §3) : champ de
## document, date du jour ou règle du Rulebook. Porte un `FieldRef` et dessine
## ses états : default · hover · focus · selected (A) · disabled · flagged ·
## concordant. Le contenu (libellé, valeur, texte de règle) est fourni par les
## sous-classes sous forme d'enfants, dessinés **au-dessus** de ces fonds.
##
## Hors Mode Inspection l'élément est transparent aux clics (le document
## parent reste déplaçable).
class_name InspectableItem
extends Control

## Clic / Entrée / Ⓐ sur l'élément en Mode Inspection.
signal picked(item: InspectableItem)

## Pas des hachures « flagged » (px).
const HATCH_STEP: float = 8.0
## Pas des pointillés du soulignement (px).
const DASH: float = 4.0

var ref: FieldRef = null
## Sélectionnable en Mode Inspection (`FieldDef.comparable`).
var comparable: bool = true
## Libellé lisible (lecteur d'écran, infobulle, messages).
var display_label: String = ""

var inspection_active: bool = false
var selected: bool = false
## Numéros des discordances confirmées qui citent cet élément (①②…).
var flag_numbers: Array[int] = []
## Comparaison concordante récente (coche temporaire).
var concordant: bool = false
## Mise en avant temporaire (lien existant re-cliqué, règle invoquée).
var pulse: float = 0.0
## Intensité des effets (Settings.fx_intensity) : glow et hachures animées.
var fx_intensity: float = 1.0

var _hovered: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func is_flagged() -> bool:
	return not flag_numbers.is_empty()


func set_inspection_active(active: bool) -> void:
	inspection_active = active
	var interactive: bool = active and comparable
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_CROSS if interactive else Control.CURSOR_ARROW
	if not interactive and has_focus():
		release_focus()
	_hovered = _hovered and interactive
	_refresh_content()
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	_refresh_content()
	queue_redraw()


func add_flag(number: int) -> void:
	if not flag_numbers.has(number):
		flag_numbers.append(number)
	_refresh_content()
	queue_redraw()


func clear_marks() -> void:
	selected = false
	flag_numbers.clear()
	concordant = false
	pulse = 0.0
	_refresh_content()
	queue_redraw()


func set_concordant(value: bool) -> void:
	concordant = value
	queue_redraw()


func set_pulse(value: float) -> void:
	pulse = value
	queue_redraw()


## Point d'ancrage d'un lien (global) : milieu du bord tourné vers `toward`.
func anchor_point(toward: Vector2) -> Vector2:
	var rect: Rect2 = get_global_rect()
	var center: Vector2 = rect.get_center()
	if absf(toward.x - center.x) < rect.size.x * 0.5:
		return Vector2(center.x, rect.position.y if toward.y < center.y else rect.end.y)
	return Vector2(rect.end.x if toward.x > center.x else rect.position.x, center.y)


func _gui_input(event: InputEvent) -> void:
	if not (inspection_active and comparable):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
		accept_event()
		picked.emit(self)
		return
	if event.is_action_pressed(&"ui_accept"):
		accept_event()
		picked.emit(self)


func _on_mouse_entered() -> void:
	_hovered = inspection_active and comparable
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


## Rafraîchit les couleurs du contenu selon l'état (sous-classes).
func _refresh_content() -> void:
	pass


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var flagged: bool = is_flagged()
	if flagged:
		draw_rect(rect, Palette.MAGENTA_12)
		_draw_hatching(rect, Palette.MAGENTA_24)
		draw_rect(rect, Palette.ACCENT_MAGENTA, false, DS.BORDER_STRONG)
	elif selected:
		draw_rect(rect, DS.CYAN_12)
		draw_rect(rect, DS.ACCENT_CYAN, false, DS.BORDER_STRONG)
	elif _hovered:
		draw_rect(rect, DS.CYAN_08)
	if pulse > 0.0:
		var glow: Color = Palette.MAGENTA_60 if flagged else DS.CYAN_60
		glow.a *= pulse
		draw_rect(rect.grow(DS.SPACE_1 * pulse), glow, false, DS.BORDER_STRONG)
	if has_focus():
		draw_rect(rect.grow(DS.FOCUS_RING_OFFSET), DS.ACCENT_CYAN, false, DS.FOCUS_RING_WIDTH)
	_draw_underline(rect)
	if concordant and not flagged:
		var check: Rect2 = Rect2(Vector2(rect.end.x - DS.ICON_S - DS.SPACE_1, DS.SPACE_1), Vector2(DS.ICON_S, DS.ICON_S))
		UiIcon.draw_icon(self, UiIcon.Kind.CHECK, check, DS.ACCENT_CYAN)
	if flagged:
		var icon: Rect2 = Rect2(Vector2(rect.end.x - DS.ICON_M - DS.SPACE_1, rect.get_center().y - DS.ICON_M * 0.5), Vector2(DS.ICON_M, DS.ICON_M))
		UiIcon.draw_icon(self, UiIcon.Kind.DISCORDANCE, icon, Palette.ACCENT_MAGENTA)
		var x: float = rect.end.x
		for number: int in flag_numbers:
			draw_number_badge(self, Vector2(x, 0.0), number, Palette.ACCENT_MAGENTA)
			x -= DS.SPACE_5
	elif selected:
		draw_letter_badge(self, Vector2(rect.end.x, 0.0), "A", DS.ACCENT_CYAN)


## Soulignement pointillé : repos (hairline), comparable en inspection (cyan 40 %),
## survol (cyan plein). Rien sur un élément non comparable.
func _draw_underline(rect: Rect2) -> void:
	if is_flagged() or selected:
		return
	var color: Color = Palette.LINE_SUBTLE
	if inspection_active:
		if not comparable:
			return
		color = DS.ACCENT_CYAN if _hovered else DS.CYAN_40
	var y: float = rect.end.y - 0.5
	draw_dashed_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0, DASH, true)


func _draw_hatching(rect: Rect2, color: Color) -> void:
	var h: float = rect.size.y
	var x: float = -h
	while x < rect.size.x:
		var a: Vector2 = Vector2(x, h)
		var b: Vector2 = Vector2(x + h, 0.0)
		var seg: PackedVector2Array = clip_segment(a, b, rect)
		if seg.size() == 2:
			draw_line(seg[0], seg[1], color, 1.0)
		x += HATCH_STEP


## Segment [a, b] découpé par `rect` (Liang–Barsky) ; vide s'il est dehors.
static func clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> PackedVector2Array:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector2 = b - a
	var p: Array[float] = [-d.x, d.x, -d.y, d.y]
	var q: Array[float] = [a.x - rect.position.x, rect.end.x - a.x, a.y - rect.position.y, rect.end.y - a.y]
	for i: int in 4:
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				return PackedVector2Array()
			continue
		var r: float = q[i] / p[i]
		if p[i] < 0.0:
			t0 = maxf(t0, r)
		else:
			t1 = minf(t1, r)
	if t0 > t1:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])


## Pastille losange avec une lettre (« A »), centrée sur le coin `corner`.
static func draw_letter_badge(canvas: CanvasItem, corner: Vector2, letter: String, color: Color) -> void:
	var half: float = DS.SPACE_3
	var center: Vector2 = corner + Vector2(-half * 0.5, half * 0.5)
	var diamond: PackedVector2Array = [center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)]
	canvas.draw_colored_polygon(diamond, color)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = DS.FS_CAPTION
	var control: Control = canvas as Control
	if control != null:
		font = control.get_theme_font(&"font", &"BadgeLabel")
		font_size = control.get_theme_font_size(&"font_size", &"BadgeLabel")
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	canvas.draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DS.TEXT_ON_ACCENT)


## Pastille numérotée d'une discordance (①②…), losange plein.
static func draw_number_badge(canvas: CanvasItem, corner: Vector2, number: int, color: Color) -> void:
	draw_letter_badge(canvas, corner, str(number), color)
